#!/usr/bin/env python3
import errno
import fcntl
import os
import threading
import time

F_GETPIPE_SZ = getattr(fcntl, "F_GETPIPE_SZ", 1032)


def fill_nonblocking_pipe():
    read_fd, write_fd = os.pipe()
    try:
        capacity = fcntl.fcntl(write_fd, F_GETPIPE_SZ)
        flags = fcntl.fcntl(write_fd, fcntl.F_GETFL)
        fcntl.fcntl(write_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        total = 0
        block = b"x" * 4096
        while True:
            try:
                total += os.write(write_fd, block)
            except BlockingIOError as error:
                if error.errno != errno.EAGAIN:
                    raise
                break
        if total != capacity:
            raise RuntimeError(
                f"filled byte count {total} differs from reported capacity {capacity}"
            )
        return capacity, total
    finally:
        os.close(read_fd)
        os.close(write_fd)


def observe_backpressure():
    read_fd, write_fd = os.pipe()
    capacity = fcntl.fcntl(write_fd, F_GETPIPE_SZ)
    filled = threading.Event()
    completed = threading.Event()
    timings = []
    errors = []

    def write_all(payload):
        position = 0
        while position < len(payload):
            position += os.write(write_fd, payload[position:])

    def producer():
        try:
            write_all(b"x" * capacity)
            filled.set()
            started = time.monotonic()
            write_all(b"y")
            timings.append(time.monotonic() - started)
            completed.set()
        except BaseException as error:
            errors.append(error)
            filled.set()
        finally:
            os.close(write_fd)

    producer_thread = threading.Thread(target=producer, name="labcap25-producer")
    producer_thread.start()
    try:
        if not filled.wait(timeout=2):
            raise RuntimeError("producer did not fill the pipe within two seconds")
        if errors:
            raise errors[0]
        time.sleep(0.30)
        was_blocked = producer_thread.is_alive() and not completed.is_set()
        if not was_blocked:
            raise RuntimeError("producer did not block on the full pipe")
        os.read(read_fd, os.sysconf("SC_PAGE_SIZE"))
        producer_thread.join(timeout=2)
        if producer_thread.is_alive():
            raise RuntimeError("producer did not resume within two seconds")
        if errors:
            raise errors[0]
        while os.read(read_fd, 65536):
            pass
        return was_blocked, timings[0]
    finally:
        os.close(read_fd)
        producer_thread.join(timeout=2)


reported_capacity, filled_bytes = fill_nonblocking_pipe()
print(f"F_GETPIPE_SZ={reported_capacity} bytes")
print(f"bytes written before EAGAIN={filled_bytes}")
blocked, blocked_seconds = observe_backpressure()
print(f"producer blocked before consumer read: {str(blocked).lower()}")
print(f"producer wait={blocked_seconds:.3f} seconds")
print("producer resumed after consumer freed one page: true")
