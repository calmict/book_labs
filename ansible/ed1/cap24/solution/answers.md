# Chapter 24 - Answers (model solution)

## The completed TODOs

    # TODO 1 (24.4) - molecule.yml: the platform and the verifier
    platforms:
      - name: cap24-instance
        image: python:3.12-slim
        pre_build_image: true
    verifier:
      name: testinfra

    # TODO 2 (24.5) - the marker task made idempotent with a creates guard
    - name: Stamp a deploy marker once
      ansible.builtin.command: touch /etc/cap24app/deployed
      args:
        creates: /etc/cap24app/deployed

    # TODO 3 (24.6) - the Testinfra verifications
    testinfra_hosts = ["all"]

    def test_config_directory(host):
        d = host.file("/etc/cap24app")
        assert d.is_directory
        assert d.mode == 0o755

    def test_config_file(host):
        f = host.file("/etc/cap24app/app.conf")
        assert f.exists
        assert f.mode == 0o644
        assert "workers = 4" in f.content_string

solution/run.sh proves the whole thing against a real throwaway Docker container: molecule test is
green end to end (create, converge, idempotence, verify, destroy); the idempotence gate catches the
start role's non-idempotent command (a touch with no creates guard); the Testinfra verifier catches
a wrong expectation; and the teardown leaves no cap24-instance container behind.

Note on the environment (verified): molecule is pinned to 5.1.0 (the last line that supports a
Python 3.9 controller) with molecule-plugins[docker] 23.4.1, the docker SDK 6.1.3 and requests
2.31.0; the collections are community.docker 3.4.11 and ansible.posix 2.2.1. On some hosts the molecule
docker driver's async create / destroy fails with a spurious "Not supported URL scheme http+docker"
unless the venv is ACTIVATED (source venv/bin/activate) instead of calling molecule by its full
path: the driver runs those steps in a detached async worker that mis-initialises without
VIRTUAL_ENV / PATH pointing at the venv. solution/run.sh activates the venv for exactly this reason;
if you drive molecule yourself, activate the venv first (the setup step above already does).

## The three questions

**a. Why Molecule proves what lint and check mode cannot.**

Because lint and check mode never actually run the role against a real system, and Molecule does.
syntax-check only parses the file; lint judges style and best practice; check mode simulates, but a
simulation is an educated guess evaluated against whatever state happens to be there - it assumes an
existing system and it cannot try anything a module refuses to simulate. Molecule replaces the guess
with the deed: it creates a clean container, applies the role for real, and reads back what actually
happened on a real filesystem. Two properties come precisely from "from scratch" and "destroyed".
"From scratch" means the test starts from a known, empty baseline every time, so a green result is
not an accident of pre-existing state: the role really did build the target from nothing, which is
exactly what you cannot assume in check mode. "Destroyed" means the result is disposable and
therefore repeatable without cost or drift - you can run it a thousand times and each run is honest,
because nothing carries over from the last. Together they turn "the playbook looks right" into "the
role, run on a blank machine, produces the right machine, reproducibly". That is a claim about
reality, not about the text.

**b. Why idempotence (apply twice, changed=0) is the strongest cheap proof.**

Because idempotence is the one property that a single correct-looking run cannot demonstrate but
almost every real bug violates, and Molecule checks it for free by simply running converge a second
time. A first apply that reports changed tells you the role *did* something; it does not tell you the
role described a *state*. The second apply is the discriminator: a role that truly declares desired
state finds reality already matching and reports changed=0, while a role that merely *runs actions*
keeps acting and reports changed again. So the second pass separates "convergent" from "merely
repeatable" - the exact distinction the whole manual is built on - and it does it with no extra
fixtures, no assertions to write, just one more converge. The cost of a non-idempotent task that
slips through is quiet but real: every subsequent run reports changed on a system that is already
correct, which poisons the signal you rely on (you can no longer tell "something drifted" from
"this task always lies"), it triggers handlers that should not fire (a needless restart on every
run - chapter 14), and in a rolling deploy it makes every host look modified forever. A command
with no creates or changed_when is the classic offender: it is a doorbell wearing a switch's
costume, and the idempotence phase is what strips the costume off.

**c. Why an independent verification catches what converge cannot.**

Because converge's ok/changed is Ansible grading its own homework, and a grader that only checks its
own intentions is blind to the gap between "I ran the module" and "the module produced the right
result". converge reports success when each task's module returns success - but a module can succeed
and still leave the system wrong for reasons outside its view: a template that renders a valid file
with the wrong value, a variable that resolved to an unexpected default, a mode that is technically
applied but too loose, a service that Ansible "started" but that crashes a second later. Testinfra
looks from the other side: it opens the real file, reads the real bytes, checks the real permission
and the real running service, with no knowledge of what Ansible meant to do. That independence is
the point - it can only agree with reality, not with the playbook's intentions, so it catches the
class of error where Ansible faithfully did what it was told and what it was told was wrong. A
concrete example: a role whose template task hardcodes "workers = 2" while the variable was meant to
be 4 converges perfectly green (the copy succeeded, idempotent on re-run), yet the deployed config
is wrong; converge will never complain, and only a verification that asserts "workers = 4" in the
actual file will. "It ran" is Ansible's claim; "it is correct" is Testinfra's.
