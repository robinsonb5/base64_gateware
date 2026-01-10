# Baremetal cross-compilation toolchain for Motorola 68K microprocessors

This is a bundle and buildscript of a C toolchain for M68K CPUs,
incorporating the following projects:
* vbcc
* vasm
* vlink
See http://www.compilers.de/ for more about these projects.

The buildscript contains a hack to short-circuit the "dtgen"
questionnaire which gathers information about the host system.
This means the buildscript is only suitable for use on typical
(i.e. 64-bit little-endian systems, and shouldn't be used elsewhere.)

