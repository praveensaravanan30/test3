# HUD Format Conversion Summary

This document summarizes the conversion of the AXI4 testbench generation problem to HUD format.

## What Was Done

### 1. Directory Structure Created
- ✅ `sources/` - Contains RTL source files (baseline and golden)
- ✅ `tests/` - Contains test files with pytest wrappers
- ✅ `tests/checkers/` - Contains testbench assertion checker
- ✅ `pyproject.toml` - Python dependencies
- ✅ `README.md` - Problem documentation

### 2. Files Created

#### Baseline RTL (incomplete - for agent to complete)
- `sources/axi4_interrupt.sv` - Interrupt controller (baseline)
- `sources/axi4_master.sv` - AXI4 master (baseline)
- `sources/axi4_slave.sv` - AXI4 slave (baseline - incomplete)
- `sources/axi4_top.sv` - Top module (baseline - incomplete)

#### Test Files
- `tests/test_axi4_slave_tb_hidden.py` - Main hidden test file with pytest wrapper
- `tests/checkers/testbench_assertion_checker.py` - Testbench checker (updated with missing methods)

#### Configuration
- `pyproject.toml` - Python project configuration
- `README.md` - Problem description
- `setup_hud_branches.sh` - Script to create git branches

### 3. Key Changes from Original Structure

1. **Directory Names:**
   - `rtl/` → `sources/` (HUD requirement)
   - `harness/test/` → `tests/` (HUD requirement)
   - `verif/` remains (where agent writes testbench)

2. **Test File Updates:**
   - Updated paths: `rtl/` → `sources/`
   - Added pytest wrapper function `test_axi4_slave_tb_hidden_runner()`
   - Fixed checker to include `check_assertions_in_code()` method
   - Updated `grade_generated_testbench()` to return tuple format

3. **Golden RTL:**
   - Complete implementation stored in script (will be in golden branch)
   - Baseline has incomplete/broken implementation

## Next Steps

### 1. Run the Setup Script

In WSL Ubuntu, run:

```bash
cd /home/praveen/phinity.ai/axi4_env
chmod +x setup_hud_branches.sh
./setup_hud_branches.sh
```

This script will:
- Initialize git repository (if needed)
- Create three branches:
  - `axi4_testbench_baseline` - Incomplete RTL, NO tests directory
  - `axi4_testbench_test` - Incomplete RTL + hidden tests
  - `axi4_testbench_golden` - Complete RTL, NO tests directory
- Push all branches to GitHub

### 2. Verify Branches on GitHub

After running the script, verify:
- https://github.com/praveensaravanan30/test3/branches

You should see:
- `axi4_testbench_baseline`
- `axi4_testbench_test`
- `axi4_testbench_golden`

### 3. Test Locally (Optional)

Before registering in HUD framework, you can test locally:

```bash
# Install dependencies
pip install -e .

# Run tests (will fail without testbench, that's expected)
pytest tests/test_axi4_slave_tb_hidden.py -v
```

### 4. Register in HUD Framework

Follow `CONTRACTOR_GUIDE.md` Part 3 to:
1. Copy this repo to `local-repos/problems/` in the HUD framework
2. Add problem to `src/hud_controller/problems/basic.py`
3. Update Dockerfile
4. Build and validate

## Branch Structure

```
axi4_testbench_baseline/
├── sources/
│   ├── axi4_interrupt.sv (baseline)
│   ├── axi4_master.sv (baseline)
│   ├── axi4_slave.sv (incomplete - TODO comments)
│   └── axi4_top.sv (incomplete - TODO comments)
├── pyproject.toml
└── README.md
(NO tests directory!)

axi4_testbench_test/
├── sources/ (same as baseline - incomplete)
├── tests/
│   ├── test_axi4_slave_tb_hidden.py (hidden tests)
│   └── checkers/
│       └── testbench_assertion_checker.py
├── pyproject.toml
└── README.md

axi4_testbench_golden/
├── sources/
│   ├── axi4_interrupt.sv (complete)
│   ├── axi4_master.sv (complete)
│   ├── axi4_slave.sv (complete - full implementation)
│   └── axi4_top.sv (complete - full implementation)
├── pyproject.toml
└── README.md
(NO tests directory!)
```

## Important Notes

1. **No Tests in Baseline/Golden:** This is critical! The baseline and golden branches must NOT have a `tests/` directory to prevent agent contamination.

2. **Testbench Location:** The agent writes the testbench to `verif/axi4_slave_tb.sv`. This directory should exist but be empty in all branches.

3. **Pytest Wrapper:** The test file includes `test_axi4_slave_tb_hidden_runner()` which is required for HUD framework to discover tests.

4. **Problem ID:** The problem ID is `axi4_testbench`. This should match the branch prefix.

## Troubleshooting

If the script fails:
1. Check git is initialized: `git status`
2. Check remote is set: `git remote -v`
3. You may need to authenticate with GitHub (use personal access token)
4. If branches already exist, delete them first: `git branch -D <branch_name>`

## Files Modified/Created

- ✅ Created: `sources/` directory with baseline RTL
- ✅ Created: `tests/` directory with test files
- ✅ Created: `tests/checkers/testbench_assertion_checker.py` (updated)
- ✅ Created: `tests/test_axi4_slave_tb_hidden.py` (with pytest wrapper)
- ✅ Created: `pyproject.toml`
- ✅ Created: `README.md`
- ✅ Created: `setup_hud_branches.sh`
- ✅ Created: `HUD_CONVERSION_SUMMARY.md` (this file)

All original files in `rtl/`, `harness/`, etc. remain unchanged.

