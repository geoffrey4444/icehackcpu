# Repository Guidelines

## Project Structure & Module Organization
- `logic/` holds Verilog source and testbench files.
  - `logic/gates.v` contains basic combinational gate modules.
  - `logic/top*v` are IceBreaker top-level modules wired to buttons/LEDs.
  - `logic/tb.v` is the simulation testbench.
- `scripts/` contains helper scripts for simulation and FPGA programming.
- `icebreaker.pcf` defines the FPGA pin constraints.

## Build, Test, and Development Commands
- `scripts/runtest.sh logic/tb.v logic/gates.v` runs a single simulation with Icarus Verilog and `vvp`.
- `scripts/runtests.sh` runs the current testbench suite (currently just `logic/tb.v`).
- `scripts/install.sh logic/top.v logic/gates.v` synthesizes with Yosys, places/routes with nextpnr, packs with icepack, and flashes with iceprog.

## Coding Style & Naming Conventions
- Use 2-space indentation and align ports with named connections.
- Modules are lowercase with numeric suffixes (e.g., `nand2`, `xor2`).
- Instance names use a descriptive prefix like `u_` or `my_`.
- Keep `default_nettype none` at the top of new Verilog files.

## Testing Guidelines
- Simulation uses Icarus Verilog (`iverilog -g2012`) with `vvp`.
- Testbenches live in `logic/` and use short, explicit `#1` delays with `$fatal` checks.
- Name new testbenches `*_tb.v` or extend `logic/tb.v` with additional vectors.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, and capitalized (e.g., “Add unit tests with simulator”).
- PRs should include: a concise description, test command(s) run, and any hardware impact notes.
- For board changes, note which pins or LEDs were affected (referencing `icebreaker.pcf`).

## Toolchain Notes
- FPGA flow expects `yosys`, `nextpnr-ice40`, `icepack`, and `iceprog` on PATH.
- Simulation expects `iverilog` and `vvp` installed.
