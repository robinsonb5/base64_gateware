package base64_m68k_pkg;

	typedef struct packed {
		bit [23:1] a;
		bit as;
		bit lds;
		bit uds;
		bit rw;
		bit drive;
		bit a_en;
	} m68k_address_ctrl;
	
	typedef struct packed {
		bit [15:0] q;
		bit drive;
		bit dq_en;
	} m68k_data_out;
	
	typedef struct packed {
		bit [15:0] d;
	} m68k_data_in;
	
	typedef struct packed {
		bit clk;
		bit dtack;
		bit vpa;
		bit reset;	// Bi-directional
		bit halt;
		bit berr;
		bit [2:0] ipl;
		bit br;
		bit bgack;
	} m68k_misc_in;
	
	typedef struct packed {
		bit vma;
		bit e;
		bit reset;	// Bi-directional
		bit [2:0] fc;
		bit bg;
	} m68k_misc_out;

	typedef struct packed {
		bit sysclk;		// High frequency system clock, integer multiple of doubled motherboard clock
		bit clk7;      // Unprocessed clk7 (for diagnostics only)
		bit clk7_en_p;	// Strobe to mark posedge of motherboard clock
		bit clk7_en_n;	// Strobe to mark negedge of motherboard clock
		bit e_internal;	// E clock - period of 10 7MHz clocks - 6 cycles low, 4 cycles high.
		bit ramclk;		// Phase shifted version of sysclk for SDRAM
		bit svclk;		// Supervisor clock, derived from FPGA board's own clock, async to motherboard
		bit reset_n_sys;// Active low reset derived from PLL lock signals
		bit reset_n_sv; // Active low reset derived from PLL lock signals
	} m68k_clocks;

endpackage

