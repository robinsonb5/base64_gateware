
MEMORY
{
  CODE (rx) : ORIGIN = 0x20000000, LENGTH = 0xfffffc
}


/* Section Definitions */

SECTIONS
{
  /* first section is .start which is used for startup code */
/*  . = 0x20000000; */
  .start :
  {
    KEEP(*(start)) /* Seed section, allows -gc-sections */
  } > CODE

  VBCC_CONSTRUCTORS;

  .ctors :
  {
	. = ALIGN(4);
    *(.ctors)
  }

  .dtors :
  {
	. = ALIGN(4);
    *(.dtors)
  }

  /* Remaining code sections */
  .code :
  {
	. = ALIGN(4);
    *(CODE)                   /* remaining code */
	. = ALIGN(4);
  } > CODE

  .data :
  {
    . = ALIGN(4);
    _data = . ;
    *(DATA)
  } > CODE

  /* .bss section which is used for uninitialized data */
  .bss :
  {
    __bss_start__ = . ;
    *(BSS)
    . = ALIGN(4);
    __bss_end__ = . ;
  } > CODE

  _end = . ;

}
