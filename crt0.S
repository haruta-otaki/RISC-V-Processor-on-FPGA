// This file is in crt0.S (uppercase) because it is convention that
// .s files do not use C preprocessor
// .S files can use the C preprocessor
//
// So I can now use #ifdef and similar functionality

// The linker script pulls .text.entry out first within .text, so _start is guaranteed to be at the very beginning of ROM 
// exactly where the processor jumps on reset.
.section .text.entry

// makes _start visible to the linker (other files can reference it)
.global _start

// declares that main is defined elsewhere
.extern main

// first instruction executed
_start:
    // loads the address of __global_pointer$ (defined in the linker script as the center of .sdata) into the gp register. 
    // any access to small global variables uses gp-relative addressing onwards
    la gp, __global_pointer$

    // loads the top of RAM into the stack pointer.
    la sp, _stack_top


// copies .sdata from ROM to RAM, 4 bytes at a time.
sdata_copy:
    // t0 = destination pointer (walks through RAM)
    // t1 = source pointer (walks through ROM)
    // t3 = end address.
    la t0, _ssdata      // Destination
    la t1, _lma_sdata   // Source
    la t3, _esdata
// loop: if t0 == _esdata, jump to data_copy. 
// otherwise, load a word from ROM (lw), store it to RAM (sw), advance both pointers by 4, repeat.
1:  beq t0, t3, data_copy
    lw t2, 0(t1)
    sw t2, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 4
    j 1b

// copy .data from ROM to RAM. 
// after this, all your initialized globals are live in RAM with their correct starting values.
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

// zeros the .sbss region as the C standard guarantees that uninitialized globals start at zero
sbss_init:
    la t0, _ssbss
    la t3, _esbss
3:  beq t0, t3, bss_init
// writes the hardwired zero register to memory.
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
    // call main program, handoff to C. 
    // by this point: GP is set, SP is set, all initialized globals have their values in RAM, all zero-initialized globals are zeroed. The C environment is fully valid. 
    call main

5:
    //infinite loop such that if main() ever returns, it traps the processor, preventing the PC from wandering into garbage memory and executing random instructions.
    j 5b