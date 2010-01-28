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
const char MODE_DEFAULT     = 'A'; // when the ledwork is not attached to anything and is laying still
const char MODE_MOVING      = 'B'; // moving while not attached to anything
const char MODE_ATTACHED    = 'C'; // attached to other ledworks and/or panels
const char MODE_HEAVYMOVING = 'D'; // moving a lot
const char MODE_TURNHUE     = 'E'; // turn the ledwork to set the hue

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
float oldHue = 0; // old value is stored to compute the current hue based on an interval, same for saturation and brightness
float oldSaturation;
float oldBrightness;
float currentHue; // the current hue of the ledwork, set in setup
float currentSaturation; // set here since at the moment it will not change during the program 
float currentBrightness;
float plannedHue = 0; // if the ledwork is going from one you to the other, this is the hue it will persue
float plannedSaturation = 0;
float plannedSaturationMin;
float plannedSaturationMax;
float plannedBrightness = 0;
float plannedBrightnessMin; // set a max and a min for brightness, this can be used for power saving when running on battery power
float plannedBrightnessMax;
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

// time variables
long currentTime = 0; // the number of milliseconds sinds the program was started (will reset to 0 after about 50 days)
long messageSendTime = 0; // last time a message was send
long messageReadTime = 0; // last time a message was read
long modeChangeTime = 0; // last time the mode was changed
long lastMovingTime = 0; // last time the ledwork has moved
long lastHeavyMovingTime = 0; // last time the ledwork has moved heavily
long lastHueChangeByTurnTime = 0; // last time the hue was changed by turning the ledwork

// mode settings
char mode = MODE_DEFAULT; // the current mode
bool pulsing = true; // whether the leds should pulsate or blink

// values for the color in RGB
float redValue   = 0;
float greenValue = 0;
float blueValue  = 0;

// accelerometer, initial value (to check against) and constantly updated values
int accValue_x;
int accValue_y;
int accValue_z;
int accXList[6]; // lists containing the last read values (must have the same length)
int accYList[6];
int accZList[6];
int accListLength = 5; // must be one less than the length of the defined lists
int accListIndex = 0; // the index in the list (used when updating the list)
int accXavarage;
int accYavarage;
int accZavarage;
bool accInitialized = false;

// info about the nodes
int currentNode = 0; // the node the ledwork is listening to
bool nodesConnected[5] = {false, false, false, false}; // array with a bool for each node whether it is connected (0 = node 1)
bool skipToNextNode = false; //when a node isn't connected or read the ledwork can skip it and go to the next node
int nrNodesConnected = 0; // the number of nodes that the ledwork is curently connected to

// commands to be saved.
const int COMMAND_LENGTH = 5; // defined here for easy changing
char COMMAND_node_1[COMMAND_LENGTH] = ""; // command recieved from node 1
char COMMAND_node_2[COMMAND_LENGTH] = ""; // command recieved from node 2
char COMMAND_node_3[COMMAND_LENGTH] = ""; // command recieved from node 3
char COMMAND_node_4[COMMAND_LENGTH] = ""; // command recieved from node 4
char* COMMANDS[5] = {COMMAND_node_1,COMMAND_node_2,COMMAND_node_3,COMMAND_node_4}; //array containing pointers to the commands
char COMMAND_temp[COMMAND_LENGTH] = ""; // used to store the command before it is fully written
char COMMAND_CALCULATED[COMMAND_LENGTH]; // the command the ledwork will send to the nodes

int currentReadCommandIndex = -1; //used to keep track of the index of the read character;
bool commandRecieved = false; // whether the current read command is fully recieved

// DEBUGVALUES
bool inDebugMode = false;
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
  updateAcc(); // update the accelerometer values
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
		Serial << "m=" << mode << " n=" << nrNodesConnected << " c" << currentNode << "=" << COMMANDS[currentNode-1] << "\n";
	}
	Serial << "x: " << accXavarage << "-" << accValue_x << "\t y:" << accYavarage << "-" << accValue_y <<  "\t z:" << accZavarage << "-" << accValue_z << "\n";
}


void updateAcc()
{
  accValue_x = analogRead(PIN_ACC_X);
  accValue_y = analogRead(PIN_ACC_Y);
  accValue_z = analogRead(PIN_ACC_Z);
  accXList[accListIndex]   = accValue_x;
  accYList[accListIndex]   = accValue_y;
  accZList[accListIndex++] = accValue_z;
  if(accListIndex == accListLength) 
  {
    accListIndex = 0; 
    accInitialized = true; 
  }
  int accXSum = 0;
  int accYSum = 0;
  int accZSum = 0;
  for(int i=0; i<accListLength; i++)
  {
    accXSum += accXList[i];
    accYSum += accYList[i];
    accZSum += accZList[i];
  }
  accXavarage = accXSum/accListLength;
  accYavarage = accYSum/accListLength;
  accZavarage = accZSum/accListLength;
}

bool isMoving(int difference)
{
  bool moving = false;
  if(accInitialized)
  {
    moving = abs(accXavarage - accValue_x) > difference || abs(accYavarage - accValue_y) > difference || abs(accZavarage - accValue_z) > difference;
  }
  if(moving)
  {
    lastMovingTime = currentTime;
  }
  return moving;
}

bool isMoving()
{
  return isMoving(4);
}

bool isHeavyMoving()
{
  bool moving = isMoving(6);
  if(moving)
  {
    lastHeavyMovingTime = currentTime;
  }
  return moving;
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
      case MODE_HEAVYMOVING:
        if(!isMoving() && currentTime - lastMovingTime > 2000)
        {
				  // the ledwork stopt moving and it has been more than two seconds since it started moving, return to defaultmode
          mode = MODE_DEFAULT;
        }
        break;
      case MODE_TURNHUE:
        break;
      case MODE_DEFAULT:
      default:
        if(isMoving())
        {
          mode = MODE_MOVING; 
        }
        break;
    } 
  }
  if(oldMode != mode)
  {
		// the mode has changed
    modeChangeTime = currentTime; // set the time the mode was changed to current
    setNewModeConditions(); // set environment variables based on the new mode
  }
}

void setNewModeConditions()
{
	//after a mode has changed some variables have to be adapted to fit the mode
  switch(mode)
  {
    case MODE_ATTACHED:
      plannedSaturationMin = 150;
      plannedSaturationMax = 255;
      plannedBrightnessMin = 150;
      plannedBrightnessMax = 255;
      hueRangeLength = 10;
      hueIntervalMin = 100;
      hueIntervalMax = 2000;
			saturationIntervalMin = 100;
      saturationIntervalMax = 2000;
      brightnessIntervalMin = 100;
      brightnessIntervalMax = 2000;
      pulsing = true;
      break;
    case MODE_HEAVYMOVING:
      break;  
    case MODE_MOVING:
      //setColorDomain(); // pick a new color domain (keep things random)
      plannedSaturationMin = 150;
      plannedSaturationMax = 255;
      plannedBrightnessMin = 150;
      plannedBrightnessMax = 255;
      hueIntervalMin = 100;
      hueIntervalMax = 500;
			saturationIntervalMin = 100;
      saturationIntervalMax = 500;
      brightnessIntervalMin = 100;
      brightnessIntervalMax = 500;
      pulsing = true;
      break;
    case MODE_TURNHUE:
      lastHueChangeByTurnTime = currentTime;
      break;
    case MODE_DEFAULT:
    default:
      setColorDomain(); // pick a color domain in HSB
      plannedSaturationMin = 150;
      plannedSaturationMax = 255;
      plannedBrightnessMin = 150;
      plannedBrightnessMax = 255;
      hueRangeLength = 80;
      hueIntervalMin = 1000;
      hueIntervalMax = 10000;
			saturationIntervalMin = 2000;
      saturationIntervalMax = 5000;
      brightnessIntervalMin = 2000;
      brightnessIntervalMax = 5000;
      saturationChangeStart = 0;
      brightnessChangeStart = 0;
      pulsing = true;
  } 
}

void expressBehaviour()
{
  switch(mode)
  {
    case MODE_ATTACHED:
      expressBehavior_attached();
      break;
    case MODE_MOVING:
      expressBehavior_moving();
      break;
    case MODE_HEAVYMOVING:
      expressBehavior_heavymoving();
      break;
    case MODE_TURNHUE:
      expressBehaviour_turnhue();
      break;
    case MODE_DEFAULT:
    default:
      expressBehavior_default();
  } 
}

void expressBehavior_default()
{
  if(currentTime - modeChangeTime > 5000)
  { 
    plannedBrightnessMin = 100;
    plannedBrightnessMax = 200;
  }
  if(currentTime - modeChangeTime > 10000)
  { 
    plannedBrightnessMin = 50;
    plannedBrightnessMax = 150;
  }
  if(currentTime - modeChangeTime > 20000)
  { 
    plannedBrightnessMin = 10;
    plannedBrightnessMax = 50;
  }
  setHSBIntervals();
  updateHSB();
  outPutMappedLightValues();
}

void expressBehavior_moving()
{
  if((currentTime - modeChangeTime) > 500 && isHeavyMoving())
  {
    mode = MODE_HEAVYMOVING;
    modeChangeTime = currentTime;
  }
  setHSBIntervals();
  updateHSB(); 
  currentBrightness = 255;
  currentSaturation = 0;
  outPutMappedLightValues();
}

void expressBehavior_heavymoving()
{
  if(!isHeavyMoving() && (currentTime - lastHeavyMovingTime) > 100)
  {
    mode = MODE_MOVING;
    modeChangeTime = currentTime;
  }
  else if((currentTime - modeChangeTime) > 4100)
  {
    mode = MODE_TURNHUE;
    modeChangeTime = currentTime;
    setNewModeConditions();
  }
  else if((currentTime - modeChangeTime) > 4000)
  {
    digitalWrite(PIN_LIGHT_RED,   HIGH);
    digitalWrite(PIN_LIGHT_GREEN, HIGH);
    digitalWrite(PIN_LIGHT_BLUE,  HIGH);
  }
  else if((currentTime - modeChangeTime) > 3000)
  {
    digitalWrite(PIN_LIGHT_RED,   HIGH);
    digitalWrite(PIN_LIGHT_GREEN, LOW);
    digitalWrite(PIN_LIGHT_BLUE,  LOW);
  }
  else if((currentTime - modeChangeTime) > 2000)
  {
    digitalWrite(PIN_LIGHT_RED,   LOW);
    digitalWrite(PIN_LIGHT_GREEN, HIGH);
    digitalWrite(PIN_LIGHT_BLUE,  LOW);
  }
  else if((currentTime - modeChangeTime) > 1000)
  {
    digitalWrite(PIN_LIGHT_RED,   LOW);
    digitalWrite(PIN_LIGHT_GREEN, LOW);
    digitalWrite(PIN_LIGHT_BLUE,  HIGH);
  }
}

void expressBehaviour_turnhue()
{
  float checkHue = currentHue;
  if(currentTime - lastHueChangeByTurnTime < 5000)
  {
    //mode = MODE_DEFAULT;
    //modeChangeTime = currentTime;
    currentHue        = plannedHue        = oldHue        = map(accXavarage, 410, 690, 0, 255);
    currentSaturation = plannedSaturation = oldSaturation = 255;
    currentBrightness = plannedBrightness = oldBrightness = 255;
    hueRangeStart = currentHue - (hueRangeLength/2);
    hueChangeStart = saturationChangeStart = brightnessChangeStart = 0;
  }
  if(abs(checkHue - currentHue) > 2)
  {
    lastHueChangeByTurnTime = currentTime;
  }
  outPutMappedLightValues();
}

void expressBehavior_attached()
{
  bool notComfi; // @TODO:  will this work as expected? it is set to null in every loop...
  if((currentTime - modeChangeTime) < 500)
  {
    setHSBIntervals();
    updateHSB(); 
    currentBrightness = 255;
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

int getAverageHueFromNodes(bool includeSelf)
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
  float hueRangeEnd = hueRangeStart + hueRangeLength;
  plannedHue = random(hueRangeStart, hueRangeEnd);
  // THE HUE CAN BECOME > 255 BUT THIS IS OK FOR CALCULATION. ONLY IN setRGBFromCurrentHSB IT WILL BE NORMALIZED
}

void planNewSaturation()
{
  plannedSaturation = (float)(random(plannedSaturationMin, plannedSaturationMax));
}

void planNewBrightness()
{
  plannedBrightness = (float)random(plannedBrightnessMin, plannedBrightnessMax);
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
  float hue = currentHue;
  float saturation = (float)(currentSaturation/255);
  float brightness = (float)(currentBrightness/255);
  if(saturation == 0)
  {
     redValue = greenValue = blueValue = brightness;
  }
  else
  {
		while(hue > 255) { hue -= 255; }
		hue = (hue/255)*6;
	 
    if(hue == 6) { hue = 0; }
    int var_i = floor( hue );    
    float var_1 = brightness * ( 1 - saturation );
    float var_2 = brightness * ( 1 - saturation * ( hue - var_i ) );
    float var_3 = brightness * ( 1 - saturation * ( 1 - ( hue - var_i ) ) );
  
    if      ( var_i == 0 ) { redValue = brightness; greenValue = var_3;      blueValue = var_1; }
    else if ( var_i == 1 ) { redValue = var_2;      greenValue = brightness; blueValue = var_1; }
    else if ( var_i == 2 ) { redValue = var_1;      greenValue = brightness; blueValue = var_3; }
    else if ( var_i == 3 ) { redValue = var_1;      greenValue = var_2;      blueValue = brightness; }
    else if ( var_i == 4 ) { redValue = var_3;      greenValue = var_1;      blueValue = brightness; }
    else                   { redValue = brightness; greenValue = var_1;      blueValue = var_2; }
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
  char command[COMMAND_LENGTH] = {(char)makeCommandCharValid(currentHue), 
                                  (char)makeCommandCharValid(currentSaturation), 
                                  (char)makeCommandCharValid(currentBrightness),  
                                  (char)(nrNodesConnected + 4)};
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

float getMappedValueIntervalBased(float startTime, int interval, bool fade, float minValue, float maxValue)
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
