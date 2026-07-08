# Chapter 2 — The messenger, not the tenant

**Level:** Foundational

The conductor of the orchestra does not implant a chip in every musician's brain:
he speaks, and they — who already know how to read music — play. Ansible works the
same way. It does not install an *agent* that lives on the machine: it **visits**
over SSH, has it do one thing using the Python that is already there, and leaves.
This is called **agentless**, and it is the heart of the architecture.

In this lab **you become the messenger**: you will reproduce by hand, over SSH,
the journey Ansible automates for every task. We will not use Ansible yet (you
install it in chapter 6): the point is exactly to show that nothing *of its own*
is needed on the target — only SSH and Python.

## Objectives

- Understand **agentless** and its three gifts: nothing to install/maintain on the
  target, no daemon listening (unchanged attack surface), works on anything that
  speaks SSH + Python.
- Tell apart the **control node** (your machine, where you start from) and the
  **managed node** (the machine you configure, which hosts nothing of yours).
- Rebuild **the journey of a task**, frame by frame: copy the module, run it with
  the remote Python, JSON on stdout, cleanup.
- See **the role of Python** — and when it is *not* needed (the raw module, pure
  shell over SSH).
- Touch the **facts**: how Ansible "interviews" the machine.

## Prerequisites

- A **Docker** engine (the managed node is a container). Check with: docker version
- A standard SSH client (ssh, scp, ssh-keygen) — already present on every
  Linux/macOS.
- **No Ansible**, again on purpose. Bringing the node up downloads sshd and
  python3: it needs the network the first time.

## The scenario

- **Control node:** your machine.
- **Managed node:** a container to which we install *only* openssh-server and
  python3. No Ansible agent, no daemon of ours. That is the whole point of the
  chapter.

## Step by step

### Phase 0 — Bring the managed node up

    bash start/node.sh up

The script builds the node and prints the ready-to-paste SSH command (with an
ephemeral key generated on the fly). Look at what we put inside: **only** SSH and
Python. Nothing else. This is the **first gift** of agentless — there is no agent
to install, version, upgrade on every machine.

Save the SSH command in a variable for convenience (the script shows it to you):

    SSH="ssh -p 2222 -i <key> -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1"

### Phase 1 — The three gifts, from the inside

Get in:

    $SSH 'hostname; python3 --version'

You are on the managed node. Now ask what runs *of ours* when you are not working:

    $SSH 'ps -e | grep -E "sshd|ansible" || true'

You see sshd, and nothing else. **Second gift:** once the task is done, no process
of yours stays listening on the target — no new attack surface, no daemon to
watch. And since everything goes through SSH + Python, the same mechanism works on
a server, a container, a network appliance: **third gift**, the barrier to entry
is very low.

### Phase 2 — The journey of a task, frame by frame

An Ansible "module" is not magic: it is a small program that gathers something and
prints **one line of JSON**. Open start/module.py and complete the **TODO**: have
the machine gather at least three facts about itself (hostname, system, Python
version…). The file stays valid even half-done (it prints JSON with empty facts),
so you can run it as you write it.

Now make it **travel by hand**, exactly as Ansible would:

    # 1. prepare the temporary directory on the node
    $SSH 'mkdir -p ~/.ansible/tmp'

    # 2. copy the module to the managed node
    scp -P 2222 -i <key> -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        start/module.py root@127.0.0.1:.ansible/tmp/mod.py

    # 3. run it with the REMOTE Python — the JSON comes back on stdout
    $SSH 'python3 ~/.ansible/tmp/mod.py'

    # 4. cleanup: Ansible always deletes the temporary file
    $SSH 'rm -f ~/.ansible/tmp/mod.py'

These four frames **are** what Ansible does for every single task: connect, ship
the module into a tmp dir, run it with the target's Python, collect the JSON, clean
up. You just did them by hand. No state was left on the node: the messenger passed
through and left.

### Phase 3 — The role of Python (and when it is not needed)

The module is Python, so it runs with the **managed node's Python** (not yours):
that is why agentless *requires* Python on the target. But not everything needs
Python. The **raw** module skips the whole mechanism: it is pure shell shipped over
SSH.

    $SSH 'echo "raw: just shell, no Python involved"'

That is exactly how you **bootstrap** a machine that does not have Python yet: with
raw you install Python over SSH, and from there on you can use the real modules.

### Phase 4 — The interview (the facts)

Re-read your module's output: you returned some **facts** inside ansible_facts. It
is the **setup** module in miniature: before acting, Ansible "interviews" every
machine — who are you, what system, how much memory, which IPs — and those facts
become variables usable throughout the rest of the work (you will use them for real
from chapter 12). The interview is the first thing that happens when you launch a
playbook; here you wrote it yourself.

## Done when

- The managed node is up with **only sshd + python3**, and you get in over SSH with
  a key.
- The completed module.py returns valid JSON with at least three facts in
  ansible_facts, run with the **node's Python**.
- You reproduced the **four frames** of the journey (copy, remote execution, JSON,
  cleanup), and at the end the temporary file **does not remain** on the node.
- You can say why the raw module does not require Python on the target, and what it
  is for.

## Questions to reflect on

**a.** Agentless requires *Python* on the managed node but **not** an *agent*. What
concrete difference does it make, for security and for maintaining a thousand
machines, not to have a daemon of yours installed and listening on each one?

**b.** List the four frames of a task's journey. At the end, *where* did the state
of what you did on the managed node remain — and what does that say about why
Ansible is called "stateless" on the target?

**c.** You have a brand-new machine with no Python. With the normal modules you can
do nothing. How do you get it to the point where you can really use Ansible on it,
and which "module" do you need for the first step?

## Cleanup

    bash start/node.sh down

## Where it leads

You took for granted the very thing that was the pivot here: the **SSH key** that
lets you in without a password. That is chapter 3, "SSH under the hood". Then, at
6, you install Ansible; and at 9, when you launch your first ansible -m ping and
ansible -m setup, you will recognize under the hood exactly these four frames and
this interview — only, automated.
