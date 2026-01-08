#!/bin/bash
set -eu  # exit if any command fails
PAYLOAD=""
DATA_OFFSET=0x00100000 # 1MB offset
BITSTREAM_SIZE_LIMIT=1048576 # 1MB (don't let fpga bitstream overwrite payload)

while getopts "p:" opt; do
  case $opt in
    p) PAYLOAD="$OPTARG" ;;
    *) echo "Usage: $0 [-p payload.bin] file1.v [file2.v ...]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
if [ "$#" -eq 0 ]; then
  echo "No Verilog files provided" >&2; exit 1;
fi


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
icepack ${TEMP_DIR}/${VERILOG_BASENAME}.asc ${TEMP_DIR}/${VERILOG_BASENAME}.bin

BITSTREAM_SIZE=$(stat -f%z ${TEMP_DIR}/${VERILOG_BASENAME}.bin)
echo "Size of binary (bytes): ${BITSTREAM_SIZE}"
if [ "$BITSTREAM_SIZE" -ge "$BITSTREAM_SIZE_LIMIT" ]; then
  echo "Bitstream size is ${BITSTREAM_SIZE} bytes, which is greater than the limit of ${BITSTREAM_SIZE_LIMIT} bytes"
  exit 1
fi


echo "Uploading to board with iceprog" && \
iceprog ${TEMP_DIR}/${VERILOG_BASENAME}.bin


if [ -n "$PAYLOAD" ]; then
  echo "Uploading payload to flash at offset ${DATA_OFFSET}" && \
  iceprog -o ${DATA_OFFSET} "$PAYLOAD"
fi

trap 'rm -rf "$TEMP_DIR"' EXIT
