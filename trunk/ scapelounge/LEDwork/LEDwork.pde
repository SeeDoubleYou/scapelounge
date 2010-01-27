#include <Streaming.h>

// ---- CONSTANTS ----
// pins
const int PIN_A = 12; // PIN_A and PIN_B are used to set the multiplexer
const int PIN_B = 13;
const int PIN_LIGHT_RED   = 10; // ledpins
const int PIN_LIGHT_GREEN = 9;
const int PIN_LIGHT_BLUE  = 11;
const int PIN_ACC_X = 0; // accelerometer pins
const int PIN_ACC_Y = 1;
const int PIN_ACC_Z = 2;

// command constants. used for beginning and end, cannot be used inside the comand!
const char COMMAND_START  = 2; // 'STX'
const char COMMAND_END    = 3; // 'ETX'

// modes, 3 modes for general behaviours.
const char MODE_DEFAULT  = 'A'; // when the ledwork is not attached to anything and is laying still
const char MODE_MOVING   = 'B'; // moving while not attached to anything
const char MODE_ATTACHED = 'C'; // attached to other ledworks and/or panels

// constants for the colors that the ledwork can use easily to read values in switches
const int RED = 0;
const int GREEN = 1;
const int BLUE = 2;

// ---- ENVIRONMENT VARIABLES ----
// A and B set the multiplexer to listen to a certain port
int PIN_A_value = LOW;
int PIN_B_value = LOW;

// variables used in HSB calculation
float hueRangeStart; // hue has a range that the ledwork can use to create it's color
int hueRangeLength; // defines the size of the range
float oldHue = 0; // old value is stored to compute the current hue based on an interval, same for saturatoin and brightness
float oldSaturation;
float oldBrightness;
float currentHue; // the current hue of the ledwork, set in setup
float currentSaturation; // set here since at the moment it will not change during the program 
float currentBrightness;
float plannedHue = 0; // if the ledwork is going from one you to the other, this is the hue it will persue
float plannedSaturation = 0;
float plannedBrightness = 0;
long hueChangeStart = 0; // the time that the ledwork started to go to a new hue
long saturationChangeStart = 0;
long brightnessChangeStart = 0;
int hueInterval; // the time it will takle to go from one hue to the other
int hueIntervalMin; // the minimum interval, can differ based on the mode
int hueIntervalMax; // the maximum interval, can differ based on the mode
int saturationInterval;
int saturationIntervalMin;
int saturationIntervalMax;
int brightnessInterval;
int brightnessIntervalMin;
int brightnessIntervalMax;

long currentTime = 0; // the number of milliseconds sinds the program was started (will reset to 0 after about 50 days)
long messageSendTime = 0; // last time a message was send
long messageReadTime = 0; // last time a message was read
long modeChangeTime = 0; // last time the mode was changed
char mode = MODE_DEFAULT; // the current mode
boolean pulsing = true; // whether the leds should pulsate or blink

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

// info about the nodes
int currentNode = 0; // the node the ledwork is listening to
boolean nodesConnected[5] = {false, false, false, false}; // array with a boolean for each node whether it is connected (0 = node 1)
boolean skipToNextNode = false; //when a node isn't connected or read the ledwork can skip it and go to the next node
int nrNodesConnected = 0; // the number of nodes that the ledwork is curently connected to

// commands to be saved.
const int COMMAND_LENGTH = 3; // defined here for easy changing
char COMMAND_node_1[COMMAND_LENGTH] = ""; // command recieved from node 1
char COMMAND_node_2[COMMAND_LENGTH] = ""; // command recieved from node 2
char COMMAND_node_3[COMMAND_LENGTH] = ""; // command recieved from node 3
char COMMAND_node_4[COMMAND_LENGTH] = ""; // command recieved from node 4
char* COMMANDS[5] = {COMMAND_node_1,COMMAND_node_2,COMMAND_node_3,COMMAND_node_4}; //array containing pointers to the commands
char COMMAND_temp[COMMAND_LENGTH] = ""; // used to store the command before it is fully written
char COMMAND_CALCULATED[COMMAND_LENGTH]; // the command the ledwork will send to the nodes

int currentReadCommandIndex = -1; //used to keep track of the index of the read character;
boolean commandRecieved = false; // whether the current read command is fully recieved

// DEBUGVALUES
boolean inDebugMode = false;
long debugTime = 0;
int debugInterval = 250;

//prototypes (for functions  that will not get parsed by the arduino environment)
static uint32_t deadbeef_seed; 
static uint32_t deadbeef_beef = 0xdeadbeef; 

void setup()
{
  Serial.begin(9600); // the serial connection. Don't make it to fast (9600 should be good) or the chance of failing will increase
  pinMode(PIN_A, OUTPUT); // PIN_A and PIN_B must be set as output to make sure that it will be set to 0 or 1 at all time
  pinMode(PIN_B, OUTPUT);
  setNewModeConditions(); // so set the intervals
}

void resetAccInitValues()
{
  accInitValue_x = analogRead(PIN_ACC_X); // set the initial values for the accelerometer by reading the pins
  accInitValue_y = analogRead(PIN_ACC_Y);
  accInitValue_z = analogRead(PIN_ACC_Z);
}

void setColorDomain()
{
  // since the default random number generator sucks monkey balls the ledwork use deadbeef to create good random seed.
  deadbeef_srand(analogRead(5)); //get a real random number (use an unused analog pin)
  randomSeed(deadbeef_rand()); //use the random to create a random seed (better randomness)
  hueRangeStart = random(0, 256); //set the huerangestart (pick a color domain)
}

void loop()
{
  currentTime = millis(); // update the current time
  setMode(); // set the mode (it might have changed)
  expressBehaviour(); // express a behaviour based on environment
  handleMessaging(); // exchanges messages with the nodes
	if(inDebugMode)
	{
	  debug();
	}
}

void debug()
{
  if(debugTime == 0 || currentTime - debugTime > debugInterval)
	{
	  debugTime = currentTime;
		//Serial << "pH: " << plannedHue << " pS: " << plannedSaturation << " pB: " << plannedBrightness << " H: " << currentHue << " S: " << currentSaturation << " V: " << currentBrightness << " R: " << redValue << " G: " << greenValue << " B: " << blueValue << "\n";
		//Serial << "oH: " << oldHue << " pH: " << plannedHue << " cH: " << currentHue << "\n";
		//Serial << "m=" << mode << " n=" << nrNodesConnected << " c" << currentNode << "=" << COMMANDS[currentNode-1] << "\n";
	}
}

void setMode()
{
  // set the mode if nessecery
  char oldMode = mode; // save the oldmode for later
  if(nrNodesConnected > 0)
	{
		mode = MODE_ATTACHED;
	}
	else
	{
    switch(mode)
    {
      case MODE_ATTACHED:
		    if(nrNodesConnected == 0)
			  {
				  mode = MODE_DEFAULT;
			  }
        break;
      case MODE_MOVING:
        //if(!isMoving() && currentTime - modeChangeTime > 2000)
        if(currentTime - modeChangeTime > 5000)
        {
				  // the ledwork stopt moving and it has been more than two seconds since it started moving, return to defaultmode
          mode = MODE_DEFAULT;
        }
        break;
      case MODE_DEFAULT:
      default:
			  // check the accelerometer values
        accValue_x = analogRead(PIN_ACC_X);
        accValue_y = analogRead(PIN_ACC_Y);
        accValue_z = analogRead(PIN_ACC_Z);
        if(isMoving())
        {
          //mode = MODE_MOVING; 
        }
    } 
  }
  if(oldMode != mode)
  {
		// the mode has changed
    modeChangeTime = currentTime; // set the time the mode was changed to current
    setNewModeConditions(); // set environment variables based on the new mode
  }
}

boolean isMoving()
{
  // @TODO: the check on movement could be radicaly improved. Better would be to keep track of an avarage. Do testing with an accelerometer to see output.
  return abs(accInitValue_x - accValue_x) > 25 || abs(accInitValue_y - accValue_y) > 25 || abs(accInitValue_z - accValue_z) > 25;
}

void setNewModeConditions()
{
	//after a mode has changed some variables have to be adapted to fit the mode
  switch(mode)
  {
    case MODE_ATTACHED:
      hueRangeLength = 10;
      hueIntervalMin = 100;
      hueIntervalMax = 2000;
			saturationIntervalMin = 100;
      saturationIntervalMax = 2000;
      brightnessIntervalMin = 100;
      brightnessIntervalMax = 2000;
      pulsing = true;
      break;
    case MODE_MOVING:
      setColorDomain(); // pick a new color domain (keep things random)
      hueIntervalMin = 100;
      hueIntervalMax = 500;
			saturationIntervalMin = 100;
      saturationIntervalMax = 500;
      brightnessIntervalMin = 100;
      brightnessIntervalMax = 500;
      pulsing = true;
      break;
    case MODE_DEFAULT:
    default:
      setColorDomain(); // pick a color domain in HSB
      resetAccInitValues();
      hueRangeLength = 80;
      hueIntervalMin = 1000;
      hueIntervalMax = 10000;
			saturationIntervalMin = 2000;
      saturationIntervalMax = 5000;
      brightnessIntervalMin = 2000;
      brightnessIntervalMax = 5000;
      pulsing = true;
  } 
}

void expressBehaviour()
{
  pinMode(7, OUTPUT);
  pinMode(6, OUTPUT);
  pinMode(5, OUTPUT);
  switch(mode)
  {
    case MODE_ATTACHED:
      digitalWrite(7, LOW);
      digitalWrite(6, LOW);
      digitalWrite(5, HIGH);
      expressBehavior_attached();
      break;
    case MODE_MOVING:
      digitalWrite(7, LOW);
      digitalWrite(6, HIGH);
      digitalWrite(5, LOW);
      expressBehavior_moving();
      break;
    case MODE_DEFAULT:
    default:
      digitalWrite(7, HIGH);
      digitalWrite(6, LOW);
      digitalWrite(5, LOW);
      expressBehavior_default();
  } 
}

void expressBehavior_default()
{
  setHSBIntervals();
  updateHSB();
  outPutMappedLightValues();
}

void expressBehavior_moving()
{
  //if(currentTime - modeChangeTime > 2000)
  //{
    currentBrightness = 1;
    currentSaturation = 0;
  //}
  //else
  //{
  //  setHSBIntervals();
  //  updateHSB();
  // }
  outPutMappedLightValues();
}

void expressBehavior_attached()
{
  boolean notComfi;
  if((currentTime - modeChangeTime) < 500)
  {
    setHSBIntervals();
    updateHSB(); 
    currentBrightness = 1;
    currentSaturation = 0;
    notComfi = true;
  }
  else
  {
    if(notComfi)
    {
      newSaturation();
      newBrightness();
      notComfi = false;
    }
    setHSBIntervals();
    updateHSB();
	  hueRangeStart = getAverageHueFromNodes(false); //nrNodesConnected <= 1);
    //currentHue = getAverageHueFromNodes(false);
  }
  outPutMappedLightValues();
}

int getAverageHueFromNodes(boolean includeSelf)
{
  int sumHue = 0;
  int countHue = 0;
  for(int i=0; i<4; i++)
  {
    if(nodesConnected[i])
    {
      sumHue += (int)COMMANDS[i][0];
      countHue++;
    }
  }
	if(includeSelf)
	{
		sumHue += currentHue;
    countHue++;
	}
	float avarageHue = sumHue/countHue;
	if(avarageHue < 0 )
	{
	  avarageHue +=255;
	}
  return avarageHue;
}

void setHSBIntervals()
{
  if(hueChangeStart == 0 || ((currentTime - hueChangeStart) >= hueInterval))
  {
    newHue();
  }
	if(saturationChangeStart == 0 || ((currentTime - saturationChangeStart) >= saturationInterval))
  {
    newSaturation();
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

void planNewHue()
{
  plannedHue = random(hueRangeStart, hueRangeStart + hueRangeLength);
  // THE HUE CAN BECOME > 255 BUT THIS IS OK FOR CALCULATION. ONLY IN setRGBFromCurrentHSB IT WILL BE NORMALIZED
}

void planNewSaturation()
{
  plannedSaturation = 1; //(float)(random(0, 100) / 100);
}

void planNewBrightness()
{
  plannedBrightness = 0.5 + (float)(random(0, 100) / 200);
}

void setNewHueInterval()
{
  hueInterval = random(hueIntervalMin, hueIntervalMax);
}

void setNewSaturationInterval()
{
  saturationInterval = random(saturationIntervalMin, saturationIntervalMax);
}

void setNewBrightnessInterval()
{
  brightnessInterval = random(brightnessIntervalMin, brightnessIntervalMax);
}

void setRGBFromCurrentHSB()
{
  if(currentSaturation == 0)
  {
     redValue = greenValue = blueValue = currentBrightness;
  }
  else
  {
     //float hue = ((currentHue % 256)/255) * 6; // arduino can't do modulo on floats (facepalm), so instead the ledwork needs the folowing three lines
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

void handleMessaging()
{
  // send a command every 100 ms
  if(currentTime - messageSendTime >= 20)
  {
    sendMessage();
  }
  // read a node message every 200 ms or when skipToNextNode == true
  if(skipToNextNode || ((messageReadTime == 0) || (currentTime - messageReadTime > 40)))
  {
    Serial.flush(); //flush the serial buffer so that other nodes will not "steal" bytes from other nodes 
    // if the ledwork hasn't read a command in previous step, that nodes wasn't connected (at least not good enough)
	  if(!commandRecieved)
	  {
		  nodesConnected[currentNode-1] = false;
	  }
	  commandRecieved = false; // reset
	  skipToNextNode = false; // reset
    messageReadTime = currentTime;
    currentNode++;  // increase the nodenumber by 1
    if(currentNode > 4)
    {
			// the ledwork has been past all the nodes
			updateNrNodesConnected();
      currentNode = 1; // reset the nodenumber to 1
    } 
    setReadCommandConditions();
  }
  readMessage();
}

void sendMessage()
{
  // send the command
	calculateCommand();
	Serial << COMMAND_START << COMMAND_CALCULATED << COMMAND_END;
  messageSendTime = currentTime;
}

void calculateCommand()
{
  char command[COMMAND_LENGTH] = {(char)makeCommandCharValid(currentHue), (char)(nrNodesConnected + 4)};
	strcpy(COMMAND_CALCULATED, command);
}

byte makeCommandCharValid(byte character)
{
  if(character == (byte)2)
  {
    character = (byte)1;
  }
  if(character == (byte)3)
  {
    character = (byte)4;
  }
  return character;
}

void readMessage()
{
  // if the serial is available, read the command and save it.
  if(Serial.available() > 0)
  {
    char readChar = Serial.read(); // read a single character from serial
    switch(readChar)
    {
      case COMMAND_START:
        currentReadCommandIndex = 0;
        break;
      case COMMAND_END:
        if(currentReadCommandIndex != -1)
        {
          if(currentReadCommandIndex == COMMAND_LENGTH -1)
          {
            //if the endbyte is in the right place the ledwork assumes the command is ok
            commandRecieved = true;
          }
        }
        currentReadCommandIndex = -1;
        break;
      default:
        if(currentReadCommandIndex != -1)
        {
          COMMAND_temp[currentReadCommandIndex++] = readChar; //save the read character to a temorary string
        }
    }
  }
  if(commandRecieved)
  {
    // the ledwork has recieved a full command, copy the temporary command to the right array.
    strcpy(COMMANDS[currentNode-1], COMMAND_temp);
		nodesConnected[currentNode-1] = true; // the currentNode is connected and the ledwork has its command
		skipToNextNode = true; // skip to the next node
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
  currentReadCommandIndex = -1; // reset
  digitalWrite(PIN_A, PIN_A_value);
  digitalWrite(PIN_B, PIN_B_value);
}

void outPutMappedLightValues()
{
	setRGBFromCurrentHSB();
  outputMappedLightValue(PIN_LIGHT_RED,   redValue);
  outputMappedLightValue(PIN_LIGHT_GREEN, greenValue);
  outputMappedLightValue(PIN_LIGHT_BLUE,  blueValue);
}

void updateHSB()
{
  currentHue =        getMappedValueIntervalBased(hueChangeStart,        hueInterval,        pulsing, plannedHue,        oldHue);
	currentSaturation = getMappedValueIntervalBased(saturationChangeStart, saturationInterval, pulsing, plannedSaturation, oldSaturation);
  currentBrightness = getMappedValueIntervalBased(brightnessChangeStart, brightnessInterval, pulsing, plannedBrightness, oldBrightness);
}

void outputMappedLightValue(int outputPin, float mappedValue)
{
  // Convert the input value to a value between 0 and 255 and write it to the pin
  int outputValue = constrain(round(mappedValue * 255),  0, 255);
  analogWrite(outputPin, outputValue);
}

void updateNrNodesConnected()
{
	nrNodesConnected = 0;
	for(int i = 0; i <= 4; i++)
	{
		if(nodesConnected[i])
		{
			nrNodesConnected++;
		}
	}
}

//---------------------------------------------------------------------------------------------------------------------------
// helper functions

float getMappedValueIntervalBased(float startTime, int interval, boolean fade, float minValue, float maxValue)
{
  float currentStep = (currentTime - startTime) / interval;
  return fade ? mapFloat(currentStep, 0, 1, maxValue, minValue) : (currentStep > 0.5 ? HIGH : LOW);
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
