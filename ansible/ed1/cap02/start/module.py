#!/usr/bin/env python3
# Chapter 2 — a tiny Ansible-style "module": a program that gathers facts about
# the machine it runs ON, and prints ONE line of JSON to stdout. This is exactly
# what the setup module does when Ansible "interviews" a host, only much smaller.
#
# It runs with the REMOTE python (the managed node's python3), never yours — that
# is why agentless needs Python on the target.

import json
import platform


def gather():
    facts = {}
    # TODO: fill the interview. Read a few facts the machine knows about ITSELF,
    # for example:
    #   facts["hostname"] = platform.node()
    #   facts["system"]   = platform.system()
    #   facts["python"]   = platform.python_version()
    # Add at least three. The file already prints valid JSON with empty facts, so
    # you can run it as you go.
    return facts


print(json.dumps({"changed": False, "ansible_facts": gather()}))
