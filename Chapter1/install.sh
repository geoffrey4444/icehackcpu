#!/bin/bash
export VERILOG_FILE=simplegates
export REPO_ROOT=../
yosys -p "synth_ice40 -top top -json ${VERILOG_FILE}.json" ${VERILOG_FILE}.v && \
nextpnr-ice40 --up5k --package sg48 --json ${VERILOG_FILE}.json --pcf ${REPO_ROOT}/icebreaker.pcf --asc ${VERILOG_FILE}.asc && \
icepack ${VERILOG_FILE}.asc ${VERILOG_FILE}.bin && \
iceprog ${VERILOG_FILE}.bin
