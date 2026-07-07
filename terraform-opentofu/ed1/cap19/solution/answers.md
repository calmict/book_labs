# Chapter 19 — Answers (model solution)

## Workspaces (Part A)

      default
      dev
    * prod
    # state per workspace: terraform.tfstate.d/dev/ and terraform.tfstate.d/prod/

## Separate directories (Part B)

    cap19dir-dev -> 0.0.0.0:8122->80/tcp
    cap19dir-prod -> 0.0.0.0:8123->80/tcp
    # after destroy dev: cap19dir-prod still running
    # prod plan: No changes. Your infrastructure matches the configuration.

## The three questions

**a. What an environment is.**

Three things distinguish dev from prod beyond the name: its settings (sizes,
ports, replica counts, feature flags — the knobs that differ), its credentials
and provider target (often a different account, region or cluster), and above all
its own separate state. Separate state matters most because the state is the
notebook that binds code to real objects (chapter 11) and the unit the lock and
the blast radius attach to (chapters 12 and 13): if dev and prod shared a state, a
dev apply could refresh, lock, corrupt or destroy prod resources, and a single
mistake would cross the environments. Chapter 13 already stated the principle with
the fire doors — environments must never share the blast radius — and everything
in this chapter is a way to honour it: separate state is not a convenience, it is
the wall.

**b. The drawer versus the room.**

The workspace risk is that the active workspace is a hidden piece of CLI state,
not something in the code: dev and prod live in the same directory, built from the
same files, against the same backend, and which one you are about to change is
decided by an invisible "current workspace". Type apply believing you are in dev
while prod is selected, and you hit production — nothing in the files stopped you.
Separate directories put a real wall between them: each environment is its own
folder with its own state and its own init, so you must physically cd into prod/
to touch prod, and a run in dev/ has no reference to prod at all. My destroy of dev
proved it operationally: after tearing dev down, prod's container was still
running and prod's own plan reported No changes — the dev command could not reach,
and did not even know about, the prod state. Isolation is not a promise here, it
is a property of the directory boundary.

**c. Terragrunt and the choice.**

Terragrunt solves the boilerplate cost of separate directories: the terraform
block, the provider configuration and the backend setup that otherwise get
copy-pasted into every environment folder. It generates them from a single root
file (with a per-environment state key), so the boilerplate has one source of
truth. What it does NOT solve — because it deliberately keeps it — is the
separation itself: each environment still has its own state and its own
plan/apply, so the walls stay up. It is DRY on top of isolation, not instead of
it. For an ephemeral test environment tied to a branch, I would choose the drawer
(a workspace): it is a throwaway variant of the same deploy, created and destroyed
in seconds with tofu workspace new/select, with no new directory or backend to
provision — exactly the case where sharing code and backend is a feature, not a
risk, because there is no production to protect from it.
