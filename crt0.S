// This file is in crt0.S (uppercase) because it is convention that
// .s files do not use C preprocessor
// .S files can use the C preprocessor
//
// So I can now use #ifdef and similar functionality

// Places at the entry point
.section .text.entry

// Provides an externally-visible _start
.global _start

// Depends on an externally-visible main
.extern main

_start:
    // Initialize global pointer
    la gp, __global_pointer$

    // Set stack pointer
    la sp, _stack_top

    // Copy data from LMA to VMA
sdata_copy:
    la t0, _ssdata      // Destination
    la t1, _lma_sdata   // Source
    la t3, _esdata
1:  beq t0, t3, data_copy
    lw t2, 0(t1)
    sw t2, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 4
    j 1b

data_copy:
    la t0, _sdata      // Destination
    la t1, _lma_data   // Source
    la t3, _edata
2:  beq t0, t3, sbss_init
    lw t2, 0(t1)
    sw t2, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 4
    j 2b

    // Zero BSS
sbss_init:
    la t0, _ssbss
    la t3, _esbss
3:  beq t0, t3, bss_init
    sw zero, 0(t0)
    addi t0, t0, 4
    j 3b

bss_init:
    la t0, _sbss
    la t3, _ebss
4:  beq t0, t3, ready
    sw zero, 0(t0)
    addi t0, t0, 4
    j 4b

ready:
    // Call main program, spins when main exits
    call main

5:
    // Infinite loop
    j 5b