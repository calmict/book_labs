# Chapter 3 — Answers (model solution)

## The completed config

The target reaches through the bastion, and multiplexing makes repeat connections
fast:

    Host *
        ControlMaster auto
        ControlPath /tmp/cap03-cm-%C     # SHORT path: the socket has a ~108-char limit
        ControlPersist 60s

    Host bastion
        HostName 127.0.0.1
        Port 2223
        User root
        IdentityFile /tmp/cap03-lab/key

    Host target
        HostName cap03-target
        User root
        IdentityFile /tmp/cap03-lab/key
        ProxyJump bastion

    # ssh -F solution/ssh_config bastion     -> the front door
    # ssh -F solution/ssh_config target      -> jumped through the bastion

solution/run.sh drives the whole arc (key auth, permissions trap, ProxyJump,
ControlMaster, passphrase) against throwaway nodes, with guaranteed teardown.

## The three questions

**a. Public everywhere, private nowhere.**

The two halves of the pair have opposite jobs. The public key can only *verify* a
signature, never *produce* one: posting it on a thousand servers lets each of them
check "does whoever is connecting hold the matching private key?", and that is all
it can do — knowing the public key gives an attacker no way in. The private key is
the one that *proves* identity; anyone holding it can authenticate as you to every
server that trusts the public half. So the private key stays on the control node,
read-protected (0600), and never travels. Copying it onto a server "for convenience"
would turn that one server into a single point of total compromise: crack or steal
that box and the attacker now has the key that opens the entire fleet, not just the
one machine. The whole security model is "the secret exists in exactly one place";
copying it around destroys that guarantee.

**b. Agent forwarding vs ProxyJump.**

Agent forwarding (-A) exposes a socket to your local ssh-agent on the machine you
log into, so further hops can ask *your* agent to sign challenges. The danger is
that root on that intermediate box — or anyone who compromises it — can use the
forwarded socket to authenticate as you to anything your key opens, for as long as
your session lasts. On a shared or untrusted bastion that is exactly the machine you
should trust least, and you have just handed it the ability to impersonate you. The
private key never leaves your laptop, but the *ability to use it* does. ProxyJump
solves the same "reach the inner host through the gateway" problem without that
exposure: it tunnels the connection through the bastion (the bastion only forwards
encrypted bytes), and the authentication to the final target happens end-to-end from
your control node, using your key locally. The bastion sees ciphertext, never a
usable handle to your identity.

**c. Turning host key checking back on.**

Disabling it (StrictHostKeyChecking no + UserKnownHostsFile /dev/null) throws away
two defenses: it no longer detects a **man-in-the-middle** (an impostor presenting a
different host key on first connection is silently accepted), and it no longer
detects that a host you already knew has **changed identity** (a redirected DNS name,
a swapped server, a compromise) — the very alarm known_hosts exists to raise. On a
real fleet you do not switch it off; you manage the known_hosts instead. The clean
approaches: pre-populate a shared known_hosts (for example ssh-keyscan the fleet, or
distribute the host keys as data you control) so first contact is already trusted; or
use StrictHostKeyChecking accept-new, which trusts a genuinely new host on first sight
but still refuses a *changed* key — keeping the change-detection defense while not
prompting on freshly provisioned machines. With Ansible this lives in ansible.cfg
(host_key_checking) and in how you seed known_hosts, not in blanket -o StrictHostKeyChecking=no.
