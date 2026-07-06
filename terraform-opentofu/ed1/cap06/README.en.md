# Chapter 6 — The first stone

**Level:** Foundational
**Estimated time:** 45–55 minutes
**Manual topics:** Terraform and OpenTofu: two binaries, one language (6.1), installation (6.2), the first complete configuration: terraform block, provider, resource (6.3), the lifecycle: init, plan, apply, destroy (6.4), the everyday accessory commands (6.5), what we have built (6.6)

## The idea

Five chapters of concepts and guided exercises: now you lay your own first
stone. In this exercise you write from scratch — line by line, no more
placeholders — your first complete configuration: the terraform block that
declares the translators, the provider block that configures them, the
resources, an output. The result is not a file on disk: it is a real web
service, reachable with a browser, switched on from code.

And above all you live the lifecycle in slow motion, looking where so far
you rushed past: what init *really* downloads (you will go and weigh the
provider binary inside .terraform: surprise), what a saved plan is and why
executing it asks for no confirmation, which everyday questions are
answered by state list, show and output, and what destroy demolishes — and
what it leaves standing.

## Goals

By the end you will be able to:

- explain "two binaries, one language": where the binary you installed
  ends and where the providers that init installs begin;
- write a complete configuration: terraform, provider, resource, output;
- use the saved plan (plan -out + apply of the file) and say why it asks
  for no confirmation;
- answer the three everyday questions with state list, show and output;
- state precisely what destroy removes and what it does not.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md.
- Docker running (as in chapter 3).
- Port 8087 free (if it is taken, pick another one and keep it for the
  whole exercise).

## Your task

### Phase 0 — The two binaries

Before building, look at the tool:

    tofu version
    which tofu

That binary you installed yourself (manual chapter 6.2: package, archive
or manager, whichever). It is the only manual installation in the whole
ecosystem: the providers — the translators towards Docker, AWS, and the
rest of the world — init will install by itself, shortly. And had it been
terraform instead of tofu, everything that follows would be identical:
same language, same cycle, same providers.

### Phase 1 — The first complete configuration (you write it all)

In start/ you will find main.tf almost empty: only the comments guiding
you. Write it yourself, block by block, validating at every step (tofu
validate):

The terraform block — who translates:

    terraform {
      required_providers {
        docker = {
          source  = "kreuzwerker/docker"
          version = "~> 3.0"
        }
      }
    }

The provider block — how to talk to it (empty = the default local Docker):

    provider "docker" {}

The resources — what must exist:

    resource "docker_image" "web" {
      name         = "nginx:1.27-alpine"
      keep_locally = true
    }

    resource "docker_container" "web" {
      name  = "cap06-web"
      image = docker_image.web.image_id

      ports {
        internal = 80
        external = 8087
      }
    }

The output — what to expose to whoever looks from outside:

    output "url" {
      value = "http://localhost:8087"
    }

Note, as you write, that you are using the whole grammar of chapter 5:
labelled blocks, nested blocks (ports, no equals sign), arguments, and a
reference that draws an edge in chapter 4's graph.

### Phase 2 — init, under the lens

    cd start
    tofu init

This time do not rush past: look at what appeared.

    ls -a
    find .terraform -name 'terraform-provider-*' -exec du -h {} \;
    cat .terraform.lock.hcl

Inside .terraform sits the docker provider's binary: weigh it — tens of
megabytes. *This* is the translators' installation: your binary somewhere
in the PATH, the providers here, per working directory. The
.terraform.lock.hcl file is the register of the exact versions chosen (it
is chapter 7's protagonist: for now know that it exists and is not to be
touched). Run init a second time: it finishes in a flash — idempotent,
like everything around here.

### Phase 3 — The saved plan

So far you used the "interactive" apply: it computes the plan, shows it,
asks for confirmation. There is a second way, and it is the way of serious
systems:

    tofu plan -out=first.plan

Read the plan calmly: 2 to add, and next to the not-yet-knowable
attributes the wording (known after apply). Then execute it:

    tofu apply first.plan

No questions. It is not impudence: a saved plan is a contract — apply
executes *exactly* what is written in the file, no more, no less. Had the
world changed in the meantime, the execution would fail rather than
improvise. (Keep it in mind: plan -out under review, apply of the approved
file — it is the heart of chapter 22's pipelines.)

The first stone is laid:

    curl http://localhost:8087

Welcome home: Welcome to nginx!, switched on from code.

### Phase 4 — The three everyday questions

Three commands, three everyday questions:

    tofu state list

"What am I managing?" — the list of resources under contract: your two,
nothing more (other containers running on the same machine are not there:
they are not yours).

    tofu show | head -20

"What does the reality I manage look like, in detail?" — the complete
photograph, attribute by attribute, including the ones you never wrote
(the provider filled in the defaults).

    tofu output
    tofu output -raw url

"What did I promise to expose?" — the outputs, in readable or raw form
(-raw, perfect for scripts).

### Phase 5 — One change, as a recap

Bring the external port from 8087 to 8088 in main.tf, then:

    tofu plan

Stop: must be replaced, and next to the port the # forces replacement
marker. That is chapter 3 knocking: the published port is contended
identity, it cannot change on a living container. Apply and verify:

    tofu apply
    curl http://localhost:8088

### Phase 6 — The demolition (and what remains)

    tofu destroy
    tofu state list
    ls -a

The state is empty and the container no longer exists — but .terraform,
the lock file and your main.tf are still there. destroy demolishes the
infrastructure, not the architect's studio: the project, the installed
translators and the version register remain, ready for the next apply.

### Cleanup

Already done: Phase 6's destroy was the cleanup. The nginx images stay on
disk (keep_locally); docker rmi if you want them gone.

## Definition of done

- You wrote the whole main.tf yourself, and tofu validate passed after
  every block.
- You found and weighed the provider binary inside .terraform (tens of
  MB) and watched .terraform.lock.hcl being born.
- tofu apply first.plan started without asking for confirmation, and curl
  on 8087 answered with the welcome page.
- The port change produced a replace (# forces replacement marker), not
  an update.
- After the destroy: state list empty, but .terraform and the lock file
  still present.
- You answered the three questions in answers.md.

## The three questions

**a.** Two binaries, one language — and two installations: what did you
install, and what did init install (where, and how heavy)? Why does this
split — a small core and translators downloaded per directory — make
sense? And what would change, across the whole exercise, using terraform
instead of tofu?

**b.** The saved plan: why did tofu apply first.plan ask for no
confirmation, while tofu apply alone does? What *is* that file — and why
is "it executes exactly what is written" a precious guarantee when a
review and an approval happen between the plan and the execution?

**c.** The three everyday questions: match state list, show and output to
the question each answers, and explain why state list does NOT show other
people's containers running on the same machine. Finally the destroy:
what did it remove and what did it leave, and why is that asymmetry
exactly what you want?
