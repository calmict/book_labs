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
| 8 | Kill the leader: quorum and elections in etcd | Foundational | [ed1/cap08](ed1/cap08/) |
| 9 | Knock at the four gates (the API server, bare-handed) | Foundational | [ed1/cap09](ed1/cap09/) |
| 10 | Write your own controller in twenty lines | Foundational | [ed1/cap10](ed1/cap10/) |
| 11 | Steer the scheduler (then bypass it) | Foundational | [ed1/cap11](ed1/cap11/) |
| 12 | The ship's doctor: probes, restarts and the self-resurrecting pod | Foundational | [ed1/cap12](ed1/cap12/) |
| 13 | The investigation: who touched my pod? | Intermediate | [ed1/cap13](ed1/cap13/) |
| 14 | The condo pod: two tenants, one invisible janitor | Intermediate | [ed1/cap14](ed1/cap14/) |
| 15 | The release, the disaster and the comeback (rollout and rollback) | Intermediate | [ed1/cap15](ed1/cap15/) |
| 16 | The registry office: names, order and disks that survive | Intermediate | [ed1/cap16](ed1/cap16/) |
| 17 | The three trades: one per node, until done, on schedule | Intermediate | [ed1/cap17](ed1/cap17/) |
| 18 | The address that does not exist (Services and kube-proxy) | Intermediate | [ed1/cap18](ed1/cap18/) |
| 19 | The door and the doorman (Ingress and Ingress Controller) | Intermediate | [ed1/cap19](ed1/cap19/) |

## Pull only this manual

    git clone --filter=blob:none --sparse https://github.com/calmict/book_labs.git
    cd book_labs
    git sparse-checkout set kubernetes/ed1
