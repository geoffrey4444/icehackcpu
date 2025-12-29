#!/bin/bash
export SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${SCRIPT_DIR%/*}"
echo $SCRIPT_DIR
echo $REPO_ROOT

# Run all tests
echo "logic/tb.v"
$SCRIPT_DIR/runtest.sh $REPO_ROOT/logic/tb.v $REPO_ROOT/logic/gates.v
