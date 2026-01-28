#!/bin/bash
set -eu # exit if any command fails

STRING_DATA_OFFSET=0x00200000 # 2MB offset for string table

usage() {
  echo "Usage: $0 -d <source directory>"
  exit 1
}

ddir=""

while getopts ":d:" opt; do
  case "$opt" in
      d) ddir="$OPTARG" ;;
      *) echo "Invalid option: $opt" >&2; usage; exit 1; ;;
  esac
done

export SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR%/*}"

# Ensure arguments were provided
if [ -z "$ddir" ]; then
  usage
fi

# Validate arguments
if [[ ! -d "$ddir" ]]; then
  echo "Source directory $ddir does not exist"
  usage
  exit 1
fi

# Compile the source directory
echo "Compiling source directory $ddir"
pushd $ddir > /dev/null

echo "Compiling Jack code"
uv run python $REPO_ROOT/compiler/jack_compiler.py *.jack
echo "Translating VM code"
uv run python $REPO_ROOT/vm/translator.py *.vm > Program.asm
echo "Assembling program"
uv run python $REPO_ROOT/assembler/assembler.py Program.asm > Program.hack
echo "Converting object code to big endian binary"
uv run python $REPO_ROOT/assembler/object_code_ascii_to_big_endian.py Program.hack Program.bin

popd > /dev/null

echo "Uploading string table to board with iceprog"
iceprog -k -o $STRING_DATA_OFFSET $ddir/StringConstantTable.bin

echo "Installing computer and program to board via install_computer.sh"
$SCRIPT_DIR/install_computer.sh $ddir/Program.bin

echo "Done installing!"
echo -n "ROM size (max is 32768 16-bit words): "
wc -l < $ddir/Program.hack
echo -n "String table size (max is 8166 characters): "
xxd -b -c 2 $ddir/StringConstantTable.bin | wc -l
