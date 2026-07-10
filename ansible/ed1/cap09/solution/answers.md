# Chapter 9 — Answers (model solution)

## The completed morning round (the TODOs)

    # TODO 1 — deploy the motd (a switch: CHANGED once, then ok)
    ansible -i "$INV" web -b -m copy -a 'src=motd dest=/etc/motd mode=0644'

    # TODO 2 — ensure the app dir exists, owned by root (idempotent too)
    ansible -i "$INV" web -b -m file -a 'path=/etc/cap09.d state=directory mode=0755'

    # TODO 3 — one fact per node: the distribution
    ansible -i "$INV" web -m setup -a 'filter=ansible_distribution'

solution/run.sh drives the whole chapter with an ephemeral venv and two nodes, and
guaranteed teardown: the roll call, command vs shell, become, the two switches
(copy, file) going CHANGED -> ok, setup, the forks timing, and finally the reader's
runbook.sh end to end.

## The three questions

**a. Ad-hoc or playbook?**

An ad-hoc command is the right tool for a one-off, throwaway action where the goal is
to *know* or *nudge* something right now: is the fleet up, how much disk is left,
restart that service, push one file this once. It is a cue — spoken, immediate, gone
the moment it is done. It becomes the wrong tool the instant the action is worth
repeating: anything you will run again next week, that a colleague must review, that
has to happen in a fixed order, or that you want under version control. There is no
record of an ad-hoc command except your shell history; nobody can diff it, nobody can
re-run it with confidence that it is the same. The moment "do this" turns into "do
this reliably, again, in order, and let others read it", you have crossed from the cue
to the written score — the playbook (chapter 10). A useful test: if you would be
uneasy about losing the exact command, it should already be a playbook.

**b. The switch and the doorbell (chapter 5, again).**

copy reports ok on the second run because it is a *switch*: the module inspects the
target's state — does /etc/motd already have exactly these bytes and this mode? — and
acts only if reality differs from the request. Nothing to do means changed: false,
green. command reports CHANGED every single time because it is a *doorbell*: it runs
the command and reports that it ran; it has no idea whether running it changed
anything, because "what this command does" is opaque to Ansible. rc=0 means "it
exited cleanly", not "the world is now different". That is why command (and shell) are
honest only about execution, never about change. If you must use command for something
whose real effect you can detect, you tell Ansible how to judge with changed_when
(e.g. changed_when: "'updated' in result.stdout") — or, far better, you reach for the
module that already knows how to check: not command -a 'mkdir ...' but the file
module, not command -a 'systemctl restart ...' but the service module. The rule of
thumb from chapter 5 holds: prefer the switch; keep the doorbell for genuinely
read-only or truly unmodelled actions, and teach it changed_when when you cannot.

**c. Why command is the default, not shell.**

Because command does not invoke a shell at all: Ansible splits your argument string
into a plain argv and executes the program directly, so the shell metacharacters —
pipes, redirections, &&, backticks, $(...), globbing, variable expansion — are passed
as literal text, not interpreted. That is exactly why the lab's echo ciao | wc -c
prints the string "ciao | wc -c" under command and the number 5 under shell. The
safety consequence is the whole point: with command there is no shell to hijack, so a
value that happens to contain ; rm -rf / or $(something) is just an odd-looking
argument, harmless. Pass that same untrusted input to shell and the shell will
faithfully interpret it — the classic injection. So command is the secure default and
shell is the deliberate exception you reach for *only* when you genuinely need shell
features (a pipe, a redirection, an environment variable), and when you do, you take
on the duty of not feeding it untrusted data (or of quoting/escaping it, which is
error-prone — another reason to prefer a real module). Least power by default:
command asks the shell for nothing, so nothing can go wrong in the shell.
