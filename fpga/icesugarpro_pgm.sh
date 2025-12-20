#!/bin/sh

# The IceSugarPro's internal cmsis-dap programmer isn't recognised by openFPGALoader
# but works as long you specify the correct USB vendor and product ID.
# (OpenOCD can recognise it from the string "CMSIS-DAP" in the USB product string)
openFPGALoader -c cmsisdap --vid 0x1d50 --pid 0x602b $1

