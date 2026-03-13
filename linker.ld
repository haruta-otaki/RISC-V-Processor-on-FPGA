/* 64KB of SRAM and 64KB of ROM (Monitor + BIOS) */
/* Lower 0x400 reserved for Kernel RAM and I/O */

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000400, LENGTH = 0x8000 - 0x400
    ROM (rx)  : ORIGIN = 0x00008000, LENGTH = 0x8000
}

ENTRY(_start)

/* The syntax *(.text*) means things starting with ".text" from all files */
/* KEEP() retains the section even if never used anywhere (so no linking-time garbage collect) */

/* AT() sets the LMA (load memory address), so crt0 copies it to VMA (virtual memory address) */
/* NOLOAD() indicates that there's no LMA (avoid wasting ROM space), just VMA */

/* The COMMON section is a place old C/FORTRAN compilers would place uninitialized variables; now they go to BSS */

/* GP indexes .sdata and .sbss. PC-relative address with AUIPC indexes .srodata */

/* The alignments on the start/end of data/sdata and bss/sbss help me write a clean crt0 that works on words, not bytes */

SECTIONS
{
  .text : {
    _stext = .;
    KEEP(*(.isr_vector))
    *(.text.entry)
    *(.text*)
    _etext = .;
  } > ROM

  .rodata : {
    _srodata = .;
    *(.rodata*)
    *(.srodata*)
    _erodata = .;
  } > ROM

  /* Small data sections (for GP-relative addressing, +- 2KB from __global_pointer$) */
  .sdata : AT(ALIGN(LOADADDR(.rodata) + SIZEOF(.rodata), 4)) {
    . = ALIGN(4);
    _ssdata = .;
    __global_pointer$ = . + 0x800;
    *(.sdata*)
    . = ALIGN(4);
    _esdata = .;
  } > RAM

  .sbss (NOLOAD) : {
    . = ALIGN(4);
    _ssbss = .;
    *(.sbss*)
    . = ALIGN(4);
    _esbss = .;
  } > RAM

  /* Regular data sections */
  .data : AT(ALIGN(LOADADDR(.sdata) + SIZEOF(.sdata), 4)) {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)
    . = ALIGN(4);
    _edata = .;
  } > RAM

  .bss (NOLOAD) : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > RAM

  /* Stack top */
  PROVIDE(_stack_top = ORIGIN(RAM) + LENGTH(RAM));

  /* Heap bottom */
  PROVIDE(_heap_start = _ebss);
  PROVIDE(_heap_end = ORIGIN(RAM) + LENGTH(RAM));

  /* Location of .data in the LMA (_sdata is the location in VMA) */
  _lma_sdata = LOADADDR(.sdata);
  _lma_data = LOADADDR(.data);
}

