#!/usr/bin/env python3
"""Runs the whole executable-requirements suite (gates + all four kinds).

Usage, from dev/requirements/:  python3 run_requirements.py
Equivalent to `flutter test` here, with the sandbox-robust runner.
"""

import os
import sys

import flutter_test_runner

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    sys.exit(flutter_test_runner.run([], done_marker="All tests passed!"))
