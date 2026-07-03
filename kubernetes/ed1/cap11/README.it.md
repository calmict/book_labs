# Cap. 11 — Guida lo scheduler (e poi scavalcalo)

> Esercizio del **Capitolo 11 — Lo Scheduler** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- dimostrare cosa fa davvero lo scheduler (sceglie e scrive il nodo) e cosa non fa — al punto da scavalcarlo del tutto con un Pod che non lo incontra mai;
- vedere il filtering in azione: un Pod respinto da tutti i nodi resta Pending, e il motivo è scritto negli eventi;
- guidare le scelte con nodeSelector e anti-affinity, e capire i taint come respingimento (con la toleration che riapre la porta).

## Prerequisiti

- Cap. 7-10 completati.
- kind e Docker: serve un cluster dedicato con 2 worker (fornito start/kind-workers.yaml); come per il cap. 8, occhio ai limiti inotify (Troubleshooting di [SETUP.md](../../SETUP.md)).
- I manifest di partenza in start/ hanno dei TODO da completare.

## Consegna

1. Crea il cluster a 3 nodi e osserva la geografia:

       kind create cluster --config start/kind-workers.yaml
       kubectl get nodes

   Un control-plane e due worker. Prima domanda da tenere a mente: perché nei prossimi passi nessun Pod finirà mai sul control-plane?

2. Lo scheduler al lavoro. Crea un Pod qualsiasi e cerca la firma dell'artista:

       kubectl run witness --image=alpine:3 -- sleep infinity
       kubectl get pod witness -o wide
       kubectl describe pod witness

   Negli eventi c'è la riga Scheduled con la firma default-scheduler: ha scelto un worker (filtering + scoring) e ha scritto la sua decisione. Annota il nodo.

3. Ora scavalcalo. Completa start/pod-bypass.yaml: c'è un TODO dove indicare direttamente spec.nodeName (usa il worker che vuoi). Poi:

       kubectl apply -f pod-bypass.yaml
       kubectl describe pod bypass

   Il Pod gira, ma negli eventi NON c'è nessuna riga Scheduled: assegnando tu il nodo, lo scheduler non è mai stato interpellato — il kubelet di quel nodo ha visto il Pod assegnato e l'ha eseguito. Ecco "cosa non fa" lo scheduler: eseguire. Lui decide soltanto.

4. Il filtering che respinge. Completa start/pod-picky.yaml: il TODO è un nodeSelector con disk: ssd. Applicalo e osserva:

       kubectl apply -f pod-picky.yaml
       kubectl get pod picky
       kubectl describe pod picky

   Pending, e il motivo è nero su bianco: nessun nodo supera il filtro (0/3 nodes available... didn't match). Ora crea l'unico nodo degno ed etichettalo:

       kubectl label node <un-worker> disk=ssd
       kubectl get pod picky -o wide

   Sbloccato, ed esattamente sul nodo etichettato. Il filtering non è magia: è un colino.

5. L'anti-affinity che sparpaglia. Completa start/deploy-spread.yaml: il TODO è il blocco podAntiAffinity (required, topologyKey kubernetes.io/hostname) su un Deployment da 2 repliche. Applica e verifica:

       kubectl apply -f deploy-spread.yaml
       kubectl get pods -l app=spread -o wide

   Una replica per worker. Ora chiedi l'impossibile:

       kubectl scale deployment spread --replicas=3
       kubectl get pods -l app=spread -o wide

   La terza resta Pending: due worker sono occupati dalle sorelle, e il terzo nodo... perché non va sul control-plane?

6. Il taint: respingere invece di attrarre. Guarda cosa protegge il control-plane:

       kubectl describe node book-labs-sched-control-plane | grep -A2 Taints

   Eccolo: node-role.kubernetes.io/control-plane:NoSchedule. Le etichette e le affinity attraggono; il taint respinge chiunque non abbia il permesso scritto. Concedi il permesso alla terza replica: aggiungi al template del Deployment la toleration per quel taint (chiave, operator Exists, effetto NoSchedule), porta replicas a 3 nel manifest e riapplica. La terza replica ora atterra proprio sul control-plane.

   Le tre domande per answers.md: (a) cosa fa davvero lo scheduler e cosa hai dimostrato col Pod bypass? Chi ha eseguito quel Pod, se lo scheduler non l'ha mai visto? (b) racconta il viaggio del Pod picky: cosa l'ha tenuto Pending, cosa l'ha sbloccato, e dove agiscono filtering e scoring; (c) spiega la differenza di verso tra affinity e taint (attrarre vs respingere) usando la terza replica come prova: cosa le mancava prima della toleration?

7. Smonta il laboratorio (solo il cluster dedicato):

       kind delete cluster --name book-labs-sched

## Criteri di "fatto"

- [ ] Hai l'evento Scheduled firmato default-scheduler per witness, e la sua assenza per bypass.
- [ ] Hai visto picky Pending con il motivo del filtro, e poi Running sul nodo etichettato.
- [ ] Le 2 repliche spread stanno su worker diversi, e la terza è passata da Pending al control-plane grazie alla toleration.
- [ ] answers.md risponde alle tre domande.
- [ ] Il cluster book-labs-sched è stato cancellato.
