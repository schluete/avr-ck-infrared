
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
	echo "failure!"

clean:
	rm -r *.hex *.lst *.cof *.obj
