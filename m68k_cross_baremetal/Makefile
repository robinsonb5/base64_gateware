VBCC = vbcc0_9hP2
VASM = vasm2_0d
VLINK = vlink0_18a

all: bin bin/vbccm68k bin/vasm bin/vlink
	$(info )
	$(info The binaries are suitable for use on a 64-bit little-endian host system.)
	$(info If your host system differs from this, please rebuild vbcc by typing )
	$(info make vbcc_exotic )

bin:
	mkdir bin

bin/vbccm68k: $(VBCC).tar.gz
	tar -xzf $(VBCC).tar.gz
	cd vbcc && patch -p1 -i ../vbcc_weak.patch
	make -C vbcc bin/dtgen
	mkdir -p vbcc/objects/m68k/
	cp dt.* vbcc/objects/m68k/
	make -C vbcc TARGET=m68k
	cp	vbcc/bin/vbccm68k bin/

# For non-64bit-little-endian systems, the use will have to answer the dtgen questionnaire.
.PHONEY:	vbcc_exotic
vbcc_exotic:
	-rm bin/vbccm68k
	-make -C vbcc distclean
	make -C vbcc TARGET=m68k
	cp	vbcc/bin/vbccm68k bin/

bin/vasm: $(VASM).tar.gz
	tar -xzf $(VASM).tar.gz
	make -C vasm CPU=m68k SYNTAX=mot
	cp vasm/vasmm68k_mot bin/

bin/vlink: $(VLINK).tar.gz
	tar -xzf $(VLINK).tar.gz
	make -C vlink
	cp vlink/vlink bin/

clean:
	-make -C vbcc distclean
	-make -C vasm clean
	-make -C vlink clean
	rm bin/*
	
