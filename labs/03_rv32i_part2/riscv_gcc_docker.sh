#!/bin/sh
# Run the RISC-V compiler in a Docker Image
# From: https://pulp-platform.org/community/showthread.php?tid=282
docker run --rm --entrypoint riscv32-unknown-elf-gcc --volume $PWD:/hostdir coderitter/pulp-riscv-gnu-toolchain  "$@"
