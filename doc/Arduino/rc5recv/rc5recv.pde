// RC5 remote control receiver decoder.
// Tested with Philips or Philips compatible TV remotes.
// Developed by Alessandro Lambardi, 25/12/2007
// Released under Creative Commons license 2.5.
// Non-commercial use, attribution, share alike.
//
// Completely interrupt driven, no 'wait until' loops.
// When a valid code is received it is made available at
// variable data_word (main loop).
// External Arduino clock 16Mhz, hardware prescaler = 1
// Designed for AVR ATtiny24, adapted for Arduino.
//
// Program memory resources used (ATtiny24):
// 670 Program bytes circa out of 2048 (1/3 circa)
// 4 data bytes out of 128
//
// Internal hardware resources used:
// 8Bit Timer 0:    reset by software as required
// PORTA B, bit 0   can be relocated together with pin
//          change interrupt assignments

#define F_CPU 16000000UL    // CPU clock in Hertz.
#define TMR0_PRESCALER 256UL
#define IR_BIT 1778UL   // bit duration (us) in use for IR remote (RC5 std)
#define IR_IN  8    //IR receiver is on digital pin 8 (PORT B, bit0)

#define TMR0_T (F_CPU/TMR0_PRESCALER*IR_BIT/1000000UL)
#define TMR0_Tmin (TMR0_T - TMR0_T/4UL) // -25%
#define TMR0_Tmax (TMR0_T + TMR0_T/4UL) // +25%
#if TMR0_Tmax > 255
    #error "TMR0_Tmax too big, change TMR0 prescaler value ", (TMR0_Tmax)
#endif

// Variables that are set inside interrupt routines and watched outside
// must be volatile
volatile uint8_t    tmr0_OC1A_int;  // flag, signals TMR0 timeout (bad !)
volatile uint8_t    no_bits;        // RC5 bits counter (0..14)
volatile uint16_t   ir_data_word;   // if <> holds a valid RC5 bits string (good !)

void start_timer0(uint8_t cnt)
{
    OCR0A = cnt;
    TCNT0 = 0;
    tmr0_OC1A_int = 0;
    TIMSK0 |= _BV(OCIE0A);  // enable interrupt on OC0A match
    TCCR0B |= _BV(CS02);    // start timer0 with prescaler = 256
}

// Interrupt service routines
//  signal handler for pin change interrupt
ISR(PCINT0_vect)
{        
    if(no_bits == 0) {      // hunt for first start bit (must be == 1)
        if(!digitalRead(IR_IN)){
            start_timer0(TMR0_Tmax);
            no_bits++;
            ir_data_word = 1;
        }
    } else {
        if(!tmr0_OC1A_int) {        // not too much time,
            if(TCNT0 > TMR0_Tmin) { // not too little.
                // if so wait next (mid bit) interrupt edge
                start_timer0(TMR0_Tmax);
                no_bits++;
                ir_data_word <<= 1;
                if(!digitalRead(IR_IN)){
                    ir_data_word |= 1;
                } else {
                    ir_data_word &= ~1;
                }
            }
        }
    }
}

// timer0 OC1A match interrupt handler
ISR(TIM0_COMPA_vect)
{
    TCCR0B &= ~(_BV(CS02) | _BV(CS01) | _BV(CS00)); // stop timer
    tmr0_OC1A_int = 1;  // signal timeout
    no_bits = 0;        // start over with hunt for valid stream
    ir_data_word = 0;
}

void setup()
{
    Serial.begin(9600); // opens serial port, sets data rate to 9600 bps

    // IR remote control receiver is on IR_IN digital port
    pinMode(IR_IN, INPUT);

    // pin change interrupt enable on IR_IN port
    PCMSK0 |= _BV(PCINT0);
    PCICR |= _BV(PCIE0);

    // Timer 0: Fast PWM mode. Stopped, for now.
    TCCR0A = _BV(WGM00) | _BV(WGM01);
    TCCR0B = _BV(WGM02);
    no_bits = 0;

    // enable interrupts
    sei();
}

void loop() {

    uint8_t data_word;    // 0..63 holds a valid RC5 key code.
    for(;;) {
        if((no_bits == 14) && ((ir_data_word & 0x37C0) == 0x3000))
        {
            no_bits = 0;                        // prepare for next capture
            data_word = ir_data_word & 0x3F;    // extract data word

            Serial.print(data_word, HEX);
        }
    }
}
