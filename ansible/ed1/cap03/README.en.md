# Chapter 3 — The key that stays home

**Level:** Foundational

In chapter 2 the script handed you a key and you got onto the managed node
**without a password**. How? Now you open the hood on SSH — the channel *all* of
Ansible travels on. At its heart is **asymmetric cryptography** and one golden
rule: the **private** key never leaves the control node; only its **public** half
travels. We will build a small world — an exposed **bastion** and a **target**
locked in a segregated network — and cross it by hand.

## Objectives

- Understand the asymmetric pair: the **private** key (stays home) and the
  **public** key (goes onto the servers, into authorized_keys); and the handshake
  that puts it to work.
- The file anatomy and the **permissions** that matter (the "UNPROTECTED PRIVATE
  KEY" trap).
- ~/.ssh/config: readable **aliases** and **ControlMaster**, the multiplexing that
  makes Ansible fast.
- **Bastion host / ProxyJump**: crossing a segregated network.
- **Passphrase** (protection at rest), **ssh-agent** (automation without prompts),
  and the **host key checking** trap.

## Prerequisites

- A **Docker** engine (bastion and target are containers). Check with: docker version
- A standard SSH client (ssh, scp, ssh-keygen).
- **No Ansible**: we get there in chapter 6. Bringing the lab up downloads sshd: it
  needs the network the first time.

## The scenario

- **Control node:** your machine.
- **Bastion:** the only exposed machine (port 2223); the front door.
- **Target:** locked in the lab network, **with no published port**, and its name
  resolves **only in there**. You reach it only by going through the bastion.

The lab lives in /tmp/cap03-lab (key included): a throwaway drawer.

## Step by step

### Phase 0 — Bring the lab up

    bash start/lab.sh up

It creates the network, the bastion, the target, and an ephemeral key in
/tmp/cap03-lab/key. You will use the SSH config with: ssh -F start/ssh_config <host>

### Phase 1 — The key and the lock

Look at the two generated files:

    ls -l /tmp/cap03-lab/key /tmp/cap03-lab/key.pub

key is the **private** one (stays home), key.pub is the **public** one. The public
key was copied into the servers' authorized_keys: it is the *lock*, you can post it
in the town square without risk. The private key is the only one that opens it. Get
in and watch the handshake:

    ssh -F start/ssh_config -v bastion 'hostname' 2>&1 | grep -iE 'offering|accepted|publickey' | head

You see SSH offer the public key and the server accept it: no password crossed the
network.

### Phase 2 — The permissions trap

The private key is a secret, and SSH insists on it. Make it world-readable and try
again:

    cp /tmp/cap03-lab/key /tmp/cap03-lab/badkey
    chmod 644 /tmp/cap03-lab/badkey
    ssh -i /tmp/cap03-lab/badkey -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 true

    @@@ WARNING: UNPROTECTED PRIVATE KEY FILE! @@@

SSH **refuses** a private key others can read. The rule: private at 600, ~/.ssh at
700. It is the first thing that breaks the automation of anyone who copies keys with
the wrong permissions.

### Phase 3 — The alias, and the bastion

Open start/ssh_config: the **bastion** entry is already written (HostName, Port,
User, IdentityFile). Now **TODO 1**: complete the **target** entry so it reaches it
*through* the bastion. First try without:

    ssh -F start/ssh_config -o ProxyJump=none target 'hostname'

    ssh: Could not resolve hostname cap03-target

The target has no published port and its name lives only in the lab network: from
here you cannot see it. Add the missing line to the target entry —

    ProxyJump bastion

— and try again:

    ssh -F start/ssh_config target 'hostname'

You are on the target, hopping through the bastion. **This is exactly how Ansible
enters segregated networks**: a ProxyJump in the inventory, and the internal fleet
becomes reachable without exposing anything.

### Phase 4 — ControlMaster: why Ansible is fast

Every SSH connection pays a TCP + crypto handshake. Ansible opens dozens per host:
if each started from scratch it would be painfully slow. The cure is **multiplexing**.
Complete **TODO 2** in the config, adding to the bastion:

    ControlMaster auto
    ControlPath /tmp/cap03-cm-%C
    ControlPersist 60s

Then time three connections in a row:

    for i in 1 2 3; do
      s=$(date +%s%N); ssh -F start/ssh_config bastion true; e=$(date +%s%N)
      echo "conn $i: $(( (e-s)/1000000 )) ms"
    done

The first opens a **master socket**; the second and third **reuse** it — near zero.
It is the foundation chapter 25 will build pipelining on. **Careful:** the
ControlPath must stay **short** (the socket has a ~108-character limit): keep it in
/tmp, not in a deep directory.

### Phase 5 — The key at rest, and the agent

So far the key had no passphrase: convenient, but if stolen it is immediately
usable. Protect it at rest:

    ssh-keygen -t ed25519 -N 'a-passphrase' -f /tmp/cap03-lab/enckey -q
    ssh-keygen -y -P '' -f /tmp/cap03-lab/enckey

    (refused: without the passphrase the private key cannot be read)

But now every connection would ask for the passphrase — and automation stalls at
the first prompt. This is where the **ssh-agent** comes in: you unlock the key
**once** (ssh-add) and the agent keeps it in memory for the session, so Ansible
meets no prompts. It is the tension between security and automation: passphrase +
agent for people; in CI, often a dedicated key *without* a passphrase but with
tightly restricted access.

### Phase 6 — Host key checking (and why we turned it off in the lab)

The first time you connect, SSH records the server's key in known_hosts: **trust on
first use**. If that key changes later, SSH raises the alarm — it is the defense
against an impostor putting itself in the middle. In the lab you saw
StrictHostKeyChecking no and UserKnownHostsFile /dev/null: handy with throwaway
containers, but in production it **turns off exactly that defense**. It is the number
one trap of people who automate: disabling host key checking "because it is
annoying", and staying exposed.

## Done when

- You get into the **bastion** with the key via the alias; the **0644 key is
  refused**.
- The **target** entry with ProxyJump takes you onto the target **through the
  bastion** (the direct attempt fails).
- With **ControlMaster** the second connection is near-instant (master socket
  created).
- You can explain why the **private** key must never leave the control node.

## Questions to reflect on

**a.** Why can the **public** key sit on a thousand servers without risk, while the
**private** one must never leave the control node? What would copying the private
key onto a server "for convenience" entail?

**b.** **Agent forwarding** (-A) forwards your agent to the machine you log into,
handy for bouncing further. Why is it dangerous on a shared or untrusted bastion,
and how does **ProxyJump** solve the same problem more safely?

**c.** In the lab you turned host key checking off. In production which defenses do
you lose by disabling it, and how would you manage it with Ansible on a real fleet
(instead of switching it off)?

## Cleanup

    bash start/lab.sh down

## Where it leads

You have taken apart the channel all of Ansible travels on. In chapter 6 you install
it; in 7, in ansible.cfg, ControlMaster, forks and pipelining become real settings;
in 8, in the inventory, keys and bastion become per-host variables. From here on,
when Ansible "connects", you will know exactly what happens under the hood.
