"""
Test runner for grading generated testbenches with assertions.

This test runner:
1. Checks if testbench has assertions
2. Compiles the testbench
3. Runs simulation
4. Verifies assertions were executed
5. Grades the testbench
"""

import os
import pytest
from pathlib import Path
from checkers.testbench_assertion_checker import grade_generated_testbench, AssertionChecker

# Fetch environment variables
testbench_path = os.getenv("TESTBENCH_PATH", "verif/axi4_slave_tb.sv")
dut_path = os.getenv("DUT_PATH", "rtl/axi4_slave.sv")
simulator = os.getenv("SIM", "icarus")
require_assertions = os.getenv("REQUIRE_ASSERTIONS", "true").lower() == "true"

# Helper to check if testbench exists
def testbench_exists():
    """Check if testbench file exists (with path resolution)."""
    checker = AssertionChecker(testbench_path, dut_path)
    return os.path.exists(checker.testbench_path)


@pytest.mark.parametrize("test", range(1))
def test_testbench_has_assertions(test):
    """
    Test that checks if generated testbench has assertions.
    """
    if not testbench_exists():
        pytest.skip(f"Testbench file not found: {testbench_path}")
    
    checker = AssertionChecker(testbench_path, dut_path)
    checker.simulator = simulator
    
    # Check assertions in code
    code_check = checker.check_assertions_in_code()
    
    print(f"\n=== Assertion Code Check ===")
    print(f"Testbench: {checker.testbench_path}")
    print(f"Has Assertions: {code_check['has_assertions']}")
    print(f"Assertion Count: {code_check['assertion_count']}")
    print(f"Assertion Types: {code_check['assertion_types']}")
    print(f"Locations: {code_check['assertion_locations']}")
    
    # Check if file was found
    if not code_check['valid']:
        pytest.skip(f"Could not read testbench file: {checker.testbench_path}")
    
    if require_assertions:
        assert code_check['has_assertions'], \
            f"No assertions found in testbench. Found {code_check['assertion_count']} assertions."


@pytest.mark.parametrize("test", range(1))
def test_testbench_compiles(test):
    """
    Test that generated testbench compiles successfully.
    """
    if not testbench_exists():
        pytest.skip(f"Testbench file not found: {testbench_path}")
    
    checker = AssertionChecker(testbench_path, dut_path)
    checker.simulator = simulator
    
    print(f"\n=== Compilation Check ===")
    print(f"Testbench: {checker.testbench_path}")
    if checker.dut_path:
        print(f"DUT: {checker.dut_path}")
    
    compile_success, compile_error = checker.compile_testbench()
    
    if compile_success:
        print("Compilation: PASS")
    else:
        print(f"Compilation: FAIL")
        print(f"Error: {compile_error}")
    
    assert compile_success, f"Testbench compilation failed: {compile_error}"


@pytest.mark.parametrize("test", range(1))
def test_testbench_simulates(test):
    """
    Test that generated testbench simulates successfully.
    """
    if not testbench_exists():
        pytest.skip(f"Testbench file not found: {testbench_path}")
    
    checker = AssertionChecker(testbench_path, dut_path)
    checker.simulator = simulator
    
    # First compile
    compile_success, compile_error = checker.compile_testbench()
    if not compile_success:
        pytest.skip(f"Testbench must compile first: {compile_error}")
    
    # Then simulate
    sim_success, sim_log = checker.run_simulation()
    
    print(f"\n=== Simulation Check ===")
    if sim_success:
        print("Simulation: PASS")
        print(f"Log length: {len(sim_log)} characters")
    else:
        print(f"Simulation: FAIL")
        print(f"Error: {sim_log[:500]}")
    
    assert sim_success, f"Testbench simulation failed: {sim_log[:200]}"


@pytest.mark.parametrize("test", range(1))
def test_assertions_execute(test):
    """
    Test that assertions in testbench are executed during simulation.
    """
    if not testbench_exists():
        pytest.skip(f"Testbench file not found: {testbench_path}")
    
    checker = AssertionChecker(testbench_path, dut_path)
    checker.simulator = simulator
    
    # Compile and simulate
    compile_success, compile_error = checker.compile_testbench()
    if not compile_success:
        pytest.skip(f"Testbench must compile first: {compile_error}")
    
    sim_success, sim_log = checker.run_simulation()
    if not sim_success:
        pytest.skip(f"Testbench must simulate first: {sim_log[:200]}")
    
    # Check assertions in log
    log_check = checker.check_assertions_in_log("sim.log")
    
    print(f"\n=== Assertion Execution Check ===")
    print(f"Assertions Executed: {log_check['assertions_executed']}")
    print(f"Assertion Passes: {log_check['assertion_passes']}")
    print(f"Assertion Failures: {log_check['assertion_failures']}")
    
    if require_assertions:
        assert log_check['assertions_executed'], \
            "Assertions were not executed during simulation"
        
        # Assertions should have been evaluated (passes or failures)
        total_assertions = log_check['assertion_passes'] + log_check['assertion_failures']
        assert total_assertions > 0, \
            "No assertion activity detected in simulation log"


@pytest.mark.parametrize("test", range(1))
def test_testbench_assertion_grade(test):
    """
    Comprehensive test that grades the entire testbench.
    """
    passed, grade, report = grade_generated_testbench(
        testbench_path=testbench_path,
        dut_path=dut_path,
        require_assertions=require_assertions,
        simulator=simulator
    )
    
    # Print full report
    print("\n" + report)
    
    # Assertions based on grading
    if require_assertions:
        assert grade['has_assertions'], \
            "Testbench must contain assertions"
        
        assert grade['assertions_work'], \
            "Assertions must execute during simulation"
    
    assert grade['compiles'], \
        "Testbench must compile successfully"
    
    assert grade['simulates'], \
        "Testbench must simulate successfully"
    
    # Score should be reasonable
    assert grade['score'] >= 70.0, \
        f"Testbench score {grade['score']:.1f} below 70.0"
    
    # Final pass/fail
    assert passed, \
        "Testbench did not pass all quality checks"


def test_quick_assertion_check():
    """
    Quick test to just check if assertions exist (no compilation).
    Useful for fast feedback.
    """
    if not testbench_exists():
        pytest.skip(f"Testbench file not found: {testbench_path}")
    
    checker = AssertionChecker(testbench_path, dut_path)
    code_check = checker.check_assertions_in_code()
    
    print(f"\nQuick Check: {code_check['assertion_count']} assertions found")
    print(f"Testbench: {checker.testbench_path}")
    
    if not code_check['valid']:
        pytest.skip(f"Could not read testbench file: {checker.testbench_path}")
    
    if require_assertions:
        assert code_check['has_assertions'], "No assertions found in testbench"

