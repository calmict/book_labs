#!/usr/bin/env bash
# Chapter 9 start - call the API server with curl and cross its request gates.
# Valid but incomplete; run from this directory against the chapter 7 cluster.
set -euo pipefail

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# TODO 1 (9.1): call /api and /apis through kubectl proxy with curl. This makes
# the core and named API groups visible without kubectl interpreting them.
:

# TODO 2 (9.2-9.3): collect the invalid-token, authenticated, impersonated, and
# over-quota responses. Their status and messages identify the rejecting gate.
:

# TODO 3 (9.4): open a namespace watch, create and delete watch-lab, and save
# the ADDED and DELETED events. The stream demonstrates push instead of polling.
:
