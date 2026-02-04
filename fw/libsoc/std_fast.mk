TOOLCHAIN = $(COMMON_DIR)/../../m68k_cross_baremetal/bin
CC      = $(TOOLCHAIN)/vbccm68k
LD      = $(TOOLCHAIN)/vlink
AS      = $(TOOLCHAIN)/vasmm68k_mot
AR      = $(TOOLCHAIN)/vlink -r

ROMGENDIR=$(COMMON_DIR)/../../romgen
ROMGEN=$(ROMGENDIR)/romgen

# Commandline options for each tool.
CFLAGS += -+ -I. -I$(COMMON_DIR) -I$(COMMON_DIR)/../include -I$(COMMON_DIR)/../include/hw -DPRINTF_HEX_ONLY -cpu=68020
CFLAGS += -O=-1 -speed

LFLAGS =

ifndef NOSTARTUP
STARTUP_OBJ = $(COMMON_DIR)/romcrt.o
endif

MAIN_OBJ = $(patsubst %.c,%.o,$(MAIN_SRC)) $(COMMON_DIR)/libsoc.a
MAIN_ASM = $(patsubst %.c,%.asm,$(MAIN_SRC))
MAIN_LST = $(patsubst %.c,%.lst,$(MAIN_SRC))

# Our target.

.phoney: init
init: all

.phoney: compile
compile: all

all: $(MAIN_PRJ).bin $(MAIN_PRJ).hex $(MAIN_PRJ)_ROM_byte.vhd

clean:
	-rm *.o
	-rm *$(MAIN_ASM)
	-rm $(MAIN_LST)
	-rm $(MAIN_PRJ).bin
	-rm $(MAIN_PRJ).bin.map
	-rm $(MAIN_PRJ)*.vhd

%.rpt: %.bin
	@echo >$@ -n "BSS Start: "
	@grep >>$@ __bss_start $*.bin.map
	@echo >>$@ -n "BSS End:   "
	@grep  >>$@ __bss_end $*.bin.map
	cat $@

%.dis: %.elf
	m68k-linux-gnu-objdump -S >$@ $+

$(ROMGEN): $(ROMGENDIR)/romgen.c
	gcc -o $(ROMGENDIR)/romgen $(ROMGENDIR)/romgen.c

%.hex: %.bin $(ROMGEN)
	$(ROMGEN) -x -z2 $*.bin >$*.hex
	
%_ROM_byte.vhd: %.bin $(ROMGEN)
	sed 's/romtemplate/$*_ROM/' >$*_ROM_byte.vhd <$(ROMGENDIR)/rom_prologue_byte.vhd
	$(ROMGEN) -z2 $*.bin >>$*_ROM_byte.vhd
	cat >>$*_ROM_byte.vhd $(ROMGENDIR)/rom_epilogue_byte.vhd


$(LINKSCRIPT):
	$(error Linkscript missing) 

$(MAIN_PRJ).bin: $(STARTUP_OBJ) $(MAIN_OBJ) $(DEPS)
	$(LD) -T$(LINKSCRIPT) $(LFLAGS) -brawbin1 -M$@.map -o $@ $+ $(DEPS) $(LIBS)

$(MAIN_PRJ).elf: $(STARTUP_OBJ) $(MAIN_OBJ) $(DEPS)
	$(LD) -T$(LINKSCRIPT) $(LFLAGS) -belf32m68k -o $@ $+ $(DEPS) $(LIBS)

%.asm: %.c
	$(CC) $(CFLAGS) -o=$@ $+

%.o: %.c
	$(CC) $(CFLAGS) $+
	$(AS) $(ASFLAGS) -L $*.lst -Lfmt=wide -Felf -o $@ $*.asm

%.o: %.s
	$(AS) $(ASFLAGS) -L $*.lst -Lfmt=wide -Felf -o $@ $+

