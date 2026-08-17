#!/usr/bin/env python3
import socket
import sys
import time


def receive(port: int) -> int:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8192)
    sock.bind(("127.0.0.1", port))
    print(f"READY port={port} receive_buffer={sock.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)}", flush=True)
    time.sleep(1.5)
    sock.settimeout(0.2)
    received = 0
    while True:
        try:
            sock.recvfrom(2048)
            received += 1
        except TimeoutError:
            break
    print(f"RECEIVED={received}", flush=True)
    return 0


def send(port: int, count: int) -> int:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    payload = b"x" * 1024
    for _ in range(count):
        sock.sendto(payload, ("127.0.0.1", port))
    print(f"SENT={count}")
    return 0


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] not in {"receive", "send"}:
        print("usage: socket_pressure.py receive PORT | send PORT COUNT", file=sys.stderr)
        return 2
    port = int(sys.argv[2])
    if sys.argv[1] == "receive":
        return receive(port)
    if len(sys.argv) != 4:
        print("send mode requires COUNT", file=sys.stderr)
        return 2
    return send(port, int(sys.argv[3]))


if __name__ == "__main__":
    raise SystemExit(main())
