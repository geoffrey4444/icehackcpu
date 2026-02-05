# Repository Guidelines

## Project Structure & Module Organization
- `computer/`, `memory/`, `logic/`, `math/`, `uart/`, `led/`: Verilog modules and testbenches (`tb_*.v`) for the Hack CPU and peripherals.
- `assembler/`, `compiler/`, `vm/`: Python tooling for Hack assembly, Jack compilation, and VM translation.
- `src/`: Example programs, OS sources, and demo apps (Jack, VM, ASM).
- `scripts/`: Build, test, and board install helpers.
- `icebreaker.pcf`: iCEBreaker FPGA pin constraints.

## Build, Test, and Development Commands
- `scripts/runtests.sh`: Runs the full Verilog + assembler/translator test suite via `iverilog`/`vvp` and Python tools.
- `scripts/runtest.sh <tb.v> <deps...>`: Runs a single Verilog testbench (pass the testbench first, then dependent modules).
- `scripts/install.sh [-p payload.bin] <verilog files...>`: Synthesizes with `yosys`, places/routes with `nextpnr-ice40`, packs with `icepack`, and flashes via `iceprog`.
- `scripts/install_computer.sh <Program.bin>`: Builds and flashes the full computer image plus payload.
- `scripts/install_computer_from_directory.sh -d src/hello`: Compiles Jack -> VM -> ASM -> Hack -> binary and flashes program + string table.

## Coding Style & Naming Conventions
- Verilog: 2-space indentation, lower_snake_case signals, lower_snake_case module names, explicit `wire`/`reg` declarations.
- Python: 4-space indentation, clear function naming; keep scripts runnable with `uv run` (used throughout `scripts/`).
- Shell: bash with `set -eu`, prefer readable, linear pipelines.

## Testing Guidelines
- Verilog tests live alongside modules as `tb_*.v`.
- Run targeted tests with `scripts/runtest.sh` before hardware flashing when possible.
- Python tools are exercised by `scripts/runtests.sh` using `uv run python ...`.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, and sentence case (e.g., "Fix bugs in division").
- PRs should describe the hardware or toolchain impact, note tests run (command + result), and include any relevant output or screenshots if changing I/O behavior (UART/LED).

## Hardware & Toolchain Notes
- Requires `yosys`, `nextpnr-ice40`, `icepack`, `iceprog`, and `iverilog`.
- Payload flashing uses fixed offsets; verify sizes in `scripts/install.sh` and `scripts/install_computer_from_directory.sh` before changing ROM layouts.
