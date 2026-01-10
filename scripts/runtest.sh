#!/bin/bash
export VERILOG_FILES=$@
export SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR%/*}"
export TEMP_DIR=$(mktemp -d)

iverilog -g2012 -D SIM -o ${TEMP_DIR}/sim $VERILOG_FILES && \
vvp ${TEMP_DIR}/sim

trap 'rm -rf "$TEMP_DIR"' EXIT
