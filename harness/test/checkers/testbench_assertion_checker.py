"""
Testbench Assertion Checker for DV Task Grading.

This module:
1. Detects assertions in SystemVerilog testbenches
2. Compiles and simulates testbenches
3. Analyzes simulation logs for assertion execution
4. Grades testbenches based on assertion coverage
"""

import os
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class AssertionChecker:
    """Checks for assertions in testbenches and analyzes their execution."""
    
    def __init__(self, testbench_path: str, dut_path: Optional[str] = None):
        """
        Initialize the assertion checker.
        
        Args:
            testbench_path: Path to the testbench file
            dut_path: Optional path to DUT file (if testbench doesn't include it)
        """
        self.testbench_path = self._resolve_path(testbench_path)
        self.dut_path = self._resolve_path(dut_path) if dut_path else None
        self.sim_log_path = "sim.log"
        self.output_dir = "sim_build"
        
    def _resolve_path(self, file_path: str) -> str:
        """Resolve file path by searching common directories."""
        if not file_path:
            return file_path
            
        # If absolute path exists, use it
        if os.path.isabs(file_path) and os.path.exists(file_path):
            return file_path
            
        # Check current directory
        if os.path.exists(file_path):
            return file_path
            
        # Check common directories
        search_dirs = [
            ".",
            "..",
            "verif",
            "rtl",
            "harness/test",
            "harness/patch/test",
        ]
        
        for search_dir in search_dirs:
            candidate = os.path.join(search_dir, file_path)
            if os.path.exists(candidate):
                return candidate
                
            # Also try just the filename
            candidate = os.path.join(search_dir, os.path.basename(file_path))
            if os.path.exists(candidate):
                return candidate
        
        # Return original if not found (will fail later)
        return file_path
    
    def find_assertions(self) -> Dict[str, List[str]]:
        """
        Find all assertions in the testbench.
        
        Returns:
            Dictionary with 'immediate' and 'concurrent' assertion lists
        """
        if not os.path.exists(self.testbench_path):
            return {"immediate": [], "concurrent": []}
        
        with open(self.testbench_path, 'r') as f:
            content = f.read()
        
        # Pattern for immediate assertions: assert (condition) [else action];
        immediate_pattern = r'assert\s*\([^)]+\)\s*(?:else\s+[^;]+)?;'
        immediate_assertions = re.findall(immediate_pattern, content, re.MULTILINE)
        
        # Pattern for concurrent assertions: assert property(...) or assert sequence(...)
        concurrent_pattern = r'assert\s+(?:property|sequence)\s*\([^)]+\)'
        concurrent_assertions = re.findall(concurrent_pattern, content, re.MULTILINE)
        
        return {
            "immediate": immediate_assertions,
            "concurrent": concurrent_assertions,
        }
    
    def compile_testbench(self) -> Tuple[bool, str]:
        """
        Compile the testbench with Icarus Verilog.
        
        Returns:
            (success, error_message)
        """
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Build command
        cmd = ["iverilog", "-g2012", "-o", f"{self.output_dir}/tb.out"]
        
        # Add DUT if specified
        if self.dut_path and os.path.exists(self.dut_path):
            cmd.append(self.dut_path)
        
        # Add testbench
        cmd.append(self.testbench_path)
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode != 0:
                return False, result.stderr
            return True, ""
        except subprocess.TimeoutExpired:
            return False, "Compilation timed out"
        except Exception as e:
            return False, str(e)
    
    def run_simulation(self, timeout: int = 60) -> Tuple[bool, str]:
        """
        Run the simulation with vvp.
        
        Args:
            timeout: Maximum simulation time in seconds
            
        Returns:
            (success, error_message)
        """
        vvp_path = f"{self.output_dir}/tb.out"
        if not os.path.exists(vvp_path):
            return False, "Compiled testbench not found. Compile first."
        
        try:
            # Run simulation and capture output
            with open(self.sim_log_path, 'w') as log_file:
                result = subprocess.run(
                    ["vvp", vvp_path],
                    stdout=log_file,
                    stderr=subprocess.STDOUT,
                    text=True,
                    timeout=timeout
                )
            
            # Check if simulation completed (look for $finish or timeout)
            with open(self.sim_log_path, 'r') as f:
                log_content = f.read()
                if "$finish" in log_content or "VCD info" in log_content:
                    return True, ""
                elif result.returncode != 0:
                    return False, f"Simulation failed with code {result.returncode}"
                else:
                    # Simulation may have completed without explicit $finish
                    return True, ""
        except subprocess.TimeoutExpired:
            return False, f"Simulation timed out after {timeout} seconds"
        except Exception as e:
            return False, str(e)
    
    def check_assertions_in_log(self, log_path: Optional[str] = None) -> Dict[str, int]:
        """
        Analyze simulation log for assertion execution.
        
        Args:
            log_path: Path to simulation log (default: self.sim_log_path)
            
        Returns:
            Dictionary with assertion statistics
        """
        log_file = log_path or self.sim_log_path
        
        if not os.path.exists(log_file):
            return {
                "assertions_executed": 0,
                "assertion_passes": 0,
                "assertion_failures": 0,
            }
        
        with open(log_file, 'r') as f:
            content = f.read()
        
        # Count assertion failures
        failure_patterns = [
            r'ASSERTION FAILED',
            r'Assertion failed',
            r'assert.*failed',
        ]
        failures = 0
        for pattern in failure_patterns:
            failures += len(re.findall(pattern, content, re.IGNORECASE))
        
        # Count assertion passes (if logged)
        pass_patterns = [
            r'ASSERTION PASSED',
            r'Assertion passed',
        ]
        passes = 0
        for pattern in pass_patterns:
            passes += len(re.findall(pattern, content, re.IGNORECASE))
        
        # If no explicit passes, assume assertions executed if we see any assertion activity
        executed = failures + passes
        if executed == 0:
            # Check for assertion-related output
            if re.search(r'assert', content, re.IGNORECASE):
                executed = 1  # At least one assertion was present
        
        return {
            "assertions_executed": executed,
            "assertion_passes": passes,
            "assertion_failures": failures,
        }
    
    def grade(self) -> Dict[str, any]:
        """
        Complete grading workflow: find assertions, compile, simulate, analyze.
        
        Returns:
            Dictionary with grading results
        """
        results = {
            "assertions_found": 0,
            "compilation_success": False,
            "simulation_success": False,
            "assertions_executed": 0,
            "assertion_passes": 0,
            "assertion_failures": 0,
            "score": 0.0,
            "errors": [],
        }
        
        # Step 1: Find assertions
        assertions = self.find_assertions()
        total_assertions = len(assertions["immediate"]) + len(assertions["concurrent"])
        results["assertions_found"] = total_assertions
        
        if total_assertions == 0:
            results["errors"].append("No assertions found in testbench")
            return results
        
        # Step 2: Compile
        compile_success, compile_error = self.compile_testbench()
        results["compilation_success"] = compile_success
        if not compile_success:
            results["errors"].append(f"Compilation failed: {compile_error}")
            return results
        
        # Step 3: Simulate
        sim_success, sim_error = self.run_simulation()
        results["simulation_success"] = sim_success
        if not sim_success:
            results["errors"].append(f"Simulation failed: {sim_error}")
            return results
        
        # Step 4: Analyze log
        log_stats = self.check_assertions_in_log()
        results["assertions_executed"] = log_stats["assertions_executed"]
        results["assertion_passes"] = log_stats["assertion_passes"]
        results["assertion_failures"] = log_stats["assertion_failures"]
        
        # Step 5: Calculate score
        # Score based on: assertions found (30%), compilation (20%), simulation (20%), execution (30%)
        score = 0.0
        if total_assertions > 0:
            score += 30.0  # Has assertions
        if compile_success:
            score += 20.0
        if sim_success:
            score += 20.0
        if log_stats["assertions_executed"] > 0:
            score += 30.0
        
        results["score"] = score
        
        return results


def grade_generated_testbench(
    testbench_path: str,
    dut_path: Optional[str] = None,
    require_assertions: bool = True
) -> Dict[str, any]:
    """
    Grade a generated testbench.
    
    Args:
        testbench_path: Path to testbench
        dut_path: Optional path to DUT
        require_assertions: Whether assertions are required
        
    Returns:
        Grading results dictionary
    """
    checker = AssertionChecker(testbench_path, dut_path)
    results = checker.grade()
    
    # Add requirement check
    if require_assertions and results["assertions_found"] == 0:
        results["errors"].append("Assertions are required but none were found")
        results["score"] = 0.0
    
    return results

