#!/usr/bin/env python3
import os
import signal


signal.signal(signal.SIGPIPE, signal.SIG_DFL)
payload = b"labcap25\n" * 1024
while True:
    os.write(1, payload)
