from helpers import BitArray

REGISTER_NAMES = [
    ["x0", "zero"],  # zero constant
    ["x1", "ra"],  # return address
    ["x2", "sp"],  # stack pointer
    ["x3", "gp"],  # global pointer
    ["x4", "tp"],  # thread pointer
    ["x5", "t0"],  # temporary value
    ["x6", "t1"],  # temporary value
    ["x7", "t2"],  # temporary value
    ["x8", "s0", "fp"],  # saved/frame pointer
    ["x9", "s1"],  # saved register
    ["x10", "a0"],  # function arguments/return values
    ["x11", "a1"],  # function arguments/return values
    ["x12", "a2"],  # function arguments
    ["x13", "a3"],
    ["x14", "a4"],
    ["x15", "a5"],
    ["x16", "a6"],
    ["x17", "a7"],
    ["x18", "s2"],  # saved registers - must be preserved by callee functions.
    ["x19", "s3"],
    ["x20", "s4"],
    ["x21", "s5"],
    ["x22", "s6"],
    ["x23", "s7"],
    ["x24", "s8"],
    ["x25", "s9"],
    ["x26", "s10"],
    ["x27", "s11"],
    ["x28", "t3"],  # more temporaries
    ["x29", "t4"],
    ["x30", "t5"],
    ["x31", "t6"],
]

REGISTER_TO_INTEGER = {}
for i, rs in enumerate(REGISTER_NAMES):
    for r in rs:
        REGISTER_TO_INTEGER[r] = i

RTYPES = [
    "add",
    "sub",
    "xor",
    "or",
    "and",
    "sll",
    "srl",
    "sra",
    "slt",
    "sltu",
]
ITYPES = [
    "addi",
    "xori",
    "ori",
    "andi",
    "slli",
    "srli",
    "srai",
    "slti",
    "sltiu",
    "jalr",
]
LTYPES = [
    "lb",
    "lh",
    "lw",
    "lbu",
    "lhu",
]
STYPES = ["sb", "sh", "sw"]
BTYPES = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
JTYPES = ["jal"]
UTYPES = ["lui", "auipc"]

OP_CODES = {}
for i in RTYPES:
    OP_CODES[i] = BitArray("0b0110011")
for i in ITYPES:
    OP_CODES[i] = BitArray("0b0010011")
for i in LTYPES:
    OP_CODES[i] = BitArray("0b0000011")
for i in STYPES:
    OP_CODES[i] = BitArray("0b0100011")
for i in BTYPES:
    OP_CODES[i] = BitArray("0b1100011")
OP_CODES["jal"] = BitArray("0b1101111")
OP_CODES["jalr"] = BitArray("0b1100111")
OP_CODES["lui"] = BitArray("0b0110111")
OP_CODES["auipc"] = BitArray("0b0010111")
# op_codes["ecall"] = BitArray("0b1110011")
# op_codes["ebreak"] = BitArray("0b1110011")

BITS_TO_OP_CODE = {v.bin: k for k, v in OP_CODES.items()}

FUNCT3_CODES = {}
for i in ["add", "sub", "addi", "lb", "sb", "beq", "jalr"]:
    FUNCT3_CODES[i] = BitArray("0b000")
for i in ["sll", "slli", "lh", "sh", "bne"]:
    FUNCT3_CODES[i] = BitArray("0b001")
for i in ["slt", "slti", "lw", "sw"]:
    FUNCT3_CODES[i] = BitArray("0b010")
for i in ["sltu", "sltiu"]:
    FUNCT3_CODES[i] = BitArray("0b011")
for i in ["xor", "xori", "lbu", "blt"]:
    FUNCT3_CODES[i] = BitArray("0b100")
for i in ["srl", "sra", "srli", "srai", "lhu", "bge"]:
    FUNCT3_CODES[i] = BitArray("0b101")
for i in ["or", "ori", "bltu"]:
    FUNCT3_CODES[i] = BitArray("0b110")
for i in ["and", "andi", "bgeu"]:
    FUNCT3_CODES[i] = BitArray("0b111")

RTYPE_FUNCT3_MAPPING = {
    "001": "sll",
    "010": "slt",
    "011": "sltu",
    "100": "xor",
    "110": "or",
    "111": "and",
}
ITYPE_FUNCT3_MAPPING = {
    "000": "addi",
    "001": "slli",
    "010": "slti",
    "011": "sltiu",
    "100": "xori",
    "110": "ori",
    "111": "andi",
}
LTYPE_FUNCT3_MAPPING = {
    "000": "lb",
    "001": "lh",
    "010": "lw",
    "100": "lbu",
    "101": "lhu",
}
STYPE_FUNCT3_MAPPING = {"000": "sb", "001": "sh", "010": "sw"}
BTYPE_FUNCT3_MAPPING = {
    "000": "beq",
    "001": "bne",
    "100": "blt",
    "101": "bge",
    "110": "bltu",
    "111": "bgeu",
}
