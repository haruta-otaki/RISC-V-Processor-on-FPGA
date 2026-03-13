import sys

labels = {}
pc = 0

def int_or_label(location):
    result = labels.get(location)

    if result:
        return result - pc
        
    # Assume location is an integer
    return int(location, 0)

def reg(name):
    return int(name[1:])  # x0..x31

def encode_r(opcode, funct3, funct7, rd, rs1, rs2):
    return ((funct7 & 0x7f) << 25) | ((rs2 & 0x1f) << 20) | ((rs1 & 0x1f) << 15) \
           | ((funct3 & 0x7) << 12) | ((rd & 0x1f) << 7) | (opcode & 0x7f)

def encode_i(opcode, funct3, rd, rs1, imm):
    imm = imm & 0xfff
    return (imm << 20) | ((rs1 & 0x1f) << 15) \
           | ((funct3 & 0x7) << 12) | ((rd & 0x1f) << 7) | (opcode & 0x7f)

def encode_s(opcode, funct3, rs1, rs2, imm):
    imm = imm & 0xfff
    imm11_5 = imm >> 5
    imm4_0 = imm & 0x1f
    return (imm11_5 << 25) | ((rs2 & 0x1f) << 20) | ((rs1 & 0x1f) << 15) \
           | ((funct3 & 0x7) << 12) | (imm4_0 << 7) | (opcode & 0x7f)

def encode_b(opcode, funct3, rs1, rs2, imm):
    imm = imm & 0x1fff
    imm12 = (imm >> 12) & 1
    imm11 = (imm >> 11) & 1
    imm10_5 = (imm >> 5) & 0x3f
    imm4_1 = (imm >> 1) & 0xf
    return (imm12 << 31) | (imm11 << 7) | (imm10_5 << 25) | (imm4_1 << 8) \
           | ((rs2 & 0x1f) << 20) | ((rs1 & 0x1f) << 15) \
           | ((funct3 & 0x7) << 12) | (opcode & 0x7f)

def encode_u(opcode, rd, imm):
    return (imm & 0xfffff000) | ((rd & 0x1f) << 7) | (opcode & 0x7f)

def encode_j(opcode, rd, imm):
    imm = imm & 0x1fffff
    imm20 = (imm >> 20) & 1
    imm19_12 = (imm >> 12) & 0xff
    imm11 = (imm >> 11) & 1
    imm10_1 = (imm >> 1) & 0x3ff
    return (imm20 << 31) | (imm19_12 << 12) | (imm11 << 20) | (imm10_1 << 21) \
           | ((rd & 0x1f) << 7) | (opcode & 0x7f)

def assemble_line(line):
    parts = line.replace(",", "").split()

    if not parts:
        return None

    mnemonic = parts[0]

    # --- R-type arithmetic/logic ---
    if mnemonic == "add":  return encode_r(0x33, 0x0, 0x00, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "sub":  return encode_r(0x33, 0x0, 0x20, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "sll":  return encode_r(0x33, 0x1, 0x00, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "slt":  return encode_r(0x33, 0x2, 0x00, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "sltu": return encode_r(0x33, 0x3, 0x00, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "xor":  return encode_r(0x33, 0x4, 0x00, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "srl":  return encode_r(0x33, 0x5, 0x00, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "sra":  return encode_r(0x33, 0x5, 0x20, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "or":   return encode_r(0x33, 0x6, 0x00, reg(parts[1]), reg(parts[2]), reg(parts[3]))
    if mnemonic == "and":  return encode_r(0x33, 0x7, 0x00, reg(parts[1]), reg(parts[2]), reg(parts[3]))

    # --- I-type arithmetic/logic ---
    if mnemonic == "addi":  return encode_i(0x13, 0x0, reg(parts[1]), reg(parts[2]), int(parts[3], 0))
    if mnemonic == "slti":  return encode_i(0x13, 0x2, reg(parts[1]), reg(parts[2]), int(parts[3], 0))
    if mnemonic == "sltiu": return encode_i(0x13, 0x3, reg(parts[1]), reg(parts[2]), int(parts[3], 0))
    if mnemonic == "xori":  return encode_i(0x13, 0x4, reg(parts[1]), reg(parts[2]), int(parts[3], 0))
    if mnemonic == "ori":   return encode_i(0x13, 0x6, reg(parts[1]), reg(parts[2]), int(parts[3], 0))
    if mnemonic == "andi":  return encode_i(0x13, 0x7, reg(parts[1]), reg(parts[2]), int(parts[3], 0))
    if mnemonic == "slli":  return encode_r(0x13, 0x1, 0x00, reg(parts[1]), reg(parts[2]), int(parts[3], 0))
    if mnemonic == "srli":  return encode_r(0x13, 0x5, 0x00, reg(parts[1]), reg(parts[2]), int(parts[3], 0))
    if mnemonic == "srai":  return encode_r(0x13, 0x5, 0x20, reg(parts[1]), reg(parts[2]), int(parts[3], 0))

    # --- Loads (I-type) ---
    if mnemonic in ["lb", "lh", "lw", "lbu", "lhu"]:
        rd = reg(parts[1])
        offset, rs1 = parts[2].split("(")
        rs1 = rs1.strip(")")
        funct3 = {"lb":0, "lh":1, "lw":2, "lbu":4, "lhu":5}[mnemonic]
        return encode_i(0x03, funct3, rd, reg(rs1), int(offset, 0))

    # --- Stores (S-type) ---
    if mnemonic in ["sb", "sh", "sw"]:
        rs2 = reg(parts[1])
        offset, rs1 = parts[2].split("(")
        rs1 = rs1.strip(")")
        funct3 = {"sb":0, "sh":1, "sw":2}[mnemonic]
        return encode_s(0x23, funct3, reg(rs1), rs2, int(offset, 0))

    # --- Branches (B-type) ---
    if mnemonic in ["beq", "bne", "blt", "bge", "bltu", "bgeu"]:
        rs1 = reg(parts[1])
        rs2 = reg(parts[2])
        imm = int_or_label(parts[3])
        funct3 = {"beq":0, "bne":1, "blt":4, "bge":5, "bltu":6, "bgeu":7}[mnemonic]
        return encode_b(0x63, funct3, rs1, rs2, imm)

    # --- U-type ---
    if mnemonic == "lui":   return encode_u(0x37, reg(parts[1]), int(parts[2], 0) << 12)
    if mnemonic == "auipc": return encode_u(0x17, reg(parts[1]), int(parts[2], 0) << 12)

    # --- J-type ---
    if mnemonic == "jal":  return encode_j(0x6f, reg(parts[1]), int_or_label(parts[2]))
    if mnemonic == "jalr": return encode_i(0x67, 0x0, reg(parts[1]), reg(parts[2]), int(parts[3], 0))

    # --- System ---
    if mnemonic == "ecall":  return 0x00000073
    if mnemonic == "ebreak": return 0x00100073

    raise ValueError(f"Unsupported instruction: {line}")

def main():
    global pc
    global labels

    if len(sys.argv) != 3:
        print("Usage: python3 assembler.py input.asm output.mem")
        return

    asm_filename, mem_filename = sys.argv[1], sys.argv[2]

    with open(asm_filename) as asm_file:
        lines = [line.split("#")[0].strip() for line in asm_file]

    # First pass: index the labels before parsing the instructions
    # PC is updated so we know to where a label refers
    pc = 0

    with open(mem_filename, "w") as mem_file:
        for line in lines:
            line = line.strip()

            if not line or line.startswith("#"):
                continue

            if ":" in line:
                # Map the current lable to the current program counter and return None
                label_name = line.split(":")[0]
                labels[label_name] = pc

                continue

            pc += 4

    # Second pass: assemble
    # PC is used to calculate offsets in branches and jumps (so it needs to be reinitialized)
    pc = 0

    with open(mem_filename, "w") as mem_file:
        for line in lines:
            line = line.strip()

            if not line or line.startswith("#"):
                continue

            if ":" in line:
                continue

            instruction = assemble_line(line)
            mem_file.write(f"{instruction:08x} // {line}\n")

            pc += 4

if __name__ == "__main__":
    main()
