
          .device attiny2313

          .equ PIND=0x10
          .equ DDRD=0x11
          .equ PORTD=0x12
          .equ PINB=0x16
          .equ DDRB=0x17
          .equ PORTB=0x18

          .equ SREG=0x3f

          .equ TIMSK=0x39
          .equ TIFR=0x38
          .equ TCCR1A=0x2f
          .equ TCCR1B=0x2e


          ; die Tabelle der Interuptvektoren
vectors:  .org 0
          rjmp main         ; Reset
          reti              ; External Interrupt Request 0
          reti              ; External Interrupt Request 1
          reti              ; Timer 1 Capture Event
          reti              ; Timer 1 Compare Match A
          rjmp timer1       ; Timer 1 Overflow
          reti              ; Timer 0 Overflow


          ; das Hauptprogram
main:     cli               ; Interrupts komplett ausschalten

          ldi r16,0x1f      ; die unteren 5 Bits von Port B sind Ausgaenge
          out DDRB,r16
          ldi r16,0x00      ; Port D sind Eingaenge
          out DDRD,r16

          ;ldi r16,0x05      ; prescaler 1024
          ldi r16,0x04      ; prescaler 256
          out TCCR1B,r16    

          ;ldi r16,0x00      ; aktuelle Interuptflags loeschen
          ;out TIFR,r16
          ldi r16,0x80      ; Timer 1 overflow interupt enable
          out TIMSK,r16


          ldi r16,0xaa      ; ein Bitmuster auf die LEDs legen
          out PORTB,r16

          sei               ; Interrupt global einschalten
loop:     rjmp loop         ; und dann im Hauptprogram nichts mehr machen


          ; der Interupthandler fuer Timer 1
timer1:   in r20,PORTB
          com r20
          out PORTB,r20
          reti
