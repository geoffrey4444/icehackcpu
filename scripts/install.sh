#!/bin/bash
VERILOG_BASENAME="${1##*/}"; VERILOG_BASENAME="${base%.*}"
VERILOG_FILES=$@
export SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR%/*}"
TEMP_DIR=$(mktemp -d)

echo "Compiling with yosys" && \
yosys -p "synth_ice40 -top top -json ${TEMP_DIR}/${VERILOG_BASENAME}.json" \
${VERILOG_FILES}

echo "Mapping with nextpnr-ice40" && \
nextpnr-ice40 --up5k --package sg48 --json ${TEMP_DIR}/${VERILOG_BASENAME}.json \
--pcf ${REPO_ROOT}/icebreaker.pcf --asc ${TEMP_DIR}/${VERILOG_BASENAME}.asc && \

echo "Packing with icepack" && \
icepack ${TEMP_DIR}/${VERILOG_BASENAME}.asc ${TEMP_DIR}/${VERILOG_BASENAME}.bin && \

echo "Uploading to board with iceprog" && \
iceprog ${TEMP_DIR}/${VERILOG_BASENAME}.bin

trap 'rm -rf "$TEMP_DIR"' EXIT
