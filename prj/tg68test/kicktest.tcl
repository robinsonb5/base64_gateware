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

# Erase the first 32 words of softkicked ROM
#set a 0x05f80000
#::jcapture::usercmd addr $a
#for {set i 0} {$i < 0x32} {incr i} {
#	::jcapture::usercmd write 0
#	incr a
#	incr a
#	::jcapture::usercmd addr $a
#}

set a 0x05f80000

set chan [open "testrom/testrom.bin" "rb"]
while {[eof $chan]==0} {
	set v [scan [read $chan 1] %c]
	set v2 [scan [read $chan 1] %c]
	if {[eof $chan]==0} {
		set v [expr "($v << 8) | $v2" ]
		::jcapture::usercmd addr $a
		::jcapture::usercmd write $v
		set a [expr "$a + 2"]
	}
}
close $chan

# Dump the first 32 words of softkicked ROM
#set a 0x05f80000
#::jcapture::usercmd addr $a
#set d [::jcapture::usercmd read 0]
#for {set i 0} {$i < 0x100} {incr i} {
#	::jcapture::usercmd read 0
#	set d [::jcapture::userdr 0]
#	puts "[format %08x $a] [format %04x [expr 0x$d]]"
#	incr a
#	incr a
#	::jcapture::usercmd addr $a
#}

sendreset 1
selkick 1
sendreset 0

exit
