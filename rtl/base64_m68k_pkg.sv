package base64_m68k_pkg;

	typedef struct packed {
		bit [23:1] a;
		bit as;
		bit lds;
		bit uds;
		bit rw;
		bit en;
	} m68k_address_ctrl;
	
	typedef struct packed {
		bit [15:0] q;
		bit drive;
		bit en;
	} m68k_data_out;
	
	typedef struct packed {
		bit [15:0] d;
	} m68k_data_in;
	
	typedef struct packed {
		bit clk;
		bit dtack;
		bit vpa;
		bit halt;
		bit berr;
		bit [2:0] ipl;
		bit br;
		bit bgack;
	} m68k_misc_in;
	
	typedef struct packed {
		bit vma;
		bit	e;
		bit reset;
		bit [2:0] fc;
		bit bg;
	} m68k_misc_out;

endpackage

