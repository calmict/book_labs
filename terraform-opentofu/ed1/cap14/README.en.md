# Chapter 14 — The three doors

**Level:** Intermediate
**Estimated time:** 45–55 minutes
**Manual topics:** input variables (14.1), input validation (14.2), outputs (14.3), locals: the internal kitchen (14.4), the three doors together (14.5)

## The idea

So far you have written configurations with the values *hard-coded* inside: the
container name, the port, all fixed in the file. That works for a single
building. But the same project must serve dev, staging and prod — and rewriting
the file for each is the photocopy chapter 1 taught us to fear.

This chapter installs **three doors** in the configuration. The front door —
*variables* — lets values in from outside: whoever uses the module chooses
environment and external_port without touching the code. The service door —
*outputs* — shows the outside only what it promises: here, the URL where the
service answers. And the internal kitchen — *locals* — has no door onto the
world: it is where the container name is *derived* once
(cap14-web-${var.environment}) and reused everywhere.

In between stands a bouncer. A variable can demand a value (no default) and can
refuse the wrong one: validation blocks environment = "banana" before the plan
even starts. And you will discover the same value can enter through three
different doors — command line, environment variable, tfvars file — with a
precise precedence when they disagree.

## Goals

By the end you will be able to:

- declare input variables with type, description and default, and tell a
  *required* variable (no default) from an optional one;
- put a bouncer on the input with a validation block (condition + error
  message);
- pass a value from three sources — -var, TF_VAR_, terraform.tfvars — and
  predict which one wins when they conflict;
- derive internal values with locals and explain why they are not variables;
- expose a result with output, and say why the output is the only service door
  (chapter 13's contract is born here).

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running. Free port: 8095.
- Chapters 3 (in-place vs replace) and 9 (arguments and attributes): you see
  them at work again here.

## Your task

### Phase 0 — The closed door (a variable that demands)

In start/ you will find a main.tf with the three doors to complete. The first
variable, environment, is declared *with no default*: it is required. Try it —
ask for the plan without providing anything:

    cd start
    tofu init
    tofu plan

It stops you at once: *No value for required variable*. No default means no
convenient value: whoever uses this configuration **must** declare the
environment. It is a design choice, not a flaw.

### Phase 1 — The bouncer (TODO 1: validation)

TODO 1 asks you to complete the validation block on environment: only dev,
staging, prod are allowed. The external_port variable, just below, already has
its full validation: use it as a model. Complete the condition:

    validation {
      condition     = contains(["dev", "staging", "prod"], var.environment)
      error_message = "The environment must be one of: dev, staging, prod."
    }

Then try to force the door:

    tofu plan -var environment=banana

The plan does not even start: *Invalid value for variable*, with your message.
Validation is a bouncer that checks the ticket **before** chapter 4's graph is
built — the wrong input is stopped at the threshold, not halfway through the
apply.

### Phase 2 — The three entrances, and who wins

The same value can enter from three sources. Try them one by one.

From the command line:

    tofu plan -var environment=dev

From the environment (same effect, no -var):

    TF_VAR_environment=staging tofu plan

From a file — copy the example provided and fill it in:

    cp terraform.tfvars.example terraform.tfvars
    # inside: environment = "dev"
    tofu plan

Now make them fight. With environment = "dev" inside terraform.tfvars, run:

    tofu plan -var environment=prod

prod wins: the **command line beats the file**. And the file beats the
environment. The precedence (strongest first): -var on the CLI, then
terraform.tfvars, then TF_VAR_. Rule of thumb: the closer a value is to the
command you are running, the more it weighs.

A note that will come in handy: .gitignore excludes tfvars files. That is why
start/ gives you a terraform.tfvars.example, not a real tfvars. tfvars are
where per-environment values live — often credentials, keys, secrets — and must
never be committed. Only the *example* travels in the repo, an innocuous
version to copy.

### Phase 3 — The internal kitchen (TODO 2: locals)

The container name is needed in more than one place and must depend on the
environment. It is not an input (nobody passes it) and not an output (nobody
reads it): it is an *internal*, derived value. The right place is a local.
Complete TODO 2:

    locals {
      container_name = "cap14-web-${var.environment}"
    }

and use it in the container: name = local.container_name. A local is computed
once and reused: change environment, and the name changes everywhere with
nothing else touched. It is not a variable because it does not enter from
outside — it is the kitchen, not the door.

### Phase 4 — The service door (TODO 3: the output)

TODO 3 exposes the result. Complete the output:

    output "url" {
      description = "Where the service answers."
      value       = "http://localhost:${var.external_port} (${var.environment})"
    }

Apply for real with the environment you want:

    tofu apply -var environment=dev

At the end of the apply, tofu prints url = "http://localhost:8095 (dev)". Open
it: *Welcome to nginx!*. The output is the only thing the outside world sees of
this room — it is exactly the door that in chapter 13 became the *contract*
between teams (terraform_remote_state reads outputs, remember?). The contract
is born here.

### Phase 5 — Chapter 3's echo

Change only the front door — the environment — and ask for the plan:

    tofu plan -var environment=prod

The container **must be replaced**:
~ name = "cap14-web-dev" -> "cap14-web-prod" # forces replacement. A value that
entered through a door crossed the local, changed the name, and chapter 3 did
the rest: name is an attribute that forces replacement. The three doors are not
decoration — they move the graph.

### Cleanup

    tofu destroy -var environment=dev

## Definition of done

- The plan with no environment stopped with *No value for required variable*.
- -var environment=banana was rejected by validation with your message.
- You had seen the same value enter from -var, TF_VAR_ and terraform.tfvars,
  and predicted who wins (-var, then file, then env).
- apply printed url = "http://localhost:8095 (<env>)", and the page answered.
- Changing environment produced a replace of the container (# forces
  replacement).
- You answered the three questions in answers.md.

## The three questions

**a.** The three doors: assign environment, container_name and url to the right
door (front / service / internal kitchen) and explain in one sentence why
container_name is neither a variable nor an output.

**b.** Precedence: you have environment = "dev" in terraform.tfvars,
TF_VAR_environment=staging in the environment, and you run
tofu apply -var environment=prod. Which environment is applied, and what is the
general rule? Why does it make sense for the CLI to win?

**c.** tfvars and the secret: why does .gitignore exclude tfvars files and only
the .example travel in the repo? Connect the answer to chapter 11 (what the
state keeps *in plain text*) — what common thread ties the two together?
