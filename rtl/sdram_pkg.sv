package sdram_pkg;

import board_pkg::*;

typedef struct packed {
	bit [SDRAM_DATA_WIDTH-1:0] d;
} sdram_in;

typedef struct packed {
	bit [SDRAM_ADDRESS_WIDTH-1:0] a;
	bit [1:0] ba;
	bit cs;
	bit ras;
	bit cas;
	bit we;
	bit [SDRAM_DATA_WIDTH/8-1:0] dqm;
	bit cke;
	bit [SDRAM_DATA_WIDTH-1:0] q;
	bit drive;
} sdram_out;

endpackage
