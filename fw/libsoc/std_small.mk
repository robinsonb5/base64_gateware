TOOLCHAIN = $(COMMON_DIR)/../../m68k_cross_baremetal/bin
CC      = $(TOOLCHAIN)/vbccm68k
LD      = $(TOOLCHAIN)/vlink
AS      = $(TOOLCHAIN)/vasmm68k_mot
AR      = $(TOOLCHAIN)/vlink -r

ROMGENDIR=$(COMMON_DIR)/../../romgen
ROMGEN=$(ROMGENDIR)/romgen

# Commandline options for each tool.
CFLAGS += -+ -I. -I$(COMMON_DIR) -I$(COMMON_DIR)/../include -I$(COMMON_DIR)/../include/hw -DPRINTF_HEX_ONLY -cpu=68020
CFLAGS += -O=-1 -size

LFLAGS = -belf32m68k

STARTUP_OBJ = $(COMMON_DIR)/romcrt.o
MAIN_OBJ = $(patsubst %.c,%.o,$(MAIN_SRC)) $(COMMON_DIR)/libsoc.a

# Our target.
all: $(MAIN_PRJ).bin $(MAIN_PRJ)_ROM_byte.vhd $(MAIN_PRJ)_ROM_word.vhd

clean:
	-rm *.o
	-rm *.asm
	-rm *.elf
	-rm $(MAIN_PRJ).bin
	-rm $(MAIN_PRJ)*.vhd

# Convert ELF binary to bin file.
#%.bin: %.elf %.rpt
#	$(CP) -O binary $< $@

%.rpt: %.bin
	@echo >$@ -n "BSS Start: "
	@grep >>$@ __bss_start $*.bin.map
	@echo >>$@ -n "BSS End:   "
	@grep  >>$@ __bss_end $*.bin.map
	cat $@

$(ROMGEN): $(ROMGENDIR)/romgen.c
	gcc -o $(ROMGENDIR)/romgen $(ROMGENDIR)/romgen.c

%_ROM_byte.vhd: %.bin $(ROMGEN)
	sed 's/romtemplate/$*_ROM/' >$*_ROM_byte.vhd <$(ROMGENDIR)/rom_prologue_byte.vhd
	$(ROMGEN) -s4 $*.bin >>$*_ROM_byte.vhd
	cat >>$*_ROM_byte.vhd $(ROMGENDIR)/rom_epilogue_byte.vhd

%_ROM_word.vhd: %.bin $(ROMGEN)
	sed 's/romtemplate/$*_ROM/' >$*_ROM_word.vhd <$(ROMGENDIR)/rom_prologue_word.vhd
	$(ROMGEN) -s4 -w $*.bin >>$*_ROM_word.vhd
	cat >>$*_ROM_word.vhd $(ROMGENDIR)/rom_epilogue_word.vhd

# Link - this produces an ELF binary.

$(LINKSCRIPT):
	$(error Linkscript missing) 

$(MAIN_PRJ).bin: $(STARTUP_OBJ) $(MAIN_OBJ) $(DEPS)
	$(LD) -T$(LINKSCRIPT) $(LFLAGS) -brawbin1 -M$@.map -o $@ $+ $(DEPS) $(LIBS)

%.asm: %.c
	$(CC) $(CFLAGS)  -o=$@ $+

%.o: %.c
	$(CC) $(CFLAGS) $+
	$(AS) $(ASLAGS) -Felf -o $@ $*.asm

