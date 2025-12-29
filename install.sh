#!/bin/bash
export VERILOG_FILE=$1
export REPO_ROOT=../
export TEMP_DIR=$(mktemp -d)

yosys -p "synth_ice40 -top top -json ${TEMP_DIR}/${VERILOG_FILE}.json" \
${VERILOG_FILE}.v && \

nextpnr-ice40 --up5k --package sg48 --json ${TEMP_DIR}/${VERILOG_FILE}.json \
--pcf ${REPO_ROOT}/icebreaker.pcf --asc ${TEMP_DIR}/${VERILOG_FILE}.asc && \

icepack ${TEMP_DIR}/${VERILOG_FILE}.asc ${TEMP_DIR}/${VERILOG_FILE}.bin && \
iceprog ${TEMP_DIR}/${VERILOG_FILE}.bin

trap 'rm -rf "$TEMP_DIR"' EXIT
