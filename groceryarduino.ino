#include "Adafruit_Thermal.h"

#include "SoftwareSerial.h"
#define TX_PIN 6 // Arduino transmit - labeled RX on printer
#define RX_PIN 5 // Arduino receive - labeled TX on printer

SoftwareSerial mySerial(RX_PIN, TX_PIN); // Declare SoftwareSerial obj first
Adafruit_Thermal printer(&mySerial);     // Pass addr to printer constructor
String rasPiVal;

int potValue;
int potMiddle = 1024 / 2;

int pinPotMeter = 2;

int pinMotorDirection = 13;
int pinMotorSpeed = 11;
int pinMotorBrake = 8;
//int pinMotorSense = 1;

int motorDirection;
int motorSpeed;

int motorMargin = 5;
int upThreshold = 800;
int downThreshold = 200;

int encPinA = 2;
int encPinB = 5;

int pinButton = 7;
boolean buttonState = 0;
boolean buttonPressed = false;
boolean buttonHeld = false;

unsigned long startMillis;
unsigned long currentMillis;
const unsigned long period = 1400;

boolean sliderMessageSendUp = false;
boolean sliderMessageSendDown = false;

static int pinA = 2; // Our first hardware interrupt pin is digital pin 2
static int pinB = 3; // Our second hardware interrupt pin is digital pin 3
volatile byte aFlag = 0; // let's us know when we're expecting a rising edge on pinA to signal that the encoder has arrived at a detent
volatile byte bFlag = 0; // let's us know when we're expecting a rising edge on pinB to signal that the encoder has arrived at a detent (opposite direction to when aFlag is set)
volatile int encoderPos = 0; //this variable stores our current value of encoder position. Change to int or uin16_t instead of byte if you want to record a larger range than 0-255
volatile int oldEncPos = 0; //stores the last encoder position value so we can compare to the current reading and see if it has changed (so we know when to print to the serial monitor)
volatile byte reading = 0; //somewhere to store the direct values we read from our interrupt pins before checking to see if we have moved a whole detent

void setup() {
  Serial.begin(9600);
  mySerial.begin(9600);
  //printer.begin();
  //prep potmeter pins
  pinMode(pinPotMeter, INPUT);
  //prep motor pins
  pinMode(pinMotorDirection, OUTPUT);
  pinMode(pinMotorBrake, OUTPUT);
  //prep button pins
  pinMode(pinButton, INPUT_PULLUP);
  //prep encoder pins
  pinMode(pinA, INPUT_PULLUP); // set pinA as an input, pulled HIGH to the logic voltage (5V or 3.3V for most cases)
  pinMode(pinB, INPUT_PULLUP); // set pinB as an input, pulled HIGH to the logic voltage (5V or 3.3V for most cases)
  attachInterrupt(0,PinA,RISING); // set an interrupt on PinA, looking for a rising edge signal and executing the "PinA" Interrupt Service Routine (below)
  attachInterrupt(1,PinB,RISING); // set an interrupt on PinB, looking for a rising edge signal and executing the "PinB" Interrupt Service Routine (below)
  //initiate serial connection
  Serial.begin(9600);
  // start millis timer
  startMillis = millis();
}

void PinA(){
  cli(); //stop interrupts happening before we read pin values
  reading = PIND & 0xC; // read all eight pin values then strip away all but pinA and pinB's values
  if(reading == B00001100 && aFlag) { //check that we have both pins at detent (HIGH) and that we are expecting detent on this pin's rising edge
    encoderPos --; //decrement the encoder's position count
    bFlag = 0; //reset flags for the next turn
    aFlag = 0; //reset flags for the next turn
  }
  else if (reading == B00000100) bFlag = 1; //signal that we're expecting pinB to signal the transition to detent from free rotation
  sei(); //restart interrupts
}

void PinB(){
  cli(); //stop interrupts happening before we read pin values
  reading = PIND & 0xC; //read all eight pin values then strip away all but pinA and pinB's values
  if (reading == B00001100 && bFlag) { //check that we have both pins at detent (HIGH) and that we are expecting detent on this pin's rising edge
    encoderPos ++; //increment the encoder's position count
    bFlag = 0; //reset flags for the next turn
    aFlag = 0; //reset flags for the next turn
  }
  else if (reading == B00001000) aFlag = 1; //signal that we're expecting pinA to signal the transition to detent from free rotation
  sei(); //restart interrupts
}

void loop() {
  potValue = analogRead(pinPotMeter);

  //controling motors on slider:
  if (potValue < (potMiddle - motorMargin)) {
    digitalWrite(pinMotorDirection, LOW); //set motor direction
    digitalWrite(pinMotorBrake, LOW); //disengage brake
    int calcSpeed = potValue;
    calcSpeed = map(calcSpeed, potMiddle, 0, 180, 255);
    analogWrite(pinMotorSpeed, calcSpeed ); //spin motor at set speed
  } else if (potValue > (potMiddle + motorMargin)) {
    digitalWrite(pinMotorDirection, HIGH); //set motor direction
    digitalWrite(pinMotorBrake, LOW); //disengage brake
    int calcSpeed = potValue;
    calcSpeed = map(calcSpeed, potMiddle, 1024, 180, 255);
    analogWrite(pinMotorSpeed, calcSpeed ); //spin motor at set speed
  } else {
    analogWrite(pinMotorSpeed, LOW); //spin motor at set speed
    //digitalWrite(pinMotorBrake, HIGH); //engage brake
  }

  //sending slider signals to raspi
  if (potValue > upThreshold && sliderMessageSendUp == false) { //statement to send 'up' string to raspi via serial
    Serial.println("sliderDown");
    printIt();
    sliderMessageSendUp = true; //set messageSend to true to avoid repeatedly sending string
  } if (potValue < downThreshold && sliderMessageSendDown == false) { //statement to send 'down' string to raspi via serial
    Serial.println("sliderUp");
    sliderMessageSendDown = true; //set messageSend to true to avoid repeatedly sending string
  }
  
  if (sliderMessageSendDown == true && potValue > (downThreshold+20)) { //re-enable sending message about slider position via serial
    //Serial.println("send");
    sliderMessageSendDown = false;
  } else if (sliderMessageSendUp == true && potValue < (upThreshold-20)) { //re-enable sending message about slider position via serial
    //Serial.println("send");
    sliderMessageSendUp = false;
  }

  //encoder
  if(oldEncPos != encoderPos) {
    if(oldEncPos < encoderPos) {
      Serial.println("encoderUp");
    }if(oldEncPos > encoderPos) {
      Serial.println("encoderDown");
    }
    oldEncPos = encoderPos;
  }

  //button
  buttonState = digitalRead(pinButton);
  if(buttonState == 0 && buttonPressed == false){
    Serial.println("buttonPressed");
    startMillis = millis();
    delay(100);
    buttonPressed = true;
  }

  if(buttonPressed){
  currentMillis = millis();
  
  if(currentMillis - startMillis >= period && buttonHeld == false){
    Serial.println("buttonDelete");
    buttonHeld = true;
    startMillis = currentMillis;
  }
  }
  
  if(buttonState == 1 && buttonPressed == true){
    buttonPressed = false;
    buttonHeld = false;
    delay(100);
  }
}
  //printer
void printIt(){
  if (Serial.available()) { //fetch data from raspi
    rasPiVal = Serial.read();
    Serial.println(rasPiVal);
  }
  printer.setSize('L');
  printer.justify('C');
  printer.setLineHeight(80);
  printer.println(F("soda 1L"));
}


