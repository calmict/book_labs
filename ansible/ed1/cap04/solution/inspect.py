#!/usr/bin/env python3
# Chapter 4 — show what the YAML parser ACTUALLY produces: each value with its
# Python type. Traps show up as the wrong type (a country that became a bool, a
# version that became a float). This is the same parser (PyYAML) Ansible uses.
#
# Usage: python3 inspect.py <file.yml>

import sys
import yaml


def show(node, indent=1):
    pad = "  " * indent
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(value, (dict, list)):
                print(f"{pad}{key}:")
                show(value, indent + 1)
            else:
                print(f"{pad}{key!r}: {value!r} ({type(value).__name__})")
    elif isinstance(node, list):
        for value in node:
            print(f"{pad}- {value!r} ({type(value).__name__})")


path = sys.argv[1] if len(sys.argv) > 1 else "config.yml"
with open(path) as handle:
    data = yaml.safe_load(handle)

print(f"parsed {path}:")
show(data)
