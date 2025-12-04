"""
Test runner for DV tasks with coverage analysis using SystemVerilog and Icarus Verilog.

This test runner:
1. Compiles SystemVerilog testbench with Icarus Verilog
2. Runs simulation with vvp
3. Analyzes coverage from logs
4. Checks testbench quality
5. Grades the testbench
"""

import os
import pytest
import subprocess
from pathlib import Path
from checkers.dv_coverage_analyzer import grade_testbench, DVCoverageAnalyzer

# Fetch environment variables
testbench_path = os.getenv("TESTBENCH_PATH", "verif/axi4_slave_tb.sv")
dut_path = os.getenv("DUT_PATH", "rtl/axi4_slave.sv")
sim = os.getenv("SIM", "icarus")  # Use Icarus for open-source
dut_type = os.getenv("DUT_TYPE", "generic")  # e.g., "axi4", "memory", "fifo"

# Coverage thresholds
coverage_threshold = int(os.getenv("COVERAGE_THRESHOLD", "80"))
quality_threshold = float(os.getenv("QUALITY_THRESHOLD", "70.0"))


def run_systemverilog_simulation(testbench_file: str, dut_file: str, output_dir: str = "sim_build") -> tuple[bool, str]:
    """
    Run SystemVerilog simulation using Icarus Verilog.
    
    Returns:
        (success, log_content)
    """
    try:
        os.makedirs(output_dir, exist_ok=True)
        
        # Compile
        compile_cmd = ["iverilog", "-g2012", "-o", f"{output_dir}/testbench.out", dut_file, testbench_file]
        compile_result = subprocess.run(
            compile_cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if compile_result.returncode != 0:
            return False, f"Compilation failed: {compile_result.stderr}"
        
        # Simulate
        sim_cmd = ["vvp", f"{output_dir}/testbench.out"]
        sim_result = subprocess.run(
            sim_cmd,
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes max
        )
        
        # Save log
        log_file = "sim.log"
        with open(log_file, 'w') as f:
            f.write(sim_result.stdout)
            f.write(sim_result.stderr)
        
        # Check for fatal errors
        if "Fatal" in sim_result.stderr or "Error" in sim_result.stderr:
            return False, sim_result.stderr
        
        return True, sim_result.stdout + sim_result.stderr
        
    except subprocess.TimeoutExpired:
        return False, "Simulation timed out"
    except Exception as e:
        return False, str(e)


@pytest.mark.parametrize("test", range(1))
def test_dv_with_coverage(test):
    """
    Test DV task with comprehensive coverage and quality analysis.
    """
    log_file = "sim.log"
    
    try:
        # Step 1: Run SystemVerilog simulation
        sim_success, sim_output = run_systemverilog_simulation(testbench_path, dut_path)
        
        if not sim_success:
            raise SystemError(f"Simulation failed: {sim_output}")
        
        # Step 2: Analyze coverage and quality
        passed, quality, report = grade_testbench(
            log_file=log_file,
            coverage_threshold=coverage_threshold,
            quality_threshold=quality_threshold,
            dut_type=dut_type
        )
        
        # Step 3: Print report
        print("\n" + report)
        
        # Step 4: Assertions
        # Check coverage
        coverage_pct = quality['coverage'].get('percentage', 0)
        assert coverage_pct >= coverage_threshold, \
            f"Coverage {coverage_pct}% below threshold {coverage_threshold}%"
        
        # Check overall quality
        overall_score = quality['overall_score']
        assert overall_score >= quality_threshold, \
            f"Overall quality score {overall_score:.1f}% below threshold {quality_threshold}%"
        
        # Check checker functionality
        assert quality['checker'].get('functional', False), \
            "Testbench checker is not functional"
        
        # Final pass/fail
        assert passed, \
            f"Testbench quality check failed. See report above."
        
    except SystemExit:
        raise SystemError("Simulation failed")
    except FileNotFoundError as e:
        raise SystemError(f"Required file not found: {e}")
    except Exception as e:
        raise SystemError(f"Test failed with error: {e}")


def test_coverage_only():
    """
    Test that only checks coverage (for debugging).
    """
    log_file = "sim.log"
    
    analyzer = DVCoverageAnalyzer(coverage_threshold, quality_threshold)
    coverage = analyzer.parse_coverage_log(log_file)
    
    print(f"\nCoverage Analysis:")
    print(f"  Percentage: {coverage.get('percentage', 0)}%")
    print(f"  Valid: {coverage.get('valid', False)}")
    print(f"  Raw Metrics: {coverage.get('raw_metrics', {})}")
    
    assert coverage.get('valid', False), "Coverage data not found in log"
    assert coverage.get('percentage', 0) >= coverage_threshold, \
        f"Coverage {coverage.get('percentage', 0)}% below threshold"


def test_stimulus_diversity_only():
    """
    Test that only checks stimulus diversity (for debugging).
    """
    log_file = "sim.log"
    
    analyzer = DVCoverageAnalyzer(coverage_threshold, quality_threshold)
    diversity = analyzer.check_stimulus_diversity(log_file, dut_type)
    
    print(f"\nStimulus Diversity Analysis:")
    print(f"  Score: {diversity.get('score', 0)}%")
    print(f"  Unique Addresses: {diversity.get('unique_addresses', 0)}")
    print(f"  Unique Data Patterns: {diversity.get('unique_data_patterns', 0)}")
    
    assert diversity.get('valid', False), "Diversity data not found in log"

