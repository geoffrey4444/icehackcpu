#!/bin/bash
export SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR%/*}"

# Run all tests
echo "logic/tb.v"
$SCRIPT_DIR/runtest.sh $REPO_ROOT/logic/tb.v $REPO_ROOT/logic/gates.v

# Run math tests
echo "math/tb.v"
$SCRIPT_DIR/runtest.sh $REPO_ROOT/math/tb.v $REPO_ROOT/math/add.v $REPO_ROOT/logic/gates.v
