/***************************************************************************
 * Script to test wireless communication with the RFM12B tranceiver module
 * with an Arduino or Nanode board.
 *
 * Transmitter - Sends an incrementing number and flashes the LED every second.
 * Puts the ATMega and RFM12B to sleep between sends in case it's running on
 * battery.
 *
 * Ian Chilton <ian@chilton.me.uk>
 * December 2011
 *
 * Requires Arduino version 0022. v1.0 was just released a few days ago so
 * i'll need to update this to work with 1.0.
 *
 * Requires the Ports and RF12 libraries from Jeelabs in your libraries directory:
 *
 * http://jeelabs.org/pub/snapshots/Ports.zip
 * http://jeelabs.org/pub/snapshots/RF12.zip
 *
 * Information on the RF12 library - http://jeelabs.net/projects/11/wiki/RF12
 *
 ***************************************************************************/

#include <Ports.h>
#include <RF12.h>

//---------------------------------------------------------------------
// The temperature and humidity sensor
//---------------------------------------------------------------------
#include <DHT22.h>
#define DHT22_PIN 7// Setup a DHT22 instance


#define RETRY_PERIOD    10  // how soon to retry if ACK didn't come in
#define RETRY_LIMIT     5   // maximum number of times to retry
#define ACK_TIME        10  // number of milliseconds to wait for an ack
#define REPORT_EVERY    5   // report every N measurement cycles

#include <NanodeUNIO.h>
char mymac[20]  = "";
byte macaddr[6];
//-----------------------------------------------------------------------------------------------------------------
//  On RF recieve
//-----------------------------------------------------------------------------------------------------------------
// Use the watchdog to wake the processor from sleep:
ISR(WDT_vect) { Sleepy::watchdogEvent(); }

// Send a single unsigned long:
static unsigned long payload;

typedef struct {
    byte  type;
    byte  data[14];
} Payload;

typedef struct { 
               float temperature, humidity;
               int light;
               char mac[15];
} PayloadTX;

Payload incNodeData;
PayloadTX emontx;   
DHT22 myDHT22(DHT22_PIN);

byte masterNode = 1 ;
int MYNODEID;


MilliTimer ackTimer;
////////////////////////////////////////////
//For more information see www.ladyada.net/learn/sensors/cds.html */
int photocellPin = 0;     // the cell and 10K pulldown are connected to a0
int photocellReading;     // the analog reading from the analog resistor divider

void setup()
{
  // Serial output at 9600 baud:
  Serial.begin(9600);
  
  // LED on Pin Digital 6:
  pinMode(6, OUTPUT);
  pinMode(1, OUTPUT);

  digitalWrite(7, LOW);

  getMac();  
  // Initialize RFM12B as an 868Mhz module and Node 2 + Group 1:
  MYNODEID = random(2, 31);
  rf12_initialize(MYNODEID, RF12_868MHZ, 1); 
  

  Serial.print("myid:");
  Serial.println(MYNODEID);
  digitalWrite(7, HIGH);  

  // DHT22_PIN
  //myDHT22.startPort(DHT22_PIN);  

}


void loop()
{
  // LED OFF:
  digitalWrite(6, LOW);
  //Serial.println("Going to sleep...");
  // Need to flush the serial before we put the ATMega to sleep, otherwise it
  // will get shutdown before it's finished sending:
  Serial.flush();
  delay(2000);
    
  // Power down radio:
  //rf12_sleep(RF12_SLEEP);
  // Sleep for 5s:
  //Sleepy::loseSomeTime(3000);
  // Power back up radio:
  //rf12_sleep(RF12_WAKEUP);
  // LED ON:
  digitalWrite(6, HIGH);
    
  //Serial.println("Woke up...");
  Serial.flush();
  delay(5);
  digitalWrite(1, LOW);
  // Wait until we can send:
  while(!rf12_canSend())
  {
     if (rf12_recvDone() && rf12_crc == 0)
     {
        digitalWrite(1, HIGH);
        Serial.println("receive ////////////////////////////");
        // Copy the received data into payload:
        memcpy(&emontx, (byte*) rf12_data, sizeof(emontx));    
        // Print it out:
        //Serial.print("Received: ");
        byte node_id = (rf12_hdr & 0x1F);
        byte lenfth = rf12_len;
        //Serial.println("received   ////////////////");
        Serial.print(emontx.temperature);Serial.print("    "); 
        Serial.print(emontx.humidity);Serial.print("    ");
        Serial.print( node_id );Serial.print("    ");
        Serial.println(emontx.mac);        
     } 
  }
  // Increment data:
  payload++;
   

  sendSensorData();
 /*
  if (millis() > timer) {
    timer = millis() + 5000;
    Serial.print("polling   timers........................");
    Serial.println( freeRam ());     
  }  
 */
 rf12_recvDone();
}



void getMac()
{
  NanodeUNIO unio(NANODE_MAC_DEVICE);  
  boolean r = true;
  
  Serial.println("Nanode MAC reader\n");
  Serial.print("Reading MAC address... ");
  r=unio.read(macaddr,NANODE_MAC_ADDRESS,6);
  if (r) Serial.println("success");
  else Serial.println("failure");
  sprintf(mymac,"%02X%02X%02X%02X%02X%02X",
          macaddr[0],macaddr[1],macaddr[2],
          macaddr[3],macaddr[4],macaddr[5]);
  
 
  Serial.print("MAC address is ");
  Serial.println(mymac);
}





char str[50]=""; 
void sendSensorData()
{  
  DHT22_ERROR_t errorCode;

  Serial.print("Requesting data...");
  errorCode = myDHT22.readData();
  switch(errorCode)
  {
    case DHT_ERROR_NONE:
      Serial.print("Got Data ");
      Serial.print(myDHT22.getTemperatureC());
      Serial.print("C ");
      Serial.print(myDHT22.getHumidity());
      Serial.println("%");

      sprintf(str,"{\'temperature\':%d,\'humidity\':%d}", (int)myDHT22.getTemperatureC(),(int)myDHT22.getHumidity());   
      readLight();
      emontx.temperature = myDHT22.getTemperatureC();
      emontx.humidity = myDHT22.getHumidity();
      Serial.print(" emontx.level = ");Serial.println( emontx.light );            
      sprintf(str,"{\'mac\':%d}",12);   
      strncpy(emontx.mac, mymac, strlen(mymac));
  
     break; 
    
    case DHT_ERROR_CHECKSUM:
      Serial.print("check sum error ");
      Serial.print(myDHT22.getTemperatureC());
      Serial.print("C ");
      Serial.print(myDHT22.getHumidity());
      Serial.println("%");
      break;
    case DHT_BUS_HUNG:
      Serial.println("BUS Hung ");
      emontx.temperature = -1;
      emontx.humidity = -1;
      emontx.light = -1;
      /*
      emontx.mac[0] = mymac[0];
      emontx.mac[1] = mymac[1];
      emontx.mac[2] = mymac[2];
      emontx.mac[3] = mymac[3];
      emontx.mac[4] = mymac[4];
      emontx.mac[5] = mymac[5];
      */
      
      sprintf(str,"{\'mac\':%d}",12);   
      strncpy(emontx.mac, mymac, strlen(mymac));
      
      // http://forum.jeelabs.net/node/700
      /* http://www.22balmoralroad.net/wordpress/wp-content/uploads/roomNode.pde
      
      // see http://talk.jeelabs.net/topic/811#post-4712

      while (!ackTimer.poll(ACK_TIME)) 
      {
        if (rf12_recvDone() && rf12_crc == 0 &&rf12_hdr == (RF12_HDR_DST | RF12_HDR_CTL | MYNODEID))
        Serial.println(100);
      }
        */          
      break;

      Serial.println("Not Present ");
      break;
    case DHT_ERROR_ACK_TOO_LONG:
      Serial.println("ACK time out ");
      break;
    case DHT_ERROR_SYNC_TIMEOUT:
      Serial.println("Sync Timeout ");
      break;
    case DHT_ERROR_DATA_TIMEOUT:
      Serial.println("Data Timeout ");
      break;
    case DHT_ERROR_TOOQUICK:
      Serial.println("Polled to quick ");
      break;
  }  
   //(RF12_HDR_DST | masterNode)
   rf12_sendStart(0, &emontx, sizeof emontx);
   rf12_sendWait(2);
   Serial.print("Sent ");
   Serial.println(payload);
  
  memset(&str,0,strlen(str));
}


int readLight()
{
  int level;
  photocellReading = analogRead(photocellPin);  
 
  Serial.print("Analog reading = ");
  Serial.print(photocellReading);     // the raw analog reading
 
  level = map(photocellReading,0,1023,0,100);
  // We'll have a few threshholds, qualitatively determined
  if (photocellReading < 10) {
    Serial.print(" - Dark  ");
  } else if (photocellReading < 200) {
    Serial.print(" - Dim  ");
  } else if (photocellReading < 500) {
    Serial.print(" - Light  ");
  } else if (photocellReading < 800) {
    Serial.print(" - Bright  ");
  } else {
    Serial.print(" - Very bright  ");

  }
  Serial.println(level);
  emontx.light = level;

  return level;
}


static int freeRam () {
  extern int __heap_start, *__brkval; 
  int v; 
  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval); 	
}
