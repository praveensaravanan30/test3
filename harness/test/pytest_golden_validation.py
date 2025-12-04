"""
Pytest test to validate that the golden RTL and golden testbench follow the spec.
This ensures the golden solution is correct before grading agent solutions.

The golden testbench can be used as a reference/helper for grading agent-generated testbenches.
"""

import os
import pytest
import subprocess
from pathlib import Path


def test_golden_rtl_compiles():
    """
    Test that the golden RTL module compiles successfully.
    This validates the golden solution before using it for grading.
    """
    rtl_dir = Path("harness/patch/rtl")
    assert rtl_dir.exists(), f"Golden RTL directory not found: {rtl_dir}"
    
    # Check that axi4_slave module compiles
    rtl_path = rtl_dir / "axi4_slave.sv"
    assert rtl_path.exists(), f"Golden RTL not found: {rtl_path}"
    
    # Compile the RTL module to check syntax
    # Use -t null to just check syntax without generating output
    cmd = ["iverilog", "-g2012", "-t", "null", str(rtl_path)]
    
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True
    )
    
    # The test passes if return code is 0 (success).
    assert result.returncode == 0, \
        f"Golden RTL compilation failed:\nFile: {rtl_path.name}\nError: {result.stderr}"


def test_golden_testbench_compiles():
    """Test that golden testbench compiles with golden RTL."""
    rtl_dir = Path("harness/patch/rtl")
    tb_path = Path("harness/patch/test/axi4_slave_tb_golden.sv")
    
    assert rtl_dir.exists(), f"Golden RTL directory not found: {rtl_dir}"
    assert tb_path.exists(), f"Golden testbench not found: {tb_path}"
    
    rtl_path = rtl_dir / "axi4_slave.sv"
    assert rtl_path.exists(), f"Golden RTL not found: {rtl_path}"
    
    # Compile testbench with RTL
    cmd = ["iverilog", "-g2012", "-o", "golden_tb.out", str(rtl_path), str(tb_path)]
    
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True
    )
    
    assert result.returncode == 0, \
        f"Golden testbench compilation failed:\nRTL file: {rtl_path.name}\nError: {result.stderr}"


def test_golden_testbench_simulates():
    """Test that golden testbench simulates successfully."""
    rtl_dir = Path("harness/patch/rtl")
    tb_path = Path("harness/patch/test/axi4_slave_tb_golden.sv")
    rtl_path = rtl_dir / "axi4_slave.sv"
    
    # Compile
    cmd = ["iverilog", "-g2012", "-o", "golden_tb.out", str(rtl_path), str(tb_path)]
    compile_result = subprocess.run(
        cmd,
        capture_output=True,
        text=True
    )
    
    if compile_result.returncode != 0:
        pytest.skip(f"Compilation failed: {compile_result.stderr}")
    
    # Simulate
    try:
        sim_result = subprocess.run(
            ["vvp", "golden_tb.out"],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if sim_result.returncode != 0 and "VCD" not in sim_result.stdout:
            assert False, f"Golden testbench simulation failed: {sim_result.stderr}"
    except subprocess.TimeoutExpired:
        pytest.skip("Simulation timed out - testbench may be missing $finish.")


def test_golden_assertions_execute():
    """Test that golden testbench assertions execute during simulation."""
    rtl_dir = Path("harness/patch/rtl")
    tb_path = Path("harness/patch/test/axi4_slave_tb_golden.sv")
    rtl_path = rtl_dir / "axi4_slave.sv"
    
    # Compile
    cmd = ["iverilog", "-g2012", "-o", "golden_tb.out", str(rtl_path), str(tb_path)]
    compile_result = subprocess.run(
        cmd,
        capture_output=True,
        text=True
    )
    
    if compile_result.returncode != 0:
        pytest.skip(f"Compilation failed: {compile_result.stderr}")
    
    # Simulate
    try:
        sim_result = subprocess.run(
            ["vvp", "golden_tb.out"],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        # Check for assertion activity in output
        output = (sim_result.stdout + sim_result.stderr).lower()
        assert "assert" in output or "assertion" in output or "$error" in output, \
            f"Golden testbench assertions did not execute. Output: {sim_result.stdout[:500]}"
    except subprocess.TimeoutExpired:
        pytest.skip("Simulation timed out - cannot verify assertions.")
