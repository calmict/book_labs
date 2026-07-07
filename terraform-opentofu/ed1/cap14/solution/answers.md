# Chapter 14 — Answers (model solution)

## The closed door (Phase 0)

    Error: No value for required variable
    # (no default on environment: it must be provided)

## The bouncer (Phase 1)

    Error: Invalid value for variable
    # The environment must be one of: dev, staging, prod.

## The three entrances (Phase 2)

    # tfvars=dev, then: tofu plan -var environment=prod
    + name = "cap14-web-prod"
    # the CLI won over the file

## The three questions

**a. The three doors.**

environment is the FRONT door: an input variable, a value that enters from
outside — whoever uses the config chooses it. url is the SERVICE door: an
output, the only thing the outside world sees of this room. container_name is
the INTERNAL KITCHEN: a local. It is not a variable because nobody passes it in
(it has no external door — it is derived from environment inside the config);
it is not an output because nobody outside reads it (it is a private detail of
how the container is named). A local exists precisely for values that are
neither input nor output: computed once from other values, reused wherever the
name is needed, so a single change to environment flows everywhere.

**b. Precedence.**

prod is applied. The precedence, strongest first, is: -var on the command line,
then terraform.tfvars, then TF_VAR_ in the environment. So -var=prod beats the
tfvars (dev) which beats the env (staging) — the winner is prod. The general
rule of thumb: the closer a value sits to the exact command you are running,
the more it weighs. It makes sense for the CLI to win because it is the most
explicit, most immediate, most deliberate act: I am typing this value right now
for this run, overriding whatever the files or the environment carry as
defaults. Files and env variables are standing configuration; the CLI flag is a
conscious, one-off override — and an override that could not beat the defaults
would be useless.

**c. tfvars and the secret.**

.gitignore excludes tfvars because that is where per-environment, per-person
values live — and those values are often credentials, API keys, passwords,
tokens. Committing them would publish secrets in the repo's history forever;
only the .example travels, an innocuous template with placeholder values that
documents the shape without leaking anything. The thread to chapter 11 is the
same danger from the other end: the state file keeps every value — including
the ones marked sensitive — in PLAIN TEXT. So secrets threaten Terraform at two
points: on the way IN (tfvars, the input you type) and at REST (the state, the
memory it keeps). Both must be treated as confidential: tfvars gitignored, the
state stored in a backend with access control (chapter 12) — never a secret
casually committed, at either door.
