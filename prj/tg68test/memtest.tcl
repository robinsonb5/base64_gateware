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

proc setcolor0 { v } {
	::jcapture::usercmd addr 0xdff180
	::jcapture::usercmd write $v
}

proc sendreset { v } {
	::jcapture::usercmd reset $v
}

proc selkick { v } {
	::jcapture::usercmd kickselect $v
}

puts "Setting TAP, capture fields and length"


::jcapture::setup target.tap $capture_fields $projectid

# Fill 32 words at 0x10000 with a data sequence
set v 0x0107
set a 0x010000
for {set i 0} {$i < 0x32} {incr i} {
	::jcapture::usercmd addr $a
	::jcapture::usercmd write $v
	incr a
	incr a
	set v [expr "$v + 0x0101"]
}

# Dump 32 words at 0x10000
# (FIXME: Auto address increment isn't working)
set a 0x010000
for {set i 0} {$i < 0x32} {incr i} {
	::jcapture::usercmd addr $a
	::jcapture::usercmd read 0
	set d [::jcapture::userdr 0]
	puts "[format %08x $a] [format %04x [expr 0x$d]]"
	incr a
	incr a
}

exit
