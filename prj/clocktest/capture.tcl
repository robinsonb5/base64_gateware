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
	{ ctr 12 }
	{ pad 16 }
}

puts "Setting TAP, capture fields and length"

set loc [file dirname [file normalize [info script]]]
source ${loc}/../../rtl/jtag/jcapture.tcl

set capture_length [::jcapture::setup target.tap $capture_fields 0xc10c]

::jcapture::settrigger edge ctr 0
::jcapture::settrigger mask ctr 0xf00
::jcapture::settrigger value ctr 0x0a0

::jcapture::settrigger edge e 1
::jcapture::settrigger mask e 1
::jcapture::settrigger value e 0


puts "Recording to cap.vcd"

	set chan [::jcapture::create_vcd cap.vcd 0]
	::jcapture::setleadin 3
	::jcapture::capture
	::jcapture::wait_fifofull
	::jcapture::fifo_to_vcd $chan 

exit


