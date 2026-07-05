# Cap. 27 — La scorta (Istio e il service mesh)

> Esercizio del **Capitolo 27 — Istio e il service mesh** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Cloud Architect

## Obiettivi

Al termine di questo laboratorio saprai:

- capire il problema che risolve un service mesh: cifratura, retry, routing e tracce oggi vivono dentro ogni applicazione, riscritti in ogni linguaggio; il mesh li sfila fuori e li affida a una scorta;
- vedere la scorta attaccarsi da sola a ogni pod (sidecar injection): il data plane sono tutte le scorte (Envoy), il control plane (istiod) è la centrale che le istruisce;
- accendere mTLS automatico (identità e cifratura senza toccare l'app né gestire un certificato) e comandare il traffico dall'alto: un canary 80/20 tra due versioni, deciso per decreto.

## Prerequisiti

- Cap. 22 (NetworkPolicy: lì la sicurezza di rete era a maglie; qui diventa identità e cifratura per ogni chiamata) e Cap. 25 (Prometheus: il mesh gli darà metriche e tracce).
- kind e istioctl installati. ATTENZIONE: Istio installa CRD e un webhook di injection cluster-wide; come nel cap. 26 il lab usa un cluster dedicato usa-e-getta (book-labs-mesh), cancellato a fine lavoro.
- In start/: mesh-app.yaml (dato: due versioni di un'app + un client), mtls.yaml (dato: PeerAuthentication STRICT) e canary.yaml (DestinationRule dato, VirtualService con un TODO sui pesi).

## Consegna

1. La scorta si attacca da sola (injection). Crea il cluster, installa Istio e schiera l'app:

       kind create cluster --name book-labs-mesh
       istioctl install --set profile=minimal -y
       kubectl apply -f mesh-app.yaml
       kubectl -n mesh wait --for=condition=Ready pod --all --timeout=120s
       kubectl -n mesh get pods -o custom-columns='NAME:.metadata.name,CONTAINERS:.status.containerStatuses[*].name'

   Il namespace mesh ha l'etichetta istio-injection=enabled: ogni pod nasce con DUE container, il tuo (web / client) e istio-proxy — la scorta Envoy, aggiunta automaticamente. L'app non è cambiata di una riga.

2. Identità e cifratura senza fatica (mTLS). Ordina che nel namespace si parli solo in mutuo TLS:

       kubectl apply -f mtls.yaml
       kubectl -n outside run oclient --image=curlimages/curl:8.11.1 --restart=Never --command -- sleep infinity
       kubectl -n outside exec oclient -- curl -s -m 5 -o /dev/null -w "%{http_code}\n" http://web.mesh/
       kubectl -n mesh exec client -c client -- curl -s http://web/

   Un client SENZA scorta (dal namespace outside, non iniettato) viene rifiutato: 000, connessione resettata — il traffico in chiaro non entra. Il client CON scorta passa: le due scorte si sono scambiate i badge e hanno cifrato tutto, senza che tu generassi un solo certificato.

3. Comandare il traffico dall'alto (canary). Completa canary.yaml: nel VirtualService instrada l'80% verso il subset v1 e il 20% verso v2. Applica e spara richieste dal client interno:

       kubectl apply -f canary.yaml
       kubectl -n mesh exec client -c client -- sh -c 'for i in $(seq 1 30); do curl -s http://web/; done' | sort | uniq -c

   Circa 24 risposte v1 e 6 v2: la centrale ha spezzato il traffico per decreto. Sposta i pesi (95/5, poi 50/50, poi 0/100) e hai fatto un rollout canary senza toccare l'app. La stessa coppia DestinationRule/VirtualService aggiunge retry e circuit breaking (outlier detection): la scorta ritenta una consegna fallita e smette di bussare a una porta morta.

4. Il terzo pilastro (osservabilità). Ogni scorta annota ogni viaggio: Istio esporta metriche e tracce (verso Prometheus del cap. 25, Jaeger, Kiali) senza strumentare l'app. Non lo installiamo qui, ma è il motivo per cui un mesh "vede" tutto il traffico est-ovest.

5. Smonta il cantiere:

       kind delete cluster --name book-labs-mesh

## Le domande per answers.md

- (a) Il problema e i due piani (27.1–27.2). Perché mettere la logica di rete (TLS, retry, routing) dentro ogni app è un problema, e cosa cambia spostandola in una scorta sidecar? Distingui data plane (le scorte Envoy) e control plane (istiod): chi trasporta i pacchetti e chi detta le regole? Cosa fa esattamente la injection e perché l'app non se ne accorge?
- (b) mTLS (27.3). Cosa hai dimostrato bloccando il client di outside con PeerAuthentication STRICT? Da dove arrivano identità e certificati se tu non ne hai creato nessuno? In che senso questo è un livello di sicurezza diverso e complementare rispetto alle NetworkPolicy del cap. 22 (chi-può-parlare-con-chi contro chi-sei-tu-davvero)?
- (c) Traffic management e osservabilità (27.4–27.5). Come fa il VirtualService a fare canary senza toccare l'app? Cosa aggiungono retry e circuit breaking, e perché conviene averli nella scorta e non nel codice? Perché un mesh è nella posizione perfetta per l'osservabilità (le tracce) rispetto a Prometheus da solo del cap. 25?

## Criteri di "fatto"

- [ ] Injection: ogni pod del namespace mesh ha due container (app + istio-proxy).
- [ ] mTLS STRICT: il client di outside è rifiutato, quello interno passa.
- [ ] Canary: circa 80/20 tra v1 e v2 su una trentina di richieste.
- [ ] answers.md risponde alle tre domande; il cluster dedicato è stato cancellato.
