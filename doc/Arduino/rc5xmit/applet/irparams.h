#define PHILIPSTV 1

// user configuration
#define SYSCLOCK 16000000  // main system clock (Hz)
#define PRESCALE 8       // TIMER1 prescale value (state machine clock)

// Philips TV defines
#define PHILIPSTV_PULSECLOCK 36000  // Hz

#define PHILIPSTV_T           889  // T, microseconds
#define PHILIPSTV_RETRANSGAP  128  // gap beween code retransmissions (T units)

#define PHILIPSTV_UNITLENGTH 5   // bits in unit code
#define PHILIPSTV_BUTTONLENGTH 6 // bits in button code

#define PHILIPSTV_UNIT 0x0 // unit code for Philips TV

