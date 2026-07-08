# Capitolo 2 — Il messaggero, non l'inquilino

**Livello:** Fondamentale

Il direttore d'orchestra non impianta un chip nel cervello di ogni musicista:
parla, e loro — che già sanno leggere la musica — eseguono. Ansible funziona
così. Non installa un *agente* che vive sulla macchina: la **visita** via SSH, le
fa fare una cosa usando il Python che è già lì, e se ne va. Questo si chiama
**agentless**, ed è il cuore dell'architettura.

In questo laboratorio **diventi tu il messaggero**: rifarai a mano, via SSH, il
viaggio che Ansible automatizza per ogni task. Non useremo ancora Ansible (lo
installi al capitolo 6): lo scopo è proprio dimostrare che sul target non serve
*niente di suo* — solo SSH e Python.

## Obiettivi

- Capire **agentless** e i suoi tre regali: niente da installare/mantenere sul
  target, nessun demone in ascolto (superficie d'attacco invariata), funziona su
  qualunque cosa parli SSH + Python.
- Distinguere **control node** (la tua macchina, da cui parti) e **managed node**
  (la macchina che configuri, che non ospita nulla di tuo).
- Ricostruire **il viaggio di un task**, fotogramma per fotogramma: copia il
  modulo, eseguilo col Python remoto, JSON su stdout, pulizia.
- Vedere **il ruolo di Python** — e quando *non* serve (il modulo raw, pura shell
  via SSH).
- Toccare i **facts**: come Ansible "intervista" la macchina.

## Prerequisiti

- Un motore **Docker** (il managed node è un container). Verifica: docker version
- Un client SSH standard (ssh, scp, ssh-keygen) — già presente su ogni
  Linux/macOS.
- **Niente Ansible**, di nuovo di proposito. Il portare su del nodo scarica sshd
  e python3: serve rete la prima volta.

## Lo scenario

- **Control node:** la tua macchina.
- **Managed node:** un container a cui installiamo *soltanto* openssh-server e
  python3. Nessun agente Ansible, nessun demone nostro. È il punto di tutto il
  capitolo.

## Consegna passo-passo

### Fase 0 — Tira su il managed node

    bash start/node.sh up

Lo script costruisce il nodo e stampa il comando SSH pronto da incollare (con una
chiave effimera generata al volo). Guarda cosa gli abbiamo messo dentro: **solo**
SSH e Python. Nient'altro. Questo è il **primo regalo** dell'agentless — non c'è
un agente da installare, versionare, aggiornare su ogni macchina.

Salva il comando SSH in una variabile per comodità (lo script te lo mostra):

    SSH="ssh -p 2222 -i <chiave> -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1"

### Fase 1 — I tre regali, dall'interno

Entra:

    $SSH 'hostname; python3 --version'

Sei sul managed node. Ora chiediti cosa gira di *nostro* quando non stai
lavorando:

    $SSH 'ps -e | grep -E "sshd|ansible" || true'

Vedi sshd, e nient'altro. **Secondo regalo:** finito il task, sul target non resta
in ascolto nessun processo tuo — nessuna nuova superficie d'attacco, nessun demone
da sorvegliare. E siccome tutto passa da SSH + Python, lo stesso meccanismo
funziona su un server, un container, un apparato di rete: **terzo regalo**, la
barriera d'ingresso è bassissima.

### Fase 2 — Il viaggio di un task, fotogramma per fotogramma

Un "modulo" Ansible non è magia: è un programmino che raccoglie qualcosa e stampa
**una riga di JSON**. Apri start/module.py e completa il **TODO**: fai raccogliere
almeno tre facts alla macchina su sé stessa (hostname, sistema, versione di
Python…). Il file resta valido anche a metà (stampa un JSON con facts vuoti), così
puoi eseguirlo mentre lo scrivi.

Ora fallo **viaggiare a mano**, esattamente come farebbe Ansible:

    # 1. prepara la cartella temporanea sul nodo
    $SSH 'mkdir -p ~/.ansible/tmp'

    # 2. copia il modulo sul managed node
    scp -P 2222 -i <chiave> -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        start/module.py root@127.0.0.1:.ansible/tmp/mod.py

    # 3. eseguilo con il Python REMOTO — il JSON torna su stdout
    $SSH 'python3 ~/.ansible/tmp/mod.py'

    # 4. pulizia: Ansible cancella sempre il file temporaneo
    $SSH 'rm -f ~/.ansible/tmp/mod.py'

Questi quattro fotogrammi **sono** ciò che Ansible fa per ogni singolo task:
connettersi, spedire il modulo in una tmp dir, eseguirlo col Python del target,
raccogliere il JSON, ripulire. Tu li hai appena fatti a mano. Nessuno stato è
rimasto sul nodo: il messaggero è passato e se n'è andato.

### Fase 3 — Il ruolo di Python (e quando non serve)

Il modulo è Python, quindi gira col **Python del managed node** (non col tuo):
ecco perché l'agentless *richiede* Python sul target. Ma non tutto ha bisogno di
Python. Il modulo **raw** salta l'intero meccanismo: è pura shell spedita via SSH.

    $SSH 'echo "raw: solo shell, nessun Python coinvolto"'

È proprio così che si fa il **bootstrap** di una macchina che Python ancora non ce
l'ha: con raw installi Python via SSH, e da lì in poi puoi usare i moduli veri.

### Fase 4 — L'intervista (i facts)

Rileggi l'output del tuo modulo: hai restituito dei **facts** dentro
ansible_facts. È il modulo **setup** in miniatura: prima di agire, Ansible
"intervista" ogni macchina — chi sei, che sistema hai, quanta memoria, quali IP —
e quei facts diventano variabili utilizzabili nel resto del lavoro (li userai sul
serio dal capitolo 12). L'intervista è la prima cosa che accade quando lanci un
playbook; qui l'hai scritta tu.

## Criteri di "fatto"

- Il managed node è in piedi con **solo sshd + python3**, e ci entri in SSH a
  chiave.
- module.py completato restituisce un JSON valido con almeno tre facts in
  ansible_facts, eseguito con il **Python del nodo**.
- Hai riprodotto i **quattro fotogrammi** del viaggio (copia, esecuzione remota,
  JSON, pulizia), e alla fine sul nodo **non resta** il file temporaneo.
- Sai dire perché il modulo raw non richiede Python sul target, e a cosa serve.

## Domande di riflessione

**a.** Agentless richiede *Python* sul managed node ma **non** un *agente*. Che
differenza fa, in concreto, per la sicurezza e per la manutenzione di mille
macchine, non avere un demone tuo installato e in ascolto su ognuna?

**b.** Elenca i quattro fotogrammi del viaggio di un task. Alla fine, *dove* è
rimasto lo stato di ciò che hai fatto sul managed node — e cosa dice questo sul
perché Ansible viene chiamato "senza stato" sul target?

**c.** Hai una macchina nuova, senza Python. Con i moduli normali non combini
nulla. Come la porti al punto da poterci usare Ansible per davvero, e quale
"modulo" ti serve per il primo passo?

## Pulizia

    bash start/node.sh down

## Dove porta

Hai dato per scontata una cosa che qui era il perno: la **chiave SSH** che ti fa
entrare senza password. È il capitolo 3, "SSH sotto il cofano". Poi, al 6,
installerai Ansible; e al 9, quando lancerai il primo ansible -m ping e ansible -m
setup, riconoscerai sotto il cofano esattamente questi quattro fotogrammi e questa
intervista — solo, automatizzati.
