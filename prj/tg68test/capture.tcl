#
# IceSugarPro demo JTAG script
#

init
scan_chain

# 16-bit project ID, so we can be sure we're capturing from the correct design
set projectid 0x68ff

# The total number of bits here must match the width defined in jcapture_pkg.vhd
set capture_fields {
	{ cpustate 2 }
	{ reset_n 1 }
	{ state 4 }
	{ addr 32 }
	{ din 16 }
	{ clkena 1 }
}

puts "Setting TAP, capture fields and length"

set loc [file dirname [file normalize [info script]]]
source ${loc}/../../rtl/jtag/jcapture.tcl

::jcapture::setup target.tap $capture_fields $projectid

::jcapture::settrigger edge reset_n 1
::jcapture::settrigger mask reset_n 1
::jcapture::settrigger value reset_n 1

#::jcapture::settrigger edge clkena 1
#::jcapture::settrigger mask clkena 1
#::jcapture::settrigger value clkena 1

#::jcapture::settrigger edge addr 0x000000
#::jcapture::settrigger mask addr 0xffffff
#::jcapture::settrigger value addr 0x000154

puts "Recording to cap.vcd"

	set chan [::jcapture::create_vcd cap.vcd 0]
	::jcapture::setleadin 3
	::jcapture::capture
	::jcapture::wait_fifofull
	::jcapture::fifo_to_vcd $chan 

exit


