# Kubernetes — exercises

Practical labs for the Calm ICT **Kubernetes** manual.

> Status: scaffolding. The chapter index below is filled in as exercises are
> created from the manual sources.

## Recommended setup

These exercises run on a local, free Kubernetes cluster. See [SETUP.md](SETUP.md)
for a reproducible (non-binding) environment using kind / minikube / k3d.

## Editions

- **ed1/** — exercises cited by the 1st edition of the manual.

## Chapter index (ed1)

| Chapter | Title | Level | Folder |
|--------:|-------|:-----:|--------|
| 1 | A container is just a process (see it for yourself) | Foundational | [ed1/cap01](ed1/cap01/) |

## Pull only this manual

    git clone --filter=blob:none --sparse https://github.com/calmict/book_labs.git
    cd book_labs
    git sparse-checkout set kubernetes/ed1
