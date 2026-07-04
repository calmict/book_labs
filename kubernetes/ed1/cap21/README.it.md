# Cap. 21 — La stagista e il robot (autenticazione e RBAC)

> Esercizio del **Capitolo 21 — Autenticazione e RBAC** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Avanzato

## Obiettivi

Al termine di questo laboratorio saprai:

- assumere un utente vero: chiave privata, CertificateSigningRequest firmata dalla CA del cluster, kubeconfig dedicato — e scoprire che gli utenti umani non sono oggetti dell'API: esistono solo nei certificati (CN = nome, O = gruppi);
- applicare il minimo privilegio con Role e RoleBinding, verificandone i confini: la stagista legge i pod di default e nient'altro — non li crea, non vede i secret, non esce dal namespace;
- dare un'identità a un Pod (ServiceAccount) e usarla dall'interno: il token montato, la chiamata all'API dal container, il 403 che diventa 200 con il binding giusto.

## Prerequisiti

- Cap. 9 completato (le quattro porte: qui si diventa il portiere).
- Il cluster book-labs acceso; openssl sull'host.
- Tre manifest in start/ coi TODO: rbac.yaml, robot.yaml e robot-binding.yaml (separato apposta: va applicato per ultimo).

## Consegna

1. Chi sei tu, oggi. Prima di assumere qualcuno, guarda i tuoi documenti:

       kubectl auth whoami

   kubernetes-admin, gruppi da amministratore: il passe-partout. Fine dell'era in cui era normale.

2. L'assunzione. Genera la chiave della stagista e la richiesta di firma, e sottoponila alla CA del cluster:

       openssl genrsa -out stagista.key 2048
       openssl req -new -key stagista.key -subj "/CN=stagista/O=tirocinanti" -out stagista.csr
       kubectl apply -f - <<RICHIESTA
       apiVersion: certificates.k8s.io/v1
       kind: CertificateSigningRequest
       metadata:
         name: stagista
       spec:
         request: $(base64 -w0 < stagista.csr)
         signerName: kubernetes.io/kube-apiserver-client
         expirationSeconds: 86400
         usages: ["client auth"]
       RICHIESTA
       kubectl get csr stagista

   Pending: la burocrazia attende una firma. Firmala tu (oggi sei ancora il capo del personale):

       kubectl certificate approve stagista
       kubectl get csr stagista -o jsonpath='{.status.certificate}' | base64 -d > stagista.crt

   Nota il punto filosofico: nessun oggetto "User" è stato creato. La stagista esiste solo in questo certificato — CN il nome, O i gruppi. (E scade in 24 ore: i certificati brevi sono una feature.)

3. Il suo kubeconfig. Costruiscile documenti separati dai tuoi (file stagista.kubeconfig):

       SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
       kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
       kubectl --kubeconfig stagista.kubeconfig config set-cluster lab --server $SERVER --certificate-authority ca.crt --embed-certs

   (Su minikube la CA è un file su disco, non dati inline — la lezione del cap. 9: se ca.crt esce vuoto, copia il percorso indicato da certificate-authority nel kubeconfig.)
       kubectl --kubeconfig stagista.kubeconfig config set-credentials stagista --client-certificate stagista.crt --client-key stagista.key --embed-certs
       kubectl --kubeconfig stagista.kubeconfig config set-context stagista --cluster lab --user stagista
       kubectl --kubeconfig stagista.kubeconfig config use-context stagista

   E falla entrare:

       kubectl --kubeconfig stagista.kubeconfig auth whoami
       kubectl --kubeconfig stagista.kubeconfig get pods

   Autenticata (whoami la riconosce, col suo gruppo tirocinanti) e respinta: Forbidden. Prima porta passata, seconda chiusa — assunta, ma senza mansioni.

4. Le mansioni minime. Completa start/rbac.yaml: un Role "pod-reader" (get, list, watch sui pods di default) e il RoleBinding che lo lega all'utente stagista. Applica e rifai i test, tutti:

       kubectl apply -f rbac.yaml
       kubectl --kubeconfig stagista.kubeconfig get pods
       kubectl --kubeconfig stagista.kubeconfig run test --image=alpine:3
       kubectl --kubeconfig stagista.kubeconfig get secrets
       kubectl --kubeconfig stagista.kubeconfig get pods -n kube-system
       kubectl --kubeconfig stagista.kubeconfig auth can-i --list

   Legge i pod; tutto il resto è Forbidden — compreso lo stesso verbo in un altro namespace: il Role è un permesso CON un confine. Annota il can-i --list: è la job description completa.

5. Il robot. Completa start/robot.yaml (il pod deve indossare il ServiceAccount robot: serviceAccountName) e applica; PRIMA di applicare il binding, prova dall'interno:

       kubectl apply -f robot.yaml
       kubectl exec robot -- sh -c 'curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes.default.svc/api/v1/namespaces/default/pods'

   403: "system:serviceaccount:default:robot cannot list". Ora completa start/robot-binding.yaml (soggetto ServiceAccount robot sul solito pod-reader), applicalo e ripeti la chiamata: una PodList. È il cap. 9 visto dal pod: il token è nel filesystem (montato e ruotato dal kubelet), l'identità è del workload, non di un umano.

6. Le domande per answers.md: (a) dove "esiste" la stagista? Racconta l'assunzione (chiave, CSR, firma, CN/O) e spiega perché gli utenti umani non sono oggetti API — vantaggi e conseguenze (revoca!); (b) la job description: leggi il tuo Role come tripla verbi-risorse-namespace, spiega i tre Forbidden del passo 4 e perché il minimo privilegio è fatto di confini più che di divieti; (c) stagista contro robot: le due autenticazioni a confronto (certificato vs token montato), chi rinnova cosa, e perché ogni workload dovrebbe avere il SUO ServiceAccount col SUO minimo.

7. Licenziamenti e pulizia:

       kubectl delete -f rbac.yaml -f robot.yaml -f robot-binding.yaml
       kubectl delete csr stagista
       rm -f stagista.key stagista.csr stagista.crt stagista.kubeconfig ca.crt

## Criteri di "fatto"

- [ ] La CSR è stata approvata e whoami riconosce la stagista (gruppo tirocinanti) dal suo kubeconfig.
- [ ] Prima del Role: Forbidden su tutto; dopo: get pods sì, create/secrets/kube-system ancora Forbidden.
- [ ] Il robot ha preso il 403 senza binding e la PodList col binding, usando il token montato.
- [ ] answers.md risponde alle tre domande.
- [ ] CSR, oggetti RBAC, robot e file locali rimossi.
