// RC5 Infrared Transmitter for Arduino Diecimila
//
// Two timers are used, TIMER2 and TIMER1. TIMER1 is used as the RC5 state machine clock,
// with tick length of irparams.t (e.g., 889 microseconds), the basic RC5 time unit.
// The on/off state of the IR LED carrier (pulse clock) may change on any given tick of
// this clock.
//
// TIMER2 is used to generate a square wave on OC2A (pin 11) at the frequency of the RC5
// pulse clock (e.g., 36 kHz). The pulse clock is modulated (turned on and off) by setting
// or clearing the COM2A0 bit of register TCCR2A. Therefore, an IR LED connected between
// pin 11 and ground is the only external circuitry needed to implement the basic IR
// transmitter.
// 
// Using a high power IR LED (Vishay TSAL6100) connected this way (without a current-
// limiting resistor) results in an "on" current of about 80ma. This is within spec of
// that device (100ma max). The Arduino output pins are specced at 40ma max, so the
// current of 80ma exceeds the Arduino spec, but the duty cycle is low (50% max),
// so it's probably OK.
//
// RC5 encoding:
//
// START + TOGGLEBIT + UNITCODE + BUTTONCODE
//
// where:
//   START is a two-bit code, always 11
//   TOGGLEBIT is a one-bit code which toggles on each successive button
//   UNITCODE is a five-bit code specifying the unit being commanded (TV, VCR, etc.)
//   BUTTONCODE is a six-bit code for the button command
//
// Each bit, 0 or 1, is transmitted according to "Manchester" encoding:
//
//   0: MARK followed by SPACE, each of duration irparams.t
//   1: SPACE followed by MARK
//
// To adapt this code to use another RC5-compatible device, minimally
// the unit code needs to be set according to the device, and any
// specific button encodings need to be defined in irparams.h. Note
// the function brand() where the buttons and other parameters are
// actually loaded into the state machine structure.
//
// For more info on RC5, see: http://www.sbprojects.com/knowledge/ir/rc5.htm
//
// Joe Knapp   jmknapp AT gmail DOT com   30APR08

#include "irparams.h"

#define IROUT 11     // pin 11 is OC2A output from TIMER2
#define BLINKLED 13  // mirrors the state of IROUT

#define TICKSPERUSEC ((SYSCLOCK/1000000.) / PRESCALE)
#define mark() (irparams.irledstate = 1) 
#define space() (irparams.irledstate = 0)

// xmitter states
#define START       1
#define STOP        2
#define IDLE        3
#define REXMIT      4
#define CODE        5
#define MANCHONE    6
#define MANCHZERO   7
#define TOGGLE      8

// Pulse clock interrupt uses 16-bit TIMER1
#define INIT_TIMER_COUNT1 (65536 - (int)(TICKSPERUSEC * irparams.t))
#define RESET_TIMER1 TCNT1 = INIT_TIMER_COUNT1

// defines for setting and clearing register bits
#ifndef cbi
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#endif
#ifndef sbi
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
#endif

// function prototypes
void button(byte buttonid, int n);
void send(byte code, int n);
uint8_t timer2top(unsigned int freq);

// state machine variables

struct {
  byte xmitstate;
  byte returnstate;
  byte timer;
  byte unitlength;
  byte buttonlength;
  byte sendflag;
  byte retransmit;
  byte codelen;
  byte bitcounter;
  byte togbit;
  byte nbuttons;
  byte blinkstate;
  byte irledstate;
  unsigned long unit;
  unsigned long button;
  unsigned long code1;
  unsigned int mask16;
  unsigned int t;
  unsigned int retransgap;
} irparams ;

void setup()
{
    cbi(TCCR2A, COM2A1); // disconnect OC2A for now (COM2A0 = 0)
    cbi(TCCR2A, COM2A0);

    cbi(TCCR2B ,WGM22) ;  // CTC mode for TIMER2
    sbi(TCCR2A, WGM21) ;
    cbi(TCCR2A, WGM20) ;
  
    TCNT2 = 0 ;

    cbi(ASSR, AS2);  // use system clock for timer 2

    OCR2A = 255 ;   // set TOP to 255 for now

    cbi(TCCR2B,CS22) ;  // TIMER2 prescale = 1
    cbi(TCCR2B,CS21) ;
    sbi(TCCR2B,CS20) ;

    cbi(TCCR2B,FOC2A) ;  // clear forced output compare bits
    cbi(TCCR2B,FOC2B) ;

    pinMode(IROUT, OUTPUT) ;  // set OC2A to OUPUT 
    pinMode(BLINKLED, OUTPUT) ;
    digitalWrite(BLINKLED, LOW);

    // setup pulse clock timer interrupt
    TCCR1A = 0;  // normal mode

    // Prescale / 8 (16M/8 = 0.5 microseconds per tick)
    // Therefore, the timer interval can range from 0.5 to 128 microseconds
    // depending on the reset value (255 to 0)
    cbi(TCCR1B, CS12);
    sbi(TCCR1B, CS11);
    cbi(TCCR1B, CS10);

    //Timer1 Overflow Interrupt Enable
    sbi(TIMSK1,TOIE1);

    RESET_TIMER1;

    // enable interrupts
    sei();

    // initialize some state machine variables
    irparams.sendflag = 0;
    irparams.togbit = 0;
    irparams.blinkstate = HIGH;
    irparams.xmitstate = IDLE;

    OCR2A = timer2top(PHILIPSTV_PULSECLOCK) ;  // sets TOP value for TIMER2
    irparams.unit = PHILIPSTV_UNIT;
    irparams.unitlength = PHILIPSTV_UNITLENGTH;
    irparams.buttonlength = PHILIPSTV_BUTTONLENGTH;
    irparams.t = PHILIPSTV_T;
    irparams.retransgap = PHILIPSTV_RETRANSGAP;
}

// main loop
void loop()
{
  send(0x5, 1);  // send ID = 0x5
  delay(250); // delay for 250 m -> ~ 4 Hz
}

// xmit state machine 
// RC5 protocol
ISR(TIMER1_OVF_vect) {
  RESET_TIMER1;

  switch(irparams.xmitstate) {
    case START:
      if (irparams.timer == 4) {
        irparams.code1 = ((unsigned long)irparams.unit << irparams.buttonlength) | irparams.button ; // concatenate unit code and button code
        irparams.codelen = irparams.unitlength + irparams.buttonlength ; // set length of signal to be transmitted
        irparams.mask16 = (unsigned int)0x1 << (irparams.codelen - 1) ; // ???
      }
      
      irparams.timer-- ;
      switch(irparams.timer) {
        case 3:
          mark() ;
          break ;
        case 2:
          space() ;
          break ;
        case 1:
          mark() ;
          irparams.xmitstate = TOGGLE ;
          break ;
      }
      break ;
    case TOGGLE:
      irparams.returnstate = CODE ; // go to CODE after toggle bit
      irparams.bitcounter = 0 ;
      if (irparams.togbit) {
        space() ;
        irparams.xmitstate = MANCHONE ;
      }
      else {
        mark() ;
        irparams.xmitstate = MANCHZERO ;
      }
      break ;
    case CODE:
      irparams.returnstate = CODE ;
      if (irparams.bitcounter == irparams.codelen) {
        space() ;
        irparams.xmitstate = STOP ;
        }
      else {
        if (irparams.code1 & irparams.mask16) {  // send ONE
          space() ;
          irparams.xmitstate = MANCHONE ;
        }
        else {
          mark() ;
          irparams.xmitstate = MANCHZERO ;
        }
        irparams.bitcounter++ ;
        irparams.mask16 >>= 1 ;
      } 
      break ;
    case STOP:
      if (irparams.retransmit) {
        irparams.xmitstate = REXMIT ;
        irparams.timer = irparams.retransgap ;
        irparams.sendflag = 0 ;
      }
      else {
        irparams.xmitstate = IDLE ;
        irparams.sendflag = 0 ;
        space() ;
        irparams.togbit ^= 0x1 ;
      }
      break ;
    case IDLE:
      if (irparams.sendflag) {
        irparams.xmitstate = START ;
        space() ;
        irparams.timer = 4 ; // RC5 start is SPACE/MARK/SPACE/MARK
      }
      break ;
   case MANCHONE:
      mark() ;
      irparams.xmitstate = irparams.returnstate ;
      break ;
   case MANCHZERO:
      space() ;
      irparams.xmitstate = irparams.returnstate ;
      break ;
   case REXMIT:
     irparams.timer-- ;
     if (irparams.timer == 0) {
       irparams.sendflag = 1 ;
       irparams.xmitstate = IDLE ;
       irparams.retransmit-- ;
     }
     break ;
  }
  
  // update LEDs
  if (irparams.irledstate) {
    digitalWrite(BLINKLED, HIGH);
    sbi(TCCR2A, COM2A0);   // connect pulse clock
  }
  else {
    digitalWrite(BLINKLED, LOW);
    cbi(TCCR2A, COM2A0);   // disconnect pulse clock
  }
}
// end RC5 state machine

void send(byte code, int n)
{
    irparams.button = code;
    irparams.retransmit = n - 1;
    irparams.sendflag = 1;     // flag for the ISR to send irparams.button 
}

// return TIMER2 TOP value per given desired frequency (Hz)
uint8_t timer2top(unsigned int freq)
{
  return((byte)((unsigned long)SYSCLOCK/2/freq) - 1) ;
}
