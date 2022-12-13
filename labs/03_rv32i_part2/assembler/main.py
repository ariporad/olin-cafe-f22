#!/usr/bin/env python3

# Heavily based on this [reference card](http://csci206sp2020.courses.bucknell.edu/files/2020/01/riscv-card.pdf)
# and the official [spec](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf)


from __future__ import annotations
from typing import *

import argparse
import os
import os.path as path
import re
import sys
from dataclasses import dataclass, replace, field

import rv32i
from helpers import BitArray


@dataclass
class ParsedLine:
    original: str
    line_number: int
    instruction: str
    args: List[str] = field(default_factory=list)
    label: Optional[str] = field(default=None)

    @property
    def is_directive(self) -> bool:
        """ Is this line an assembler directive? """
        return self.instruction.startswith('.')

    @property
    def is_pseudo(self) -> bool:
        """ Is this line a pesudo-instruction? """
        return self.instruction in rv32i.PSEUDO_INSTRUCTIONS

    def __str__(self) -> str:
        output = f"{self.line_number:03} "
        if self.label:
            output += f"{self.label}: "
        output += f"{self.instruction} "
        output += ', '.join(self.args)

        return f"`{output}`"


COMMENTS_REGEX = r"\s*#.*"
LABEL_REGEX = r"^([\w\(\)_\.]+):\s*(.*)"
INSTRUCTION_REGEX = r"^([\w\.]+)\s*(.*)"


class AssemblyProgram:
    parsed_lines: List[ParsedLine]

    def __init__(self, start_address=0, labels=None):
        self.address = start_address
        self.line_number = 0
        self.labels = {}
        if labels:
            for k in labels:
                self.labels[k] = labels[k]
        self.parsed_lines = []

    def parse_args(self, args_str) -> List[str]:
        return [
            x.strip()
            for x in args_str.split(",")
            if x.strip() != ''
        ]

    def parse_line(self, line):
        self.line_number += 1
        line = line.strip()
        original_line = line
        label = None

        # Remove Comments
        line = re.sub(COMMENTS_REGEX, "", line)

        # Check for Label
        label_match = re.search(LABEL_REGEX, line)
        if label_match:
            label, line = label_match.groups()
            self.labels[label] = self.address

        # Parse Instruction
        instruction_match = re.search(INSTRUCTION_REGEX, line)
        if not instruction_match:
            return -1
        instruction, args_str = instruction_match.groups()

        parsed = ParsedLine(
            original=original_line,
            label=label,
            line_number=self.line_number,
            instruction=instruction,
            args=self.parse_args(args_str)
        )

        if parsed.is_directive:
            print(
                f"Detected assembler directive: {parsed.instruction}, ignoring...", parsed)
            return 0

        new_parsed_lines = [parsed]

        # Handle psuedo-instructions.
        if parsed.is_pseudo:
            pseudo_result = \
                rv32i.PSEUDO_INSTRUCTIONS[parsed.instruction](*parsed.args)

            # NOTE: pseudo_result can either be a tuple in the form ('inst', [arg1, arg2]) or a list
            # of tuples like that. We need to handle both cases

            # if just one returned instruction
            if not isinstance(pseudo_result[0], tuple):
                parsed.instruction, parsed.args = pseudo_result
            else:  # otherwise, handle multiple
                new_parsed_lines = [
                    replace(parsed, instruction=instruction, args=args)
                    for instruction, args in pseudo_result
                ]

        for new_parsed_line in new_parsed_lines:
            self.address += 4
            self.parsed_lines.append(new_parsed_line)

        return 0

    def write_mem(self, fn, hex_notbin=True, disable_annotations=False, disable_sourcemaps=False):
        output: List[Tuple[BitArray, ParsedLine]] = []
        address: int = 0

        # Convert all parsed instructions to binary
        for parsed in self.parsed_lines:
            try:
                bits = rv32i.line_to_bits(
                    parsed, labels=self.labels, address=address
                )
            except rv32i.LineException as e:
                print(
                    f"Error on line {parsed.line_number} ({parsed.instruction})"
                )
                print(f"  {e}")
                print(f"  original line: {parsed.original}")
                return -1
            except Exception as e:
                print(f"Unhandled error, possible bug in assembler!!!")
                print(
                    f"Error on line {parsed.line_number} ({parsed.instruction})"
                )
                print(f"  {e}")
                print(f"  original line: {parsed.original}")
                raise e
            address += 4
            output.append((bits, parsed))

        # Write to disk
        # Only write the file if the above completes without errors
        source_map = []
        with open(fn, "w") as f:
            address = 0
            for bits, parsed in output:
                annotation = f" // PC={hex(address)} line={parsed.line_number}: {parsed.original}"
                if disable_annotations:
                    annotation = ""
                if not disable_sourcemaps:
                    source_map.append((address, parsed.line_number))
                if hex_notbin:
                    f.write(f"{bits.hex}{annotation}\n")
                else:
                    f.write(bits.bin + "\n")
                address += 4

        # Source maps
        if not disable_sourcemaps:
            # FIXME: This is *highly* inefficient
            with open("tests/gtkwave_filters/assembly_sourcemap.txt", 'w') as f:
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

    # Halt execution at the end of the file
    ap.parsed_lines.append(
        ParsedLine(original='', line_number=-1, instruction='halt', args=[])
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
