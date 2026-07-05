# Cap. 26 — Il libro mastro e il revisore (ArgoCD e GitOps)

> Esercizio del **Capitolo 26 — ArgoCD e il GitOps** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Cloud Architect

## Obiettivi

Al termine di questo laboratorio saprai:

- capire il principio GitOps: Git è il libro mastro, l'unica fonte di verità su cosa deve esistere nel cluster; nessuno tocca il mondo a mano, si scrive nel libro;
- dare l'incarico a un revisore instancabile (ArgoCD) con l'oggetto Application, e vederlo rendere il cluster identico al libro (sync), accorgersi di ogni divergenza (drift) e correggerla da solo (self-heal);
- fare rollback nel modo dichiarativo: non si aggiusta il mondo, si corregge il libro con git revert, e il revisore propaga la correzione.

## Prerequisiti

- Cap. 24 (Helm: nel mondo reale ArgoCD si installa anche via chart; qui lo installiamo via manifest per vederne i pezzi) e Cap. 15 (rollout/rollback a mano: qui a comandare il rollback è Git).
- kind installato. ATTENZIONE: ArgoCD installa risorse cluster-wide (CRD, ClusterRole); per non sporcare il cluster book-labs, questo lab usa un cluster dedicato usa-e-getta (book-labs-gitops), che a fine lavoro si cancella con un solo comando.
- In start/: gitserver.yaml (dato, il libro mastro in-cluster) e application.yaml (TODO, l'incarico al revisore).

## Consegna

1. Il cantiere. Crea il cluster dedicato, installa ArgoCD e accendi il git server che ospita il libro mastro:

       kind create cluster --name book-labs-gitops
       kubectl create namespace argocd
       kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
       kubectl -n argocd wait --for=condition=Available deploy --all --timeout=300s
       kubectl apply -f gitserver.yaml
       kubectl -n gitops rollout status deploy/gitserver

   (--server-side evita l'errore "annotation too long" sulla CRD più grande di ArgoCD.) Il git server ospita un repo con manifests/web.yaml: un Deployment web a 1 replica. È il libro mastro.

2. L'incarico al revisore. Completa application.yaml: un oggetto Application che dice al revisore quale libro leggere e dove applicarlo. Metti nel source il repoURL (git://gitserver.gitops.svc.cluster.local:9418/app.git), il path (manifests) e targetRevision (main); nel destination il namespace demo; e una syncPolicy automated con selfHeal e CreateNamespace. Applica e guarda il revisore mettersi al lavoro:

       kubectl apply -f application.yaml
       kubectl -n argocd get application web -o wide
       kubectl -n demo get deploy web

   In pochi secondi: Synced e Healthy, e web esiste con 1 replica. Nessuno ha fatto kubectl apply del Deployment: l'ha fatto ArgoCD, leggendo il libro.

3. Il revisore non dorme (drift e self-heal). Prova a comandare il mondo a mano:

       kubectl -n demo scale deploy web --replicas=3
       kubectl -n argocd get application web -o jsonpath='{.status.sync.status}'
       kubectl -n demo get deploy web -w

   Per un istante è OutOfSync a 3 repliche, poi il revisore lo riporta a 1: la modifica manuale viene annullata. Nel GitOps il mondo non comanda — comanda il libro.

4. Correggere il libro, non il mondo (git revert). Il repo vive nel cluster: fai un commit sbagliato entrando nel git server, poi guarda ArgoCD obbedire al libro anche quando sbaglia:

       kubectl -n gitops exec deploy/gitserver -- sh -c 'cd /work && sed -i "s/replicas: 1/replicas: 5/" manifests/web.yaml && git commit -qam "scale web to 5" && git push -q origin main'
       kubectl -n argocd annotate application web argocd.argoproj.io/refresh=hard --overwrite
       kubectl -n demo get deploy web -w

   Il mondo va a 5 repliche: il libro è legge. Ora NON scalare a mano — correggi il libro:

       kubectl -n gitops exec deploy/gitserver -- sh -c 'cd /work && git revert --no-edit HEAD && git push -q origin main'
       kubectl -n argocd annotate application web argocd.argoproj.io/refresh=hard --overwrite
       kubectl -n demo get deploy web -w

   Il revisore riporta il mondo a 1. Il rollback è una riga barrata nel libro mastro (git revert), non un intervento a mano: resta nella storia, firmato e tracciabile.

5. Smonta il cantiere (un comando, zero residui cluster-wide):

       kind delete cluster --name book-labs-gitops

## Le domande per answers.md

- (a) Il principio GitOps (26.1). Perché Git come unica fonte di verità, e cosa cambia rispetto a un kubectl apply lanciato a mano? ArgoCD gira dentro il cluster e tira da Git (pull), come Prometheus del cap. 25 andava a prendere le metriche: che vantaggio ha il pull rispetto a una pipeline che spinge (push) col kubeconfig di produzione in mano?
- (b) Application e reconciliation (26.2–26.3). Cos'è l'oggetto Application e cosa significano Synced / OutOfSync / Healthy? Cosa fa esattamente selfHeal quando qualcuno tocca il cluster a mano, e perché la reconciliation continua (non una tantum) è il cuore del modello? Il drift è un errore o è normale?
- (c) Rollback dichiarativo (26.4). Perché in GitOps non si fa rollback né a mano né con helm rollback, ma con git revert? Che cosa ti dà avere la storia in Git (audit, chi-ha-cambiato-cosa, ripetibilità)? Lega col cap. 24: helm rollback impila revisioni nei Secret; git revert impila commit nel libro — quale delle due è la fonte di verità in un mondo GitOps?

## Criteri di "fatto"

- [ ] ArgoCD installato e il git server (libro mastro) in esecuzione sul cluster dedicato.
- [ ] Application completata: web Synced e Healthy, 1 replica, creato da ArgoCD.
- [ ] Drift e self-heal: lo scale manuale a 3 viene annullato, torna a 1.
- [ ] git revert: il commit sbagliato porta il mondo a 5, il revert lo riporta a 1.
- [ ] answers.md risponde alle tre domande; il cluster dedicato è stato cancellato.
