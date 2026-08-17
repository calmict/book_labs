#!/usr/bin/env python3
import os
import sys
import threading
from pathlib import Path


def make_payload(version: int) -> bytes:
    marker = bytes([65 + version % 26])
    return f"version:{version:04d}\n".encode() + marker * 8192 + b"\n"


def validate_payload(data: bytes) -> bool:
    first_line, separator, body = data.partition(b"\n")
    if not separator or not first_line.startswith(b"version:"):
        return False
    try:
        version = int(first_line.removeprefix(b"version:"))
    except ValueError:
        return False
    return body == bytes([65 + version % 26]) * 8192 + b"\n"


def write_all(fd: int, data: bytes) -> None:
    view = memoryview(data)
    while view:
        written = os.write(fd, view)
        if written == 0:
            raise OSError("write returned zero bytes")
        view = view[written:]


def publish(directory: Path, version: int) -> None:
    temporary = directory / "current.tmp"
    final = directory / "current.dat"
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        write_all(fd, make_payload(version))
        os.fsync(fd)
    finally:
        os.close(fd)
    os.replace(temporary, final)
    directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} DIRECTORY", file=sys.stderr)
        return 2
    directory = Path(sys.argv[1]).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    publish(directory, 0)
    stop = threading.Event()
    failures: list[str] = []
    reads = [0]

    def reader() -> None:
        while not stop.is_set():
            try:
                data = (directory / "current.dat").read_bytes()
            except FileNotFoundError:
                failures.append("missing file")
                stop.set()
                return
            if not validate_payload(data):
                failures.append("partial or mixed content")
                stop.set()
                return
            reads[0] += 1

    reader_thread = threading.Thread(target=reader)
    reader_thread.start()
    try:
        for version in range(1, 201):
            publish(directory, version)
            if failures:
                break
    finally:
        stop.set()
        reader_thread.join()
    if failures:
        print(f"reader failure: {failures[0]}", file=sys.stderr)
        return 1
    final_data = (directory / "current.dat").read_bytes()
    if final_data != make_payload(200):
        print("unexpected final version", file=sys.stderr)
        return 1
    print(f"atomic replacements: 200; validated concurrent reads: {reads[0]}")
    print("final durable version: 0200")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

