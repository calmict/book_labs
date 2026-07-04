# Cap. 22 — La cassaforte e il corridoio (NetworkPolicy e zero-trust)

> Esercizio del **Capitolo 22 — NetworkPolicy e l'approccio zero-trust** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Avanzato

## Obiettivi

Al termine di questo laboratorio saprai:

- toccare il problema del default allow: nel condominio Kubernetes ogni pod raggiunge ogni pod, cassaforte inclusa;
- invertire la regola con un default deny di tre righe, e poi riaprire SOLO la porta giusta: label come regole firewall, porte come contratto;
- chiudere anche l'uscita (egress): la cassaforte che riceve ma non telefona — e scoprire chi realizza davvero le policy (il CNI), con il test di enforcement come abitudine igienica.

## Prerequisiti

- Cap. 18 e 21 completati (Service e minimo privilegio: qui il minimo privilegio arriva alla rete).
- Il cluster book-labs acceso. ATTENZIONE: le NetworkPolicy le realizza il CNI — il kind recente le applica; su minikube standard NO (serve minikube start --cni=calico). Il passo 2 include il test per scoprirlo subito.
- Quattro manifest in start/: pods.yaml e deny-all.yaml (dati), allow-app.yaml e no-exfiltration.yaml (TODO).

## Consegna

1. Il corridoio aperto. Crea il namespace del laboratorio e i tre inquilini:

       kubectl create namespace vault
       kubectl apply -f pods.yaml
       kubectl -n vault get pods --show-labels

   safe (la cassaforte, etichetta app=safe, serve i gioielli sulla 8080), app (role=app, l'applicazione legittima) e guest (nessun ruolo). Prova ENTRAMBI gli accessi:

       SAFE=$(kubectl -n vault get pod safe -o jsonpath='{.status.podIP}')
       kubectl -n vault exec app -- wget -T 3 -qO- http://$SAFE:8080
       kubectl -n vault exec guest -- wget -T 3 -qO- http://$SAFE:8080

   Gioielli per tutti: default allow. Nessuno ha mai autorizzato niente — semplicemente, nessuno ha mai vietato.

2. L'inversione. deny-all.yaml è già scritto (leggilo: podSelector vuoto = tutti i pod del namespace, policyTypes Ingress, nessuna regola = nessun ingresso). Applicalo e rifai i due wget:

       kubectl apply -f deny-all.yaml
       kubectl -n vault exec app -- wget -T 3 -qO- http://$SAFE:8080
       kubectl -n vault exec guest -- wget -T 3 -qO- http://$SAFE:8080

   Timeout per entrambi: il corridoio è murato. Questo è anche il TEST DI ENFORCEMENT: se i gioielli arrivano ancora, il tuo CNI sta ignorando le policy (l'oggetto senza esecutore — il déjà vu del cap. 19) e devi cambiarlo prima di proseguire.

3. La porta con la targhetta. Completa allow-app.yaml: una policy che seleziona la cassaforte (app=safe) e ammette ingress SOLO dai pod role=app, SOLO sulla porta TCP 8080. Applica e riprova entrambi:

       kubectl apply -f allow-app.yaml
       kubectl -n vault exec app -- wget -T 3 -qO- http://$SAFE:8080
       kubectl -n vault exec guest -- wget -T 3 -qO- http://$SAFE:8080

   app passa, guest resta fuori. Nota la grammatica: le policy sono ADDITIVE — hai scritto un permesso, mai un divieto esplicito; il divieto è il silenzio.

4. La cassaforte non telefona. Completa no-exfiltration.yaml: policy su app=safe, policyTypes Egress, nessuna regola egress. Applica e prova la chiamata in uscita:

       kubectl apply -f no-exfiltration.yaml
       APP=$(kubectl -n vault get pod app -o jsonpath='{.status.podIP}')
       kubectl -n vault exec safe -- wget -T 3 -qO- http://$APP:8080

   Timeout: chi buca la cassaforte non può portare fuori niente. (Avvertenza da professionisti: un egress deny blocca anche il DNS — qui usiamo IP diretti; nel mondo reale si riapre la 53 verso kube-dns.)

5. Le domande per answers.md: (a) da default allow a default deny: perché la rete piatta è IL problema, cosa dice esattamente il podSelector vuoto, e perché nella grammatica delle policy esistono solo permessi (il deny è il silenzio); (b) leggi le tue tre policy come contratto di rete: chi parla con chi, su quale porta, e cosa servirebbe per far entrare guest — cambiare la policy o... cambiargli l'etichetta? Rifletti su cosa questo dice del modello; (c) chi realizza le policy? Racconta il test di enforcement e il déjà vu del cap. 19, spiega il ruolo del CNI (22.4) e l'avvertenza DNS dell'egress deny.

6. Smonta il caveau:

       kubectl delete namespace vault

## Criteri di "fatto"

- [ ] Prima delle policy: gioielli per tutti (default allow toccato con mano).
- [ ] Col deny-all: timeout per tutti — e il test di enforcement superato.
- [ ] Con allow-app: app dentro, guest fuori; con no-exfiltration: la cassaforte non chiama.
- [ ] answers.md risponde alle tre domande.
- [ ] Il namespace vault è stato cancellato.
