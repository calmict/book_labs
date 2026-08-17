#!/usr/bin/env python3
import socket
import sys


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[1] not in {"allow", "block"}:
        return 2
    expectation, host, port_text = sys.argv[1:]
    port = int(port_text)
    try:
        with socket.create_connection((host, port), timeout=0.8) as connection:
            connection.sendall(b"GET / HTTP/1.0\r\nHost: labcap29\r\n\r\n")
            response = connection.recv(4096)
    except OSError as error:
        if expectation == "block":
            print(f"BLOCKED target={host}:{port} error={type(error).__name__}")
            return 0
        print(f"UNEXPECTED_FAILURE target={host}:{port} error={error}", file=sys.stderr)
        return 1
    if expectation == "block":
        print(f"UNEXPECTED_SUCCESS target={host}:{port}", file=sys.stderr)
        return 1
    if b"200 OK" not in response:
        print("UNEXPECTED_RESPONSE", file=sys.stderr)
        return 1
    print(f"ALLOWED target={host}:{port} response=200")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
