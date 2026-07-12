# Ansible — exercises

Practical labs for the Calm ICT **Ansible** manual — the conductor of the
infrastructure orchestra.

> Status: in progress — chapters are being added.

## Recommended setup

These exercises run locally and for free — no paid cloud account is needed to
complete any of them. Your machine is the **control node**; the **managed
nodes** are ephemeral local containers, brought up and torn down on demand. See
[SETUP.md](SETUP.md) for a reproducible (non-binding) environment: Ansible, a
local Docker engine, and Molecule to provide the throwaway hosts.

## Control node and managed nodes

Ansible is agentless: it runs from one **control node** (your machine — Python
plus ansible-core) and configures **managed nodes** over SSH, with nothing
installed on them but Python. To stay free and reproducible, the managed nodes
here are throwaway Docker containers driven by **Molecule** — one command up,
one command down, teardown guaranteed. Molecule doubles as the testing tool the
manual reaches in chapter 24.

Cloud-specific topics from the manual (dynamic inventories on AWS, cloud secret
managers) are shown as configuration you can read and reason about; the hands-on
parts are reproduced locally, so nothing costs money.

## Editions

- **ed1/** — exercises cited by the 1st edition of the manual.

## Chapter index (ed1)

| Chapter | Title | Level | Folder |
|--------:|-------|:-----:|--------|
| 1 | The three cracks (3/30/3000 servers, drift, repeatable vs convergent, push vs pull) | Foundational | [ed1/cap01](ed1/cap01/) |
| 2 | The messenger, not the tenant (agentless, control/managed nodes, a task's journey, facts) | Foundational | [ed1/cap02](ed1/cap02/) |
| 3 | The key that stays home (asymmetric keys, config aliases, ControlMaster, bastion/ProxyJump) | Foundational | [ed1/cap03](ed1/cap03/) |
| 4 | The score that lies (YAML anatomy: implicit typing, the Norway Problem, quoting, anchors, linting) | Foundational | [ed1/cap04](ed1/cap04/) |
| 5 | The switch and the doorbell (idempotence, the colours of change, changed_when, check mode) | Foundational | [ed1/cap05](ed1/cap05/) |
| 6 | The baton (installing ansible-core in a venv, the command family, preparing the target nodes) | Foundational | [ed1/cap06](ed1/cap06/) |
| 7 | The nearest music stand (ansible.cfg: the search hierarchy, dump --only-changed, the world-writable trap) | Foundational | [ed1/cap07](ed1/cap07/) |
| 8 | The address book (static inventories: INI/YAML, groups, patterns, ranges, group_vars) | Foundational | [ed1/cap08](ed1/cap08/) |
| 9 | The cue, not the score (ad-hoc commands: ping, command/shell, copy/file/setup, forks, become) | Foundational | [ed1/cap09](ed1/cap09/) |
| 10 | The written score (the first playbook: play/task/module, re-running, many plays, tags) | Foundational | [ed1/cap10](ed1/cap10/) |
| 11 | The caretaker's keys (privilege escalation in depth: become, sudoers, -K/password, become_user) | Intermediate | [ed1/cap11](ed1/cap11/) |
| 12 | Annotations on the score (variables: types, Jinja2, where they live, register/set_fact, defaults) | Intermediate | [ed1/cap12](ed1/cap12/) |
| 13 | The chain of command (the 22 levels of variable precedence: three principles, real clashes, the traps) | Intermediate | [ed1/cap13](ed1/cap13/) |
| 14 | The recall at the end of rehearsal (tasks, handlers and notifications: notify/listen, changed_when, the three rules) | Intermediate | [ed1/cap14](ed1/cap14/) |
| 15 | If, and for each (conditional logic and loops: when without braces, register+when, loop over dicts, loop_control) | Intermediate | [ed1/cap15](ed1/cap15/) |
| 16 | The section (roles: structure, defaults vs vars, files/templates auto-resolution, galaxy init) | Intermediate | [ed1/cap16](ed1/cap16/) |
| 17 | The shared repertoire (Galaxy and collections: FQCN, requirements.yml, collections_path, Automation Hub) | Intermediate | [ed1/cap17](ed1/cap17/) |
| 18 | The strongbox (Ansible Vault: encrypt/view/rekey, encrypt_string, running with encrypted data, vault-id) | Advanced | [ed1/cap18](ed1/cap18/) |
| 19 | The strongroom (key management in production: runtime lookups, HashiCorp Vault, AppRole, cloud managers, no_log) | Advanced | [ed1/cap19](ed1/cap19/) |
| 20 | The arranger (advanced Jinja2: map/select/selectattr, dict2items/combine, default/mandatory, tests, .j2 templates, lookups) | Advanced | [ed1/cap20](ed1/cap20/) |
| 21 | The roll-call (dynamic inventories: inventory plugins, keyed_groups, groups/compose, hostnames, cache) | Advanced | [ed1/cap21](ed1/cap21/) |
| 22 | When a string snaps (error handling: block/rescue/always, until/retries, ignore_errors/failed_when, any_errors_fatal, assert/fail, force_handlers) | Advanced | [ed1/cap22](ed1/cap22/) |
| 23 | The dress rehearsal (linting and check mode: --syntax-check, ansible-lint profiles, --check/--diff, check_mode) | Advanced | [ed1/cap23](ed1/cap23/) |
| 24 | The throwaway stage (testing with Molecule: scenario anatomy, create/converge/idempotence/verify/destroy, Testinfra, phases, more distributions) | Advanced | [ed1/cap24](ed1/cap24/) |
| 25 | Performance at scale (forks, strategies, pipelining, taming facts, Mitogen) | Cloud Architect | ed1/cap25 |
| 26 | CI/CD (version control, the pipeline, GitHub Actions, the production gate) | Cloud Architect | ed1/cap26 |
| 27 | Orchestration and rolling updates (serial, delegate_to, pre/post_tasks, rollback) | Cloud Architect | ed1/cap27 |
| 28 | AWX and Automation Platform (the job template, RBAC/audit, workflows, EE/EDA) | Cloud Architect | ed1/cap28 |

## Pull only this manual

    git clone --filter=blob:none --sparse https://github.com/calmict/book_labs.git
    cd book_labs
    git sparse-checkout set ansible/ed1
