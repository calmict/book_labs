# Chapter 2 — Answers (model solution)

## The journey, by hand

    bash start/node.sh up          # build the node, print the ssh command
    SSH="ssh -p 2222 -i <key> -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1"

    $SSH 'mkdir -p ~/.ansible/tmp'                                   # 1
    scp -P 2222 -i <key> ... solution/module.py root@127.0.0.1:.ansible/tmp/mod.py  # 2
    $SSH 'python3 ~/.ansible/tmp/mod.py'                             # 3 -> JSON
    $SSH 'rm -f ~/.ansible/tmp/mod.py'                               # 4

    bash start/node.sh down        # remove node + key

solution/run.sh drives this whole arc on a throwaway node (only sshd + python3),
with an ephemeral key and guaranteed teardown.

## The completed module

The interview gathers a few facts the machine knows about itself and prints one
JSON line:

    facts["hostname"] = platform.node()
    facts["system"]   = platform.system()
    facts["release"]  = platform.release()
    facts["machine"]  = platform.machine()
    facts["python"]   = platform.python_version()

    -> {"changed": false, "ansible_facts": {"hostname": "...", "system": "Linux", ...}}

## The three questions

**a. Python on the target, but no agent.**

The difference is between something the machine *already has* and something *you*
add and then own forever. Python is a general-purpose runtime that is present (or
one apt/yum away) on essentially every Linux box; Ansible borrows it for the few
seconds a task runs and leaves nothing behind. An *agent* would be a piece of your
software installed on all thousand machines: a long-lived daemon you must deploy,
version, keep compatible with the control side, patch when it has a CVE, and watch
because it listens on a port. Agentless removes that entire second system. For
security it means no extra attack surface and no persistent listener to harden; the
only door is SSH, which you already secure. For maintenance it means there is no
fleet-wide agent rollout to coordinate and no "agent version skew" to debug — you
upgrade Ansible in one place, the control node, and every managed node is
immediately "up to date" because it was never running your code in the first place.

**b. The four frames, and where the state lives.**

The frames are: (1) connect over SSH and create a temporary directory on the node;
(2) copy the module into it; (3) execute the module with the node's own Python,
capturing its JSON on stdout; (4) delete the temporary file and disconnect. At the
end, the state of what you did does not live on the managed node at all — the temp
file is gone, no daemon is running, nothing records that Ansible was ever there.
That is why Ansible is "stateless" on the target: the node is not asked to remember
anything. Whatever memory exists (what was done, what the desired state is) lives on
the control side and in your version-controlled code, not scattered across a
thousand machines. The messenger visits and leaves; the message is kept back home.

**c. Bootstrapping a machine with no Python.**

You cannot use the normal modules, because they *are* Python programs that need a
Python interpreter on the target to run — the very thing this machine lacks. The way
out is the one module that does not go through that mechanism: **raw**, which ships
plain shell commands over SSH and needs nothing but the SSH connection itself. With
raw you run the package manager to install Python (for example apt-get install -y
python3), and from that point the machine has an interpreter, so every other module
works normally. It is the chicken-and-egg escape hatch: one raw step to lay down
Python, then the full agentless machinery on top.
