#! ./oocd.sh
#
# IceSugarPro demo JTAG script
#

init
scan_chain

# 16-bit project ID, so we can be sure we're capturing from the correct design
set projectid 0x68ff

# The total number of bits here must match the width defined in jcapture_pkg.vhd
source ./capturefields.tcl

set loc [file dirname [file normalize [info script]]]
source ${loc}/../../rtl/jtag/jcapture.tcl

# Enumerate user IR codes, starting at 0
set ::jcapture::usercodes {
	reset kickselect addr read write
}

proc readpotgor { } {
	::jcapture::usercmd addr 0xdff016
	return [::jcapture::usercmd read 0]
}

proc sendreset { v } {
	::jcapture::usercmd reset $v
}

proc selkick { v } {
	::jcapture::usercmd kickselect $v
}

puts "Setting TAP, capture fields and length"


::jcapture::setup target.tap $capture_fields $projectid

# Ensure device is in reset

for {set i 0} {$i < 0x100} {incr i} {
	puts [readpotgor]
}

exit


