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
	{ sd_ca 1 }
	{ sd_cas 1 }
	{ sd_ras 1 }
	{ sd_we 1 }
	{ sd_ba 2 }
	{ sd_a 13 }
	{ bootrom_ena 1 }
}

proc sendreset { v } {
	::jcapture::virscan write
	::jcapture::vdrscan $::jcapture::capture_width $v
}

puts "Setting TAP, capture fields and length"

set loc [file dirname [file normalize [info script]]]
source ${loc}/../../rtl/jtag/jcapture.tcl

::jcapture::setup target.tap $capture_fields $projectid

::jcapture::settrigger edge reset_n 1
::jcapture::settrigger mask reset_n 1
::jcapture::settrigger value reset_n 1

::jcapture::settrigger edge clkena 0
::jcapture::settrigger mask clkena 1
::jcapture::settrigger value clkena 1

::jcapture::settrigger edge addr 0x00000000
::jcapture::settrigger mask addr 0xffffffff
::jcapture::settrigger value addr 0x01000200

#::jcapture::settrigger edge cpustate 0
#::jcapture::settrigger mask cpustate 3
#::jcapture::settrigger value cpustate 3

#::jcapture::settrigger edge sd_cas 0
#::jcapture::settrigger mask  sd_cas 1
#::jcapture::settrigger value sd_cas 1

#::jcapture::settrigger edge sd_ras 1
#::jcapture::settrigger mask  sd_ras 1
#::jcapture::settrigger value sd_ras 0

#::jcapture::settrigger edge bootrom_ena 1
#::jcapture::settrigger mask bootrom_ena 1
#::jcapture::settrigger value bootrom_ena 0

::jcapture::setsubsample 0 0

puts "Recording to cap.vcd"

	set chan [::jcapture::create_vcd cap.vcd 0]
	::jcapture::setleadin 1
	::jcapture::capture
	::jcapture::wait_fifofull
	::jcapture::fifo_to_vcd $chan 

exit


