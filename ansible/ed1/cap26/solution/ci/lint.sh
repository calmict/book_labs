#!/usr/bin/env bash
# Quality gate 1: style and best practice (chapter 23). Non-zero exit stops the
# pipeline. The pre-commit hook and the CI job both call this same script.
set -euo pipefail
exec ansible-lint site.yml
