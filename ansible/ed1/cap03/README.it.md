# Capitolo 3 — La chiave che resta a casa

**Livello:** Fondamentale

Al capitolo 2 lo script ti ha regalato una chiave e sei entrato sul managed node
**senza password**. Come? Ora apri il cofano dell'SSH — il canale su cui viaggia
*tutto* Ansible. Il cuore è la **crittografia asimmetrica** e una regola d'oro: la
chiave **privata** non lascia mai il control node; viaggia solo la sua metà
**pubblica**. Costruiremo un piccolo mondo — un **bastion** affacciato e un
**target** chiuso in una rete segregata — e lo attraverseremo a mano.

## Obiettivi

- Capire la coppia asimmetrica: **privata** (resta a casa) e **pubblica** (va sui
  server, in authorized_keys); e l'handshake che lo mette in pratica.
- Anatomia dei file e i **permessi** che contano (la trappola "UNPROTECTED PRIVATE
  KEY").
- ~/.ssh/config: **alias** leggibili e **ControlMaster**, il multiplexing che
  rende Ansible veloce.
- **Bastion host / ProxyJump**: attraversare una rete segregata.
- **Passphrase** (protezione a riposo), **ssh-agent** (automazione senza prompt),
  e la trappola dell'**host key checking**.

## Prerequisiti

- Un motore **Docker** (bastion e target sono container). Verifica: docker version
- Un client SSH standard (ssh, scp, ssh-keygen).
- **Niente Ansible**: ci arriviamo al capitolo 6. Il portare su del lab scarica
  sshd: serve rete la prima volta.

## Lo scenario

- **Control node:** la tua macchina.
- **Bastion:** l'unica macchina affacciata (porta 2223); il portone di casa.
- **Target:** chiuso nella rete di lab, **senza porta pubblica**, e il suo nome si
  risolve **solo lì dentro**. Ci arrivi soltanto passando dal bastion.

Il lab vive in /tmp/cap03-lab (chiave inclusa): un cassetto usa-e-getta.

## Consegna passo-passo

### Fase 0 — Tira su il lab

    bash start/lab.sh up

Crea la rete, il bastion, il target, e una chiave effimera in /tmp/cap03-lab/key.
Userai la config SSH con: ssh -F start/ssh_config <host>

### Fase 1 — La chiave e la serratura

Guarda i due file generati:

    ls -l /tmp/cap03-lab/key /tmp/cap03-lab/key.pub

key è la **privata** (resta a casa), key.pub è la **pubblica**. La pubblica è
stata copiata nell'authorized_keys dei server: è la *serratura*, puoi appenderla
in piazza senza rischio. La privata è l'unica che apre. Entra e osserva
l'handshake:

    ssh -F start/ssh_config -v bastion 'hostname' 2>&1 | grep -iE 'offering|accepted|publickey' | head

Vedi SSH offrire la chiave pubblica e il server accettarla: nessuna password ha
attraversato la rete.

### Fase 2 — La trappola dei permessi

La chiave privata è un segreto, e SSH lo pretende. Rendila leggibile a tutti e
riprova:

    cp /tmp/cap03-lab/key /tmp/cap03-lab/badkey
    chmod 644 /tmp/cap03-lab/badkey
    ssh -i /tmp/cap03-lab/badkey -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 true

    @@@ WARNING: UNPROTECTED PRIVATE KEY FILE! @@@

SSH **rifiuta** una chiave privata leggibile da altri. Regola: privata a 600,
~/.ssh a 700. È la prima cosa che rompe l'automazione di chi copia le chiavi con i
permessi sbagliati.

### Fase 3 — L'alias, e il bastion

Apri start/ssh_config: l'entry **bastion** è già scritta (HostName, Port, User,
IdentityFile). Ora il **TODO 1**: completa l'entry **target** perché lo raggiunga
*attraverso* il bastion. Prima prova senza:

    ssh -F start/ssh_config -o ProxyJump=none target 'hostname'

    ssh: Could not resolve hostname cap03-target

Il target non ha porta pubblica e il suo nome vive solo nella rete di lab: da qui
non lo vedi. Aggiungi la riga che manca all'entry target —

    ProxyJump bastion

— e riprova:

    ssh -F start/ssh_config target 'hostname'

Sei sul target, saltando dal bastion. **Questo è esattamente come Ansible entra
nelle reti segregate**: un ProxyJump nell'inventario, e la flotta interna diventa
raggiungibile senza esporre nulla.

### Fase 4 — ControlMaster: perché Ansible è veloce

Ogni connessione SSH paga un handshake TCP + crittografia. Ansible ne apre a
decine per host: se ognuna ripartisse da zero, sarebbe lentissimo. La cura è il
**multiplexing**. Completa il **TODO 2** nella config, aggiungendo al bastion:

    ControlMaster auto
    ControlPath /tmp/cap03-cm-%C
    ControlPersist 60s

Poi misura tre connessioni di fila:

    for i in 1 2 3; do
      s=$(date +%s%N); ssh -F start/ssh_config bastion true; e=$(date +%s%N)
      echo "conn $i: $(( (e-s)/1000000 )) ms"
    done

La prima apre un **socket master**; la seconda e la terza lo **riusano** — quasi
zero. È la fondazione su cui il capitolo 25 costruirà il pipelining. **Attenzione:**
il ControlPath deve restare **corto** (il socket ha un limite di ~108 caratteri):
tienilo in /tmp, non in una cartella profonda.

### Fase 5 — La chiave a riposo, e l'agente

Finora la chiave era senza passphrase: comoda, ma se rubata è subito usabile.
Proteggila a riposo:

    ssh-keygen -t ed25519 -N 'una-passphrase' -f /tmp/cap03-lab/enckey -q
    ssh-keygen -y -P '' -f /tmp/cap03-lab/enckey

    (rifiutata: senza la passphrase la chiave privata non si legge)

Ora però ogni connessione chiederebbe la passphrase — e l'automazione si blocca al
primo prompt. Qui entra l'**ssh-agent**: sblocchi la chiave **una volta**
(ssh-add) e l'agente la tiene in memoria per la sessione, così Ansible non incontra
richieste. È la tensione fra sicurezza e automazione: passphrase + agent per le
persone; in CI, spesso una chiave dedicata *senza* passphrase ma con accessi
strettissimi.

### Fase 6 — Host key checking (e perché nel lab l'abbiamo spento)

La prima volta che entri, SSH registra la chiave del server in known_hosts:
**fiducia al primo incontro**. Se quella chiave cambia dopo, SSH lancia l'allarme
— è la difesa contro un impostore che si mette in mezzo. Nel lab hai visto
StrictHostKeyChecking no e UserKnownHostsFile /dev/null: comodo con container
usa-e-getta, ma in produzione **spegne proprio quella difesa**. È la trappola
numero uno di chi automatizza: disabilitare l'host key checking "perché dà
fastidio", e restare esposti.

## Criteri di "fatto"

- Entri nel **bastion** con la chiave via alias; la chiave a **0644 viene
  rifiutata**.
- L'entry **target** con ProxyJump ti porta sul target **attraverso il bastion**
  (il diretto fallisce).
- Con il **ControlMaster** la seconda connessione è quasi istantanea (socket master
  creato).
- Sai spiegare perché la chiave **privata** non deve mai lasciare il control node.

## Domande di riflessione

**a.** Perché la chiave **pubblica** può stare su mille server senza rischio,
mentre la **privata** non deve lasciare il control node? Cosa comporterebbe copiare
la privata su un server "per comodità"?

**b.** L'**agent forwarding** (-A) inoltra il tuo agente alla macchina su cui
entri, comodo per rimbalzare oltre. Perché su un bastion condiviso o non fidato è
pericoloso, e in che modo **ProxyJump** risolve lo stesso problema in modo più
sicuro?

**c.** Nel lab hai disattivato l'host key checking. In produzione quali difese
perdi disabilitandolo, e come lo gestiresti con Ansible su una flotta vera (invece
di spegnerlo)?

## Pulizia

    bash start/lab.sh down

## Dove porta

Hai smontato il canale su cui viaggia tutto Ansible. Al capitolo 6 lo installi; al
7, nell'ansible.cfg, ControlMaster, forks e pipelining diventano impostazioni
vere; all'8, nell'inventario, chiavi e bastion diventano variabili per-host. Da qui
in poi, quando Ansible "si connette", saprai esattamente cosa succede sotto il
cofano.
