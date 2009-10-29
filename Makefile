
AVRA=           ./bin/avra
AVRDUDE=        ./bin/avrdude
AVRDUDE_CONF=   ./bin/avrdude.conf


SOURCE=         led1.asm
HEX=            $(SOURCE:%.asm=%.hex)
LIST=           $(SOURCE:%.asm=%.lst)


all: assemble upload

assemble: 
	$(AVRA) -l $(LIST) $(SOURCE)

upload:
	$(AVRDUDE) -C $(AVRDUDE_CONF) -c stk200 -p t2313 -e -U $(HEX)

clean:
	rm -r *.hex *.lst *.cof *.obj
