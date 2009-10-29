
          .device attiny2313

          .equ PINB=0x10
          .equ DDRB=0x11
          .equ PORTB=0x12
          .equ PINB=0x16
          .equ DDRB=0x17
          .equ PORTB=0x18

          .org 0
reset:    rjmp  main

main:     ldi r16,0xff
          out DDRB,r16
          ldi r16,0xaa
          out PORTB,r16

loop:     rjmp loop
