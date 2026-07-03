# Cap. 9 — Bussa alle quattro porte (l'API server a mani nude)

> Esercizio del **Capitolo 9 — API Server: l'unico punto di verità** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- parlare con l'API server senza kubectl, con un semplice curl, e riconoscere gruppi, versioni e risorse dell'API REST;
- attraversare consapevolmente le porte di una richiesta: respinto all'autenticazione (401), respinto all'autorizzazione (403), respinto dall'admission (quota) e infine accolto;
- usare un watch per vedere in streaming gli eventi con cui il cluster resta sincronizzato.

## Prerequisiti

- Aver completato i cap. 7-8; il cluster book-labs del cap. 7 acceso (kubectl get nodes deve rispondere).
- curl e base64 (presenti su qualsiasi Linux).

## Consegna

1. Il centralino risponde anche senza kubectl. In un terminale apri il tunnel:

       kubectl proxy

   e in un secondo terminale esplora l'API REST come un sito web (9.1):

       curl -s http://127.0.0.1:8001/api
       curl -s http://127.0.0.1:8001/apis | head -30
       curl -s http://127.0.0.1:8001/apis/apps/v1 | head -30

   Riconosci il gruppo "core" (/api/v1) e i gruppi con nome (apps, batch...): sono le stesse coordinate di kubectl api-resources del cap. 7.

2. Prima porta: bussare senza documenti. Prendi l'indirizzo vero del server e presentati senza credenziali:

       kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
       curl -sk https://<quell-indirizzo>/api/v1/namespaces

   Risposta 401/403 per l'utente anonimo: la porta dell'autenticazione è chiusa. (Il -k serve solo a ignorare la CA per ora.)

3. Con i documenti in mano. Estrai i tuoi certificati dal kubeconfig e ripresentati:

       kubectl config view --raw --minify -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d > client.crt
       kubectl config view --raw --minify -o jsonpath='{.users[0].user.client-key-data}' | base64 -d > client.key
       kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
       curl -s --cert client.crt --key client.key --cacert ca.crt https://<indirizzo>/api/v1/namespaces | head -15

   Eccoti dentro: kubectl non ha mai fatto altro che questo. (Con minikube i certificati sono già file su disco: trovi i percorsi al posto dei dati nel kubeconfig.)

4. Seconda porta: autenticato non vuol dire autorizzato. Chiedi al cluster cosa puoi fare, poi impersona un'identità più umile:

       kubectl auth can-i create pods
       kubectl get pods --as=system:serviceaccount:default:default

   Forbidden: la richiesta è entrata (autenticata!) ma la seconda porta l'ha respinta. Nota la differenza col 401 del passo 2.

5. Terza porta: l'admission. Anche chi è autenticato e autorizzato può essere respinto nel merito. Costruisci il buttafuori:

       kubectl create namespace quota-lab
       kubectl create quota one-pod-only --hard=pods=1 -n quota-lab
       kubectl run sleeper1 -n quota-lab --image=alpine:3 -- sleep infinity
       kubectl run sleeper2 -n quota-lab --image=alpine:3 -- sleep infinity

   Il secondo Pod è respinto con "exceeded quota": è il plugin di admission ResourceQuota, che parla DOPO le prime due porte. Rileggi l'errore: è un 403, ma di natura diversa da quello del passo 4.

6. Il segreto della sincronizzazione: il watch (9.4). Con il proxy del passo 1 ancora attivo:

       curl -sN "http://127.0.0.1:8001/api/v1/namespaces?watch=1"

   e dall'altro terminale crea e cancella un namespace:

       kubectl create namespace watch-lab
       kubectl delete namespace watch-lab

   Guarda lo stream: eventi ADDED, MODIFIED, DELETED in tempo reale. È questa connessione, non un polling, che tiene sincronizzati controller, scheduler e kubelet. Chiudi il curl con Ctrl-C.

7. Rispondi in answers.md e smonta:

       kubectl delete namespace quota-lab
       rm -f client.crt client.key ca.crt

   (e ferma il kubectl proxy con Ctrl-C). Le tre domande: (a) ricostruisci il viaggio di una richiesta attraverso le porte del §9.2 usando le prove raccolte: a quale porta corrispondono il 401/403 del passo 2, il Forbidden del passo 4, l'exceeded quota del passo 5? (b) 401 contro 403: chi li emette e cosa dicono di diverso? (c) perché il watch del passo 6 è più efficiente di un polling, e cosa c'entra col reconciliation loop del cap. 7?

## Criteri di "fatto"

- [ ] Hai esplorato /api e /apis via curl e riconosciuto gruppi e versioni.
- [ ] Hai collezionato la sequenza completa: respinto da anonimo → 200 coi certificati → Forbidden impersonando → exceeded quota.
- [ ] Hai visto nello stream del watch gli eventi ADDED e DELETED di watch-lab.
- [ ] answers.md risponde alle tre domande.
- [ ] Namespace quota-lab rimosso, certificati estratti cancellati, proxy chiuso.
