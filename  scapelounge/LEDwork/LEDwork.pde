#include <Streaming.h>

// CONSTANTS
// pins
const int PIN_A = 12;
const int PIN_B = 13;
const int PIN_LIGHT_RED   = 10;
const int PIN_LIGHT_GREEN = 9;
const int PIN_LIGHT_BLUE  = 11;
const int PIN_ACC_X = 0;
const int PIN_ACC_Y = 1;
const int PIN_ACC_Z = 2;

// command constants. used for beginning and end, cannot be used inside the comand!
const char COMMAND_START  = 2; // 'STX'
const char COMMAND_END    = 3; // 'ETX'

// modes, 3 modes for general behaviours.
const char MODE_DEFAULT  = 'A'; // when the ledwork is not attached to anything and is laying still
const char MODE_MOVING   = 'B'; // moving while not attached to anything
const char MODE_ATTACHED = 'C'; // attached to other ledworks and/or panels

// constants for the colors that we can use easily to read values in switches
const int RED = 0;
const int GREEN = 1;
const int BLUE = 2;

// ENVIRONMENT VARIABLES
// A and B set the multiplexer to listen to a certain port
int PIN_A_value = LOW;
int PIN_B_value = LOW;

// variables used in HSB calculation
float hueRangeStart;
int hueRangeLength = 80;
float oldHue = 0;
float oldSaturation;
float oldBrightness;
float currentHue = 0;
float currentSaturation = 1;
float currentBrightness = 1;
float plannedHue = 0;
float plannedSaturation = 0;
float plannedBrightness = 0;
long hueChangeStart = 0;
long saturationChangeStart = 0;
long brightnessChangeStart = 0;
int hueInterval = 0;
int hueIntervalMin;
int hueIntervalMax;
int saturationInterval;
int saturationIntervalMin;
int saturationIntervalMax;
int brightnessInterval;
int brightnessIntervalMin;
int brightnessIntervalMax;

long currentTime = 0;
long messageSendTime = 0; // last time a message was send
long messageReadTime = 0; // last time a message was read
long modeChangeTime = 0; // last time the mode was changed
char mode = MODE_DEFAULT; // the current mode
boolean pulsing = true; // whether the leds should pulsate or blink
int currentNode = 0; // the node the ledwork is listening to
boolean allNodesRead = false;

// values for the color in RGB
float redValue   = 0;
float greenValue = 0;
float blueValue  = 0;

// accelerometer, initial value (to check against) and constantly updated values
int accInitValue_x;
int accInitValue_y;
int accInitValue_z;
int accValue_x;
int accValue_y;
int accValue_z;

// commands to be saved. Command is build as followes: 0 => master/slave (0=slave, 1=master), 1 => red (value (0-255)), 2 => green, 3 => blue
const int COMMAND_LENGTH = 4; // defined here for easy changing
char COMMAND_node_1[COMMAND_LENGTH] = "";
char COMMAND_node_2[COMMAND_LENGTH] = "";
char COMMAND_node_3[COMMAND_LENGTH] = "";
char COMMAND_node_4[COMMAND_LENGTH] = "";
char COMMAND_temp[COMMAND_LENGTH] = ""; // used to store the command before it is fully written

int currentReadCommandIndex = -1; //used to keep track of the index of the read character;
boolean commandRecieved = false; // whether the current read command is fully recieved

//prototypes
static uint32_t deadbeef_seed; 
static uint32_t deadbeef_beef = 0xdeadbeef; 

void setup()
{
  Serial.begin(9600); // the serial connection. Don't make it to fast (9600 should be good) or the changes of failing will increase
  pinMode(PIN_A, OUTPUT);
  pinMode(PIN_B, OUTPUT);
  accInitValue_x = analogRead(PIN_ACC_X);
  accInitValue_y = analogRead(PIN_ACC_Y);
  accInitValue_z = analogRead(PIN_ACC_Z);
  setColorDomain();
}

void setColorDomain()
{
  // since the default random number generator sucks monkey balls we use deadbeef to create good random seed.
  deadbeef_srand(analogRead(5)); //get a real random number (use an unused analog pin)
  randomSeed(deadbeef_rand()); //use the random to create a random seed (better randomness)
  currentHue = hueRangeStart = random(0, 265); //set the huerangestart (pick a color domain)
}

void loop()
{
  currentTime = millis();
  setMode();
  expressBehaviour();
  handleMessaging();
}

void setHSBIntervals()
{
  if(hueChangeStart == 0 || ((currentTime - hueChangeStart) >= hueInterval))
  {
    newHue();
  }
  if(brightnessChangeStart == 0 || ((currentTime - brightnessChangeStart) >= brightnessInterval))
  {
    newBrightness();
  } 
}

void newHue()
{
  hueChangeStart = currentTime;
  oldHue = currentHue;
  planNewHue();
  setNewHueInterval();
}

void newSaturation()
{
  saturationChangeStart = currentTime;
  oldSaturation = currentSaturation;
  planNewSaturation();
  setNewSaturationInterval();
}

void newBrightness()
{
  brightnessChangeStart = currentTime;
  oldBrightness = currentBrightness;
  planNewBrightness();
  setNewBrightnessInterval();
}

void setMode()
{
  // set the mode if nessecery
  char oldMode = mode; // save the oldmode for later
  switch(mode)
  {
    case MODE_ATTACHED:
      break;
    case MODE_MOVING:
      if(!isMoving() && currentTime - modeChangeTime > 2000)
      {
        mode = MODE_DEFAULT;
      }
      break;
    case MODE_DEFAULT:
    default:
      accValue_x = analogRead(PIN_ACC_X);
      accValue_y = analogRead(PIN_ACC_Y);
      accValue_z = analogRead(PIN_ACC_Z);
      if(isMoving())
      {
        mode = MODE_MOVING; 
      }
  } 
  if(oldMode != mode)
  {
    modeChangeTime = currentTime;
    setNewModeConditions();
  }
}

boolean isMoving()
{
  // the check on movement could be radicaly improved. Better would be to keep track of an avarage. Do testing with an accelerometer to see output.
  return abs(accInitValue_x - accValue_x) > 25 || abs(accInitValue_y - accValue_y) > 25 || abs(accInitValue_z - accValue_z) > 25;
}

void setNewModeConditions()
{
  switch(mode)
  {
    case MODE_ATTACHED:
      break;
    case MODE_MOVING:
      hueIntervalMin = 100;
      hueIntervalMax = 1000;
      brightnessIntervalMin = 100;
      brightnessIntervalMax = 500;
      pulsing = false;
      break;
    case MODE_DEFAULT:
    default:
      hueIntervalMin = 1000;
      hueIntervalMax = 10000;
      brightnessIntervalMin = 2000;
      brightnessIntervalMax = 5000;
      pulsing = true;
  } 
}

void expressBehaviour()
{
  switch(mode)
  {
    case MODE_ATTACHED:
      digitalWrite(PIN_LIGHT_RED, HIGH);
      digitalWrite(PIN_LIGHT_GREEN, LOW);
      digitalWrite(PIN_LIGHT_BLUE, LOW);
      break;
    case MODE_MOVING:
      expressBehavior_moving();
      break;
    case MODE_DEFAULT:
    default:
      expressBehavior_default();
  } 
}

void expressBehavior_default()
{
  setHSBIntervals();
  outPutMappedLightValues(true);
}

void expressBehavior_moving()
{
  setHSBIntervals();
  outPutMappedLightValues(false);
}

void handleMessaging()
{
  // send a command every 100 ms
  if(currentTime - messageSendTime >= 100)
  {
    sendMessage();
  }
  // read a node message very 200 ms 
  // (!) check should be altered a bit: whenever a command is succesfully read, we should go on to the next node (if any),
  //     if after, say 200 ms nothing is read, it is not connected. If the full command is not received after 200 ms,
  //     we treat it as not being connected as well (or do we?)
  if((messageReadTime == 0) || (currentTime - messageReadTime > 200))
  {
    messageReadTime = currentTime;
    currentNode++;  // increase the nodenumber by 1
    if(currentNode > 4)
    {
	  allNodesRead = true;
      currentNode = 1; // reset the nodenumber to 1
    } 
    setReadCommandConditions();
  }
  readMessage();
}

void sendMessage()
{
  // send the command
  // the command is an array of bytes representing
  // {COMMAND_START, NR_NODES, HUE, PULSING, COMMAND_END}
  Serial << COMMAND_START << mode << COMMAND_END;
  messageSendTime = currentTime;
}

void readMessage()
{
  // if the serial is available, read the command and save it.
  if(Serial.available())
  {
    char readChar = (char)Serial.read();
    switch(readChar)
    {
      case COMMAND_START:
        currentReadCommandIndex = 0;
        break;
      case COMMAND_END:
        if(currentReadCommandIndex != -1)
        {
          commandRecieved = true;
          currentReadCommandIndex = -1;
        }
        break;
      default:
        if(currentReadCommandIndex != -1)
        {
          COMMAND_temp[currentReadCommandIndex++] = readChar;
        }
    }
  }
  if(commandRecieved)
  {
    // copy the temporary command to the right array.
    switch(currentNode)
    {
      case 1:
        memcpy (COMMAND_temp,COMMAND_node_1,strlen(COMMAND_node_1)+1);
        break;
      case 2:
        memcpy (COMMAND_temp,COMMAND_node_2,strlen(COMMAND_node_2)+1);
        break;
      case 3:
        memcpy (COMMAND_temp,COMMAND_node_3,strlen(COMMAND_node_3)+1);
        break;
      case 4:
        memcpy (COMMAND_temp,COMMAND_node_4,strlen(COMMAND_node_4)+1);
        break;
    }
	commandRecieved = false;
  }
}

void setReadCommandConditions()
{
  // set conditions to read based on the current node
  switch(currentNode)
  {
    case 1:
      PIN_A_value = LOW;
      PIN_B_value = LOW;
      break;
    case 2:
      PIN_A_value = LOW;
      PIN_B_value = HIGH;
      break;
    case 3:
      PIN_A_value = HIGH;
      PIN_B_value = LOW;
      break;
    case 4:
      PIN_A_value = HIGH;
      PIN_B_value = HIGH;
      break;
  }
  currentReadCommandIndex = -1;
  digitalWrite(PIN_A, PIN_A_value);
  digitalWrite(PIN_B, PIN_B_value);
}

void planNewHue()
{
  plannedHue = random(hueRangeStart, hueRangeStart + hueRangeLength);
  // THE HUE CAN BECOME > 360 BUT THIS IS OK FOR CALCULATION. ONLY IN setRGBFromCurrentHSB IT WILL BE NORMALIZED
}

void planNewSaturation()
{
  plannedSaturation = 0.5 + (float)(random(1, 1000) / 2000);
}

void planNewBrightness()
{
  plannedBrightness = 1;//0.5 + (float)(random(1, 1000) / 2000);
}

void setNewHueInterval()
{
  hueInterval = ceil(random(hueIntervalMin, hueIntervalMax)); 
}

void setNewSaturationInterval()
{
  saturationInterval = ceil(random(saturationIntervalMin, saturationIntervalMax));
}

void setNewBrightnessInterval()
{
  brightnessInterval = ceil(random(brightnessIntervalMin, brightnessIntervalMax));
}

void setRGBFromCurrentHSB()
{
  if(currentSaturation == 0)
  {
     redValue = greenValue = blueValue = currentBrightness;
  }
  else
  {
     //float hue = ((currentHue % 256)/255) * 6; // arduino can't do modulo on floats (facepalm), so instead we need the folowing three lines
	 float hue = currentHue;
	 while(hue > 255) { hue -= 255; }
	 hue = (hue/255)*6;
	 
     if(hue == 6) { hue = 0; }
     int var_i = floor( hue );    
     float var_1 = currentBrightness * ( 1 - currentSaturation );
     float var_2 = currentBrightness * ( 1 - currentSaturation * ( hue - var_i ) );
     float var_3 = currentBrightness * ( 1 - currentSaturation * ( 1 - ( hue - var_i ) ) );
  
     if      ( var_i == 0 ) { redValue = currentBrightness; greenValue = var_3;             blueValue = var_1; }
     else if ( var_i == 1 ) { redValue = var_2;             greenValue = currentBrightness; blueValue = var_1; }
     else if ( var_i == 2 ) { redValue = var_1;             greenValue = currentBrightness; blueValue = var_3; }
     else if ( var_i == 3 ) { redValue = var_1;             greenValue = var_2;             blueValue = currentBrightness; }
     else if ( var_i == 4 ) { redValue = var_3;             greenValue = var_1;             blueValue = currentBrightness; }
     else                   { redValue = currentBrightness; greenValue = var_1;             blueValue = var_2; }
  }
}

void outPutMappedLightValues(boolean fade)
{
  currentHue = getMappedValueIntervalBased(hueChangeStart, hueInterval, fade, plannedHue, oldHue);
  currentBrightness = getMappedValueIntervalBased(brightnessChangeStart, brightnessInterval, fade, plannedBrightness, oldBrightness);
  setRGBFromCurrentHSB();
  
  outputMappedLightValue(PIN_LIGHT_RED,   redValue);
  outputMappedLightValue(PIN_LIGHT_GREEN, greenValue);
  outputMappedLightValue(PIN_LIGHT_BLUE,  blueValue);
}

void outputMappedLightValue(int outputPin, float mappedValue)
{
  // Convert the input value to a value between 0 and 255 and write it
  int outputValue = constrain(round(mappedValue * 255),  0, 255);
  analogWrite(outputPin, outputValue);
}

//---------------------------------------------------------------------------------------------------------------------------
// helper functions

float getMappedValueIntervalBased(float startTime, int interval, boolean fade, float minValue, float maxValue)
{
  float currentStep = abs((currentTime - startTime) / interval - 0.5) * 2;
  return fade ? mapFloat(currentStep, 0, 1, minValue, maxValue) : (currentStep > 0.5 ? HIGH : LOW);
}

float mapFloat(float x, float in_min, float in_max, float out_min, float out_max)
{
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

uint32_t deadbeef_rand()
{ 
  deadbeef_seed = (deadbeef_seed << 7) ^ ((deadbeef_seed >> 25) + deadbeef_beef); 
  deadbeef_beef = (deadbeef_beef << 7) ^ ((deadbeef_beef >> 25) + 0xdeadbeef); 
  return deadbeef_seed;
} 

void deadbeef_srand(uint32_t x) 
{ 
  deadbeef_seed = x; 
  deadbeef_beef = 0xdeadbeef; 
}
