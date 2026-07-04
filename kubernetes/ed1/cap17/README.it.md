# Cap. 17 — I tre mestieri: uno per nodo, fino in fondo, a orario

> Esercizio del **Capitolo 17 — DaemonSet, Job e CronJob** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- leggere il DaemonSet come contratto geografico: nessun campo replicas — il numero lo decide il cluster, un guardiano per nodo (e la toleration del cap. 11 per coprire anche il control-plane);
- incontrare il primo oggetto che vuole finire: il Job, con la differenza tra riavviare un container e riprovare un Pod (backoffLimit), e il fallimento onesto di un Job che non ce la fa;
- vedere un CronJob timbrare il cartellino: la catena CronJob → Job → Pod, un minuto dopo l'apply.

## Prerequisiti

- Cap. 11-16 completati.
- **kind** e Docker: serve il cluster a 3 nodi (fornito start/kind-workers.yaml, nome book-labs-crew) — il DaemonSet senza più nodi non racconta niente. Occhio ai limiti inotify ([SETUP.md](../../SETUP.md)).
- Tre manifest in start/ coi TODO: watchman.yaml, jobs.yaml, tick.yaml.

## Consegna

1. Il cantiere. Crea il cluster a 3 nodi:

       kind create cluster --config start/kind-workers.yaml
       kubectl get nodes

2. Un guardiano per nodo. Completa start/watchman.yaml: un DaemonSet "watchman" (alpine:3, sleep infinity) — e nota cosa NON c'è nei TODO: nessun replicas. Applica e conta:

       kubectl apply -f watchman.yaml
       kubectl get pods -l app=watchman -o wide

   Due guardiani, uno per worker. Ma i nodi sono tre: chi manca all'appello, e perché? (Il cap. 11 te l'ha già detto: il taint del control-plane.) Aggiungi al template la toleration per node-role.kubernetes.io/control-plane e riapplica:

       kubectl get pods -l app=watchman -o wide

   Tre guardiani, tre nodi. Ora la prova del contratto geografico: cancella il guardiano di un worker e guarda dove rinasce:

       kubectl delete pod <watchman-di-un-worker>
       kubectl get pods -l app=watchman -o wide

   Stesso nodo. Non è un conteggio da ripristinare (cap. 7), è una mappa da rispettare.

3. Il lavoro che finisce. Completa start/jobs.yaml: due Job — "countdown" conta alla rovescia da 5 ed esce con 0 (restartPolicy Never è nei TODO: un Job non può avere Always... chiediti perché); "flaky" esce sempre con 1, backoffLimit 2. Applica e osserva i due destini:

       kubectl apply -f jobs.yaml
       kubectl get jobs -w

   countdown arriva a COMPLETIONS 1/1 e il suo pod resta lì, Completed, come ricevuta (leggigli i log: kubectl logs job/countdown). flaky invece riprova: guarda i pod moltiplicarsi (2 retry dopo il primo tentativo), poi il Job si arrende:

       kubectl get pods -l job-name=flaky
       kubectl describe job flaky | grep -A3 Conditions

   Failed, con il motivo: BackoffLimitExceeded. Il primo oggetto della collana che ha il diritto di fallire per sempre.

4. Il lavoro a orario. Completa start/tick.yaml: un CronJob "tick", schedule ogni minuto, che stampa la data. Applica e aspetta il timbro (fino a un minuto):

       kubectl apply -f tick.yaml
       kubectl get jobs -w

   Al minuto: nasce un Job tick-<timestamp>, che genera un Pod, che stampa e muore. Leggi la catena di comando:

       kubectl get jobs
       kubectl logs job/<il-job-nato>

   È la delega del cap. 13 con un piano in più: CronJob → Job → Pod.

5. Il quadro completo (§17.4): nelle domande chiuderai la tabella dei mestieri degli oggetti core.

   Le domande per answers.md: (a) dove sta scritto "quanti" in un DaemonSet? Spiega il contratto geografico con le tue prove (la rinascita sullo stesso nodo, il terzo guardiano arrivato con la toleration); (b) il Job e i suoi tentativi: perché restartPolicy Always è vietata, cosa conta il backoffLimit, e che differenza c'è tra il kubelet che riavvia un container (cap. 12) e il Job che crea un nuovo Pod? (c) la tabella dei mestieri: per ognuno dei 5 oggetti core (Deployment, StatefulSet, DaemonSet, Job, CronJob) scrivi una riga — chi lo usa, per cosa, e la domanda a cui risponde ("quante copie?", "chi sei?", "dove?", "è finito?", "quando?").

6. Smonta il cantiere:

       kind delete cluster --name book-labs-crew

## Criteri di "fatto"

- [ ] watchman: 2 guardiani prima della toleration, 3 dopo, e la rinascita sullo stesso nodo.
- [ ] countdown Completed con i log della conta; flaky Failed con BackoffLimitExceeded dopo 3 pod.
- [ ] Il primo timbro del CronJob: un Job tick-<timestamp> coi log della data.
- [ ] answers.md risponde alle tre domande (tabella dei mestieri inclusa).
- [ ] Il cluster book-labs-crew è stato cancellato.
