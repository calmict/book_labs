#!/usr/bin/env python3
import sys


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/labcap26-missing.conf"
    try:
        with open(path, encoding="utf-8") as stream:
            stream.read()
    except OSError:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
