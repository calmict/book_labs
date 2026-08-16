#!/usr/bin/env python3

import os
import pathlib
import sys
import time

if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} WORK_DIRECTORY")

work_dir = pathlib.Path(sys.argv[1])
stage_file = work_dir / "labcap16-stage"
target_file = work_dir / "labcap16-open-target.txt"


def pause(stage):
    stage_file.write_text(stage + "\n", encoding="ascii")
    acknowledgement = work_dir / f"labcap16-continue-{stage}"
    deadline = time.monotonic() + 10
    while not acknowledgement.exists():
        if time.monotonic() >= deadline:
            raise TimeoutError(f"no acknowledgement for stage {stage}")
        time.sleep(0.05)


pause("before-open")
descriptor = os.open(target_file, os.O_CREAT | os.O_RDWR, 0o600)
os.write(descriptor, b"descriptor is open\n")
pause("after-open")
os.close(descriptor)
pause("after-close")
