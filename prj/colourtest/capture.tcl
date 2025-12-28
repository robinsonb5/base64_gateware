#
# IceSugarPro demo JTAG script
#

init
scan_chain

# 16-bit project ID, so we can be sure we're capturing from the correct design
set projectid 0x680a

# The total number of bits here must match the width defined in jcapture_pkg.vhd
set capture_fields {
	{ clk7 1 }
	{ clk7_en_n 1 }
	{ clk7_en_p 1 }
	{ e 1 }
	{ as 1 }
	{ uds 1 }
	{ lds 1 }
	{ rw 1 }
	{ dtack 1 }
	{ vpa 1 }
	{ vma 1 }
	{ q 16 }
    { d 16 }
    { a 24 }
	{ pad 7 }
}

puts "Setting TAP, capture fields and length"

set loc [file dirname [file normalize [info script]]]
source ${loc}/../../rtl/jtag/jcapture.tcl

set capture_length [::jcapture::setup target.tap $capture_fields $projectid]

puts "Recording to cap.vcd"

	set chan [::jcapture::create_vcd cap.vcd 0]
	::jcapture::setleadin 0
	::jcapture::capture
	::jcapture::wait_fifofull
	::jcapture::fifo_to_vcd $chan 

exit


