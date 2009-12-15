#include <Streaming.h>

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
char state = STATE_DEFAULT;
int redValue   = 0;
int blueValue  = 0;
int greenValue = 0;

void setup()
{
  Serial.begin(9600);
}

void loop()
{
  //do stuff
}


