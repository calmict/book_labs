# Cap. 19 — Il portone e il portiere (Ingress e Ingress Controller)

> Esercizio del **Capitolo 19 — Ingress e Ingress Controller** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- capire perché i Service (L4) non bastano: l'Ingress legge ciò che loro non vedono — host e path;
- toccare la separazione dei ruoli con un esperimento: le regole Ingress applicate SENZA controller non fanno nulla — l'oggetto è la richiesta scritta, il controller è chi la esegue;
- installare ingress-nginx su kind e vedere il routing L7 dal vivo: due host sullo stesso IP e porta, ognuno alla sua app, e il default backend per gli sconosciuti.

## Prerequisiti

- Cap. 18 completato (Service e ClusterIP).
- **kind** e Docker: serve un cluster dedicato con la porta 8081 dell'host mappata (fornito start/kind-ingress.yaml; se la 8081 è occupata, cambiala lì). Primo capitolo che installa un componente esterno: serve rete per scaricare ingress-nginx. (Su minikube il percorso è diverso: addon ingress + minikube tunnel — qui si resta su kind.)
- Due manifest in start/: apps.yaml (dato completo) e ingress.yaml (le regole sono i TODO).

## Consegna

1. Il palazzo. Crea il cluster con la porta d'ingresso mappata e le due app coi loro Service:

       kind create cluster --config start/kind-ingress.yaml
       kubectl apply -f start/apps.yaml
       kubectl get pods,svc

   Due inquilini (uno e due, ognuno risponde col proprio nome) e i loro centralini interni (cap. 18). Ma dall'esterno del palazzo, nessuno li raggiunge.

2. La richiesta scritta, senza il portiere. Completa start/ingress.yaml: due regole host-based — uno.labs.local verso il service uno, due.labs.local verso il service due (i TODO guidano rules, host, backend). Applica e prova a bussare:

       kubectl apply -f ingress.yaml
       kubectl get ingress
       curl http://localhost:8081

   Connessione rifiutata, e la colonna ADDRESS dell'Ingress è vuota. Le regole sono scritte, protocollate... e ignorate: hai dichiarato un oggetto che nessun controller realizza. Kubernetes non protesta — è il pattern del cap. 10: gli oggetti sono desideri, i controller sono chi li esaudisce.

3. Arriva il portiere. Installa ingress-nginx nella variante per kind (versione pinnata):

       kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.0/deploy/static/provider/kind/deploy.yaml
       kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=300s
       kubectl get pods -n ingress-nginx

   Guarda cos'è il portiere: un Deployment come gli altri (nginx più un processo che osserva gli oggetti Ingress via watch — il cap. 9 — e riscrive la propria configurazione).

4. Il portone funziona. Stessa porta, stesso IP, due destinazioni:

       curl -H "Host: uno.labs.local" http://localhost:8081
       curl -H "Host: due.labs.local" http://localhost:8081
       curl http://localhost:8081

   app-uno, app-due, e un 404 per chi non dice il nome giusto: il routing L7 che nessun Service può fare (il Service vede solo IP e porta; l'header Host vive dentro l'HTTP). Riguarda anche kubectl get ingress: ora ADDRESS è popolata.

5. L'anatomia (19.4). Segui una richiesta nei log del portiere:

       kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=5

   Riconosci le tue curl: host, path, upstream scelto. Il viaggio completo: porta 8081 dell'host → porta 80 del nodo (extraPortMapping) → pod del controller (hostPort) → decisione L7 sull'header Host → Service dell'app (cap. 18: ClusterIP e moneta) → pod.

   Le domande per answers.md: (a) L4 contro L7: cosa vede un Service e cosa vede l'Ingress? Perché il routing per host è impossibile a livello 4? (b) l'esperimento del passo 2: perché Kubernetes accetta oggetti che nessuno realizza, e cosa hanno in comune Ingress-senza-controller e i controller del cap. 10? (rifletti: oggetti = desideri, controller = esecutori — è il pattern che rende il sistema estensibile); (c) l'anatomia completa: elenca le stazioni del viaggio dal tuo curl al pod di app-uno, indicando a ogni passaggio chi decide (portmapping, hostPort, nginx, ClusterIP...).

6. Smonta il palazzo:

       kind delete cluster --name book-labs-ingress

## Criteri di "fatto"

- [ ] Con le regole applicate ma senza controller: curl rifiutato e ADDRESS vuota.
- [ ] Dopo l'installazione: uno.labs.local → app-uno, due.labs.local → app-due, host ignoto → 404.
- [ ] Hai riconosciuto le tue richieste nei log del controller.
- [ ] answers.md risponde alle tre domande.
- [ ] Il cluster book-labs-ingress è stato cancellato.
