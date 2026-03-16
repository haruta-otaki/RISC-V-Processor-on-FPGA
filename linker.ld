/* 64KB of SRAM and 64KB of ROM (Monitor + BIOS) */
/* 0x400 (1 kB) reserved at the lower level for Kernel RAM and memory-mapped I/O registers */

MEMORY
{
  /* RAM starts at 0x400 (skipping the reserved bottom 1KB) and is 0x7C00 bytes (31KB) long */
  RAM (rwx) : ORIGIN = 0x00000400, LENGTH = 0x8000 - 0x400
  /* ROM starts at 0x8000 and is 0x8000 bytes (32KB) long. */
  ROM (rx)  : ORIGIN = 0x00008000, LENGTH = 0x8000
}

/* "_start": marks the entry point, the very first instruction to execute when the processor boots, mapping to that in crt0.S.*/
ENTRY(_start)

/* Syntax: */
/* "*(.__*)": collects all sections starting with ".__" from all files */
/* "KEEP()": retains the section even if it is never used anywhere (so no linking-time garbage collect) */
/* "AT()": sets the LMA (load memory address - where the data physically sits in ROM), so crt0 copies it to VMA (virtual memory address, where the CPU expects to find it at runtime) */
/* "NOLOAD()": indicates there's no LMA (no data in ROM space), but exists in VMA (takes up space in RAM) */
/* "_s..." and "_e...": marks the start and end of the code */
/* "ALIGN()": maintains a clean crt0 that works (copies) in clean 4-byte chunks, with word alignment, by implementing it on the start/end of data/sdata and bss/sbss.*/
/*">__" copy the section to "__"*/

/* GP indexes .sdata and .sbss. PC-relative address with AUIPC indexes .srodata */

/* section placement block: everything inside maps a section name to a memory region. */
SECTIONS
{
  /*.text section holds all executable code, placed in ROM*/
  .text : {
    /*defines a symbol at the start of .text. The . means "current address."*/
    _stext = .;

    KEEP(*(.isr_vector))
    /* .text.entry section is where crt0.S places _start (it needs to be first in ROM so the processor finds it on boot).*/
    *(.text.entry)
    *(.text*)
    _etext = .;
  } > ROM

  .rodata : {
    _srodata = .;
    /*read-only data*/
    *(.rodata*)
    /*"small" variant accessed via PC-relative addressing (AUIPC instruction)*/
    *(.srodata*)
    _erodata = .;
  } > ROM

  /* Small data sections for GP-relative addressing from $__global_pointer$*/
  /* small data: initialized global/static variables small enough to be accessed efficiently via the global pointer (GP) register.*/
  /* "ALIGN(LOADADDR(.rodata) + SIZEOF(.rodata), 4": sets the LMA to be right after .rodata, 4-byte aligned.*/
  /* At runtime, crt0.S will copy it from that ROM address to the VMA in RAM*/
  .sdata : AT(ALIGN(LOADADDR(.rodata) + SIZEOF(.rodata), 4)) {
    . = ALIGN(4);
    /* defines the GP symbol at _ssdata + 2KB.*/
    _ssdata = .;
    /* The GP register gives ±2KB reach, so centering it at +0x800 into the small data region maximizes the number of variables reachable with a single instruction.*/
    /*crt0.S loads this into the gp register on startup.*/
    __global_pointer$ = . + 0x800;
    *(.sdata*)
    . = ALIGN(4);
    _esdata = .;
  } > RAM

  /*.sbss is zero-initialized small global/static variables., meaning there is no need to be stored or copied. crt0.S zeros it manually.*/
  .sbss (NOLOAD) : {
    . = ALIGN(4);
    _ssbss = .;
    *(.sbss*)
    . = ALIGN(4);
    _esbss = .;
  } > RAM

  /* Regular data sections */
  /* regular initialized global/static variables. Same LMA/VMA split as .sdata*/
  .data : AT(ALIGN(LOADADDR(.sdata) + SIZEOF(.sdata), 4)) {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)
    . = ALIGN(4);
    _edata = .;
  } > RAM

  /*Zero-initialized regular globals.*/
  .bss (NOLOAD) : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss*)
    /* catches any old-style uninitialized globals from legacy C/FORTRAN compilers that don't use .bss. */
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > RAM

  /* Stack top */
  /*defines the initial stack pointer — the very top of RAM (0x8000).*/
  /*The stack grows downward on RISC-V. PROVIDE means "define this symbol only if nothing else already defines it"*/
  PROVIDE(_stack_top = ORIGIN(RAM) + LENGTH(RAM));

  /* Heap bottom */
  /*defines the heap region — from the end of BSS up to the top of RAM.*/
  /*Note the heap and stack share the same space and grow toward each other — stack down from the top, heap up from _ebss.*/
  /*Stack overflow = heap corruption.*/
  PROVIDE(_heap_start = _ebss);
  PROVIDE(_heap_end = ORIGIN(RAM) + LENGTH(RAM));

  /* Location of .data in the LMA (_sdata is the location in VMA) */
  /* exports the LMA (ROM) addresses of .sdata and .data as named symbols.*/
  /* crt0.S uses these (_lma_sdata, _lma_data) as the source addresses when copying data from ROM to RAM.*/
  _lma_sdata = LOADADDR(.sdata);
  _lma_data = LOADADDR(.data);
}

