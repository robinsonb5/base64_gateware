# we use printf from here
COMMON_DIR = ../../../fw/libsoc
TOOLCHAIN = $(COMMON_DIR)/../../m68k_cross_baremetal/bin
AS = $(TOOLCHAIN)/vasmm68k_mot

ALL : testrom.bin

%.bin: %.s
	$(AS) $+ -Fbin -o $@