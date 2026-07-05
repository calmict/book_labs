# Cap. 28 — Il passaporto del portiere (Ingress-Nginx e Cert-Manager)

> Esercizio del **Capitolo 28 — Ingress-Nginx e Cert-Manager: TLS automatico** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Cloud Architect

## Obiettivi

Al termine di questo laboratorio saprai:

- inquadrare il problema dei certificati TLS: il portiere (Ingress-Nginx del cap. 19) deve provare l'identità del palazzo a ogni visitatore via HTTPS, ma i certificati si generano, si installano e — soprattutto — scadono;
- montare una fabbrica di passaporti automatica con Cert-Manager: un'autorità (CA), e certificati emessi e rinnovati da soli;
- ottenere HTTPS end-to-end con una sola annotazione sull'Ingress, e verificare il certificato contro la tua CA — capendo dove, in produzione, entrerebbe Let's Encrypt via ACME.

## Prerequisiti

- Cap. 19 (Ingress e Ingress Controller: il portiere che instrada per host; qui gli diamo il passaporto TLS). Familiarità con Deployment/Service/Ingress.
- kind installato. ATTENZIONE: ingress-nginx e cert-manager installano risorse cluster-wide (CRD, webhook); come nei cap. 26–27 il lab usa un cluster dedicato usa-e-getta (book-labs-tls), cancellato a fine lavoro.
- In start/: issuer.yaml (dato, la catena SelfSigned→CA→CA issuer), app.yaml (dato, il negozio dietro il portiere) e ingress.yaml (TODO, l'Ingress da rendere HTTPS).

## Consegna

1. La fabbrica dei passaporti. Crea il cluster, etichetta il nodo per l'ingress, installa portiere e fabbrica, poi costruisci l'autorità locale:

       kind create cluster --name book-labs-tls
       kubectl label node book-labs-tls-control-plane ingress-ready=true
       kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.0/deploy/static/provider/kind/deploy.yaml
       kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
       kubectl -n ingress-nginx wait --for=condition=Available deploy/ingress-nginx-controller --timeout=180s
       kubectl -n cert-manager wait --for=condition=Available deploy --all --timeout=180s
       kubectl apply -f issuer.yaml

   issuer.yaml costruisce l'autorità: un ClusterIssuer SelfSigned firma un certificato CA (la radice di fiducia locale), e un secondo ClusterIssuer usa quella CA per firmare i certificati veri. In produzione questa autorità sarebbe Let's Encrypt via ACME; qui, senza un DNS pubblico, siamo noi la nostra autorità.

2. Un passaporto chiesto da solo. Completa ingress.yaml: aggiungi l'annotazione cert-manager.io/cluster-issuer: local-ca e una sezione tls che indichi l'host (shop.book-labs.local) e il nome del Secret dove finirà il certificato (shop-tls). Applica app e ingress:

       kubectl apply -f app.yaml
       kubectl apply -f ingress.yaml
       kubectl -n web get certificate,secret shop-tls

   In pochi secondi Cert-Manager, visto l'Ingress, crea da solo un oggetto Certificate e lo emette nel Secret shop-tls (tipo kubernetes.io/tls). Non hai generato né una chiave né un certificato: li ha chiesti e firmati la fabbrica.

3. Il visitatore controlla il passaporto. Chiama il negozio in HTTPS, validando contro la TUA CA (niente -k). L'ingress è raggiungibile via ClusterIP: usa il client interno con la CA montata:

       IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
       kubectl -n web exec tlsclient -- curl -sS --cacert /ca/ca.crt --resolve shop.book-labs.local:443:$IP https://shop.book-labs.local/
       kubectl -n web get secret shop-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer -ext subjectAltName

   Risposta secure shop su HTTPS, e il certificato mostra issuer=book-labs-local-ca (la tua CA) e la SAN shop.book-labs.local, che Cert-Manager ha riempito da solo leggendo l'host dell'Ingress. HTTPS end-to-end, automatico e rinnovabile.

4. Il quadro completo (28.4). Portiere + fabbrica + autorità: una richiesta HTTP arriva al controller, viene servita in TLS con un certificato che nessuno ha creato a mano e che Cert-Manager rinnoverà prima della scadenza. In produzione basta cambiare l'issuer da CA locale a un issuer ACME (Let's Encrypt) e lo stesso identico Ingress ottiene un certificato valido pubblicamente.

5. Smonta il cantiere:

       kind delete cluster --name book-labs-tls

## Le domande per answers.md

- (a) Il problema dei certificati (28.1–28.2). Perché servire in HTTPS richiede un certificato firmato da un'autorità di cui il client si fida, e perché farlo a mano è un problema (generazione, installazione, e soprattutto la scadenza/rinnovo)? Che ruolo ha qui il portiere Ingress-Nginx del cap. 19?
- (b) Cert-Manager e ACME (28.3). Cosa fa Cert-Manager quando vede l'annotazione sull'Ingress, e cos'è l'oggetto Certificate? Spiega la catena SelfSigned→CA→certificato foglia che hai costruito. Cos'è il protocollo ACME e perché in produzione l'autorità sarebbe Let's Encrypt e non tu: cosa serve (che qui manca) perché ACME funzioni?
- (c) Il quadro completo (28.4). Racconta il percorso di una richiesta dal visitatore al negozio in HTTPS. Da dove è spuntata la SAN del certificato? E cosa cambierebbe, e cosa NO, passando dalla CA locale a un issuer ACME reale?

## Criteri di "fatto"

- [ ] ingress-nginx e cert-manager in esecuzione; la catena issuer pronta (CA Ready).
- [ ] L'Ingress completato fa emettere a Cert-Manager il Secret shop-tls da solo.
- [ ] curl HTTPS validato contro la CA locale risponde secure shop; il certificato ha la SAN dell'host.
- [ ] answers.md risponde alle tre domande; il cluster dedicato è stato cancellato.
