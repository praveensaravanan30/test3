#!/bin/bash
# Quick script to run golden testbench simulation and generate waveforms
# This creates both VCD waveforms and log files
# Usage: ./run_golden_simulation.sh [module_name]
#        module_name: slave, master, interrupt, top (default: slave)

set -e  # Exit on error

MODULE=${1:-slave}

case $MODULE in
    slave)
        TESTBENCH="harness/patch/test/axi4_slave_tb_golden.sv"
        DUT="harness/patch/rtl/axi4_slave.sv"
        VCD_FILE="$LOG_DIR/axi4_slave_tb_golden.vcd"
        ;;
    master)
        TESTBENCH="harness/patch/test/axi4_master_tb_golden.sv"
        DUT="harness/patch/rtl/axi4_master.sv"
        VCD_FILE="$LOG_DIR/axi4_master_tb_golden.vcd"
        ;;
    interrupt)
        TESTBENCH="harness/patch/test/axi4_interrupt_tb_golden.sv"
        DUT="harness/patch/rtl/axi4_interrupt.sv"
        VCD_FILE="$LOG_DIR/axi4_interrupt_tb_golden.vcd"
        ;;
    top)
        TESTBENCH="harness/patch/test/axi4_top_tb_golden.sv"
        DUT="harness/patch/rtl/axi4_top.sv harness/patch/rtl/axi4_master.sv harness/patch/rtl/axi4_slave.sv harness/patch/rtl/axi4_interrupt.sv"
        VCD_FILE="$LOG_DIR/axi4_top_tb_golden.vcd"
        ;;
    *)
        echo "ERROR: Unknown module '$MODULE'"
        echo "Usage: $0 [slave|master|interrupt|top]"
        exit 1
        ;;
esac

OUTPUT_DIR="harness/test/sim_build"
LOG_DIR="harness/test/log"
LOG_FILE="$LOG_DIR/sim.log"

echo "=========================================="
echo "Golden Testbench Simulation"
echo "=========================================="
echo "Module: $MODULE"
echo "Testbench: $TESTBENCH"
echo "DUT: $DUT"
echo ""

# Check files exist
if [ ! -f "$TESTBENCH" ]; then
    echo "ERROR: Testbench not found: $TESTBENCH"
    exit 1
fi

# For top module, check all RTL files separately
if [ "$MODULE" == "top" ]; then
    if [ ! -f "harness/patch/rtl/axi4_top.sv" ] || \
       [ ! -f "harness/patch/rtl/axi4_master.sv" ] || \
       [ ! -f "harness/patch/rtl/axi4_slave.sv" ] || \
       [ ! -f "harness/patch/rtl/axi4_interrupt.sv" ]; then
        echo "ERROR: One or more RTL files not found for top module"
        exit 1
    fi
else
    if [ ! -f "$DUT" ]; then
        echo "ERROR: DUT not found: $DUT"
        exit 1
    fi
fi

# Create output directories
mkdir -p $OUTPUT_DIR
mkdir -p $LOG_DIR

# Compile
echo "[1/3] Compiling..."
if [ "$MODULE" == "top" ]; then
    # Top module needs all RTL files
        iverilog -g2012 -o $OUTPUT_DIR/golden_tb.out \
        harness/patch/rtl/axi4_slave.sv \
        harness/patch/rtl/axi4_master.sv \
        harness/patch/rtl/axi4_interrupt.sv \
        harness/patch/rtl/axi4_top.sv \
        $TESTBENCH 2>&1 | tee $LOG_DIR/compile.log
    COMPILE_EXIT=${PIPESTATUS[0]}
else
    iverilog -g2012 -o $OUTPUT_DIR/golden_tb.out $DUT $TESTBENCH 2>&1 | tee $LOG_DIR/compile.log
    COMPILE_EXIT=${PIPESTATUS[0]}
fi

# Check for compilation errors
if [ $COMPILE_EXIT -ne 0 ]; then
    echo "ERROR: Compilation failed. Check compile.log"
    exit 1
fi

# Also check compile.log for error messages (iverilog sometimes returns 0 even with errors)
if grep -qi "error" compile.log 2>/dev/null; then
    echo "ERROR: Compilation errors found. Check compile.log"
    exit 1
fi

echo "✓ Compilation successful"
echo ""

# Run simulation with timeout
echo "[2/3] Running simulation..."
timeout 60 vvp $OUTPUT_DIR/golden_tb.out 2>&1 | tee $LOG_FILE

SIM_EXIT=${PIPESTATUS[0]}
echo ""

# Check if timeout occurred
if [ $SIM_EXIT -eq 124 ]; then
    echo "ERROR: Simulation timed out after 60 seconds"
    echo "The testbench may be missing \$finish or stuck in a wait()"
    echo "Check $LOG_FILE for details"
    exit 1
fi

# Check results
if [ $SIM_EXIT -ne 0 ]; then
    echo "WARNING: Simulation exited with code $SIM_EXIT"
    echo "Check $LOG_FILE for details"
fi

# Check for VCD file
if [ -f "$VCD_FILE" ]; then
    VCD_SIZE=$(du -h "$VCD_FILE" | cut -f1)
    echo "[3/3] Waveform file generated: $VCD_FILE ($VCD_SIZE)"
else
    echo "WARNING: VCD file not found: $VCD_FILE"
fi

echo ""
echo "=========================================="
echo "Simulation Complete!"
echo "=========================================="
echo "Log file:    $LOG_FILE"
echo "VCD file:    $VCD_FILE"
echo "Compile log: $LOG_DIR/compile.log"
echo ""
echo "To view waveforms:"
echo "  gtkwave $VCD_FILE"
echo ""
echo "To view log:"
echo "  cat $LOG_FILE"
echo ""
echo "All output files are in: $LOG_DIR"
echo ""

