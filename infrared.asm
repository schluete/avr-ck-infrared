
            .device attiny2313

            .equ PIND=0x10
            .equ DDRD=0x11
            .equ PORTD=0x12
            .equ PINB=0x16
            .equ DDRB=0x17
            .equ PORTB=0x18

            .equ MCUCR=0x35
            .equ SREG=0x3f
  
            .equ TIMSK=0x39
            .equ TIFR=0x38

            .equ TCCR0A=0x30
            .equ TCCR0B=0x33
            .equ TCNT0=0x32
            .equ OCR0A=0x36

            .equ TCCR1A=0x2f
            .equ TCCR1B=0x2e
            .equ TCNT1H=0x2d
            .equ TCNT1L=0x2c
            .equ OCR1AH=0x2b
            .equ OCR1AL=0x2a

            ; beim RC5-Code wird jedes Bit des Codewortes durch zwei einzelne 
            ; "Sendezeiten" dargestellt. Um den Code moeglichst einfach zu 
            ; senden speichern wir deshalb jedes RC5-Bit in zwei Bits im 
            ; Speicher. Zwei RC5-Bits ergeben also im Speicher ein Nibble 
            ; und lassen sich sich als Hexwert so darstellen:
            ;
            ; RC5: 0 0 =>  Sendzeiten: 10 10 =>  Hexwert: 0xa
            ;      0 1 =>              10 01 =>           0x9
            ;      1 0 =>              01 10 =>           0x6
            ;      1 1 =>              01 01 =>           0x5
            ;
            ; Das RC5-Codewort an sich besteht aus 15 Bits (2 Start, 1 Toggle,
            ; 5 Adress- und 6 Datenbits). Die Startbits sind immer 1, das Toggle
            ; sollte bei jedem Versand wechseln und die Daten sind frei. Ein 
            ; Beispiel mit Adresse=0x5, Daten=0x35 (mit Codierung im Speicher):
            ;
            ;     5     a     9     9     5     9     9  
            ; 01 01 10 10 10 01 10 01 01 01 10 01 10 01   
            ; 1  1  0  0  0  1  0  1  1  1  0  1  0  1  
            ; S1 S2 To A4 A3 A2 A1 A0 D5 D4 D3 D2 D1 D0 
            ;

            .equ CMD0=0x05
            .equ CMD1=0xa9
            .equ CMD2=0x95
            .equ CMD3=0xa6


            ; --------------------------------------------------------------------------------------
            ; die Tabelle der Interuptvektoren
            ; --------------------------------------------------------------------------------------
vectors:    .org 0
            rjmp main         ; Reset
            reti              ; External Interrupt Request 0
            reti              ; External Interrupt Request 1
            reti              ; Timer 1 Capture Event
            reti              ; Timer 1 Compare Match A
            reti              ; Timer 1 Overflow
            reti              ; Timer 0 Overflow
            reti              ; USART Rx Complete
            reti              ; USART Data Register Empty
            reti              ; USART Tx Complete
            reti              ; Analog Comparator
            reti              ; Pin Change Interrupt
            reti              ; Timer 1 Compare Match B
            rjmp timer0       ; Timer 0 Compare Match A
            reti              ; Timer 0 Compare Match B


            ; --------------------------------------------------------------------------------------
            ; das Hauptprogram
            ; --------------------------------------------------------------------------------------
main:       cli               ; Interrupts komplett ausschalten
 
            ;
            ; zuerst die Ports richtig konfigurieren
            ;
            ldi r16,0x1f      ; Port B.0-4 sind Ausgaenge, der Rest durch ISP belegt
            out DDRB,r16
            ldi r16,0x1f      ; Port D.5-6 sind Eingaenge, der D.0-4 sind Ausgaenge
            out DDRD,r16
            ldi r16,0x1f      ; alle Ausgaenge von Port B auf High (also LED aus)
            out PORTB,r16

            ;
            ; jetzt den IR-Code ins RAM schreiben
            ;
            ldi r31,0x00      ; wir schreiben den IR-Code ins SRAM ab 0x60
            ldi r30,0xa0
            ldi r16,CMD0
            st z+,r16
            ldi r16,CMD1
            st z+,r16
            ldi r16,CMD2
            st z+,r16
            ldi r16,CMD3
            st z+,r16

            ;
            ; die PWM fuer den Grundtakt von 36kHz starten
            ;
            ldi r16,0x43      ; WGM=0x0f ergibt eine Fast PWM mit Toggle auf jedem OCR-Match
            out TCCR1A,r16    ; und auf PIN OC1A soll das Signal ausgegeben werden 

            ldi r16,0x19      ; wir wollen keinen Prescaler =0x01 (also 1MHz bei einem 
            out TCCR1B,r16    ; Systemtakt von 8Mhz mit CLKDIV8 programmiert ergibt 1MHz)
                              ; Ausserdem noch WGM12,13=0x0f, siehe oben bei TCCR1A

            ldi r16,0x00      ; wg. des Toggle auf OCR-Match ist die Frequenz genau 50% des
            ldi r17,14        ; Taktes, also 512kHz. Das dividiert durch 14 ergibt 36.571kHz
            ;ldi r17,40       ; Taktes, also 512kHz. Das dividiert durch 14 ergibt 36.571kHz
            out OCR1AH,r16    ; als Takt am Ausgang OC1A 
            out OCR1AL,r17

            ; 
            ; als Einschaltmeldung einmal die LED flashen
            ;
            ldi r16,0x00
            out PORTD,r16
            rcall delay
            ldi r16,0x00      ; Port D auf Eingaenge, dadurch Treiber ausschalten
            out DDRD,r16      ; und Strom sparen

            ;
            ; und jetzt den Timer fuer die 889us starten
            ; 
            ldi r16,0x02      ; WGM=Fast PWM fuer Timer 0, keine Outputpins
            out TCCR0A,r16
            sei               ; alle Interrupts erlauben

            ldi r16,0xff
            out PORTD,r16

forever:    ldi r20,1         ; wir wollen sofort ein Bit shiften
            ldi r21,5         ; insgesamt werden 4 Bytes versendet
            ldi r31,0x00      ; und diese stehen im SRAM ab 0x060
            ldi r30,0xa0
            rcall start_t0    ; Timer 0 loslaufen lassen

            rcall delay
            rjmp forever


            ; --------------------------------------------------------------------------------------
            ; der Interrupt-Handler fuer Timer 0, liest das naechste Bit 
            ; fuer den IR-Datenstrom aus und starten den Sendevorgang
            ; --------------------------------------------------------------------------------------
timer0:     dec r20           ; muessen wir das naechste Byte laden?
            brne send_bit     ; nein, muessen wir noch nicht
            dec r21           ; haben wir schon vier Bytes versandt?
            brne load_byte

done:       ldi r16,0x00      ; Timer 0 stoppen (einfach den Takt wegnehmen)
            out TCCR0B,r16
            ldi r16,0x03      ; PWM vom Port OC1A trennen (also ausschalten)
            out TCCR1A,r16
            reti              ; das war's, zurueck ohne Timer-Neustart

load_byte:  ld r19,z+         ; das naechste Byte aus dem Speicher einlesen
            ldi r20,8         ; wir shiften 8 Bits

send_bit:   lsl r19           ; das naechste Bit ins Carry schieben
            brcc is_clear     ; ist das Carry geloescht oder gesetzt?
is_set:     ldi r16,0x43      ; PWM mit Port OC1A verbinden (also einschalten)
            out TCCR1A,r16
            rjmp go_home      ; zum Schleifenende springen
is_clear:   ldi r16,0x03      ; PWM vom Port OC1A trennen (also ausschalten)
            out TCCR1A,r16

go_home:    rcall start_t0    ; und Timer 0 wieder starten
            reti


            ; --------------------------------------------------------------------------------------
            ; initialisiert und startet den Timer 0 so, das der Handler alle 
            ; 888us aufgerufen wird, um dort das naechste Bit ausgeben zu koennen
            ; --------------------------------------------------------------------------------------
start_t0:   ldi r16,111       ; Output Compare bei 111 ergibt 1.126kHz=888us
            out OCR0A,r16
            ldi r16,0         ; Timer startet wieder bei 0
            out TCNT0,r16
            ldi r16,0x01      ; und den Output Compare Interrupt A einschalten
            out TIMSK,r16
            ldi r16,0x02      ; wir wollen einen Prescaler von 8=0x02 (also 125kHz bei einem
            out TCCR0B,r16    ; Systemtakt von 8Mhz mit CLKDIV8 programmiert ergibt 1MHz). 
            ret


            ; --------------------------------------------------------------------------------------
            ; wartet zum Debugging eine halbe Ewigkeit
            ; --------------------------------------------------------------------------------------
delay:      ldi r25,100
outer:      ldi r24,255
inner:      nop
            nop
            nop
            nop
            nop
            nop
            dec r24
            brne inner
            dec r25
            brne outer
            ret
