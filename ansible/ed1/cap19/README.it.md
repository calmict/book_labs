# Capitolo 19 — Il caveau

**Livello:** Avanzato

Al capitolo 18 hai chiuso la password in cassaforte. Ma alla fine restava un paradosso: la
cassaforte è cifrata, e la sua chiave — la parola d'ordine del vault — dove vive? Se la
scrivi in un file accanto al playbook, sei tornato al peccato del capitolo 11: un segreto in
chiaro su disco. Il capitolo 18 ha spostato il problema, non l'ha eliminato. La soluzione
vera cambia paradigma: il segreto **non si conserva affatto** — né in chiaro né cifrato — ma
si va a **prendere a runtime** da un servizio esterno che lo custodisce, lo consegna a chi ha
diritto, e non lascia mai che riposi con te. Quel servizio è un **caveau**: in questo
laboratorio, HashiCorp Vault.

## Obiettivi

- I **tre limiti** che Vault (cap. 18) non risolve (19.1).
- Il cambio di paradigma: il **lookup a runtime** (19.2).
- **HashiCorp Vault** e la collezione community.hashi_vault (19.3).
- **Autenticazione**: token, AppRole e l'identità di macchina (19.4).
- I **secret manager del cloud**: AWS, Azure, GCP (19.5).
- Le **chiavi SSH** in produzione: distribuzione, rotazione, bastion (19.6).
- **no_log**: il segreto che non deve finire nei log (19.7).
- Quando **basta Vault** (cap. 18), quando serve un **manager** (19.8).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt), più la libreria hvac.
- La collezione community.hashi_vault (la installi tu, come al capitolo 17).
- Docker: qui girano *due* container — il nodo secops (come al cap. 18) e il caveau.
- Il segreto è lo stesso di sempre: la password di sudo di secops. Cambia solo *dove vive*.

## Lo scenario

Due container. Il primo, cap19-web1, è il solito nodo raggiunto come **secops** (sudo con
password). Il secondo, cap19-vault, è **HashiCorp Vault** in modalità dev: il caveau. La
password di sudo non sta più in un file — né in chiaro (cap. 11) né cifrata (cap. 18): sta
*dentro il caveau*. Al momento del bisogno, Ansible bussa al caveau, si fa identificare,
riceve il segreto in memoria per il tempo di un task, e diventa root. Su disco, nel
repository, nell'output: **niente**.

Lo script nodes.sh prepara tutto: accende il nodo, accende il caveau, ci deposita il segreto
e configura un'identità di macchina (AppRole). Nella realtà a riempire il caveau è qualcun
altro, fuori banda; qui lo fa lo script per te — perciò nodes.sh è l'unico file che conosce
il valore, mentre la configurazione vera (group_vars, site.yml) non lo tocca mai.

## Consegna passo-passo

Prepara l'ambiente e la piattaforma:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start
    ./nodes.sh up          # nodo + caveau + segreto depositato + AppRole pronto

Lo script stampa l'indirizzo del caveau e il token di root del lab. Esportali:

    export VAULT_ADDR=http://127.0.0.1:8200
    export VAULT_TOKEN=lab-root-token

### Fase 1 — I tre limiti che restano (19.1)

Vault (cap. 18) cifra benissimo, ma non risolve tre cose:

1. **La chiave del vault è ancora un segreto su disco.** L'hai messa in un file o la digiti a
   mano: nel primo caso è in chiaro, nel secondo non automatizzi.
2. **Non c'è controllo d'accesso né revoca.** Chi ha la parola d'ordine ha *tutto*, per
   sempre; non puoi dare a uno il dev e non il prod, né togliergli l'accesso senza ri-cifrare
   tutto.
3. **Non c'è traccia né rotazione facile.** Vault non sa *chi* ha decifrato *cosa*, e ruotare
   un segreto significa modificare i file e ri-committare.

Un **secret manager** nasce per questi tre buchi — Domanda a.

### Fase 2 — Il cambio di paradigma: il lookup a runtime (19.2 — TODO 1 e TODO 2)

Fin qui il segreto *viaggiava col codice* (in chiaro o cifrato). Il paradigma si rovescia: il
segreto **resta nel caveau**, e il playbook lo va a **prendere quando serve**, con un lookup.

Prima procurati lo strumento (come al capitolo 17). Completa il **TODO 1**: dichiara la
collezione in requirements.yml —

    collections:
      - name: community.hashi_vault
        version: "7.1.0"

e installala (hvac è già in requirements.txt):

    ansible-galaxy collection install -r requirements.yml

Poi il cuore. Completa il **TODO 2** in group_vars/web/vars.yml: la become password non è più
un valore, è una *chiamata al caveau* (accanto trovi già, come modello, lo stesso lookup per
app_db_password) —

    ansible_become_password: "{{ lookup('community.hashi_vault.hashi_vault',
        'secret/data/myapp:become_password',
        url=vault_url, token=vault_token) }}"

Nessun file cifrato, nessuna parola d'ordine del vault: il segreto viene letto dal caveau
*nell'istante* in cui serve, e vive solo in memoria per la durata del play. Confronta i tre
mondi — Domanda b:

    cap. 11:  ansible_become_password: secops-pw                          # in chiaro su disco
    cap. 18:  ansible_become_password: "{{ vault_become_password }}"      # cifrato su disco
    cap. 19:  ansible_become_password: "{{ lookup('...hashi_vault'...) }}"  # non su disco

### Fase 3 — Eseguire: il segreto non tocca il disco (19.3)

Esegui:

    ansible-playbook -i inventory.ini site.yml

Il play interroga il caveau, ottiene la password, diventa root, scrive il marker. Poi cerca
il segreto dove il playbook potrebbe averlo depositato — e non lo trovi:

    grep -r secops-pw group_vars site.yml       # niente nella configurazione
    ansible-playbook -i inventory.ini site.yml -vvv | grep secops-pw   # niente nell'output

Il segreto è esistito solo in RAM, per il tempo di un task. Questo è il caveau (19.3): il
servizio custodisce, Ansible richiede via API (community.hashi_vault), il valore non si
sedimenta da nessuna parte. (Il solo file che conosce il valore è nodes.sh, che simula il
deposito fuori banda; la configurazione che andrebbe in produzione non lo contiene.)

### Fase 4 — Chi sei tu, per il caveau? (19.4)

Il caveau non consegna a chiunque bussi: prima ti **identifichi**. Nel TODO 2 hai usato un
**token** (VAULT_TOKEN) — comodo per una persona, ma un token di root in uno script è esso
stesso un segreto pericoloso. In produzione un *processo* si identifica con un'**AppRole**:
una coppia role_id + secret_id che è **identità di macchina**, legata a una **policy** che
concede solo il minimo (qui: leggere *quel* segreto, niente altro). Lo script l'ha già
creata; provala:

    ansible-playbook -i inventory.ini approle.yml \
        -e role_id="$(cat /tmp/cap19-lab/role_id)" \
        -e secret_id="$(cat /tmp/cap19-lab/secret_id)"

Stesso segreto, ma l'identità non è più "il re con tutte le chiavi": è un impiegato con un
badge che apre una sola porta — e revocabile. Token per le persone, identità di macchina per
i processi (19.4) — Domanda c.

### Fase 5 — no_log: il segreto fuori dai log (19.7 — TODO 3)

Un segreto preso dal caveau può ancora tradirti *dopo*: se un task lo stampa, lo passa a un
comando, o fallisce mostrando gli argomenti, finisce nei log — e i log si conservano, si
spediscono, si indicizzano. La rete di sicurezza è **no_log: true**. Completa il **TODO 3**
sul task che scrive la credenziale dell'app.

Eseguendo a -vvv, il task protetto mostra solo:

    the output has been hidden due to the fact that 'no_log: true' was specified

Senza no_log, lo stesso task stamperebbe il segreto in chiaro nell'output. (La become
password è già protetta da Ansible; ma qualunque *altro* segreto che tocchi con le tue mani
va marcato no_log.)

### Fase 6 — Il cloud e le chiavi SSH (19.5, 19.6)

- **I secret manager del cloud** (19.5): lo stesso paradigma, altra porta. AWS Secrets
  Manager, Azure Key Vault, GCP Secret Manager si interrogano con i rispettivi lookup —
  cambia il plugin, non l'idea. Trovi esempi da leggere in start/gallery/ (amazon.aws, azure,
  google.cloud): non li eseguiamo (servono account cloud), ma la forma è identica a
  hashi_vault.
- **Le chiavi SSH in produzione** (19.6): anche la chiave privata con cui Ansible si connette
  è un segreto. In produzione non gira a mano copiata: si **distribuisce** con l'authorized_key
  module, si **ruota** periodicamente (nuova coppia, si aggiorna, si revoca la vecchia), e
  spesso passa da un **bastion** unico e sorvegliato (cap. 3). La chiave viva può a sua volta
  arrivare da un caveau o da un SSH CA che firma certificati a breve durata.

### Fase 7 — Quando basta Vault, quando serve un manager (19.8)

Non serve sempre il caveau. La regola onesta:

- **Basta Ansible Vault (cap. 18)** quando: sei solo o in un team piccolo e fidato, i segreti
  cambiano di rado, non hai già un secret manager. La cassaforte cifrata nel repo è semplice e
  sufficiente.
- **Serve un manager (cap. 19)** quando: più persone/team con accessi diversi, serve revoca e
  audit, rotazione frequente, segreti dinamici (credenziali a scadenza), o esiste già un
  Vault/cloud manager aziendale a cui agganciarsi.

Il caveau costa complessità (un servizio in più da gestire): lo paghi quando i tre limiti del
19.1 ti fanno male davvero — Domanda a.

## Criteri di "fatto"

- requirements.yml installa community.hashi_vault; hvac è nel venv.
- In group_vars/web/vars.yml la become password è un **lookup** community.hashi_vault, non un
  valore.
- Il playbook diventa root con la password **presa dal caveau**; il marker è root:root;
  rieseguendo → changed=0.
- Il segreto secops-pw **non compare** nella configurazione (group_vars, site.yml) né
  nell'output a -vvv.
- L'AppRole (identità di macchina) legge lo stesso segreto con una policy di sola lettura.
- Il task marcato no_log mostra "the output has been hidden" a -vvv.

## Domande di riflessione

**a.** Vault del capitolo 18 cifrava benissimo. Quali tre cose *non* risolve — la chiave che
resta su disco, l'assenza di controllo accessi/revoca, la mancanza di audit/rotazione — e come
le colma un secret manager? Quando quei tre limiti giustificano la complessità in più di un
caveau, e quando invece Ansible Vault basta?

**b.** Metti in fila i tre modi di dare la become password: in chiaro (cap. 11), cifrata in un
file (cap. 18), presa a runtime dal caveau (cap. 19). Dove *vive* il segreto in ciascuno, e
perché solo l'ultimo fa sì che il segreto non riposi mai su disco né viaggi col codice? Cosa
cambia per chi clona il repository?

**c.** Nel TODO 2 ti sei identificato al caveau con un token; l'AppRole usa invece role_id +
secret_id. Perché infilare un token di root in uno script è pericoloso quanto il segreto che
protegge, e cosa ti dà in più un'identità di macchina legata a una policy minima (sola lettura
di *quel* segreto) e revocabile?

## Pulizia

    ./nodes.sh down        # rimuove cap19-web1 e cap19-vault, cancella /tmp/cap19-lab

Il caveau dev è tutto in memoria: spento il container, i segreti spariscono con lui.

## Dove porta

Chiudi il tema dei segreti: sai cifrarli (cap. 18) e, meglio, non conservarli affatto ma
prenderli a runtime da un caveau con identità e policy (cap. 19). Da qui il manuale cambia
registro: il **capitolo 20** torna al *contenuto* dei playbook e apre il Jinja2 avanzato — i
filtri, le trasformazioni, i template che danno forma ai dati che finora hai solo passato.
