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

puts "Setting TAP, capture fields and length"

::jcapture::setup target.tap $capture_fields $projectid

proc readloc {loc} {
	::jcapture::usercmd addr $loc
	::jcapture::usercmd read 0
	set d [::jcapture::userdr 0]
	puts "[format %08x $loc] [format %04x [expr 0x$d]]"
}

proc writeloc {loc d} {
	::jcapture::usercmd addr $loc
	::jcapture::usercmd write $d
}

puts -nonewline "DMACONR: "
readloc 0xdff002
writeloc 0xdff100 0x6200

exit
