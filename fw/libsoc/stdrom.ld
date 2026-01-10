
/* Memory Definitions for a program running from boot "ROM" */

MEMORY
{
  CODE (rx) : ORIGIN = 0x00000000, LENGTH = 0x0000fffc /* Up to the end of the first 64K */
}


/* Section Definitions */

SECTIONS
{
  /* first section is .start which is used for startup code */
  . = 0x0000000;
  .start :
  {
    KEEP(*(start)) /* Seed section, allows -gc-sections */
  }>CODE

  /* Remaining code sections */
  .text :
  {
	. = ALIGN(4);
    *(CODE)                   /* remaining code */
    *(.text)                   /* remaining code */
    *(.text.*)                   /* remaining code */
	. = ALIGN(4);
	__ctors_start__ = . ;
	KEEP(*(.ctors))
	KEEP(*(.ctors.*))
	__ctors_end__ = . ;
    . = ALIGN(4);
	__dtors_start__ = . ;
	KEEP(*(.dtors))
	KEEP(*(.dtors.*))
	__dtors_end__ = . ;
  } >CODE

  /* .rodata section which is used for read-only data (constants) */
  .rodata :
  {
    *(.rodata)
    *(.rodata.*)
	. = ALIGN(4);
	_romend = . ;
  } >CODE

  /* .data section which is used for initialized data.
     Since we don't want any writable data within the ROM
     itself, we put this stuff in a "trap" section. */
  .data :
  {
    _data = . ;
    *(DATA)
    *(.data)
    *(.data.*)
    . = ALIGN(4);
  } >CODE

  /* .bss section which is used for uninitialized data */
  .bss (NOLOAD):
  {
    *(.bss.stack)
    __bss_start = . ;
    *(BSS)
    *(.bss)
    *(.scommon)
    *(.sbss)
    *(.bss.*)
    *(COMMON)
    . = ALIGN(4);
	__bss_end = . ;
  } >CODE

	/* Debug information */
  .debug_loc 0 : { *(.debug_loc) }
  .debug_abbrev 0 : { *(.debug_abbrev) }
  .debug_str 0 : { *(.debug_str) }
  .debug_info 0 : { *(.debug_info) }
  .debug_line 0 : { *(.debug_line) }
  .debug_frame 0 : { *(.debug_frame) }
  .debug_pubnames 0 : { *(.debug_pubnames) }
  .debug_aranges 0 : { *(.debug_aranges) }
  .comment : { *(.comment) }
}
