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
SDRAM controller will run in burst mode - 4 words or words?

