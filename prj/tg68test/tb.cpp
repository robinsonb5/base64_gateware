#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>
#include <list>
#include "Vtb.h"
#include "Vtb__Syms.h"
#include "verilated.h"
#include "verilated_vcd_c.h"


static Vtb *tb;
static VerilatedVcdC *trace;
static double timestamp = 0;

static double period_7mhz = 500/7.09;

double sc_time_stamp() {
	return timestamp;
}

void tick(int c) {
	tb->clk7=c;
	for(int i=0;i<12;++i) {
		tb->clk2x=(i<6) ? 1 : 0;
		tb->rootp->tb__DOT__hostclocks__DOT__sysclk=i&1;
		tb->rootp->tb__DOT__hostclocks__DOT__svclk=(i&1)^1;
		tb->sysclk=(i&1);
		tb->svclk=(i&1)^1;
		tb->eval();
		trace->dump(timestamp);
		timestamp += period_7mhz / 12.0;
	}
}


int main(int argc, char **argv) {

	// Initialize Verilators variables
	Verilated::commandArgs(argc, argv);
//	Verilated::debug(1);
	Verilated::traceEverOn(true);
	trace = new VerilatedVcdC;

	// Create an instance of our module under test
	tb = new Vtb;
	tb->trace(trace, 99);
	trace->open("sim.vcd");

	for(int i=0;i<500;++i) {
		tick(1);
		tick(0);
	}

	trace->close();

}
