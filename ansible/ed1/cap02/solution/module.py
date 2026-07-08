#!/usr/bin/env python3
# Chapter 2 — a tiny Ansible-style module: gather facts, print one line of JSON.
# Runs with the managed node's own python3 (agentless: Python lives on the target).

import json
import platform


def gather():
    facts = {}
    facts["hostname"] = platform.node()
    facts["system"] = platform.system()
    facts["release"] = platform.release()
    facts["machine"] = platform.machine()
    facts["python"] = platform.python_version()
    return facts


print(json.dumps({"changed": False, "ansible_facts": gather()}))
