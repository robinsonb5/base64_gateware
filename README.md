# Gateware for jbilander's Base64 MC68000 accelerator project
by Alastair M. Robinson
making use of the TG68k CPU core by Tobias Gubener

## General structure:

### Clock recovery:
Incoming 7MHz Amiga clock is clock-doubled to 14MHz in order to supply a fast enough
base clock for the ECP5's PLLs.

A high frequency clock of an integer multiple is generated, then _pos and _neg strobe signals
are generated to mark the rising and falling edges of the 7MHz clock.
  
### MC68000 bus state machine
Has responsibility for the 24-bit address space
Handles communication with the motherboard
Can intercept Autoconfig accesses in order to configure 32-bit Fast RAM and potentially
other devices such as SD card.
  
### CPU Wrapper
A shim around TG68K which does basic address decoding, directing addresses in 24-bit space
to the bus state machine, and addresses in 32-bit space to the SDRAM controller / cache.
Potentially reserve some RAM space for a kickstart ROM, in which case some of the 24-bit address
will have to be decoded too.
  
### SDRAM controller and cache
SDRAM controller will run in burst mode - 4 words or words

## Building

There are a few paths that need to be set so that the project can find the
required tools - this is done by copying the "site.template" file to "site.mk"
then editing site.mk to set the paths.

The following tools are required to build this project:

### Lattice Diamond
To build bitstreams for the FPGA you'll need Lattice Diamond. Version 3.11 is
recommended (newer versions may work, but have been known to cause problems
with the Minimig core on ECP5-based boards, so 3.11 is the safest option.)

Lattice Diamond is provided as a .rpm file, which is a bit awkward to install
on .deb-based distributions such as Ubuntu or Mint (or Debian, of course!) -
some information on the subject can be found at
https://retroramblings.net/?p=1917

### openFPGALoader
You can use whichever tool you like to load bitstreams onto the FPGA, but the
makefiles expect to use openFPGALoader.

### Verilator
Makefiles with a "sim" target will expect to use Verilator for simulation. It
will need to be at least version 5.
In order to build with verilator, it's necessary to set the path to
Verilator's  includes in the site.mk file.  (If Verilator is installed 
systemwide this will probably be /usr/share/verilator/include - or if you're
using oss-cad-suite,  it will likely be
/path/to/oss-cad-suite/share/verilator/include

### OpenOCD
Some projects are able to capture data from the running design over JTAG.
This is done using OpenOCD.

The easiest way to obtain openFPGALoader, Verilator and OpenOCD (if your
distro of choice doesn't supply new enough versions) is to install
oss-cad-suite from https://github.com/YosysHQ/oss-cad-suite-build

### Open-source tooling
While yosys and nextpnr have mature and dependable support for the Lattice
ECP5 FPGAs, the last time I checked they struggled to build the TG68K CPU,
which is why this project uses Diamond.

