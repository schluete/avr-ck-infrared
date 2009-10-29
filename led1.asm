
          .device attiny2313

          .equ PIND=0x10
          .equ DDRD=0x11
          .equ PORTD=0x12
          .equ PINB=0x16
          .equ DDRB=0x17
          .equ PORTB=0x18

          .org 0
main:     
          ldi r16,0x0
          out PORTB,r16

          ldi r16,0xff
          out DDRB,r16

loop:     rjmp loop
