# Cap. 8 — Uccidi il leader: quorum ed elezioni in etcd

> Esercizio del **Capitolo 8 — Etcd e il consenso distribuito** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- avviare un cluster con 3 control-plane e interrogare i 3 membri etcd che ne custodiscono la memoria;
- vedere che ogni oggetto Kubernetes è letteralmente una chiave dentro etcd (/registry/...);
- assassinare il leader e assistere all'elezione del successore, col cluster che non perde un colpo;
- rompere il quorum e toccare con mano cosa significa "il cluster è congelato" — e poi riportarlo in vita.

## Prerequisiti

- Aver completato il cap. 7 (il cluster e il modello dichiarativo).
- **kind** e Docker: questo capitolo richiede kind (minikube non supporta più control-plane); i nodi kind sono container Docker, e questo diventerà la nostra arma.
- Circa 4 GB di RAM liberi: il cluster HA a 3 nodi è il più pesante della collana finora.
- Il file di configurazione è fornito in start/kind-ha.yaml.

> ⚠️ Se la creazione fallisce con il join dei nodi che va in timeout (etcd
> learner che non parte) o errori "too many open files", i limiti inotify del
> tuo host sono troppo bassi per 3 nodi: vedi la sezione Troubleshooting di
> [SETUP.md](../../SETUP.md).

## Consegna

1. Crea il cluster dedicato a 3 control-plane (dalla cartella dell'esercizio):

       kind create cluster --config start/kind-ha.yaml
       kubectl get nodes

   Tre nodi control-plane (e in Docker è comparso anche un load balancer: kind lo aggiunge da solo per smistare le richieste ai 3 apiserver).

2. La memoria è triplicata: tre pod etcd, uno per nodo. Prepara la chiave inglese per interrogarli (etcdctl dentro il pod, con i certificati del cluster):

       kubectl get pods -n kube-system | grep etcd
       ETCD="kubectl exec -n kube-system etcd-book-labs-ha-control-plane -- etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key"
       $ETCD member list -w table
       $ETCD endpoint status --cluster -w table

   Nella colonna IS LEADER c'è un solo true: annota chi comanda e su quale IP.

3. Kubernetes vive letteralmente qui dentro. Crea un oggetto e ritrovalo come chiave:

       kubectl create namespace raft-lab
       $ETCD get /registry/namespaces/raft-lab --keys-only
       $ETCD get /registry/namespaces --prefix --keys-only

   Ogni kubectl create del cap. 7 non era che un put su questo database.

4. L'assassinio. Scopri quale nodo ospita il leader (confronta l'IP del leader con kubectl get nodes -o wide) e congelalo — i nodi kind sono container, e li metteremo in pausa invece di spegnerli (spegnendoli, Docker potrebbe riassegnare gli IP alla riaccensione, e le identità dei membri etcd sono legate agli IP):

       kubectl get nodes -o wide
       docker pause <nodo-del-leader>

   Ora interroga un superstite (aggiorna ETCD col nome di un pod etcd vivo) e guarda le elezioni già avvenute:

       $ETCD endpoint status --cluster -w table

   Un nuovo leader, eletto in una frazione di secondo. E il cluster? kubectl get nodes funziona ancora: 2 su 3 è maggioranza, la democrazia regge.

5. La rottura del quorum. Congela un secondo nodo (uno dei due superstiti) e riprova:

       docker pause <secondo-nodo>
       kubectl get namespaces --request-timeout=5s

   Errore: con 1 membro su 3 non c'è maggioranza, e senza maggioranza etcd non risponde né alle scritture né alle letture consistenti. Il cluster non è morto: è congelato, in attesa di poter di nuovo garantire la verità.

6. La resurrezione: scongela i due nodi e verifica il ritorno alla normalità:

       docker unpause <nodo-del-leader> <secondo-nodo>
       kubectl get namespaces
       $ETCD endpoint status --cluster -w table

   Tre membri, un leader, e il namespace raft-lab mai andato perso: era replicato su tutti.

   Le tre domande per answers.md: (a) perché 3 membri tollerano la perdita di 1 solo? Quanti ne tollererebbe un cluster da 5? Scrivi la regola generale, e spiega perché 2 membri sono peggio di 1. (b) racconta l'elezione del passo 4: chi ha eletto il nuovo leader, e su quale base? Perché Kubernetes ha continuato a rispondere come se nulla fosse? (c) durante il congelamento del passo 5, i container già in esecuzione sul nodo superstite hanno continuato a girare? Perché il "cervello congelato" non ferma le "braccia"?

7. Smonta il laboratorio (solo il cluster HA: quello del cap. 7 resta tuo):

       kind delete cluster --name book-labs-ha

## Criteri di "fatto"

- [ ] Hai visto 3 membri etcd con un solo IS LEADER=true e annotato chi era.
- [ ] Hai trovato il namespace raft-lab come chiave /registry/... dentro etcd.
- [ ] Dopo la pausa del leader hai visto un nuovo leader e kubectl ancora funzionante.
- [ ] Con 2 nodi congelati hai ottenuto l'errore da quorum perso, e dopo l'unpause il cluster è tornato integro con raft-lab al suo posto.
- [ ] answers.md risponde alle tre domande e il cluster book-labs-ha è stato cancellato.
