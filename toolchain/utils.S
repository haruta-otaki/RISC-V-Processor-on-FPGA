// Numeric labels are local to the assembly-language file and
// can be repeated; 1b and 1f refer to the "closest" backward or forward 1 label
// This is very useful for small loops where we do not want to invent names

// .Llabel is also a syntax for local labels

.global read_cycles
.global read_instructions_retired

read_cycles:
1:
    rdcycleh a1
    rdcycle a0
    rdcycleh t0
    bne a1, t0, 1b
    ret

read_instructions_retired:
1:
    rdinstreth a1
    rdinstret a0
    rdinstreth t0
    bne a1, t0, 1b
    ret

