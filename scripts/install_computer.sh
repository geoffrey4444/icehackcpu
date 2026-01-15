#!/bin/bash
set -eu  # exit if any command fails

export SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR%/*}"
# Payload file is first positional argument
export PAYLOAD_FILE="$1"
echo "Installing computer to icebreaker board..."
echo "Payload file: ${PAYLOAD_FILE}"
echo "CWD: $(pwd)"

$SCRIPT_DIR/install.sh -p $PAYLOAD_FILE \
  ./computer/top_computer.v \
  ./memory/memory_spram.v \
  ./memory/memory_dff.v \
  ./memory/dff.v \
  ./uart/uart.v \
  ./computer/cpu.v \
  ./math/alu.v \
  ./math/add.v \
  ./logic/gates.v

echo "Done!"
