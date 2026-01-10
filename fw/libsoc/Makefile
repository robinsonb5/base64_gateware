TOOLCHAIN = ../../m68k_cross_baremetal/bin
CC      = $(TOOLCHAIN)/vbccm68k
LD      = $(TOOLCHAIN)/vlink
AS      = $(TOOLCHAIN)/vasmm68k_mot
AR      = ar
CP      = $(BASE)-objcopy
DUMP    = $(BASE)-objdump

CFLAGS=-+ -I../include -O=-1 -speed -cpu=68020
LDFLAGS=-belf32m68k
ARFLAGS= crs
ASFLAGS=-L $*.lst -Lfmt=wide

all: appcrt.o romcrt.o libsoc.a

clean:
	-rm crt0.a
	-rm appcrt.a
	-rm libsoc.a
	-rm *.o
	-rm *.asm
	-rm *.lst

libsoc.a: uart.o small_printf.o ldiv.o string_c.o string.o string_stubs.o \
	spi_c.o minfat.o swap.o premain.o
	$(AR) $(ARFLAGS) $@ $+

%.o: %.s
	$(AS) $(ASFLAGS) -o $@ -Felf $+

%.o: %.c
	$(CC) $(CFLAGS) $+
	$(AS) $(ASFLAGS) -o $@ -Felf $*.asm

