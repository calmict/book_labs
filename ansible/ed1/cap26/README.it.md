# Capitolo 26 — La macchina di scena

**Livello:** Cloud Architect

Il capitolo 25 ti ha dato la velocità per servire mille nodi. Ma a questa scala una cosa è già
cambiata sotto i tuoi piedi: **non è più una persona a lanciare il playbook**. Con mille nodi e più
mani sullo stesso codice, un ansible-playbook battuto a mano dal portatile di qualcuno è troppo
fragile — nessuno ha controllato il lint, nessuno sa da quale versione parte, nessuno impedisce che
una modifica non provata finisca in produzione un venerdì sera. La risposta è una **macchina di
scena**: ogni modifica passa dal controllo di versione, attraversa una **pipeline** che la valida da
sola (CI), e solo una release autorizzata attraversa il **cancello** ed entra in produzione (CD).
Questo capitolo la costruisce: i cancelli di qualità su GitHub Actions, il cancello di produzione che
si apre solo su un tag, e i pre-commit hook che anticipano il controllo prima ancora del commit.

## Obiettivi

- Che cosa significano **CI e CD**, e perché a scala sostituiscono la persona che lancia (26.1).
- Il **fondamento**: senza controllo di versione non c'è pipeline (26.2).
- L'**anatomia di una pipeline** Ansible: i cancelli in fila (26.3).
- Una pipeline concreta: **GitHub Actions** e i cancelli di qualità (26.4).
- Il **deploy e il cancello di produzione**: chi entra in scena, e quando (26.5).
- **GitLab CI**: lo stesso pattern, altra sintassi (26.6).
- Anticipare ancora: i **pre-commit hook**, lo stesso cancello prima del commit (26.7).
- Le **buone abitudini** con CI/CD (26.8).

## Prerequisiti

- Il venv del capitolo 6 con **ansible-core**, più **ansible-lint** (cap23) e **pre-commit** (in
  start/requirements.txt).
- Il **lint** e il **check mode** del capitolo 23: qui diventano i passi automatici di una pipeline.
- L'idea di **git** come fondamento: la pipeline reagisce a ciò che entra nel repository.
- Nessun account cloud e nessun nodo remoto: la flotta è locale, la pipeline gira a vuoto ma i
  cancelli sono veri.

## Lo scenario

start/ è un piccolo progetto Ansible pronto per la spedizione: site.yml (un playbook corretto),
inventory.ini (un host locale), e una cartella ci/ con due script già pronti — lint.sh e validate.sh
— che sono i **cancelli di qualità** (ansible-lint, poi syntax-check e check mode). Attorno a questo
progetto costruisci la macchina di scena: una pipeline GitHub Actions e un hook pre-commit, tutti e
due che riusano gli stessi due script. Tre lacune la lasciano incompleta; le colmi.

Prepara l'ambiente:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Fase 1 — CI e CD (26.1)

**CI** (Continuous Integration) è: ogni modifica, appena entra nel repository, viene integrata e
**validata automaticamente** — lint, syntax-check, prove — così un errore si scopre in minuti, non in
produzione. **CD** (Continuous Delivery/Deployment) è il passo dopo: una modifica che ha passato tutti
i cancelli viene **consegnata**, e — con un'autorizzazione — messa in produzione. A tre nodi lanci a
mano e te la cavi; a mille, con più persone, il lancio a mano è il punto debole. La macchina di scena
toglie la persona dal loop del controllo e la lascia solo dove serve una **decisione**: aprire il
cancello di produzione.

### Fase 2 — Il fondamento: il controllo di versione (26.2)

Nulla di tutto questo esiste senza **git**. La pipeline non reagisce ai file sul tuo disco: reagisce a
ciò che viene **committato e spinto** nel repository. Il repository è l'unica fonte di verità — la
versione che gira è quella che è nel commit, non quella che avevi aperto nell'editor. Ed è git a dare
al cancello di produzione il suo segnale: un **tag** di release (v1.4.0) è un punto nella storia che
dice "questa, e solo questa, va in produzione". Senza versionamento non c'è né CI (cosa validi?) né CD
(cosa consegni?).

### Fase 3 — L'anatomia di una pipeline (26.3)

Una pipeline Ansible è una **fila di cancelli**, dal più economico al più costoso, ognuno che ferma la
corsa se non passa:

    lint          # stile e best practice (cap23) - veloce, gira sempre
    syntax-check  # il playbook e' ben formato (cap23)
    check mode    # prova a vuoto: cosa cambierebbe (cap23)
    (molecule)    # il ruolo funziona su un sistema vero (cap24) - piu' costoso
    deploy        # solo se tutto sopra e' verde E c'e' autorizzazione

L'ordine è deliberato: prima i controlli rapidi, che bocciano subito la maggior parte degli errori; il
deploy è **l'ultimo** ed è protetto da un cancello. In questo esercizio i cancelli di qualità sono
lint.sh e validate.sh (molecule resta lettura: l'hai già fatto girare nel cap24, ma richiede Docker e
appesantisce la pipeline).

### Fase 4 — GitHub Actions: i cancelli di qualità (26.4 — TODO 1)

Una pipeline GitHub Actions vive in .github/workflows/ci.yml. Ha dei **job**, ogni job dei **passi**.
Apri il file: il job test scarica il codice, prepara Python e installa le dipendenze, ma i due passi
che contano — i cancelli — mancano. Completa il **TODO 1**: aggiungi i due passi che eseguono i
cancelli di qualità a ogni push —

    - name: Lint
      run: ./ci/lint.sh
    - name: Validate
      run: ./ci/validate.sh

Il job test gira su push e pull_request: ogni modifica è validata prima di poter essere fusa. Se
lint.sh o validate.sh escono con errore, il job diventa **rosso** e la pipeline si ferma. È il cap23
reso automatico e obbligatorio: non più "ricordati di lanciare il lint", ma "non entri se il lint non
passa".

### Fase 5 — Il deploy e il cancello di produzione (26.5 — TODO 2)

Il job deploy è la parte CD, e non deve girare **quasi mai**: solo per una release, solo se i cancelli
sono verdi. Sono due condizioni distinte. Completa il **TODO 2** nel job deploy —

    needs: test
    if: startsWith(github.ref, 'refs/tags/v')

needs: test incatena il deploy alla CI: se il job test fallisce, deploy non parte nemmeno. L'if è il
**cancello di produzione**: deploy gira solo quando ciò che ha innescato la pipeline è un **tag di
release** (refs/tags/v1.4.0), mai un normale push su un branch. Un push quotidiano fa girare i
cancelli di qualità ma **non** tocca la produzione; solo un tag deliberato la attraversa. Nel workflow
c'è anche environment: production: su GitHub un *environment protetto* aggiunge un secondo cancello —
l'**approvazione umana** di un revisore — sopra la condizione sul tag. Il cancello, quindi, ha due
forme: una **condizione** (il tag) e una **persona** (l'approvazione). Domanda a.

### Fase 6 — GitLab CI: stesso pattern, altra sintassi (26.6)

GitHub Actions non è l'unico direttore d'orchestra. **GitLab CI** legge un .gitlab-ci.yml e descrive
gli stessi concetti con parole diverse: stages al posto dei job in needs, rules con
if: $CI_COMMIT_TAG al posto del guard sul ref, script per i comandi. Cambia la grammatica, non la
frase: cancelli di qualità su ogni push, deploy dietro un cancello legato al tag. Chi ha capito il
pattern lo ritrova ovunque — Jenkins, CircleCI, Drone — perché il pattern è la pipeline, non il
prodotto.

### Fase 7 — Anticipare ancora: i pre-commit hook (26.7 — TODO 3)

La CI becca gli errori dopo il push. Ma perché aspettare il push? Un **pre-commit hook** fa scattare
lo stesso cancello sul tuo portatile, **prima** che il commit esista — l'errore non lascia nemmeno la
macchina. Apri .pre-commit-config.yaml e completa il **TODO 3**: aggiungi l'hook che riusa lo stesso
lint della pipeline —

    repos:
      - repo: local
        hooks:
          - id: ansible-lint
            name: ansible-lint
            entry: ./ci/lint.sh
            language: system
            pass_filenames: false
            files: \.(yml|yaml)$

repo: local significa che l'hook non scarica nulla da internet: chiama lo script che hai già. Lo
installi una volta con "pre-commit install", e da lì in poi ogni "git commit" esegue il lint; se
fallisce, il commit è bloccato. È lo **stesso cancello** della fase 4, spostato ancora più a monte —
il principio del capitolo 23, "anticipa il controllo", portato al suo estremo. Domanda b.

### Fase 8 — Le buone abitudini (26.8)

- **Il repository è la verità**: gira ciò che è committato, non ciò che hai sul disco. Niente
  modifiche a mano sui server.
- **Cancelli in fila, dal più economico**: lint prima di molecule prima di deploy — boccia presto,
  spendi tardi.
- **Il deploy è sempre dietro un cancello**: mai automatico su ogni push; una condizione (il tag) e,
  per la produzione, una persona (l'approvazione).
- **Lo stesso cancello a più livelli**: pre-commit sul portatile, CI sul push — così un errore ha due
  reti prima ancora della revisione umana.
- **DRY sui cancelli**: pipeline e pre-commit riusano gli stessi script (ci/), così "verde in locale"
  e "verde in CI" vogliono dire la stessa cosa.

## Criteri di "fatto"

- Il job test di ci.yml esegue i due cancelli di qualità a ogni push (TODO 1): lint.sh e validate.sh.
- Il job deploy ha needs: test e l'if sul tag (TODO 2): non parte se la CI fallisce, e gira solo su un
  tag di release.
- .pre-commit-config.yaml ha l'hook ansible-lint locale (TODO 3): lo stesso lint scatta prima del
  commit.
- I cancelli **mordono davvero**: verdi sul progetto buono, rossi su un playbook rotto — sia nella
  pipeline sia nel pre-commit.

## Come viene verificato

solution/run.sh lo dimostra, tutto in locale e senza rete:

1. **I cancelli mordono**: esegue lint.sh e validate.sh sul progetto spedito (verde), poi su un
   playbook volutamente rotto (un comando nudo, senza nome né changed_when) e pretende che
   falliscano — la pipeline diventerebbe rossa.
2. **Il cancello di produzione è corretto**: fa il parse di ci.yml e verifica che deploy abbia
   needs: test e un if legato a refs/tags/v; poi mostra la regola all'opera — un ref di branch è
   bloccato, un ref di tag è permesso.
3. **Lo shift-left funziona**: inizializza un repo git temporaneo ed esegue "pre-commit run": passa
   sull'albero pulito, fallisce appena si introduce una violazione di lint — l'hook bloccherebbe il
   commit. Tutto offline (repo: local).

## Domande di riflessione

**a.** Il cancello di produzione ha due forme: una **condizione** (il deploy gira solo su un tag
refs/tags/v) e una **persona** (l'approvazione di un environment protetto). Perché a scala servono
**entrambe**? Descrivi un incidente che la sola condizione sul tag non ferma ma l'approvazione umana
sì — e uno che l'approvazione da sola non ferma ma la condizione sì.

**b.** Lo stesso lint gira in tre posti: sul portatile (pre-commit), sul push (CI) e, idealmente, lo
lanci anche a mano. Non è ridondante? Spiega perché avere lo **stesso cancello a più livelli** rende
il sistema più veloce *e* più sicuro invece che solo più lento — e cosa si perderebbe togliendo il
pre-commit e tenendo solo la CI.

**c.** needs: test incatena il deploy alla CI. Cosa accadrebbe, concretamente, in una pipeline dove il
job deploy **non** dichiara needs e gira in parallelo al job test? Perché "il deploy dipende dalla
riuscita dei cancelli" non è un'ottimizzazione ma una **condizione di sicurezza**?

## Pulizia

Niente da smontare: nessun nodo remoto, nessun container, nessun account cloud. Chiudi il venv con:

    deactivate

## Dove porta

Hai la macchina di scena che porta una modifica dal commit alla produzione attraverso i cancelli
(cap26). Ma il job deploy, finora, è una riga di echo: *come* si consegna davvero a una flotta senza
spegnere il servizio? Il **capitolo 27** entra nell'**orchestrazione e nei rolling update** — serial,
delegate_to, pre/post_tasks, rollback — perché mettere in produzione su mille nodi non è "applica a
tutti insieme", ma "applica a ondate, controllando dopo ognuna, pronti a tornare indietro".
