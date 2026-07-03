# Kubernetes — environment setup (non-binding)

This guide suggests a free, reproducible local cluster for the exercises. It is a
**suggestion**, not a requirement: any conformant Kubernetes you can reach with
kubectl works. Use what you are comfortable with.

## Option A — kind (Kubernetes in Docker)

Lightweight, fast, single command. Requires Docker.

    # install: https://kind.sigs.k8s.io
    kind create cluster --name book-labs
    kubectl cluster-info --context kind-book-labs

Tear down when done:

    kind delete cluster --name book-labs

## Option B — minikube

Full-featured local cluster with addons (ingress, dashboard…).

    # install: https://minikube.sigs.k8s.io
    minikube start
    kubectl get nodes

Tear down:

    minikube delete

## Option C — k3d (k3s in Docker)

Very light, good for quick iteration. Requires Docker.

    # install: https://k3d.io
    k3d cluster create book-labs
    kubectl get nodes

Tear down:

    k3d cluster delete book-labs

## Verifying you are ready

    kubectl version --output=yaml
    kubectl get nodes

If the last command shows a node in Ready state, you can start any exercise.

---

*IT — Questa guida suggerisce un cluster locale gratuito e riproducibile. È un
suggerimento, non un vincolo: va bene qualsiasi Kubernetes raggiungibile con
kubectl.*
