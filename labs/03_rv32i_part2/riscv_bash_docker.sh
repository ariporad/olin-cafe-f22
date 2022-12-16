#!/bin/sh
# Start a shell in a Docker Image with the RISC-V toolchain
# Why? The RISC-V toolchain is a pain to install! This is a one-liner (and only requires Docker!)
# See ./riscv_gcc_docker.sh for a version of this that just runs GCC.
# From: https://pulp-platform.org/community/showthread.php?tid=282
docker run --rm -it --entrypoint bash --volume $PWD:/hostdir coderitter/pulp-riscv-gnu-toolchain
