try:
    from bitstring import BitArray
except:
    raise Exception(
        "Missing a library, try `sudo apt install python3-bitstring`"
    )
import re

pattern_immediate_offset_register = "(-?\d+)\((\w+)\)"

register_names = [
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
register_to_integer = {}
for i, rs in enumerate(register_names):
    for r in rs:
        register_to_integer[r] = i


def register_to_bits(register):
    return BitArray(uint=register_to_integer[register], length=5)


def bits_to_register(bits):
    if bits.length != 5:
        raise ValueError(f"Register must be 5 bits, not {bits.length}.")
    return register_names[bits.uint][0]


def parse_int_immediate(imm):  # TODO: use this consistently
    """
    Parse all valid number literals (0x for hex, 0b for binary, etc.). Does not parse labels.
    Returns signed values.

    I got this spec from here, which may or may not be correct--but it seems reasonable:
    https://www.eecs.yorku.ca/teaching/docs/2021/RVS-Assembler.pdf
    """
    if isinstance(imm, int):
        return imm
    assert isinstance(imm, str), f"Unknown type for imm: {type(imm)} ({imm})"

    imm = imm.strip().lower()
    if imm.startswith('0x'):  # hex
        return int(imm[2:], 16)
    elif imm.startswith('0b'):  # binary
        return int(imm[2:], 2)
    elif imm.startswith('0'):  # octal
        return int(imm, 8)
    else:  # decimal
        return int(imm)


class LineException(Exception):
    pass


def check_imm(imm, bits):
    if imm >= 2 ** (bits - 1) or imm < -(2 ** (bits - 1)):
        raise LineException(f"Immediate {imm} does not fit into {bits} bits.")


rtypes = [
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
itypes = [
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
ltypes = [
    "lb",
    "lh",
    "lw",
    "lbu",
    "lhu",
]
stypes = ["sb", "sh", "sw"]
btypes = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
jtypes = ["jal"]
utypes = ["lui", "auipc"]


def pseudo_instruction_li(rd, expression):
    # TODO: Support 32-bit li
    print("WARNING: 32-bit li is not supported")
    imm = parse_int_immediate(expression)
    try:
        check_imm(imm, 12)
        return 'addi', [rd, 'zero', expression]
    except LineException:  # need to do a full 32-bit li
        # NOTE: addi does sign extension, so we need to be clever here. If the MSB is high, it will
        # think imm12 is negative (resulting in a net change of -4096). Adding 1 to upimm will add
        # 4096, thereby cancelling it out.
        # Credit: https://stackoverflow.com/a/59546567
        imm12 = imm & 0xFFF
        upimm = imm >> 12
        if imm12 >= 0x800:  # MSB is high
            imm12 = -1  # This will be 0xFFF
            upimm += 1
        return [
            ('lui', [rd, upimm]),
            ('addi', [rd, rd, imm12])
        ]


def pseudo_instruction_call(label):
    print("WARNING: call only works with nearby functions")
    return 'jal', ['ra', label]


# Table from: https://michaeljclark.github.io/asm.html
PSEUDO_INSTRUCTIONS = {
    # No operation
    "nop": lambda: ("addi", ["zero", "zero", 0]),
    # Copy register
    "mv": lambda rd, rs1: ("addi", [rd, rs1, 0]),
    # One's complement
    "not": lambda rd, rs1: ("xori", [rd, rs1, -1]),
    # Two's complement
    "neg": lambda rd, rs1: ("sub", [rd, "zero", rs1]),
    # Two's complement Word
    "negw": lambda rd, rs1: ("subw", [rd, "zero", rs1]),
    # Set if = zero
    "seqz": lambda rd, rs1: ("sltiu", [rd, rs1, 1]),
    # Set if ≠ zero
    "snez": lambda rd, rs1: ("sltu", [rd, "zero", rs1]),
    # Set if < zero
    "sltz": lambda rd, rs1: ("slt", [rd, rs1, "zero"]),
    # Set if > zero
    "sgtz": lambda rd, rs1: ("slt", [rd, "zero", rs1]),
    # Branch if = zero
    "beqz": lambda rs1, offset: ("beq", [rs1, "zero", offset]),
    # Branch if ≠ zero
    "bnez": lambda rs1, offset: ("bne", [rs1, "zero", offset]),
    # Branch if ≤ zero
    "blez": lambda rs1, offset: ("bge", ["zero", rs1, offset]),
    # Branch if ≥ zero
    "bgez": lambda rs1, offset: ("bge", [rs1, "zero", offset]),
    # Branch if < zero
    "bltz": lambda rs1, offset: ("blt", [rs1, "zero", offset]),
    # Branch if > zero
    "bgtz": lambda rs1, offset: ("blt", ["zero", rs1, offset]),
    # Branch if >
    "bgt": lambda rs, rt, offset: ("blt", [rt, rs, offset]),
    # Branch if ≤
    "ble": lambda rs, rt, offset: ("bge", [rt, rs, offset]),
    # Branch if >, unsigned
    "bgtu": lambda rs, rt, offset: ("bltu", [rt, rs, offset]),
    # Branch if ≤, unsigned
    "bleu": lambda rs, rt, offset: ("bltu", [rt, rs, offset]),
    # Jump
    "j": lambda offset: ("jal", ["zero", offset]),
    # Jump register
    # NB: Other table said this should be jal x1, offset
    "jr": lambda offset: ("jalr", ["zero", offset, 0]),
    # Return from subroutine
    "ret": lambda: ("jalr", ["zero", "ra", 0]),
    # Call a function
    "call": pseudo_instruction_call,

    # Load immediate
    "li": pseudo_instruction_li,
    # Load address
    "la": lambda rd, symbol: None  # TODO

    # TODO: What is this?
    # Sign extend Word
    # "sext.w": lambda rd, rs1: ("addiw", [rd, rs, 0]),
}

op_codes = {}
for i in rtypes:
    op_codes[i] = BitArray("0b0110011")
for i in itypes:
    op_codes[i] = BitArray("0b0010011")
for i in ltypes:
    op_codes[i] = BitArray("0b0000011")
for i in stypes:
    op_codes[i] = BitArray("0b0100011")
for i in btypes:
    op_codes[i] = BitArray("0b1100011")
op_codes["jal"] = BitArray("0b1101111")
op_codes["jalr"] = BitArray("0b1100111")
op_codes["lui"] = BitArray("0b0110111")
op_codes["auipc"] = BitArray("0b0010111")
# op_codes["ecall"] = BitArray("0b1110011")
# op_codes["ebreak"] = BitArray("0b1110011")

bits_to_op_code = {v.bin: k for k, v in op_codes.items()}

funct3_codes = {}
for i in ["add", "sub", "addi", "lb", "sb", "beq", "jalr"]:
    funct3_codes[i] = BitArray("0b000")
for i in ["sll", "slli", "lh", "sh", "bne"]:
    funct3_codes[i] = BitArray("0b001")
for i in ["slt", "slti", "lw", "sw"]:
    funct3_codes[i] = BitArray("0b010")
for i in ["sltu", "sltiu"]:
    funct3_codes[i] = BitArray("0b011")
for i in ["xor", "xori", "lbu", "blt"]:
    funct3_codes[i] = BitArray("0b100")
for i in ["srl", "sra", "srli", "srai", "lhu", "bge"]:
    funct3_codes[i] = BitArray("0b101")
for i in ["or", "ori", "bltu"]:
    funct3_codes[i] = BitArray("0b110")
for i in ["and", "andi", "bgeu"]:
    funct3_codes[i] = BitArray("0b111")


def line_to_bits(line, labels={}, address=0):
    instruction = line["instruction"]
    args = line["args"]
    bits = None
    if instruction in rtypes:
        if len(args) != 3:
            raise LineException(
                "R-type instructions require 3 arguments.",
            )

        try:
            rd, rs1, rs2 = [register_to_bits(a) for a in args]
        except KeyError:
            line = line.copy()
            line['instruction'] += 'i'
            return line_to_bits(line, labels, address)

        funct7 = BitArray(length=7)
        if instruction in ["sub", "sra"]:
            funct7 = BitArray("0b0100000")
        bits = (
            funct7
            + rs2
            + rs1
            + funct3_codes[instruction]
            + rd
            + op_codes[instruction]
        )
    if instruction in itypes:
        if len(args) != 3:
            raise LineException(
                "I-type instructions require 3 arguments.",
            )
        rd, rs1, imm12 = args
        rd = register_to_bits(rd)
        rs1 = register_to_bits(rs1)
        imm12 = int(imm12)
        check_imm(imm12, 12)
        imm12 = BitArray(int=imm12, length=12)
        bits = (
            imm12
            + rs1
            + funct3_codes[instruction]
            + rd
            + op_codes[instruction]
        )
    # Not an official "type", but parsed differently
    if instruction in ltypes:
        # ex: lw rd, imm(rs1)
        rd, offset_rs = args
        match = re.match(pattern_immediate_offset_register, offset_rs)
        if not match:
            raise LineException(
                "Load: immediate offset incorrectly formatted."
            )
        imm12 = int(match.group(1))
        check_imm(imm12, 12)
        imm12 = BitArray(int=int(match.group(1)), length=12)
        if instruction in ["slli", "srli"]:
            imm12[0:7] = "0b0000000"
        if instruction == "srai":
            imm12[0:7] = "0b0100000"
        rs = register_to_bits(match.group(2))
        rd = register_to_bits(rd)
        bits = (
            imm12 + rs + funct3_codes[instruction] + rd + op_codes[instruction]
        )
    if instruction in stypes:
        rs2, offset_rs = args
        match = re.match(pattern_immediate_offset_register, offset_rs)
        if not match:
            raise LineException(
                "Load: immediate offset incorrectly formatted.",
            )
        imm12 = int(match.group(1))
        check_imm(imm12, 12)
        imm12 = BitArray(int=int(match.group(1)), length=12)
        rs1 = register_to_bits(match.group(2))
        rs2 = register_to_bits(rs2)
        # bitstring slicing is opposite to Verilog (0 is MSB)
        bits = (
            imm12[0:7]
            + rs2
            + rs1
            + funct3_codes[instruction]
            + imm12[7:]
            + op_codes[instruction]
        )
    if instruction in btypes:
        rs1, rs2, label = args
        rs1 = register_to_bits(rs1)
        rs2 = register_to_bits(rs2)
        if label not in labels:
            raise LineException(
                f"label '{label}' was not in the stored table.",
            )
        offset = int(labels[label]) - address
        offset = offset >> 1
        check_imm(offset, 12)
        imm12 = BitArray(int=offset, length=12)
        print("#" * 48)

        print(
            f"Found a branch, setting BTA to offset = {offset}, "
            f"imm12 = {imm12.int}, "
            f"original offset = {int(labels[label]) - address} "
        )
        print("#" * 48 + "\n")

        # Verilog: 12 11 10  9  8  7  6  5  4  3  2  1
        #  Python:  0  1  2  3  4  5  6  7  8  9 10 11

        print("BRANCH: imm[1:2] =", imm12[1:2])

        bits = (
            imm12[0:1]
            + imm12[2:8]
            + rs2
            + rs1
            + funct3_codes[instruction]
            + imm12[8:12]
            + imm12[1:2]
            + op_codes[instruction]
        )
    if instruction == "jal":
        rd, label = args
        rd = register_to_bits(rd)
        if label not in labels:
            raise LineException(
                f"label '{label}' was not in the stored table.",
            )
        offset = (labels[label] - address) >> 1
        check_imm(offset, 20)
        imm = BitArray(int=offset, length=20)

        # imm[20|10:1|11|19:12] in normal bit order, this library makes us flip that
        # imm20,10:1,11,19:12
        imm20 = imm[0:1] + imm[10:20] + imm[9:10] + imm[1:9]
        print(
            f"Found a jal: offset = {offset}, imm={imm.bin}, imm20={imm20.bin} | {label}"
        )
        bits = imm20 + rd + op_codes[instruction]
    if instruction in utypes:
        rd, upimm = args
        rd = register_to_bits(rd)
        check_imm(upimm, 20)
        upimm = BitArray(int=int(upimm), length=20)
        bits = upimm + rd + op_codes[instruction]
    if instruction == 'halt':
        bits = BitArray(length=32)  # zeroed by default
        print("HALT:", not not bits)
    if bits is None:
        raise LineException(
            f"Instruction {instruction} was not handled.",
        )
    if bits.length != 32:
        raise LineException(
            f"Internal: Hard coded values didn't line up to 32 bits (was {bits.length} instead)",
        )
    return bits


rtype_funct3_mapping = {
    "001": "sll",
    "010": "slt",
    "011": "sltu",
    "100": "xor",
    "110": "or",
    "111": "and",
}
itype_funct3_mapping = {
    "000": "addi",
    "001": "slli",
    "010": "slti",
    "011": "sltiu",
    "100": "xori",
    "110": "ori",
    "111": "andi",
}
ltype_funct3_mapping = {
    "000": "lb",
    "001": "lh",
    "010": "lw",
    "100": "lbu",
    "101": "lhu",
}
stype_funct3_mapping = {"000": "sb", "001": "sh", "010": "sw"}
btype_funct3_mapping = {
    "000": "beq",
    "001": "bne",
    "100": "blt",
    "101": "bge",
    "110": "bltu",
    "111": "bgeu",
}


def bits_to_line(bits, labels=None):
    if bits.length != 32:
        raise ValueError("instruction must be 32 bits")
    op_code = bits[25:]
    rd = bits_to_register(bits[31 - 11: 31 - 7 + 1])
    rs1 = bits_to_register(bits[31 - 19: 31 - 15 + 1])
    rs2 = bits_to_register(bits[31 - 24: 31 - 20 + 1])
    funct3 = bits[31 - 14: 31 - 12 + 1]
    imm12 = bits[0:12]
    op = None
    funct7 = bits[0:7]
    if op_code.bin == "0110011":  # r-type
        if funct3.bin == "000":
            if funct7.bin == "0000000":
                op = "add"
            elif funct7.bin == "0100000":
                op = "sub"
            else:
                raise ValueError(
                    f"Invalid r-type add/sub funct7: {funct7.bin}"
                )
        elif funct3.bin == "101":
            if funct7.bin == "0000000":
                op = "srl"
            elif funct7.bin == "0100000":
                op = "sra"
            else:
                raise ValueError(
                    f"Invalid r-type srl/sra funct7: {funct7.bin}"
                )
        else:
            try:
                op = rtype_funct3_mapping[funct3.bin]
            except KeyError as e:
                raise ValueError(f"Invalid r-type funct3: {funct3.bin}")
        return f"{op} {rd}, {rs1}, {rs2}"
    if op_code.bin == "0010011":  # i-type
        if funct3.bin == "101":
            if funct7.bin == "0000000":
                op = "srli"
            elif funct7.bin == "0100000":
                op = "srai"
            else:
                raise ValueError(
                    f"Invalid i-type srl/sra funct7: {funct7.bin}"
                )
        else:
            try:
                op = itype_funct3_mapping[funct3.bin]
            except KeyError as e:
                raise ValueError(f"Invalid i-type funct3: {funct3.bin}")
        immediate = imm12.int
        if op in ["slli", "srli", "srai"]:
            immediate = imm12[4:].uint
        return f"{op} {rd}, {rs1}, {immediate}"
    if op_code.bin == "0000011":  # l-type
        try:
            op = ltype_funct3_mapping[funct3.bin]
        except KeyError as e:
            raise ValueError(f"Invalid load i-type funct3: {funct3.bin}")
        immediate = imm12.int
        return f"{op} {rd}, {immediate}({rs1})"
    if op_code.bin == "0100011":  # s-type
        try:
            op = stype_funct3_mapping[funct3.bin]
        except KeyError:
            raise ValueError(f"Invalid s-type funct3: {funct3.bin}")
        imm12 = bits[31 - 31: 31 - 25 + 1] + bits[31 - 11: 31 - 11 + 5]
        return f"{op} {rs2}, {imm12.int}({rs1})"
    if op_code.bin == "1100011":  # b-type
        try:
            op = btype_funct3_mapping[funct3.bin]
        except KeyError:
            raise ValueError(f"Invalid b-type funct3: {funct3.bin}")
        imm12 = BitArray(length=12)
        imm12[0] = bits[0]
        imm12[12 - 10: 12 - 5 + 1] = bits[1:7]
        imm12[12 - 4: 12 - 1 + 1] = bits[31 - 11: 31 - 7 + 1]
        imm12[1] = bits[31 - 7: 31 - 7 + 1]
        address = imm12
        if labels is None:
            return f"{op} {rs1}, {rs2}, {address.uint}"
        address = address.int * 2
        if address not in labels:
            labels[address] = f"LABEL_{len(labels)}"
        return f"{op} {rs1}, {rs2}, {labels[address]} # {labels[address]} <- {address}"
    imm20 = BitArray(length=21)
    imm20 = bits[31] + bits[19:12] + bits[20] + bits[30:25]
    imm20 = imm20 * 2
    if op_code == op_codes["auipc"]:
        return f"auipc {rd}, {imm20.int}"
    if op_code == op_codes["lui"]:
        return f"lui {rd}, {imm20.int}"
    if op_code == op_codes["jalr"]:
        if funct3.bin != "000":
            raise ValueError(
                f"Incorrectly formatted jalr: funct3 should be 000, not {funct3.bin}"
            )
        return f"jalr {rd}, {rs1}, {imm12.int}"

    if op_code == op_codes["jal"]:
        # original imm=00000000000000100100,
        # packed      =00001000010000000000
        # bad          00001000010000000000
        tmp = [
            bits[0:1],  # 31
            bits[12:20],  # 19:12
            bits[11:12],  # 11
            bits[1:11],  # 30:25
        ]
        imm20 = bits[0:1] + bits[12:20] + bits[11:12] + bits[1:11]
        address = imm20.int * 2
        if address % 4:
            raise Exception(
                "Disassembly bug: computed misaligned jump address."
            )
        if labels is None:
            # TODO(avinash) - add flag that lets this pick out labels from an assembly file.
            return f"jal {rd}, {address}"
        if address not in labels:
            labels[address] = f"LABEL_{len(labels)}"
        return f"jal {rd}, {labels[address]} # {labels[address]} <- {address}"
    raise ValueError(f"Unsupported opcode: {op_code.bin} ({op_code.uint})")
