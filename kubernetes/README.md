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
| 2 | A container by hand, without Docker | Foundational | [ed1/cap02](ed1/cap02/) |
| 3 | Limiting CPU and RAM by hand | Foundational | [ed1/cap03](ed1/cap03/) |
| 4 | Dissect an image by hand (anatomy of a container) | Foundational | [ed1/cap04](ed1/cap04/) |
| 5 | Climb the runtime chain (and run a container with runc alone) | Foundational | [ed1/cap05](ed1/cap05/) |
| 6 | Wire two network namespaces by hand (veth, a bridge and a ping) | Foundational | [ed1/cap06](ed1/cap06/) |
| 7 | First contact: kill a Pod and watch who resurrects it | Foundational | [ed1/cap07](ed1/cap07/) |

## Pull only this manual

    git clone --filter=blob:none --sparse https://github.com/calmict/book_labs.git
    cd book_labs
    git sparse-checkout set kubernetes/ed1
