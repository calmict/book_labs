# Cap. 24 — Lo stampo e le colate (Helm, il package manager)

> Esercizio del **Capitolo 24 — Helm, il package manager di Kubernetes** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Cloud Architect

## Obiettivi

Al termine di questo laboratorio saprai:

- sentire il problema che Helm risolve: gestire a mano decine di manifest quasi identici, che cambiano per due righe — il crampo del copia-incolla;
- costruire un chart locale: uno stampo (i template) più una scheda di regolazioni (values), e vedere lo stesso stampo colare manifest diversi al variare dei valori;
- gestire le release come colate numerate: installare, aggiornare con nuovi valori, leggere la storia e tornare indietro con un rollback — e capire perché un cambio di sola configurazione non fa ripartire i pod.

## Prerequisiti

- Cap. 15 completato (rollout e rollback a mano: qui li fa Helm, versionati) e la familiarità con Deployment/Service/ConfigMap dei capitoli precedenti.
- Il cluster book-labs acceso e il binario helm installato (helm version). Tutto è local-first: costruirai il tuo chart, nessun repository esterno richiesto.
- In start/: plain.yaml (il "prima", manifest scritti a mano) e greeter/ (lo scheletro del chart, con dei TODO nei template).

## Consegna

1. Il crampo del copia-incolla. Apri start/plain.yaml: una ConfigMap, un Deployment e un Service, tutti con valori scritti a mano. Immagina di doverne tenere tre copie — dev, staging, prod — identiche tranne il numero di repliche e un messaggio. Ogni modifica va replicata a mano su tutte: è il problema che Helm risolve.

2. Costruisci lo stampo. In start/greeter/ trovi Chart.yaml e values.yaml già pronti, e tre template con dei TODO. Completa i template sostituendo i valori fissi con le espressioni Helm: il nome della release ({{ .Release.Name }}), il numero di repliche ({{ .Values.replicaCount }}) e il messaggio ({{ .Values.message }}). Poi guarda cosa colerebbe lo stampo, senza installare niente:

       helm lint greeter
       helm template greeter greeter

   helm template rende i template a manifest veri, con i valori di values.yaml al posto delle espressioni. Nessun copia-incolla: un solo stampo.

3. La prima colata. Installa il chart come release chiamata greeter, nel suo namespace:

       helm install greeter greeter -n helmlab --create-namespace --wait
       helm list -n helmlab
       kubectl -n helmlab get deploy,svc,cm

   È la revisione 1. Leggi cosa dichiara la colata e cosa serve davvero:

       kubectl -n helmlab get cm greeter-page -o jsonpath='{.data.index\.html}'
       kubectl -n helmlab exec deploy/greeter -- wget -qO- http://localhost:8080

   Una replica, "Greetings from revision one".

4. Ricolare con nuove regolazioni. Cambia due valori al volo e aggiorna la release:

       helm upgrade greeter greeter -n helmlab --set replicaCount=3 --set message="Greetings from revision two" --wait
       helm history -n helmlab greeter

   La revisione 2: tre repliche e il nuovo messaggio. Nota un dettaglio importante: il messaggio è cambiato perché il chart porta un'annotazione checksum/config sul pod template — un'impronta della ConfigMap. Senza di essa, cambiare solo la ConfigMap non farebbe ripartire i pod, che continuerebbero a servire il vecchio contenuto.

5. Tornare alla colata precedente. Fai rollback alla revisione 1:

       helm rollback greeter 1 -n helmlab --wait
       helm history -n helmlab greeter
       kubectl -n helmlab get cm greeter-page -o jsonpath='{.data.index\.html}'

   La storia ora ha tre righe (install, upgrade, rollback-to-1) e la ConfigMap è tornata a "revision one": Helm non cancella, impila. Ogni colata resta nella storia, e tornare indietro è a sua volta una nuova revisione.

6. Smonta la release e il namespace:

       helm uninstall greeter -n helmlab
       kubectl delete namespace helmlab

## Le domande per answers.md

- (a) Chart, template e values (24.2). Cosa separa lo stampo (i template) dalle regolazioni (values)? Spiega la differenza tra {{ .Release.Name }} e {{ .Values.message }}, tra impostare un valore in values.yaml e passarlo con --set, e cosa ti mostra helm template che helm install non ti fa vedere.
- (b) Release e rollback (24.3). Cos'è una release e cos'è una revisione? Cosa fa esattamente helm rollback (ricrea i manifest di una revisione precedente)? E il tranello che hai visto: perché cambiare solo una ConfigMap non fa ripartire i pod, e come l'annotazione checksum/config lo risolve? Dove tiene Helm la storia delle release: dai un'occhiata ai Secret nel namespace.
- (c) Helm nella pratica (24.4). Cos'è un chart repository (helm repo add) e perché installare un addon come ingress-nginx o metrics-server è lo stesso helm install che hai fatto, ma con lo stampo di qualcun altro. Qui hai costruito il tuo chart (local-first); in produzione, quanto spesso scriverai uno stampo e quanto spesso ne installerai uno già pronto?

## Criteri di "fatto"

- [ ] I template completati: helm lint pulito e helm template rende manifest con i tuoi valori.
- [ ] Revisione 1 installata: una replica, "revision one" servito.
- [ ] Revisione 2 dopo l'upgrade: tre repliche e "revision two" (i pod sono ripartiti).
- [ ] Rollback: la storia ha tre righe e la ConfigMap è tornata a "revision one".
- [ ] answers.md risponde alle tre domande; release e namespace rimossi.
