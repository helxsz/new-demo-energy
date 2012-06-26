/*
 EmonTx CT123 example
 
 An example sketch for the emontx module for
 CT only electricity monitoring.
 
 Part of the openenergymonitor.org project
 Licence: GNU GPL V3
 
 Authors: Glyn Hudson, Trystan Lea
 Builds upon JeeLabs RF12 library and Arduino
 
*/

const int CT2 = 1;                                                      // Set to 0 to disable CT channel 2
const int CT3 = 0;                                                      // Set to 0 to disable CT channel 3

#define freq RF12_868MHZ                                                // Frequency of RF12B module can be RF12_433MHZ, RF12_868MHZ or RF12_915MHZ. You should use the one matching the module you have.
const int nodeID = 10;                                                  // emonTx RFM12B node ID
const int networkGroup = 1;                                           // emonTx RFM12B wireless network group - needs to be same as emonBase and emonGLCD

const int UNO = 1;                                                      // Set to 0 if your not using the UNO bootloader (i.e using Duemilanove) - All Atmega's shipped from OpenEnergyMonitor come with Arduino Uno bootloader
#include <avr/wdt.h>                                                     

#include <JeeLib.h>                                                     // Download JeeLib: http://github.com/jcw/jeelib
ISR(WDT_vect) { Sleepy::watchdogEvent(); }                              // Attached JeeLib sleep function to Atmega328 watchdog -enables MCU to be put into sleep mode inbetween readings to reduce power consumption 

#include "EmonLib.h"
EnergyMonitor ct1,ct2,ct3;                                              // Create  instances for each CT channel

typedef struct 
{ 
   int power1, power2, battery; 
   //int  power3;
   char mac[12];
} PayloadTX;      // create structure - a neat way of packaging data for RF comms
PayloadTX emontx;                                                       

const int LEDpin = 9;                                                   // On-board emonTx LED 

#include <NanodeUNIO.h>
char mymac[20]  = "004A3";
byte macaddr[6];
void setup() 
{
  Serial.begin(9600);
  getMac();   
  Serial.println("emonTX CT123 example"); 
  Serial.println("OpenEnergyMonitor.org");
             
  ct1.currentTX(1, 115.6);                                              // Setup emonTX CT channel (channel, calibration)
  if (CT2) ct2.currentTX(2, 115.6);
  if (CT3) ct3.currentTX(3, 115.6);
  
  rf12_initialize(nodeID, freq, networkGroup);                          // initialize RFM12B
  rf12_sleep(RF12_SLEEP);

  pinMode(LEDpin, OUTPUT);                                              // Setup indicator LED
  digitalWrite(LEDpin, HIGH);
  
  if (UNO) wdt_enable(WDTO_8S);                                         // Enable anti crash (restart) watchdog if UNO bootloader is selected. Watchdog does not work with duemilanove bootloader                                                             // Restarts emonTx if sketch hangs for more than 8s
}

void getMac()
{
  NanodeUNIO unio(NANODE_MAC_DEVICE);  
  boolean r = true;
  
  Serial.println("Nanode MAC reader\n");
  Serial.print("Reading MAC address... ");
  /*
  r=unio.read(macaddr,NANODE_MAC_ADDRESS,6);
  if (r) 
  {
    Serial.println("success");
    sprintf(mymac,"%02X%02X%02X%02X%02X%02X",
          macaddr[0],macaddr[1],macaddr[2],
          macaddr[3],macaddr[4],macaddr[5]);   
  }
  else 
  {
    Serial.println("failure");
    mymac[0] = '0';
    mymac[1] = '0';    
    mymac[2] = '0';
    mymac[3] = '4';
    mymac[4] = 'A';
    mymac[5] = '3';
    
    for(int i=0;i<6;i++)
    {
      mymac[i+6] = (char)random(48,57);
    }
    mymac[6] = '2';
    mymac[7] = 'C';    
    mymac[8] = '1';
    mymac[9] = '2';
    mymac[10] = '3';
    mymac[11] = '4';    
  }  
 */
  sprintf(mymac,"0000002C1234");  
  //sprintf(mymac,"0000002C5678");
  Serial.print("MAC address is ");
  Serial.println(mymac);
}


void loop() 
{ 
  emontx.power1 = ct1.calcIrms(1480) * 240.0 -30;                           // Calculate CT 1 power
  Serial.print("ct1 ");Serial.print(emontx.power1);                                          // Output to serial  
  if(emontx.power1<0)  emontx.power1=0;
  
  if (CT2) {
    emontx.power2 = ct2.calcIrms(1480) * 240.0;
    Serial.print("   CT2 "); Serial.print(emontx.power2);
    
  } 

  if (CT3) {
    //emontx.power3 = ct3.calcIrms(1480) * 240.0;
    //Serial.print("   CT3 "); Serial.print(emontx.power3);
  } 
  
  //emontx.power1 = random(102,120);
  //emontx.power2 = 0;
  
  
  emontx.battery = ct1.readVcc();
  Serial.println(); delay(100);
  strncpy(emontx.mac, mymac, strlen(mymac));
  send_rf_data();                                                       // *SEND RF DATA* - see emontx_lib
  emontx_sleep(1);                                                      // sleep or delay in seconds - see emontx_lib
  digitalWrite(LEDpin, HIGH); delay(1); digitalWrite(LEDpin, LOW);      // flash LED
  //
}
