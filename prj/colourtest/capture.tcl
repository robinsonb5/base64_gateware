#
# IceSugarPro demo JTAG script
#

init
scan_chain

# 16-bit project ID, so we can be sure we're capturing from the correct design
set projectid 0x680b

# The total number of bits here must match the width defined in jcapture_pkg.vhd
set capture_fields {
	{ clk7 1 }
	{ clk7_en_n 1 }
	{ clk7_en_p 1 }
	{ reset_n 1 }
	{ e 1 }
	{ as 1 }
	{ uds 1 }
	{ lds 1 }
	{ rw 1 }
	{ dtack 1 }
	{ vpa 1 }
	{ vma 1 }
    { ipl 3 }
	{ q 16 }
    { d 16 }
    { dq_en 1 }
    { dq_drive 1 }
    { a 24 }
    { a_en 1 }
    { a_drive 1 }
	{ rxd 1 }
	{ txd 1 }
}

puts "Setting TAP, capture fields and length"

set loc [file dirname [file normalize [info script]]]
source ${loc}/../../rtl/jtag/jcapture.tcl

::jcapture::setup target.tap $capture_fields $projectid

::jcapture::settrigger edge reset_n 1
::jcapture::settrigger mask reset_n 1
::jcapture::settrigger value reset_n 1

#::jcapture::settrigger edge rxd 1
#::jcapture::settrigger mask rxd 1
#::jcapture::settrigger value rxd 0


puts "Recording to cap.vcd"

	set chan [::jcapture::create_vcd cap.vcd 0]
	::jcapture::setleadin 3
	::jcapture::capture
	::jcapture::wait_fifofull
	::jcapture::fifo_to_vcd $chan 

exit


