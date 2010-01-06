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

// constants for the colors so that we can use easy to read values in switches
const int RED = 0;
const int GREEN = 1;
const int BLUE = 2;

// ENVIRONMENT VARIABLES
// A and B set the multiplexer to listen to a certain port
int PIN_A_value = LOW;
int PIN_B_value = LOW;

long currentTime = 0;
long messageSendTime = 0; // last time a message was send
long messageReadTime = 0; // last time a message was read
long modeChangeTime = 0; // last time the mode was changed
char mode = MODE_DEFAULT; // the current mode
int currentNode = 0; // the node the ledwork is listening to

// values for the colors
float redValue   = 0;
float greenValue = 0;
float blueValue  = 0;

// values for the intervals used in flashing/pulsating
int redInterval   = 0;
int greenInterval = 0;
int blueInterval  = 0;

// starttimes to keep track of intervalposition while flashin/pulsating
long redStartTime   = 0;
long greenStartTime = 0;
long blueStartTime  = 0;

// vars for colorrange
int COLOR_MAIN;
int COLOR_SECUNDARY;
int COLOR_HELPER;

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

void setup()
{
  Serial.begin(9600);
  pinMode(PIN_A, OUTPUT);
  pinMode(PIN_B, OUTPUT);
  accInitValue_x = analogRead(PIN_ACC_X);
  accInitValue_y = analogRead(PIN_ACC_Y);
  accInitValue_z = analogRead(PIN_ACC_Z);
  setColorDomain();
}

void setColorDomain()
{
  //COLOR_MAIN = ceil(random(1,4)); // select a number 1, 2 or 3 randomly
  //COLOR_SECUNDARY = 
  COLOR_MAIN = BLUE;
  COLOR_SECUNDARY = RED;
  COLOR_HELPER = GREEN;
}

void loop()
{
  currentTime = millis();
  setMode();
  expressBehaviour();
  // send a command every 100 ms
  if(currentTime - messageSendTime >= 100)
  {
    sendMessage();
  }
  // read a node message very 200 ms
  if((messageReadTime == 0) || (currentTime - messageReadTime > 200))
  {
    messageReadTime = currentTime;
    currentNode++;  // increase the nodenumber by 1
    if(currentNode > 4)
    {
      currentNode = 1; // reset the nodenumber to 1
    } 
    setReadCommandConditions();
  }
  readMessage();
}

void sendMessage()
{
  // send the command
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

void setMode()
{
  // set the mode if nessecery
  char oldMode = mode; // save the oldmode for later
  switch(mode)
  {
    case MODE_ATTACHED:
      break;
    case MODE_MOVING:
      if(currentTime - modeChangeTime > 2000)
      {
        mode = MODE_DEFAULT;
      }
      break;
    case MODE_DEFAULT:
    default:
      accValue_x = analogRead(PIN_ACC_X);
      accValue_y = analogRead(PIN_ACC_Y);
      accValue_z = analogRead(PIN_ACC_Z);
      if(abs(accInitValue_x - accValue_x) > 25 || abs(accInitValue_y - accValue_y) > 25 || abs(accInitValue_z - accValue_z) > 25)
      {
        mode = MODE_MOVING; 
      }
  } 
  if(oldMode != mode)
  {
    modeChangeTime = currentTime;
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
  setColorIntervals(500, 8000);
  outPutMappedLightValues(true);
}

void expressBehavior_moving()
{
  setColorIntervals(100, 500);
  outPutMappedLightValues(false);
}

void setColorIntervals(int minInterval, int maxInterval)
{
  if((redStartTime == 0) || ((currentTime - redStartTime) >= redInterval))
  {
    redInterval = random(minInterval, maxInterval);
    redStartTime = currentTime;
  }
  if((greenStartTime == 0) || ((currentTime - greenStartTime) >= greenInterval))
  {
    greenInterval = random(minInterval, maxInterval);
    greenStartTime = currentTime;
  }
  if((blueStartTime == 0) || ((currentTime - blueStartTime) >= blueInterval))
  {
    blueInterval = random(minInterval, maxInterval);
    blueStartTime = currentTime;
  }
}

float getMappedLedValueIntervalBased(float startTime, int interval, boolean fade, float minValue, float maxValue)
{
  float currentStep = abs((currentTime - startTime) / interval - 0.5) * 2;
  return fade ? mapFloat(currentStep, 0, 1, minValue, maxValue) : (currentStep > 0.5 ? HIGH : LOW);
}

void outPutMappedLightValues(boolean fade)
{
  //@TODO: better values for colors based on domain
  redValue   = getMappedLedValueIntervalBased(redStartTime, redInterval, fade, (COLOR_MAIN == RED ? 0.5 : 0), (COLOR_MAIN == RED ? 1 : (COLOR_SECUNDARY == RED ? 0.8 : 0.4)));
  greenValue = getMappedLedValueIntervalBased(greenStartTime, greenInterval, fade, (COLOR_MAIN == GREEN ? 0.5 : 0), (COLOR_MAIN == GREEN ? 1 : (COLOR_SECUNDARY == GREEN ? 0.5 : 0.3)));
  blueValue  = getMappedLedValueIntervalBased(blueStartTime, blueInterval,  fade, (COLOR_MAIN == BLUE ? 0.5 : 0), (COLOR_MAIN == BLUE ? 1 : (COLOR_SECUNDARY == BLUE ? 0.4 : 0.2)));
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

float mapFloat(float x, float in_min, float in_max, float out_min, float out_max)
{
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}
