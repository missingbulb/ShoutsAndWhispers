#!/usr/bin/env python3
"""Regenerates every golden (screen stills + saga animations) and the gallery.

Usage, from dev/requirements/:  python3 refresh_goldens.py

Regeneration is for reviewing intended UI changes — a diff in a committed
golden is a product change that the owner approves in review. NEVER
regenerate to make a failing case pass without approval; that transfers
ownership of the product to whoever regenerated (see README.md).
"""

import os
import subprocess
import sys

import flutter_test_runner

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    rc = flutter_test_runner.run(
        [
            "--update-goldens",
            "test/screen_requirements_test.dart",
            "test/saga_requirements_test.dart",
        ],
        done_marker="All tests passed!",
    )
    if rc != 0:
        sys.exit(rc)
    env = dict(os.environ, REQ_UPDATE_GALLERY="1")
    subprocess.run(
        [flutter_test_runner.find_flutter(), "test", "test/gallery_gate_test.dart"],
        check=True,
        env=env,
    )
    print("Goldens and gallery regenerated.")
