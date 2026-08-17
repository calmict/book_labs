#!/usr/bin/env python3
import socket
import sys


def main() -> int:
    if len(sys.argv) != 3:
        return 2
    port = int(sys.argv[1])
    ready_file = sys.argv[2]
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("10.29.2.2", port))
    listener.listen(1)
    with open(ready_file, "w", encoding="utf-8") as stream:
        stream.write("ready\n")
    connection, peer = listener.accept()
    with connection:
        local = connection.getsockname()
        connection.recv(4096)
        body = b"labcap29 service\n"
        response = b"HTTP/1.0 200 OK\r\nContent-Length: " + str(len(body)).encode() + b"\r\n\r\n" + body
        connection.sendall(response)
    print(f"PEER={peer[0]}:{peer[1]}")
    print(f"LOCAL={local[0]}:{local[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
