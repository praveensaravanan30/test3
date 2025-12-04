# AXI4 Testbench Generation Problem

This is a HUD-formatted problem for testing AI agent capabilities in generating SystemVerilog testbenches.

## Problem Description

The agent must generate a testbench file (`verif/axi4_slave_tb.sv`) that:
1. Instantiates the AXI4 slave module from `sources/axi4_slave.sv`
2. Contains SystemVerilog assertions to verify AXI4 protocol compliance
3. Compiles successfully with Icarus Verilog
4. Simulates successfully
5. Executes assertions during simulation

## Directory Structure

- `sources/` - RTL source files (baseline implementation)
- `tests/` - Test files for grading
- `verif/` - Directory where agent writes the generated testbench
- `docs/` - Specification documentation

## Running Tests

```bash
# Install dependencies
pip install -e .

# Run tests
pytest tests/ -v
```

## See Also

- `docs/Specification.md` - AXI4 protocol specification
- `CONTRACTOR_GUIDE.md` - Guide for converting problems to HUD format

