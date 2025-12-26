#
# IceSugarPro demo JTAG script
#

init
scan_chain


# The total number of bits here must match the width defined in jcapture_pkg.vhd
set capture_fields {
	{ clk7 1 }
	{ clk7_en_n 1 }
	{ clk7_en_p 1 }
	{ e 1 }
	{ pad 28 }
}

puts "Setting TAP, capture fields and length"

set loc [file dirname [file normalize [info script]]]
source ${loc}/../../rtl/jtag/jcapture.tcl

set capture_length [::jcapture::setup target.tap $capture_fields 0xc10c]

puts "Recording to cap.vcd"

	set chan [::jcapture::create_vcd cap.vcd 0]
	::jcapture::setleadin 0
	::jcapture::capture
	::jcapture::wait_fifofull
	::jcapture::fifo_to_vcd $chan 

exit


