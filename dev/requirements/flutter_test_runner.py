"""Shared `flutter test` runner for the executable-requirements suite.

Adapted from HelloWorldFlutterApp's runner: streams output, exits the moment
the done-marker prints (skipping the long teardown stall some sandboxes hit
after the VM's sockets drop), and a watchdog turns a silent hang into a fast,
explicit failure. On a normal machine/CI, plain `flutter test` works too —
this wrapper just makes the loop robust everywhere.
"""

from __future__ import annotations

import os
import shutil
import signal
import subprocess
import sys
import threading

DEFAULT_STALL_SECONDS = 120


def find_flutter() -> str:
    flutter = shutil.which("flutter")
    if not flutter:
        sys.exit(
            "flutter not found on PATH. Install the Flutter SDK (stable) and "
            "re-run — see the repository README."
        )
    return flutter


def run(args: list[str], *, done_marker: str, fail_marker: str = "Some tests failed",
        stall_seconds: int = DEFAULT_STALL_SECONDS, cwd: str | None = None) -> int:
    """Runs `flutter test <args>`; returns 0 on done_marker, 1 on failure."""
    cmd = [find_flutter(), "test", *args]
    print("$", " ".join(cmd), flush=True)
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,  # own process group => killpg reaps helpers
    )

    outcome: dict[str, int | None] = {"rc": None}

    def kill(sig: int) -> None:
        try:
            os.killpg(os.getpgid(proc.pid), sig)
        except (ProcessLookupError, PermissionError):
            pass

    def watchdog() -> None:
        if outcome["rc"] is None:
            print(f"[runner] no output for {stall_seconds}s — killing", flush=True)
            outcome["rc"] = 1
            kill(signal.SIGKILL)

    timer = threading.Timer(stall_seconds, watchdog)
    timer.daemon = True
    timer.start()

    assert proc.stdout is not None
    for line in proc.stdout:
        print(line, end="", flush=True)
        timer.cancel()
        timer = threading.Timer(stall_seconds, watchdog)
        timer.daemon = True
        timer.start()
        if outcome["rc"] is None and done_marker in line:
            outcome["rc"] = 0
            kill(signal.SIGTERM)  # skip the teardown stall — we are done
        elif outcome["rc"] is None and fail_marker in line:
            outcome["rc"] = 1
            kill(signal.SIGTERM)

    proc.wait()
    timer.cancel()
    if outcome["rc"] is None:  # process ended without either marker
        outcome["rc"] = proc.returncode if proc.returncode not in (None, 0) else 0
    return int(outcome["rc"])
