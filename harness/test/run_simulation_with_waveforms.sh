#!/bin/bash
# Script to run simulation and generate VCD waveforms
# Usage: ./run_simulation_with_waveforms.sh [testbench_path] [dut_path]

TESTBENCH_PATH=${1:-"harness/patch/test/axi4_slave_tb_golden.sv"}
DUT_PATH=${2:-"harness/patch/rtl/axi4_slave.sv"}
OUTPUT_DIR="sim_build"
LOG_FILE="sim.log"
VCD_FILE="axi4_slave_tb_golden.vcd"

echo "=========================================="
echo "Running simulation with waveforms"
echo "=========================================="
echo "Testbench: $TESTBENCH_PATH"
echo "DUT: $DUT_PATH"
echo ""

# Create output directory
mkdir -p $OUTPUT_DIR

# Compile
echo "Compiling..."
iverilog -g2012 -o $OUTPUT_DIR/testbench.out $DUT_PATH $TESTBENCH_PATH 2>&1 | tee compile.log

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed. Check compile.log"
    exit 1
fi

echo "Compilation successful!"
echo ""

# Run simulation
echo "Running simulation..."
vvp $OUTPUT_DIR/testbench.out 2>&1 | tee $LOG_FILE

if [ $? -ne 0 ]; then
    echo "ERROR: Simulation failed. Check $LOG_FILE"
    exit 1
fi

echo ""
echo "=========================================="
echo "Simulation completed!"
echo "=========================================="
echo "Log file: $LOG_FILE"
echo "VCD file: $VCD_FILE"
echo ""
echo "To view waveforms, use:"
echo "  gtkwave $VCD_FILE"
echo "  or"
echo "  vcd2vcd $VCD_FILE | vcd2fst -o output.fst"
echo ""

