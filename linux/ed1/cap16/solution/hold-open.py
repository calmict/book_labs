#!/usr/bin/env python3

import os
import pathlib
import sys
import time

if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} WORK_DIRECTORY")

work_dir = pathlib.Path(sys.argv[1])
target_file = work_dir / "labcap16-held-open.bin"
ready_file = work_dir / "labcap16-held-ready"
close_file = work_dir / "labcap16-close-held"
closed_file = work_dir / "labcap16-held-closed"

descriptor = os.open(target_file, os.O_RDONLY)
ready_file.write_text(f"pid={os.getpid()} fd={descriptor}\n", encoding="ascii")
deadline = time.monotonic() + 10
while not close_file.exists():
    if time.monotonic() >= deadline:
        raise TimeoutError("no close acknowledgement")
    time.sleep(0.05)
os.close(descriptor)
closed_file.write_text("closed\n", encoding="ascii")
time.sleep(0.5)
