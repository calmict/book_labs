#!/usr/bin/env bash
# Quality gate 2: the playbook is well formed (syntax-check) and its dry run holds
# up (check mode) - chapter 23. Non-zero exit stops the pipeline.
set -euo pipefail
ansible-playbook --syntax-check site.yml
ansible-playbook --check site.yml
