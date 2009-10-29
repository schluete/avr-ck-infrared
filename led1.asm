
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
            .equ TCNT1H=0x2d
            .equ TCNT1L=0x2c


            ; die Tabelle der Interuptvektoren
vectors:    .org 0
            rjmp main         ; Reset
            reti              ; External Interrupt Request 0
            reti              ; External Interrupt Request 1
            reti              ; Timer 1 Capture Event
            reti              ; Timer 1 Compare Match A
            rjmp timer1       ; Timer 1 Overflow
            reti              ; Timer 0 Overflow


            ; das Hauptprogram
main:       cli               ; Interrupts komplett ausschalten
 
            ldi r16,0x1f      ; die unteren 5 Bits von Port B sind Ausgaenge
            out DDRB,r16
            ldi r16,0x00      ; Port D sind Eingaenge
            out DDRD,r16

            ldi r16,0x00      ; aktuelle Interuptflags loeschen
            out TIFR,r16
            ldi r16,0x80      ; Timer 1 overflow interupt enable
            out TIMSK,r16

            ldi r16,0x02      ; die Systemclock ist 8MHz, mit CLKDIV8 als Default programmiert
            out TCCR1B,r16    ; dann 1MHz, mit einem Prescaler von 8(=0x02) also 125kHz
            rcall reload_t1   ; und jetzt noch den Startwert fuer 250ms eintragen

            ldi r16,0xaa      ; ein Bitmuster auf die LEDs legen
            out PORTB,r16

            sei               ; Interrupt global einschalten
loop:       rjmp loop         ; und dann im Hauptprogram nichts mehr machen


            ; der Interupthandler fuer Timer 1
timer1:     in r20,SREG       ; Statusregister sichern und dann ...
            cli               ; ... die Interupt ausschalten

            in r21,PORTB      ; jetzt die LEDs toggeln
            com r21
            out PORTB,r21
 
            rcall reload_t1   ; Timer wieder auf 250ms initialisieren
            out SREG,r20      ; Interrupts wieder einschalten
            reti
              

            ; laedt den initialen TimerCount fuer 250ms
reload_t1:  ldi r16,0x85      ; der Timer soll alle 250ms auftreten, bei einem Takt von 125kHz...
            out TCNT1H,r16    ; ... (entspricht 8us) muessen wir also 62500 Zyklen warten. Da der... 
            ldi r16,0xed      ; ... Counter hochzaehlt und bei 0xffff ausloest schreiben wir als...
            out TCNT1L,r16    ; ... Startwert deshalb 0xffff-62500=0xbdb in den Timer
            ret

