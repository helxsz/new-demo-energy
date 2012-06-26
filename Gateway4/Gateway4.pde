///http://arduino.cc/playground/Main/FloatToString
//#include <sha1.h>
//--------------------------------------------------------------------------
// Ethernet
//--------------------------------------------------------------------------
#include <EtherCard.h>
#include <NanodeUNIO.h>

// ethernet interface mac address
static byte mymac[] = { 0x74,0x69,0x69,0x2D,0x30,0x31 };
// ethernet interface ip address
 byte myip[] = { 192,168,24,203 };
// gateway ip address
static byte gwip[] = { 192,168,24,1 };
// remote website ip address and port

// remote website name
char *token = "VnXY3UWJ";
char website[] PROGMEM = "mashweb.fokus.fraunhofer.de";
#define APIKEY  "b872449aa3ba74458383a798b740a378"

// buffer 
byte Ethernet::buffer[320];   // a very small tcp/ip buffer is enough here
static BufferFiller bfill;  // used as cursor while filling the buffer
char line_buf[150];                        // Used to store line of http reply header
static uint32_t timer;/////////////////////

//https://github.com/thiseldo/EtherCardExamples/blob/master/EtherCard_RESTduino/EtherCard_RESTduino.ino
// https://github.com/openenergymonitor/NanodeRF/blob/master/NanodeRF_singleCT_RTCrelay_GLCDtemp/NanodeRF_singleCT_RTCrelay_GLCDtemp.ino

#include <RF12.h>
#include <JeeLib.h>
#include <avr/pgmspace.h>

#define DEBUG 0

#include <SPI.h>
#include <SRAM9.h>
typedef struct {
    char id[12];             /* id */
    byte types[5];              /* type */    
    byte channel;  // 0 -31
}Mote;
Mote mote;
byte device_num =0;
#define type_mote 0;
#define type_actuator 1;



int INDEX_MOTE_LENGTH = 500;
int LIST_MOTE_BEGIN = 1000;
////////////////////////////////////////////
#include <avr/eeprom.h>
#define CONFIG_EEPROM_ADDR ((byte*) 0x10)

// configuration, as stored in EEPROM
struct Config {
    byte band;
    byte group;
    byte valid; // keep this as last byte
} config;

static void loadConfig() {
    for (byte i = 0; i < sizeof config; ++i)
        ((byte*) &config)[i] = eeprom_read_byte(CONFIG_EEPROM_ADDR + i);
    if (config.valid != 253) {
        config.valid = 253;
        config.band = 8;
        config.group = 1;
    }
    byte freq = config.band == 4 ? RF12_433MHZ :
                config.band == 8 ? RF12_868MHZ :
                                   RF12_915MHZ;
}

static void saveConfig() {
    for (byte i = 0; i < sizeof config; ++i)
        eeprom_write_byte(CONFIG_EEPROM_ADDR + i, ((byte*) &config)[i]);
}
//
#define RS_EEPROM_ADDR ((byte*) 0x80)

// configuration, as stored in EEPROM
struct RS {
    byte hisip[4];
} rs;

static void loadRS() {
    for (byte i = 0; i < sizeof rs; ++i)
        ((byte*) &rs)[i] = eeprom_read_byte(RS_EEPROM_ADDR + i);
        Serial.println(rs.hisip[0],HEX);
        Serial.println(rs.hisip[1],HEX);
        
        Serial.println(rs.hisip[2],HEX);
        Serial.println(rs.hisip[3],HEX);
    if(rs.hisip[2]==0){   
      Serial.println("not, load");
       rs.hisip[0] = 192;
       rs.hisip[1] = 168;
       rs.hisip[2] = 210;
       rs.hisip[3] = 6; 
    }    
       
}

static void saveRS(byte *a) {
  Serial.println(sizeof a);
    for (byte i = 0; i < 4; ++i)
    {
      Serial.println(a[i]);
      eeprom_write_byte(RS_EEPROM_ADDR + i, a[i]);
    }
}

////////////////////////////////////////////
#include <avr/pgmspace.h>
prog_char type_temp[] PROGMEM = "temperature";   // "String 0" etc are strings to store - change to suit.
prog_char type_hum[] PROGMEM = "humidity";
prog_char type_light[] PROGMEM = "light";
prog_char type_volt[] PROGMEM = "voltage";
prog_char type_elec[] PROGMEM = "electrcity";

prog_char type_lamb[] PROGMEM = "http://webinos.org/api/motes.lamb";

PROGMEM const char *sensor_table[] = 	   // change "string_table" name to suit
{   
  type_temp,
  type_hum,
  type_light,
  type_volt,
  type_elec 
};

PROGMEM const char *actuator_table[] = 	   // change "string_table" name to suit
{   
  type_lamb
};


byte s_temp = 0;
byte s_hum =1;
byte s_light =2;
byte s_volt =3;
byte s_elec =4;

byte s_lamb =10;


prog_char sramfail[] PROGMEM       = "SRAM failure";
prog_char freemem[] PROGMEM        = "Free Mem: ";
prog_char okmsg[] PROGMEM	   = "OK";
prog_char badlinemsg[]	PROGMEM	   = "Invalid line number";
prog_char invalidexprmsg[] PROGMEM = "Invalid expression";
prog_char syntaxmsg[] PROGMEM      = "Syntax Error";
prog_char badinputmsg[] PROGMEM    = "\nBad number";
prog_char nomemmsg[] PROGMEM       = "Not enough memory!";
prog_char initmsg[] PROGMEM        = "NanodeBasic V0.5";
prog_char memorymsg[] PROGMEM      = " bytes";
prog_char breakmsg[] PROGMEM       = "break!";
prog_char stackstuffedmsg[] PROGMEM = "Stack is stuffed!\n";
prog_char badportmsg[] PROGMEM        = "Invalid I/O port";


////////////////////////////////////////////
#define MYNODE 1            
#define freq RF12_868MHZ      // frequency
#define group 1            // network group
//---------------------------------------------------
// Data structures for transfering data between units
//---------------------------------------------------
typedef struct { 
               float temperature, humidity;
               int light;
               char mac[15]; 
} PayloadTX;
PayloadTX emonen;    

// The RF12 data payload - a neat way of packaging data when sending via RF - JeeLabs
// must be same structure as transmitted from emonTx
typedef struct
{
  int ct1;		     // current transformer 1
  int ct2;                 // current transformer 2 - un-comment as appropriate 
  //int ct3;                 // current transformer 1 - un-comment as appropriate 
  int supplyV;               // emontx voltage
  char mac[12]; 
} Payload;
Payload emontx;     

//---------------------------------------------------------------------
// xxtea
//---------------------------------------------------------------------



 #define KEY_SIZE 1   //set acording to your needs
#define BLOCK_SIZE (128/8)

uint32_t k[KEY_SIZE]={0x6f6e6e61 };
//, 0x676e6979, 0x6e6f6d20, 0x0079656b
//#define	BLOCK_SIZE	(128/8)

#define DELTA 0x9e3779b9
#define MX ((z>>5^y<<2) + (y>>3^z<<4)) ^ ((sum^y) + (k[(p&3)^e] ^ z));

//---------------------------------------------------------------------
// The PacketBuffer class is used to generate the json string that is send via ethernet - JeeLabs
//---------------------------------------------------------------------




const byte redLED = 6;                     // NanodeRF RED indicator LED
const byte greenLED = 5;                   // NanodeRF GREEN indicator LED

byte ethernet_error = 0;                   // Etherent (controller/DHCP) error flag
byte rf_error = 0;                         // RF error flag - high when no data received 
byte ethernet_requests = 0;                // count ethernet requests without reply                 

byte dhcp_status = 0;
byte dns_status = 0;

byte emonglcd_rx = 0;                      // Used to indicate that emonglcd data is available
byte data_ready=0;                         // Used to signal that emonen data is ready to be sent
unsigned long last_rf;                    // Used to check for regular emonen data - otherwise error


char okHeader[] PROGMEM =
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Pragma: no-cache\r\n"
    "\r\n" ;
 
char responseHeader[] PROGMEM =
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Access-Control-Allow-Origin: *\r\n"
    "\r\n" ;


// called when the client request is complete
static void my_result_cb (byte status, word off, word len) {
  //Serial.print("<<< reply ");Serial.print(millis() - timer);Serial.println(" ms");
  Serial.println("server reply");
  //
  //Serial.println((const char*) Ethernet::buffer + off);
}


uint16_t http200ok(void)
{
  bfill = ether.tcpOffset();
  bfill.emit_p(PSTR(
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Pragma: no-cache\r\n"
    "\r\n"));
  return bfill.position();
}

uint16_t http404(void)
{
  bfill = ether.tcpOffset();
  bfill.emit_p(PSTR(
    "HTTP/1.0 404 OK\r\n"
    "Content-Type: text/html\r\n"
    "\r\n"));
  return bfill.position();
}

// prepare the webpage by writing the data to the tcp send buffer
uint16_t print_webpage()
{
  bfill = ether.tcpOffset();
 
  bfill.emit_p(PSTR(
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Pragma: no-cache\r\n"
    "\r\n"
    "<html><body>Invalid option selected</body></html>"));
    /*
        bfill.emit_p( PSTR (
       "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Pragma: no-cache\r\n"
    "\r\n" 
      "<p><em>"    // $F = htmlheader in flash memory
      "Reading of A0 input pin =  <br/><br/>"
      "The LED is $S <br/><br/>"
      "Entered in text box = $S <br/>"
      "</em></p><div style='text-align: center;'><p><em>"
      "<A HREF='?cmd=on'>Turn on</A> <br/>"
      "<A HREF='?cmd=off'>Turn off</A> <br/>"
      "<A HREF='?cmd=blank'>Refresh Page</A> <br/>"
      "<FORM>Test input box <input type=text name=boxa size=10> <input type=submit value=Enter> </form> <br/><br/>"
      "<FORM METHOD=LINK ACTION='http://www.alanesq.com/arduino.htm'> <INPUT TYPE=submit VALUE='More Info Here'> </FORM>"
      "</em></p></body></html>" 
    )  ); */
  return bfill.position();
  
  /*http://alanesq.com/arduino/ethernet_test.txt
   
   */
}
     
void getMac()
{
  boolean r;
  NanodeUNIO unio(NANODE_MAC_DEVICE) ;
  r= unio.read(mymac, NANODE_MAC_ADDRESS, 6) ;
  if (r) Serial.println("success");
  else Serial.println("failure");
  sprintf(line_buf,"%02X:%02X:%02X:%02X:%02X:%02X",
          mymac[0],mymac[1],mymac[2],
          mymac[3],mymac[4],mymac[5]);
  //Serial.print("MAC address is ");
  Serial.println(line_buf);
}

void setup () {
     
  Serial.begin(9600);  
  loadRS();
  //byte ip[] = { 0,0,0,0 };
  //saveRS(ip);
  
  //showString(okmsg);
  
  //test();  



/*  */
  if (ether.begin(sizeof Ethernet::buffer, mymac) == 0) 
  Serial.println( "Failed to access Ethernet controller");
        
  if (!ether.dhcpSetup()) Serial.println("DHCP failed");

  ether.printIp("IP:  ", ether.myip);
  ether.printIp("GW:  ", ether.gwip);  
  ether.printIp("DNS: ", ether.dnsip);  


  // get the mac address of this device
  getMac();  
  // config the ethernets
  ether.staticSetup(ether.myip, ether.gwip);

  Serial.println("1212");
  while (ether.clientWaitingGw())
    ether.packetLoop(ether.packetReceive());
  Serial.println("Gateway found");

  #if 1
  // use DNS to locate the IP address we want to ping
  if (!ether.dnsLookup(PSTR("www.abcd.com")))
    Serial.println("abcd DNS failed");
  #else
  ether.parseIp(ether.hisip, "192.168.210.5");  // doesn't know what it means
  #endif
  ether.printIp("Server: ", ether.hisip);
  
  //Serial.println(ether.hisip[0]);
  //ether.hisport = 80; 
  ether.copyIp(ether.hisip, rs.hisip);  


 rf12_initialize(MYNODE, RF12_868MHZ, 1);    
 
 // Sha1.initHmac((uint8_t*)"secret",6);
 // Sha1.print("hello world!");
 // Sha1.resultHmac();
}



void loop () {
  
  byte types[5];
  memset(&emontx, -1, 5);
  memset(&emontx, 0, sizeof(emontx));
  memset(&emonen, 0, sizeof(emonen));
  
  if (millis() > timer) {
    timer = millis() + 5000;
    Serial.print("polling   ........................");
    Serial.println( freeRam ());     
  }    
  
  // http://www.22balmoralroad.net/wordpress/wp-content/uploads/homeBase.pde
  if (rf12_recvDone() && rf12_crc == 0 )
  {
      byte SenderID = (RF12_HDR_MASK & rf12_hdr);
      Serial.print("SENDID:");Serial.println(SenderID,HEX);Serial.println("     ");
        
    // Flash LED:
    digitalWrite(6, HIGH);
    delay(100);
    digitalWrite(6, LOW);    
    
#ifdef DEBUG 
Serial.print("receive packets   ");Serial.print(sizeof(emonen));Serial.print(  "   :    ");Serial.println((int)rf12_len);
#endif

       memset(&line_buf,0,150);
       
       String name; 
       char str1[7];
       char id1[9];
       char id2[9];
       char id3[9];
      // char va1[5];
      // char va2[5];
    if( rf12_len == sizeof emontx){
       memcpy(&emontx, (byte*) rf12_data, sizeof(emontx));
              
#ifdef DEBUG       
Serial.print("ct1:");    Serial.print(emontx.ct1);                // Add CT 1 reading 
Serial.print(",ct2:");    Serial.println(emontx.ct2);
Serial.print(",mac:");    Serial.println(emontx.mac);
#endif
       name = String(emontx.mac).substring(6,12);
       name.toCharArray(str1,7);
       Serial.print("name:");Serial.println(name);
 
       Serial.println(str1);
       
       memset(&line_buf,0,150);
       //memset(&va1,0,5);memset(&va2,0,5);
       strcpy (id1,str1);strcat(id1,"40");
       //Serial.println(eleid1);Serial.println("   " );Serial.println(str1);
       strcpy (id2,str1); strcat(id2,"41");
       //Serial.println(eleid2);Serial.println("   " );Serial.println(str1);
       strcpy (id3,str1);strcat(id3,"30");
       //Serial.println(volid);Serial.println("   " );Serial.println(str1);
       //Serial.println("..........");
              
    //Serial.println(id1);Serial.println(eleid2);Serial.println(volid);   
       sprintf(line_buf,"id=%s&id=%s&id=%s&value=%d&value=%d&value=%d&token=%s", id1,id2,id3,emontx.ct1,emontx.ct2,220,token);  
       //Serial.print("````````````````");Serial.println(line_buf);               
       ether.browseUrl(PSTR("/rest/notify/sensors?"),line_buf,website,my_result_cb);
  }
    
    if(rf12_len == sizeof emonen)
    {
       // Copy the received data into payload:
       memcpy(&emonen, (byte*) rf12_data, sizeof(emonen));
       byte lenfth = rf12_len;
#ifdef DEBUG                         
   Serial.print("mac:");Serial.println(emonen.mac);
   Serial.println(strlen(emonen.mac));
#endif       
       if(strcmp(emonen.mac,"000000000000")==0 || strlen(emonen.mac)==0){
         Serial.println("NO MAC ");
         goto NO_MAC;
       }

#ifdef DEBUG
//Serial.print("temp:"); Serial.print(emonen.temperature);Serial.print(" "); 
//Serial.print("hum:"); Serial.print(emonen.humidity);Serial.println(" ");
//Serial.print("light:"); Serial.print(emonen.light);Serial.print(" ");
//Serial.print("mac:"); Serial.println(emonen.mac);
#endif 
       
       
       name = String(emonen.mac).substring(6,12);
       //Serial.print("name:");Serial.println(name);
       
       name.toCharArray(str1,7); 
             
       memset(&line_buf,0,150);memset(&id1,0,15);//memset(&id2,0,15);memset(&id3,0,15);

       strcpy (id1,str1);strcat(id1,"00");
       strcpy (id2,str1);strcat(id2,"10");
       strcpy (id3,str1);strcat(id3,"20"); 
      
       //char va[5];
       //char va2[5];
       //fmtDouble(emonen.temperature, 2, va,7);
       //fmtDouble(emonen.humidity, 2, va2,7);
       
      
      
       //dtostrf( emonen.temperature, 2, 0, va1 );
       //dtostrf( emonen.humidity, 2, 2, va2 );       
       //Serial.println(va1);//Serial.print("   ");//Serial.println(va2);
      // sprintf(line_buf,"id=%s&id=%s&id=%s&value=%s&value=%s&value=%d&token=%s", id1,id2,id3,va,va2,emonen.light,token);        
       //Serial.println(id1);Serial.println(id2);Serial.println(id3);                 
      
       sprintf(line_buf,"id=%s&id=%s&id=%s&value=%d&value=%d&value=%d&token=%s", id1,id2,id3,(int)emonen.temperature,(int)emonen.humidity,emonen.light,token);   
       //Serial.print("````````````````2");Serial.println(line_buf);        
      
       //Serial.println(line_buf); 
       ether.browseUrl(PSTR("/rest/notify/sensors?"),line_buf,website,my_result_cb);


       /* encrpt       
    Serial.println(crc_string(line_buf));      
   encrypt(line_buf, sizeof(line_buf), &k[0]);
   Serial.print("Encrypted data: ");           
   Serial.println(line_buf);
   decrypt(line_buf, sizeof(line_buf),&k[0]);
   Serial.print("Decrypted data: ");          
   Serial.println(line_buf);
   */ 
   }
    
    //////////////////////////////////////////////////////////////////////////
    //Serial.println(millis()-last_rf);
         //(RF12_HDR_DST | masterNode)

 
    
    NO_MAC:
    last_rf = millis();     
    
    data_ready = 1;                                                // data is ready
    rf_error = 0;
    
   }  
    uint16_t  dat_p;
    // read packet, handle ping and wait for a tcp packet:
    dat_p=ether.packetLoop(ether.packetReceive());   
    if(dat_p==0){
      // no http request
      //Serial.println("no packet");
      return;
    }
    if (strncmp("POST ",(char *)&(Ethernet::buffer[dat_p]),5)==0){
      // head, post and other methods:
Serial.println("post ");
      //dat_p = process_request(1,(char *)&(Ethernet::buffer[dat_p+5]));
      goto SENDTCP;
    }
    // tcp port 80 begin
    if (strncmp("GET ",(char *)&(Ethernet::buffer[dat_p]),4)!=0){
      // head, post and other methods:
Serial.println("GET ");
      dat_p = print_webpage();
      goto SENDTCP;
    }
    
    // just one web page in the "root directory" of the web server
    if (strncmp("/ ",(char *)&(Ethernet::buffer[dat_p+4]),2)==0){
#ifdef DEBUG
Serial.println("GET / request");
#endif
      dat_p = print_webpage();
      goto SENDTCP;
    }
    //dat_p = process_request(0,(char *)&(Ethernet::buffer[dat_p+4]));
    
   SENDTCP:
      if( dat_p )
        ether.httpServerReply( dat_p);

  delay( 34 );
}
#define CMDBUF 100
//-------------------------------------------------------------------
// -- http --
//



/////////////////////////////////////////////////
// called when the client request is complete
static void callback (byte status, word off, word len) {
  //Serial.println(">>>");    
    //get_header_line(2, off);
    //get_header_line("X-Powered-By",off);
    //Serial.println(line_buf);
    
  get_reply_data(off);
#ifdef DEBUG
Serial.print("body:");
Serial.println(line_buf);
#endif  

  if (strcmp(line_buf,"ok")) 
  {
    Serial.println("ok recieved"); //request_attempt = 0;
  }    
}

int getA(char *str)
{
   Serial.println(str);
  memset(line_buf,NULL,sizeof(line_buf));

    uint16_t pos = 0;
    int line_num = 0;
    int line_pos = 0;
    
    // Skip over header until data part is found
    while (str[pos]) {
      if (str[pos-1]=='\n' && str[pos]=='\r') break;
      pos++; 
    }
    pos+=4;
    while (str[pos])
    {
      if (line_pos<49) {line_buf[line_pos] = str[pos]; line_pos++;} else break;
      pos++; 
    }
    line_buf[line_pos] = '\0';
 
  return 0;   
}

int get_header_line(char* line,word off)
{
  memset(line_buf,NULL,sizeof(line_buf));
  if (off != 0)
  {
    uint16_t pos = off;
    int line_num = 0;
    int line_pos = 0;
    
    while (Ethernet::buffer[pos])
    {
      if (Ethernet::buffer[pos]=='\n')
      {
        line_num++; line_buf[line_pos] = '\0';
        line_pos = 0;
        //if (line_num == line) return 1;
        if (strncmp(line,line_buf,50)==0)  return 1;
       
      }
      else
      {
        if (line_pos<49) {line_buf[line_pos] = Ethernet::buffer[pos]; line_pos++;}
      }  
      pos++; 
    } 
  }
  return 0;
}

int get_reply_data(word off)
{
  memset(line_buf,NULL,sizeof(line_buf));
  if (off != 0)
  {
    uint16_t pos = off;
    int line_num = 0;
    int line_pos = 0;
    
    // Skip over header until data part is found
    while (Ethernet::buffer[pos]) {
      if (Ethernet::buffer[pos-1]=='\n' && Ethernet::buffer[pos]=='\r') break;
      pos++; 
    }
    pos+=4;
    while (Ethernet::buffer[pos])
    {
      if (line_pos<49) {line_buf[line_pos] = Ethernet::buffer[pos]; line_pos++;} else break;
      pos++; 
    }
    line_buf[line_pos] = '\0';
  }
  return 0;
}

///////////////////////////////////////////////////////////////////////////////




static char* wtoa (word value, char* ptr) {
  if (value > 9)
    ptr = wtoa(value / 10, ptr);
  *ptr = '0' + value % 10;
  *++ptr = 0;
  return ptr;
}


static int freeRam () {
  extern int __heap_start, *__brkval; 
  int v; 
  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval); 	
}








int getLength()
{
  SRAM9.readstream(INDEX_MOTE_LENGTH);   // start address from 0   
  byte t = SRAM9.RWdata(0xFF);
  SRAM9.closeRWstream();
  return t;
}

void storeDevice(char *id,byte *type, byte channel){
  int length = 0;
  
#ifdef DEBUG
//Serial.print("store device   ");Serial.println(strlen(id));
#endif  
  length = getLength();
  SRAM9.writestream(LIST_MOTE_BEGIN +length*sizeof(Mote));   // start address from 0
  /// store id
  for(byte i=0;i<12;i++){
    if(i<strlen(id))
    SRAM9.RWdata(id[i]);
    else 
    SRAM9.RWdata(0);
  }
  /// type
#ifdef DEBUG
//Serial.print("type length:");Serial.println(sizeof(type));
#endif  
  
  for(byte i=0;i<5;i++) {
   // Serial.println((int)type[i]);
    if(i<=sizeof(type))
    SRAM9.RWdata(type[i]);
    else 
    SRAM9.RWdata(-1);
  }  
  
  SRAM9.RWdata(channel);

  // write length
  SRAM9.writestream(INDEX_MOTE_LENGTH);
  SRAM9.RWdata(++length);
  SRAM9.closeRWstream();

#ifdef DEBUG
  //Serial.print("len:");  Serial.println(length);
#endif  
   
}

boolean findDevice(char *id){
  // empty the mote structure
#ifdef DEBUG
  // Serial.print("findDevice   ");Serial.println(id);  
#endif   
  // flag to break 
  boolean found = false;
  SRAM9.readstream(INDEX_MOTE_LENGTH);   // start address from 0      
  int length = SRAM9.RWdata(0xFF); // get the length of devices
  //Serial.print("length:");Serial.println(length);
  for(int i=0;i<length;i++)
  {  
    if(found ==true) break;    
    SRAM9.readstream(LIST_MOTE_BEGIN+i*sizeof(Mote));   // start address from 0
     // id
    //line_buf
    memset(line_buf,0,strlen(line_buf));
    for(int j=0;j<12;j++)
    line_buf[j]= SRAM9.RWdata(0xFF);
//Serial.print("id:  ");Serial.print(i);Serial.print("  ");Serial.print(line_buf);Serial.print(" compare ");Serial.println(id);
    if(strncmp(line_buf,id,12)==0)
    {
      found = true;
#ifdef DEBUG
//Serial.print("found:    ");Serial.println(id);
        for(int j=0;j<5;j++)
        SRAM9.RWdata(0xFF);
        
//Serial.print("channel:");Serial.println((int)SRAM9.RWdata(0xFF));
#endif 
      break;   
    }
   
  }
  SRAM9.closeRWstream();
  return found;  
}


boolean getChannel(char *id){
  
  int channel  = -1;
  // empty the mote structure
#ifdef DEBUG
  // Serial.print("findDevice   ");Serial.println(id);  
#endif   
  // flag to break 
  boolean found = false;
  SRAM9.readstream(INDEX_MOTE_LENGTH);   // start address from 0      
  int length = SRAM9.RWdata(0xFF); // get the length of devices
  //Serial.print("length:");Serial.println(length);
  for(int i=0;i<length;i++)
  {  
    if(found ==true) break;    
    SRAM9.readstream(LIST_MOTE_BEGIN+i*sizeof(Mote));   // start address from 0
     // id
    //line_buf
    memset(line_buf,0,strlen(line_buf));
    for(int j=0;j<12;j++)
    {
      if(j>5)
      line_buf[j-6]= SRAM9.RWdata(0xFF);
      else
      SRAM9.RWdata(0xFF);
    }
//Serial.print("id:  ");Serial.print(i);Serial.print("  ");Serial.print(line_buf);Serial.print(" compare ");Serial.println(id);
    if(strncmp(line_buf,id,6)==0)
    {
      found = true;
#ifdef DEBUG
//Serial.print("found:    ");Serial.println(id);
        for(int j=0;j<5;j++)
        SRAM9.RWdata(0xFF);
        
channel = (int)SRAM9.RWdata(0xFF);
//Serial.print("channel:");Serial.println(channel);
#endif 
      break;   
    }
   
  }
  SRAM9.closeRWstream();
  return channel;  
}


void testram()
{
  SRAM9.writestream(0);  // start address from 0
  unsigned long stopwatch = millis(); //start stopwatch
  for(unsigned int i = 0; i < 32768; i++)
    SRAM9.RWdata(0x00); //write to every SRAM address 
  //Serial.print(millis() - stopwatch);
  //Serial.println("   ms to write full SRAM");
  SRAM9.readstream(0);   // start address from 0 

  for(unsigned int i = 0; i < 32768; i++)
  {
    if(SRAM9.RWdata(0xFF) != 0x00)  //check every address in the SRAM
    {
#ifdef DEBUG
//Serial.println("error in location  ");
//Serial.println(i);
#endif 
      break;
    }//end of print error
    if(i == 32767)
    {
      #ifdef DEBUG
      //Serial.println("no errors in the 32768 bytes");
      #endif  
    }
   }//end of get byte
  SRAM9.closeRWstream();
}



void getInfoList(byte devicegroup)
{
  SRAM9.readstream(INDEX_MOTE_LENGTH);   // start address from 0   
  int length = (int)SRAM9.RWdata(0xFF); // get the length of devices
  //Serial.print("len:");Serial.println((int)length);Serial.println(length,HEX);  
   bfill = ether.tcpOffset();
   bfill.emit_p(PSTR(
        "HTTP/1.0 200 OK\r\n"
        "Content-Type: text/html\r\n"
        "Pragma: no-cache\r\n"
        "\r\n"
        "["));
  //Serial.println(" ---getInfoList ");
  char id[15]; char tempid[15];boolean created = false;
  for(int i=0;i<length;i++)
  {      
    SRAM9.readstream(LIST_MOTE_BEGIN+i*sizeof(Mote));   // start address from 0  
     // id
    memset(line_buf,0,150); 
    memset(id,0,15); 
    for(byte j=0;j<12;j++)
    {
      byte a = SRAM9.RWdata(0xFF);
      if(j>5)
      id[j-6]= a;
     
    }
#ifdef DEBUG
//Serial.print(" --------------------------------------------- ");Serial.println(id);
#endif 

    int type = -1;
 
    for(byte j=0;j<5;j++){
          
      type = (int)SRAM9.RWdata(0xFF);
#ifdef DEBUG
// Serial.print("type   ");  Serial.println((int)type);
#endif                    
      if(type == 255) continue;     
    if(created==true)
    {
      bfill.emit_p(PSTR(","));created=false;
    }      
      if(devicegroup ==0)// get sensor
      {        
        memcpy(&tempid,id,sizeof(id));
#ifdef DEBUG 
//Serial.print("type:");Serial.println(type);
#endif
        switch(type)
        {
          case 0:
          strcat(tempid,"0");
          break;
          
          case 1:
          strcat(tempid,"1");
          break;
          
          case 2:
          strcat(tempid,"2");
          break;
          
          case 3:
          strcat(tempid,"3");
          break;
          
          case 4:
          strcat(tempid,"4");
          break;
        }
        //http://webinos.org/api/
#ifdef DEBUG 
//Serial.println(tempid);
#endif        


        bfill.emit_p(PSTR("{\"sId\":\"$S\""), tempid); // start address from 0
        //Serial.println(id);
        strcpy_P(line_buf, (char*)pgm_read_word(&(sensor_table[type])));
        bfill.emit_p(PSTR(",\"sType\":\"$S\"}"), line_buf); // 
        created = true; 
        memset(&line_buf,0,150);
      }
      
      else if(devicegroup ==1) // get actuator
      {
        bfill.emit_p(PSTR("{\"aId\":\"$S\""), id);   // start address from 0
        strcpy_P(line_buf, (char*)pgm_read_word(&(actuator_table[type-10])));
        bfill.emit_p(PSTR(",\"aType\":\"$S\""), line_buf);   // start address from 0
      }
      /**/      
      memset(&tempid,0,15);
      

    }   
  }
  bfill.emit_p(PSTR(
        "]"));
  SRAM9.closeRWstream();
}

// http://192.168.210.203/sensors/0004A32C30231
void getInfo(byte deviceGroup, char *id)
{
  
  //Serial.println(id[12]);
  byte type = id[6]-'0';
  
  memset(&mote,NULL,sizeof(Mote));
  boolean found = false;
  SRAM9.readstream(INDEX_MOTE_LENGTH);   // start address from 0   
  
  int length = (int)SRAM9.RWdata(0xFF); // get the length of devices
  //Serial.print("len:");Serial.println((int)length);
   
  // http://192.168.210.203/motes/F6F_hum
  for(int i=0;i<length;i++)
  {  
    //Serial.print("id:");Serial.println(id);
    if(found ==true) break;    
    SRAM9.readstream(LIST_MOTE_BEGIN+i*sizeof(Mote));   // start address from 0

     // id
    memset(line_buf,0,50); 

    
    for(byte j=0;j<12;j++)
    {
      byte a = SRAM9.RWdata(0xFF);
      if(j>5)
      line_buf[j-6]= a;
     
    }
    //Serial.print(" ---- ");Serial.println(line_buf);
    if(strncmp(id,line_buf,6)==0)
    {      
      bfill = ether.tcpOffset();
      bfill.emit_p(PSTR(
        "HTTP/1.0 200 OK\r\n"
        "Content-Type: text/html\r\n"
        "Pragma: no-cache\r\n"
        "\r\n"));
      
     // Serial.print("==========================found:    ");Serial.print(id);Serial.print("   compares:  ");Serial.println(line_buf);
      /*  type    */
      for(byte j=0;j<5;j++)
      {
         byte s =  SRAM9.RWdata(0xFF);
         if(s == type)
         found = true; 
      }
      
      if(found)
      {  
          //Serial.println("//////////////////////////////////");
         /*  id    */
         if(deviceGroup ==0)
          bfill.emit_p(PSTR("{\"sId\":\"$S\""), id);
          else
          bfill.emit_p(PSTR("{\"aId\":\"$S\""), id);        
        
        
        strcpy_P(line_buf, (char*)pgm_read_word(&(sensor_table[type]))); // Necessary casts and dereferencing, just copy. 
       
#ifdef DEBUG
//Serial.println( line_buf );
#endif  
    
        if(deviceGroup ==0)
        bfill.emit_p(PSTR(",\"sType\":\"$S\""), line_buf);
        else
        bfill.emit_p(PSTR(",\"aType\":\"$S\""), line_buf);
      
        bfill.emit_p(PSTR(",\"vendor\":\"HOC\",\"version\":\"01\",\"name\":\"$S\"}"), "sensor");
       }
       
       break;
    }   
  }
  
  SRAM9.closeRWstream();
  
 
  if(!found)
  {
        http404();  
  }
/////////////////////////////////////////////////////////  
}


#define SWAP(a, b) (((a) ^= (b)), ((b) ^= (a)), ((a) ^= (b)))

static PROGMEM prog_uint32_t crc_table[16] = {
    0x00000000, 0x1db71064, 0x3b6e20c8, 0x26d930ac,
    0x76dc4190, 0x6b6b51f4, 0x4db26158, 0x5005713c,
    0xedb88320, 0xf00f9344, 0xd6d6a3e8, 0xcb61b38c,
    0x9b64c2b0, 0x86d3d2d4, 0xa00ae278, 0xbdbdf21c
};

unsigned long crc_update(unsigned long crc, byte data)
{
    byte tbl_idx;
    tbl_idx = crc ^ (data >> (0 * 4));
    crc = pgm_read_dword_near(crc_table + (tbl_idx & 0x0f)) ^ (crc >> 4);
    tbl_idx = crc ^ (data >> (1 * 4));
    crc = pgm_read_dword_near(crc_table + (tbl_idx & 0x0f)) ^ (crc >> 4);
    return crc;
}

unsigned long crc_string(char *s)
{
  unsigned long crc = ~0L;
  while (*s)
    crc = crc_update(crc, *s++);
  crc = ~crc;
  return crc;
}

union convertor
{
  struct
  {
    byte type: 4;
    byte number: 4;
  } pieces;
  byte whole;
};

struct {
    union {
        uint16_t big;
        uint8_t small[2];
    };
} nums;




 void showString (PGM_P s) {
        char c;
        while ((c = pgm_read_byte(s++)) != 0)
            Serial.print(c);
    }
    
    
 ///////////////////////////////////////
 
 void test(){
 char data[]="helloxsz 11111111111111111111111111111111111111";
  unsigned int length=sizeof(data);
  
   encrypt(data, length, &k[0]);
   Serial.print("Encrypted data: ");           
   Serial.println(data);
   decrypt(data, length,&k[0]);
   Serial.print("Decrypted data: ");          
   Serial.println(data);
   
   
   //base64_encode(char *output, char *input, int inputLen)
   char output[60]; 
   char output2[60];   
   base64_encode(output,data,sizeof(data));
   //base64_encode(data,output,sizeof(data));
   Serial.println(output);
   base64_decode(data,output,sizeof(data));
   Serial.println(data);   
  
   Serial.println(crc_string("HELLO111111111111111111111111111111111111111"), HEX);
 }
 
 
 
 


void btea(uint32_t *v, int n, uint32_t *k) {
    uint32_t y, z, sum;
    unsigned p, rounds, e;
    if (n > 1) {          /* Coding Part */
      rounds = 6 + 52/n;
      sum = 0;
      z = v[n-1];
      do {
        sum += DELTA;
        e = (sum >> 2) & 3;
        for (p=0; p<n-1; p++)
          y = v[p+1], z = v[p] += MX;
        y = v[0];
        z = v[n-1] += MX;
      } while (--rounds);
    } else if (n < -1) {  /* Decoding Part */
      n = -n;
      rounds = 6 + 52/n;
      sum = rounds*DELTA;
      y = v[0];
      do {
        e = (sum >> 2) & 3;
        for (p=n-1; p>0; p--)
          z = v[p-1], y = v[p] -= MX;
        z = v[n-1];
        y = v[0] -= MX;
      } while ((sum -= DELTA) != 0);
    }
  }
 
 
 
 /* FUNCIÓN: encrypt
 * ARGS:
 *	- inputText : puntero al texto en claro
 *	- inputTextLength : longitud del texto en claro (en bytes)
 *	- k[4] : clave de cifrado, en forma de array de cuatro elementos de 32 bits = clave de 128 bits.
 * SALIDA: número de bloques cifrados, -1 en caso de error
 */
int encrypt( char *inputText,  int inputTextLength, uint32_t *k)
{  
  unsigned int numBlocks = (inputTextLength <= BLOCK_SIZE ? 1 : inputTextLength/BLOCK_SIZE);
  Serial.println(numBlocks);
  unsigned int offset, i;

  // Padding if necessary till a full block size
  if ((offset = inputTextLength % BLOCK_SIZE) != 0)
	  memset(inputText+inputTextLength, 0x00, BLOCK_SIZE - offset);

  for (i=0; i<numBlocks;i++){
     btea((uint32_t *)inputText, BLOCK_SIZE/4,k);
     inputText+=BLOCK_SIZE;
  }

  return numBlocks;
}

/* FUNCIÓN: decrypt
 * ARGS:
 *	- inputText : puntero al texto en claro
 *	- inputTextLength : longitud del texto en claro (en bytes)
 *	- k[4] : clave de cifrado, en forma de array de cuatro elementos de 32 bits = clave de 128 bits.
 * SALIDA: número de bloques cifrados, -1 en caso de error
 */
int decrypt( char *inputText,  int inputTextLength, uint32_t *k)
{
  unsigned int numBlocks = (inputTextLength <= BLOCK_SIZE ? 1 : inputTextLength/BLOCK_SIZE), i;
  Serial.println(numBlocks);
  for (i=0; i<numBlocks;i++){
     btea((uint32_t *)inputText, BLOCK_SIZE/4*(-1),k);
     inputText+=BLOCK_SIZE;
  }

  return numBlocks;
}










const char b64_alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		"abcdefghijklmnopqrstuvwxyz"
		"0123456789+/";

/* 'Private' declarations */
inline void a3_to_a4(unsigned char * a4, unsigned char * a3);
inline void a4_to_a3(unsigned char * a3, unsigned char * a4);
inline unsigned char b64_lookup(char c);

int base64_encode(char *output, char *input, int inputLen) {
	int i = 0, j = 0;
	int encLen = 0;
	unsigned char a3[3];
	unsigned char a4[4];

	while(inputLen--) {
		a3[i++] = *(input++);
		if(i == 3) {
			a3_to_a4(a4, a3);

			for(i = 0; i < 4; i++) {
				output[encLen++] = b64_alphabet[a4[i]];
			}

			i = 0;
		}
	}

	if(i) {
		for(j = i; j < 3; j++) {
			a3[j] = '\0';
		}

		a3_to_a4(a4, a3);

		for(j = 0; j < i + 1; j++) {
			output[encLen++] = b64_alphabet[a4[j]];
		}

		while((i++ < 3)) {
			output[encLen++] = '=';
		}
	}
	output[encLen] = '\0';
	return encLen;
}

int base64_decode(char * output, char * input, int inputLen) {
	int i = 0, j = 0;
	int decLen = 0;
	unsigned char a3[3];
	unsigned char a4[4];


	while (inputLen--) {
		if(*input == '=') {
			break;
		}

		a4[i++] = *(input++);
		if (i == 4) {
			for (i = 0; i <4; i++) {
				a4[i] = b64_lookup(a4[i]);
			}

			a4_to_a3(a3,a4);

			for (i = 0; i < 3; i++) {
				output[decLen++] = a3[i];
			}
			i = 0;
		}
	}

	if (i) {
		for (j = i; j < 4; j++) {
			a4[j] = '\0';
		}

		for (j = 0; j <4; j++) {
			a4[j] = b64_lookup(a4[j]);
		}

		a4_to_a3(a3,a4);

		for (j = 0; j < i - 1; j++) {
			output[decLen++] = a3[j];
		}
	}
	output[decLen] = '\0';
	return decLen;
}

int base64_enc_len(int plainLen) {
	int n = plainLen;
	return (n + 2 - ((n + 2) % 3)) / 3 * 4;
}

int base64_dec_len(char * input, int inputLen) {
	int i = 0;
	int numEq = 0;
	for(i = inputLen - 1; input[i] == '='; i--) {
		numEq++;
	}

	return ((6 * inputLen) / 8) - numEq;
}

inline void a3_to_a4(unsigned char * a4, unsigned char * a3) {
	a4[0] = (a3[0] & 0xfc) >> 2;
	a4[1] = ((a3[0] & 0x03) << 4) + ((a3[1] & 0xf0) >> 4);
	a4[2] = ((a3[1] & 0x0f) << 2) + ((a3[2] & 0xc0) >> 6);
	a4[3] = (a3[2] & 0x3f);
}

inline void a4_to_a3(unsigned char * a3, unsigned char * a4) {
	a3[0] = (a4[0] << 2) + ((a4[1] & 0x30) >> 4);
	a3[1] = ((a4[1] & 0xf) << 4) + ((a4[2] & 0x3c) >> 2);
	a3[2] = ((a4[2] & 0x3) << 6) + a4[3];
}

inline unsigned char b64_lookup(char c) {
	int i;
	for(i = 0; i < 64; i++) {
		if(b64_alphabet[i] == c) {
			return i;
		}
	}

	return -1;
}


/*

*/

/***********************************************************/
// SRAM functions to have program, variables and stack in sram.
// Define size of SRAM buffer by setting start and end values. Default is all ram.

// https://github.com/thiseldo/NanodeBasic/blob/master/NanodeBasic.pde
/* 
#define SRAM_START 0
#define SRAM_END 32767
unsigned int sp = 0;
unsigned int txtpos;
// ASCII Characters
#define CR	'\r'
#define NL	'\n'
#define TAB	'\t'
#define BELL	'\b'
#define DEL	'\177'
#define SPACE   ' '
#define CTRLC	0x03
#define CTRLH	0x08
#define CTRLS	0x13
#define CTRLX	0x18

void clearMemory() {
  SRAM9.writestream( SRAM_START );
  for( int i = 0; i < (SRAM_END-SRAM_START); i++ )
    SRAM9.RWdata( 0 );
  SRAM9.closeRWstream(); 
}

boolean testMemory() {
  // Write pattern 0x55
  SRAM9.writestream( SRAM_START );
  for( int i = 0; i < (SRAM_END-SRAM_START); i++ )
    SRAM9.RWdata( 0x55 );
  SRAM9.closeRWstream();
  
  // Read back
  SRAM9.readstream( SRAM_START );
  for( int i = 0; i < (SRAM_END-SRAM_START); i++ ) {
    if( SRAM9.RWdata(0xFF) != 0x55 ) {
      SRAM9.closeRWstream();
      return false;
    }
  }
  SRAM9.closeRWstream();
  return true;
}




unsigned char readMemory( unsigned int address ) {
  SRAM9.readstream( address );
  unsigned char ch = SRAM9.RWdata(0xFF);
  SRAM9.closeRWstream();
  return ch;  
}

unsigned int readMemoryInt( unsigned int address ) {
  SRAM9.readstream( address );
  unsigned int val = SRAM9.RWdata(0xFF);
  val += (SRAM9.RWdata(0xFF) << 8);
  SRAM9.closeRWstream();
  return val;  
}

void getStackFrame( unsigned int address, int len, unsigned char *ptr) {
  SRAM9.readstream( address );
  while( len > 0 ) {
    *ptr++ = SRAM9.RWdata(0xFF);
    len--;
  }
  SRAM9.closeRWstream();
}

void writeMemory( unsigned int address, unsigned char val ) {
  SRAM9.writestream( address );
  SRAM9.RWdata( val );
  SRAM9.closeRWstream();
}

void writeMemoryInt( unsigned int address, unsigned int val ) {
  SRAM9.writestream( address );
  SRAM9.RWdata( val & 0xFF );
  SRAM9.RWdata( val >> 8 );
  SRAM9.closeRWstream();
}

void writeStackFrame( unsigned int address, int len, unsigned char *ptr) {
  SRAM9.writestream( address );
  while( len > 0 ) {
    SRAM9.RWdata(*ptr++);
    len--;
  }
  SRAM9.closeRWstream();
}




static void pushb(unsigned char b)
{
  sp--;
  writeMemory(sp, b);
}


static unsigned char popb()
{
  unsigned char b;
  b = readMemory(sp);
  sp++;
  return b;
}



static void ignore_blanks(void)
{
  while(readMemory(txtpos) == SPACE || readMemory(txtpos) == TAB)
    txtpos++;
}
*/


void fmtDouble(double val, byte precision, char *buf, unsigned bufLen = 0xffff);
unsigned fmtUnsigned(unsigned long val, char *buf, unsigned bufLen = 0xffff, byte width = 0);

//
// Produce a formatted string in a buffer corresponding to the value provided.
// If the 'width' parameter is non-zero, the value will be padded with leading
// zeroes to achieve the specified width.  The number of characters added to
// the buffer (not including the null termination) is returned.
//
unsigned
fmtUnsigned(unsigned long val, char *buf, unsigned bufLen, byte width)
{
  if (!buf || !bufLen)
    return(0);

  // produce the digit string (backwards in the digit buffer)
  char dbuf[10];
  unsigned idx = 0;
  while (idx < sizeof(dbuf))
  {
    dbuf[idx++] = (val % 10) + '0';
    if ((val /= 10) == 0)
      break;
  }

  // copy the optional leading zeroes and digits to the target buffer
  unsigned len = 0;
  byte padding = (width > idx) ? width - idx : 0;
  char c = '0';
  while ((--bufLen > 0) && (idx || padding))
  {
    if (padding)
      padding--;
    else
      c = dbuf[--idx];
    *buf++ = c;
    len++;
  }

  // add the null termination
  *buf = '\0';
  return(len);
}

//
// Format a floating point value with number of decimal places.
// The 'precision' parameter is a number from 0 to 6 indicating the desired decimal places.
// The 'buf' parameter points to a buffer to receive the formatted string.  This must be
// sufficiently large to contain the resulting string.  The buffer's length may be
// optionally specified.  If it is given, the maximum length of the generated string
// will be one less than the specified value.
//
// example: fmtDouble(3.1415, 2, buf); // produces 3.14 (two decimal places)
//
void
fmtDouble(double val, byte precision, char *buf, unsigned bufLen)
{
  if (!buf || !bufLen)
    return;

  // limit the precision to the maximum allowed value
  const byte maxPrecision = 6;
  if (precision > maxPrecision)
    precision = maxPrecision;

  if (--bufLen > 0)
  {
    // check for a negative value
    if (val < 0.0)
    {
      val = -val;
      *buf = '-';
      bufLen--;
    }

    // compute the rounding factor and fractional multiplier
    double roundingFactor = 0.5;
    unsigned long mult = 1;
    for (byte i = 0; i < precision; i++)
    {
      roundingFactor /= 10.0;
      mult *= 10;
    }

    if (bufLen > 0)
    {
      // apply the rounding factor
      val += roundingFactor;

      // add the integral portion to the buffer
      unsigned len = fmtUnsigned((unsigned long)val, buf, bufLen);
      buf += len;
      bufLen -= len;
    }

    // handle the fractional portion
    if ((precision > 0) && (bufLen > 0))
    {
      *buf++ = '.';
      if (--bufLen > 0)
        buf += fmtUnsigned((unsigned long)((val - (unsigned long)val) * mult), buf, bufLen, precision);
    }
  }

  // null-terminate the string
  *buf = '\0';
} 

