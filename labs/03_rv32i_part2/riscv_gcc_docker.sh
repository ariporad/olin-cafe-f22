#!/bin/sh
# Run the RISC-V compiler in a Docker Image
# Why? The RISC-V toolchain is a pain to install! This is a one-liner (and only requires Docker!)
# Use this script in place of `gcc`, and it should just work(tm).
# From: https://pulp-platform.org/community/showthread.php?tid=282
docker run --rm --entrypoint riscv32-unknown-elf-gcc --volume $PWD:/hostdir coderitter/pulp-riscv-gnu-toolchain  "$@"
