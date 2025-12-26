// High-level CPU interface

package cpu_pkg;

	localparam cpu_addr_high=31;
	localparam cpu_data_width=16;

	typedef struct {
		bit req;
		bit wr;
		bit [cpu_addr_high:0] addr;
		bit [cpu_data_width-1:0] d;
		bit [cpu_data_width/8-1:0] dm;
		bit ifetch;
		bit supervisor;
	} cpu_request;
	
	typedef struct {
		bit ack;
		bit [cpu_data_width-1:0] q;
	} cpu_response;

endpackage

