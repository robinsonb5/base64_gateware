OBJ_DIR=obj_dir
IMPL_DIR=impl1

HDL_FILES = ../../fpga/icesugarpro_board_pkg.sv ../../rtl/sdram_pkg.sv ../../rtl/base64_m68k_pkg.sv ../../rtl/hostclocks.sv ../../rtl/jtag/jcapture.sv ../../rtl/jtag/vjtag_sync_fifo.sv virtualtoplevel.sv
HDL_FILES_SYNTH = $(HDL_FILES) ../../fpga/base64_icesugarpro_top.sv ../../pll/ecp5_14MHz_85MHz/clocks/clocks.sbx ../../pll/ecp5_25MHz_85MHz/supervisorclk/supervisorclk.sbx
HDL_FILES_SIM = ../../rtl/base64_m68k_pkg.sv ../../rtl/hostclocks.sv sim/clocks.sv tb.sv ../../rtl/jtag/vjtag_sync_fifo.sv

PROJ_FILE = clocktest.ldf
BIT_FILE = impl1/clocktest_impl1.bit

all: info

../../site.mk: 
	$(info )
	$(info site.mk not found -)
	$(info copy ../../site.template to ../../site.mk, then edit site.mk to set tool paths)
	$(info )
	$(info )
	
include ../../site.mk

.phony info:
info: ../../site.mk
	$(info )
	$(info | > make sim - build and run a simulation of clocking using verilator.)
	$(info |              output file: sim.vcd)
	$(info |)
	$(info | > make bit - use lattice diamondc to build the bitstream from source.)
	$(info |)
	$(info | > make pgm - configure the FPGA using openFPGALoader)
	$(info |)
	$(info | > make cap - connect to the design using openOCD and capture a trace. )
	$(info |              output file: cap.vcd)
	$(info )

clean:
	-rm tb
	-rm $(OBJ_DIR)/*
	-rm $(IMPL_DIR)/*

# Project synthesis

bit: $(BIT_FILE)

$(BIT_FILE): $(HDL_FILES_SYNTH)
	echo prj_project open ${PROJ_FILE} \; prj_run Export -task Bitgen | $(DIAMOND_PATH)/diamondc


# Configure FPGA
.phony pgm:
pgm: $(BIT_FILE)
	../../fpga/icesugarpro_pgm.sh $(BIT_FILE)


# Attempt to capture a trace from the running design

.phony cap:
cap: $(BIT_FILE)
	openocd -f ../../fpga/icesugarpro.cfg -f capture.tcl

# Simulation

${OBJ_DIR}/Vtb.cpp: ${HDL_FILES_SIM}
	verilator -cc -exe -MMD --trace --top-module tb -cc tb.cpp ${HDL_FILES_SIM}

$(OBJ_DIR)/Vtb: ${OBJ_DIR}/Vtb.cpp tb.cpp
	make -j -C ${OBJ_DIR} -f Vtb.mk CXX=$(CXX)
	
sim: $(OBJ_DIR)/Vtb
	$(OBJ_DIR)/Vtb


