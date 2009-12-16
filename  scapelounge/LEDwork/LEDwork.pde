#include <Streaming.h>

void setColorInterval(long &startTime, int &interval);

// CONSTANTS
const char COMMAND_START  = 'STX';   // cannot be used in the command!!!
const char COMMAND_END    = 'ETX';     // cannot be used in the command!!!

const char STATE_DEFAULT  = 'A';
const char STATE_FADING   = 'B';
const char STATE_PICKEDUP = 'C';

const int COMMAND_STATE_NEW     = 0;
const int COMMAND_STATE_READ    = 1;
const int COMMAND_STATE_RED     = 2;
const int COMMAND_STATE_BLUE    = 3;
const int COMMAND_STATE_GREEN   = 4;
const int COMMAND_STATE_STATE   = 5;
const int COMMAND_STATE_END     = 6;

// ENVIRONMENT VARIABLES
long currentTime = 0;
char state = STATE_DEFAULT;
int fase  = 0;  //can range from 0-255
int redValue   = 0;
int blueValue  = 0;
int greenValue = 0;
int redInterval   = 0;
int blueInterval  = 0;
int greenInterval = 0;
long redStartTime   = 0;
long blueStartTime  = 0;
long greenStartTime = 0;

//function prototypes (needed if function uses references)
void setColorInterval(long &startTime, int &interval, int minInterval, int maxInterval);
void setColorInterval(long &startTime, int &interval);

void setup()
{
  Serial.begin(9600);
  setColorInterval(redStartTime, redInterval);
  setColorInterval(blueStartTime, blueInterval);
  setColorInterval(greenStartTime, greenInterval);
}

void loop()
{
  //do stuff, or not, or...
}

void expressBehaviour()
{
  //setColorInterval(&redStartTime, &redInterval);
  switch(state)
  {
    case STATE_DEFAULT:
    default:
      expressBehavior_default();
  } 
}

void expressBehavior_default()
{
  if(currentTime - redStartTime >= redInterval)
  {
  }
}

void setColorInterval(long &startTime, int &interval, int minInterval, int maxInterval)
{
  if((startTime == 0) || (currentTime - startTime >= interval))
  {
    interval = random(minInterval, maxInterval);
    startTime = currentTime;
  }
}

void setColorInterval(long &startTime, int &interval)
{
  setColorInterval(startTime, interval, 0, 10000);
}
