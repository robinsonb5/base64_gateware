# Use GHDL to create a Verilog version of TG68K for simulation

all: TG68KdotC_Kernel.v

TG68KdotC_Kernel.v:
	ghdl --synth --out=verilog -o=$@ -fsynopsys -fexplicit --latches ../../../rtl/TG68K.C/TG68K_Pack.vhd ../../../rtl/TG68K.C/TG68K_ALU.vhd ../../../rtl/TG68K.C/TG68KdotC_Kernel.vhd -e TG68KdotC_Kernel

