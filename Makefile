
AVRA=           ./bin/avra
AVRDUDE=        ./bin/avrdude
AVRDUDE_CONF=   ./bin/avrdude.conf


SOURCE=         infrared.asm
HEX=            $(SOURCE:%.asm=%.hex)
LIST=           $(SOURCE:%.asm=%.lst)


all: assemble upload

assemble: 
	$(AVRA) -l $(LIST) $(SOURCE)
#	cat $(LIST)

upload:
	$(AVRDUDE) -C $(AVRDUDE_CONF) -c stk200 -p t2313 -e -U $(HEX)

unfuse:
	$(AVRDUDE) -C $(AVRDUDE_CONF) -c stk200 -p t2313 -U lfuse:w:0x64:m -U hfuse:w:0xdf:m -U efuse:w:0xff:m

quartz:
	$(AVRDUDE) -C $(AVRDUDE_CONF) -c stk200 -p t2313 -U lfuse:w:0x7d:m -U hfuse:w:0xdf:m -U efuse:w:0xff:m

clean:
	rm -r *.hex *.lst *.cof *.obj
