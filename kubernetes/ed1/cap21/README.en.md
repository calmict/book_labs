# Chapter 21 — The Intern and the Robot (Authentication and RBAC)

> Exercise for **Chapter 21 — Authentication and RBAC** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Advanced

## Objectives

By the end of this lab you will be able to:

- hire a real user: private key, CertificateSigningRequest signed by the cluster CA, dedicated kubeconfig — discovering that human users are not API objects: they exist only in certificates (CN = name, O = groups);
- apply least privilege with Role and RoleBinding, and verify its borders: the intern reads pods in default and nothing else — cannot create them, cannot see secrets, cannot leave the namespace;
- give a Pod an identity (ServiceAccount) and use it from inside: the mounted token, the API call from the container, the 403 that becomes a 200 with the right binding.

## Prerequisites

- Chapter 9 completed (the four gates: now you become the gatekeeper).
- The book-labs cluster running; openssl on the host.
- Three manifests in start/ with TODOs: rbac.yaml, robot.yaml and robot-binding.yaml (kept separate on purpose: it goes last).

## Instructions

1. Who you are, today. Before hiring anyone, look at your own papers:

       kubectl auth whoami

   kubernetes-admin, administrator groups: the skeleton key. The end of the era when that was normal.

2. The hiring. Generate the intern's key and signing request, and submit it to the cluster CA:

       openssl genrsa -out stagista.key 2048
       openssl req -new -key stagista.key -subj "/CN=stagista/O=tirocinanti" -out stagista.csr
       kubectl apply -f - <<REQUEST
       apiVersion: certificates.k8s.io/v1
       kind: CertificateSigningRequest
       metadata:
         name: stagista
       spec:
         request: $(base64 -w0 < stagista.csr)
         signerName: kubernetes.io/kube-apiserver-client
         expirationSeconds: 86400
         usages: ["client auth"]
       REQUEST
       kubectl get csr stagista

   Pending: the paperwork awaits a signature. Sign it yourself (today you are still head of HR):

       kubectl certificate approve stagista
       kubectl get csr stagista -o jsonpath='{.status.certificate}' | base64 -d > stagista.crt

   Note the philosophical point: no "User" object was created. The intern exists only in this certificate — CN the name, O the groups. (And it expires in 24 hours: short-lived certificates are a feature.)

3. Her own kubeconfig. Build her papers separate from yours (file stagista.kubeconfig):

       SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
       kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
       kubectl --kubeconfig stagista.kubeconfig config set-cluster lab --server $SERVER --certificate-authority ca.crt --embed-certs

   (On minikube the CA is a file on disk, not inline data — chapter 9's lesson: if ca.crt comes out empty, copy the path shown by certificate-authority in the kubeconfig.)
       kubectl --kubeconfig stagista.kubeconfig config set-credentials stagista --client-certificate stagista.crt --client-key stagista.key --embed-certs
       kubectl --kubeconfig stagista.kubeconfig config set-context stagista --cluster lab --user stagista
       kubectl --kubeconfig stagista.kubeconfig config use-context stagista

   And let her in:

       kubectl --kubeconfig stagista.kubeconfig auth whoami
       kubectl --kubeconfig stagista.kubeconfig get pods

   Authenticated (whoami recognises her, with her tirocinanti group) and rejected: Forbidden. First gate passed, second gate shut — hired, but with no duties.

4. The minimal duties. Complete start/rbac.yaml: a "pod-reader" Role (get, list, watch on pods in default) and the RoleBinding tying it to user stagista. Apply and redo every test:

       kubectl apply -f rbac.yaml
       kubectl --kubeconfig stagista.kubeconfig get pods
       kubectl --kubeconfig stagista.kubeconfig run test --image=alpine:3
       kubectl --kubeconfig stagista.kubeconfig get secrets
       kubectl --kubeconfig stagista.kubeconfig get pods -n kube-system
       kubectl --kubeconfig stagista.kubeconfig auth can-i --list

   She reads pods; everything else is Forbidden — including the same verb in another namespace: a Role is a permission WITH a border. Note the can-i --list: the complete job description.

5. The robot. Complete start/robot.yaml (the pod must wear the robot ServiceAccount: serviceAccountName) and apply; BEFORE applying the binding, try from inside:

       kubectl apply -f robot.yaml
       kubectl exec robot -- sh -c 'curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes.default.svc/api/v1/namespaces/default/pods'

   403: "system:serviceaccount:default:robot cannot list". Now complete start/robot-binding.yaml (ServiceAccount robot as subject on the same pod-reader), apply it and repeat the call: a PodList. Chapter 9 seen from inside the pod: the token lives in the filesystem (mounted and rotated by the kubelet), the identity belongs to the workload, not to a human.

6. The questions for answers.md: (a) where does the intern "exist"? Tell the hiring story (key, CSR, signature, CN/O) and explain why human users are not API objects — benefits and consequences (revocation!); (b) the job description: read your Role as a verbs-resources-namespace triple, explain the three Forbidden of step 4, and why least privilege is made of borders more than prohibitions; (c) intern versus robot: the two authentications compared (certificate vs mounted token), who renews what, and why every workload should have its OWN ServiceAccount with its OWN minimum.

7. Layoffs and cleanup:

       kubectl delete -f rbac.yaml -f robot.yaml -f robot-binding.yaml
       kubectl delete csr stagista
       rm -f stagista.key stagista.csr stagista.crt stagista.kubeconfig ca.crt

## Definition of "done"

- [ ] The CSR was approved and whoami recognises the intern (tirocinanti group) from her kubeconfig.
- [ ] Before the Role: Forbidden on everything; after: get pods yes, create/secrets/kube-system still Forbidden.
- [ ] The robot got the 403 without the binding and the PodList with it, using the mounted token.
- [ ] answers.md answers the three questions.
- [ ] CSR, RBAC objects, robot and local files removed.
