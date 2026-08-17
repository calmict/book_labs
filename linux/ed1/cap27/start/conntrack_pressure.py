#!/usr/bin/env python3
import socket
import sys
import time


def server(port: int, ready_file: str) -> int:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("127.0.0.1", port))
    with open(ready_file, "w", encoding="utf-8") as stream:
        stream.write("ready\n")
    sock.settimeout(2.0)
    sources = set()
    while True:
        try:
            _, address = sock.recvfrom(64)
            sources.add(address)
        except socket.timeout:
            break
    print(f"UNIQUE_SOURCES_RECEIVED={len(sources)}", flush=True)
    return 0


def clients(port: int, count: int) -> int:
    sockets = []
    sent = 0
    for source_port in range(30000, 30000 + count):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("127.0.0.1", source_port))
        sock.sendto(b"flow", ("127.0.0.1", port))
        sockets.append(sock)
        sent += 1
    print(f"UNIQUE_FLOWS_SENT={sent}", flush=True)
    time.sleep(2)
    return 0


def main() -> int:
    if len(sys.argv) < 3:
        return 2
    mode = sys.argv[1]
    port = int(sys.argv[2])
    if mode == "server" and len(sys.argv) == 4:
        return server(port, sys.argv[3])
    if mode == "clients" and len(sys.argv) == 4:
        return clients(port, int(sys.argv[3]))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
