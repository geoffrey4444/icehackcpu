#!/bin/bash
export SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR%/*}"

# Run memory tests
echo "memory/tb_dff.v"
$SCRIPT_DIR/runtest.sh $REPO_ROOT/memory/tb_dff.v $REPO_ROOT/memory/dff.v

# Run ALU tests
echo "math/tb_alu.v"
$SCRIPT_DIR/runtest.sh $REPO_ROOT/math/tb_alu.v $REPO_ROOT/math/alu.v $REPO_ROOT/math/add.v $REPO_ROOT/logic/gates.v

# Run gate tests
echo "logic/tb.v"
$SCRIPT_DIR/runtest.sh $REPO_ROOT/logic/tb.v $REPO_ROOT/logic/gates.v

# Run math tests
echo "math/tb.v"
$SCRIPT_DIR/runtest.sh $REPO_ROOT/math/tb.v $REPO_ROOT/math/add.v $REPO_ROOT/logic/gates.v

