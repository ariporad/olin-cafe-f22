#!/usr/bin/env python3

# Heavily based on this [reference card](http://csci206sp2020.courses.bucknell.edu/files/2020/01/riscv-card.pdf)
# and the official [spec](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf)


import argparse
import os
import os.path as path
import re
import sys

import rv32i

try:
    from bitstring import BitArray
except:
    raise Exception(
        "Missing a library, try `sudo apt install python3-bitstring`"
    )


class AssemblyProgram:
    def __init__(self, start_address=0, labels=None):
        self.address = start_address
        self.line_number = 0
        self.labels = {}
        if labels:
            for k in labels:
                self.labels[k] = labels[k]
        self.parsed_lines = []

    def parse_line(self, line):
        self.line_number += 1
        parsed = {}
        line = line.strip()
        parsed["original"] = line
        line = re.sub("\s*#.*", "", line)  # Remove comments.
        match = re.search("^([\w\(\)_\.]+):", line)
        if match:
            self.labels[match.group(1)] = self.address
            line = re.sub("^([\w\(\)_\.]+):\s*", "", line)
            parsed["label"] = match.group(1)
        match = re.search("^([\w\.]+)\s*(.*)", line)
        if not match:
            return -1
        parsed["line_number"] = self.line_number
        parsed["instruction"] = match.group(1)
        parsed["args"] = [
            x.strip()
            for x in match.group(2).split(",")
            if x.strip() != ''
        ]

        if parsed['instruction'].startswith('.'):
            print(
                f"Detected assembler directive: {parsed['instruction']}, ignoring...", parsed)
            return 0

        # Handle psuedo-instructions.
        if parsed['instruction'] in rv32i.PSEUDO_INSTRUCTIONS:
            pseudo_result = \
                rv32i.PSEUDO_INSTRUCTIONS[parsed['instruction']](
                    *parsed["args"]
                )

            # NOTE: pseudo_result can either be a tuple in the form ('inst', [arg1, arg2]) or a list
            # of tuples like that. We need to handle both cases

            # if just one returned instruction
            if not isinstance(pseudo_result[0], tuple):
                parsed['instruction'], parsed['args'] = pseudo_result
            else:  # otherwise, handle multiple
                for i, (instruction, args) in enumerate(pseudo_result, start=1):
                    pseudo_parsed = parsed.copy()
                    # Each part of a pseudo-instruction is +0.1 to the line number
                    pseudo_parsed['line_number'] += i / 10
                    pseudo_parsed['instruction'] = instruction
                    pseudo_parsed['args'] = args
                    self.address += 4
                    self.parsed_lines.append(pseudo_parsed)
                return 0  # have to return so we don't append parsed

        self.address += 4
        self.parsed_lines.append(parsed)
        return 0

    def write_mem(self, fn, hex_notbin=True, disable_annotations=False, disable_sourcemaps=False):
        output = []
        address = 0
        for line in self.parsed_lines:
            try:
                bits = rv32i.line_to_bits(
                    line, labels=self.labels, address=address
                )
            except rv32i.LineException as e:
                print(
                    f"Error on line {line['line_number']} ({line['instruction']})"
                )
                print(f"  {e}")
                print(f"  original line: {line['original']}")
                return -1
            except Exception as e:
                print(f"Unhandled error, possible bug in assembler!!!")
                print(
                    f"Error on line {line['line_number']} ({line['instruction']})"
                )
                print(f"  {e}")
                print(f"  original line: {line['original']}")
                raise e
            address += 4
            output.append((bits, line))
        # Only write the file if the above completes without errors
        source_map = []
        with open(fn, "w") as f:
            address = 0
            for bits, line in output:
                annotation = f" // PC={hex(address)} line={line['line_number']}: {line['original']}"
                if disable_annotations:
                    annotation = ""
                if not disable_sourcemaps:
                    source_map.append((address, line['line_number']))
                if hex_notbin:
                    f.write(f"{bits.hex}{annotation}\n")
                else:
                    f.write(bits.bin + "\n")
                address += 4
        if not disable_sourcemaps:
            # FIXME: This is *highly* inefficient
            with open("assembly_sourcemap.txt", 'w') as f:
                print(self.labels.items())
                for address, line_no in source_map:
                    try:
                        nearest_label = sorted(
                            filter(
                                lambda entry: entry[1] <= address,
                                self.labels.items()
                            ),
                            key=lambda entry: entry[1],
                            reverse=True
                        )[0][0]
                    except IndexError:
                        nearest_label = "root"
                    f.write(f"{address:08X} {line_no}: {nearest_label}\n")

        return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input", help="input file name of human readable assembly"
    )
    parser.add_argument(
        "-o",
        "--output",
        help="output file name of hex values in text that can be read from SystemVerilog's readmemh",
    )
    parser.add_argument(
        "--disable_annotations",
        action="store_true",
        default=False,
        help="Prints memh files without any annotations.",
    )
    parser.add_argument(
        "--disable_sourcemaps",
        action="store_true",
        default=False,
        help="Don't emit a sourcemap filter file for GTK Wave"
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        default=os.environ.get('ASSEMBLER_VERBOSE', '0') == '1',
        help="increases verbosity of the script",
    )
    parser.add_argument(
        "-c",
        "--gcc",
        action="store_true",
        default=False,
        help="add appropriate handling for assembly generated by GCC (preamble, etc.)",
    )
    args = parser.parse_args()

    if not path.exists(args.input):
        raise Exception(f"input file {args.input} does not exist.")
    ap = AssemblyProgram()

    files = [args.input]

    if args.gcc:
        files.insert(0, 'asm/_preamble.s')  # TODO: account for CWD

    for file in files:
        with open(file, "r") as f:
            for line in f:
                ap.parse_line(line)

    ap.parsed_lines.append(
        {'line_number': 'EOF', 'instruction': 'halt', 'args': [], 'original': ''}
    )
    if args.verbose:
        print(f"Parsed {len(ap.parsed_lines)} instructions. Label table:")
        print(
            "  " + ",\n  ".join([f"{k} -> {ap.labels[k]}" for k in ap.labels])
        )
    if args.output:
        exit_code = ap.write_mem(
            args.output,
            hex_notbin=not "memb" in args.output,
            disable_annotations=args.disable_annotations,
            disable_sourcemaps=args.disable_sourcemaps
        )
        sys.exit(exit_code)
    sys.exit(0)


if __name__ == "__main__":
    main()
