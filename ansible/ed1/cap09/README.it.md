# Capitolo 9 — Il cenno, non lo spartito

**Livello:** Fondamentale

La rubrica risponde all'appello (cap. 8). Ora il direttore dà i primi ordini — ma
senza scrivere lo spartito completo (quello è il playbook, cap. 10). Un comando
**ad-hoc** è un *cenno*: un modulo, un bersaglio, subito, su tutta la flotta. Perfetto
per una cosa al volo (chi è acceso? quanto spazio disco? riavvia quel servizio);
sbagliato per qualcosa da ripetere o versionare — lì serve lo spartito. Qui impari
l'anatomia del cenno, l'arsenale dei moduli, e la differenza cruciale — che già
intuivi dal cap. 5 — fra un modulo **interruttore** e un comando **campanello**.

## Obiettivi

- Quando l'ad-hoc **sì** e quando **no**.
- L'**anatomia**: ansible <pattern> -m <modulo> -a "<args>" [-b].
- **command vs shell** (pipe e redirezioni), e perché entrambi sono "campanelli".
- L'**arsenale**: copy e file (interruttori idempotenti), setup (i facts =
  l'intervista del cap. 2).
- I **fork**: parallelismo misurabile (cap. 7).
- **-b / become**: amministratore al volo (cap. 7 e 11).
- I **casi reali** (9.8): il giro del mattino.

## Prerequisiti

- Il venv del capitolo 6 (o ricrealo con start/requirements.txt).
- Docker per due nodi. Rete alla prima accensione (apt sui nodi).

## Lo scenario

Due web server, **web1** e **web2**. Ti colleghi come **deploy** — un utente *non*
root con sudo — così vedi become entrare in azione: senza -b sei deploy, con -b sei
root.

## Consegna passo-passo

### Fase 0 — Accendi i nodi

    bash start/nodes.sh up

Due container con l'utente deploy (sudo senza password), sshd e python3.

### Fase 1 — L'anatomia, e il ping

    ansible -i start/inventory.ini web -m ping

L'anatomia del cenno: **pattern** (chi, dal cap. 8) + **-m modulo** (cosa) + **-a
argomenti** (come) + **-b** (facoltativo, coi gradi da root). Il modulo di default è
command, quindi questo è già un cenno completo:

    ansible -i start/inventory.ini web -a uptime

### Fase 2 — command contro shell

    ansible -i start/inventory.ini web1 -m command -a 'echo ciao | wc -c'
    ansible -i start/inventory.ini web1 -m shell   -a 'echo ciao | wc -c'

Il primo stampa **letteralmente** ciao | wc -c: command **non** usa una shell, la pipe
è solo testo. Il secondo stampa **5**: shell passa tutto a /bin/sh, la pipe gira.
Regola: **command di default** (più sicuro), **shell solo** quando ti servono pipe,
redirezioni o variabili. E guarda il colore: entrambi dicono sempre **CHANGED** — sono
*campanelli* (cap. 5): l'exit code non sa se qualcosa è davvero cambiato.

### Fase 3 — L'arsenale interruttore: copy

Completa il **TODO 1** in start/runbook.sh: deploya il file di motd con **copy** (e
-b, perché /etc è di root). Poi lancia il runbook **due volte** e guarda la riga del
copy:

    web1 | CHANGED => ...      # primo giro: il file non c'era, l'ha scritto (giallo)
    web1 | SUCCESS => ...      # secondo giro: già a posto, "changed": false (verde)

**Questo è un interruttore** (cap. 5): il modulo controlla lo stato del file e agisce
*solo se serve*. È tutta qui la differenza con command.

### Fase 4 — file + become

Completa il **TODO 2**: assicura che la cartella /etc/cap09.d esista, con **file
state=directory** e -b. Idempotente anche lui (changed → ok), e -b è obbligatorio
perché scrivi in /etc.

### Fase 5 — L'amministratore al volo (-b)

    ansible -i start/inventory.ini web1 -m command -a whoami        # -> deploy
    ansible -i start/inventory.ini web1 -b -m command -a whoami      # -> root

È il **become** del capitolo 7 (là era il default nel cfg), qui esplicito sulla riga.
La regola: chiedi i gradi da root **solo** quando servono.

### Fase 6 — setup: l'intervista

Completa il **TODO 3**: leggi *un* fact con **setup** e un filtro:

    ansible -i start/inventory.ini web1 -m setup -a 'filter=ansible_distribution'

Sono i **facts** del capitolo 2 (la macchina che si racconta), ora a comando. È la
miniera da cui il capitolo 12 pescherà le variabili.

### Fase 7 — I fork: il parallelismo

    ansible -i start/inventory.ini web -a 'sleep 3'                # due host in parallelo: ~4s
    ansible -i start/inventory.ini web --forks 1 -a 'sleep 3'      # in fila: ~6s

I forks del capitolo 7 resi visibili col cronometro: è la differenza tra fare tremila
server in un minuto o in un'ora.

### Fase 8 — Il giro del mattino (i casi reali)

Il runbook.sh completo è l'ad-hoc nel suo mestiere: chi è acceso (ping), da quanto
(uptime), motd aggiornato (copy), la cartella al suo posto (file), un fact letto
(setup). Operazioni veloci, da operatore — che però **non** metteresti in produzione
senza uno spartito ripetibile.

## Criteri di "fatto"

- runbook.sh completato gira: **motd** deployato (copy), **/etc/cap09.d** creato
  (file+become), **un fact** letto (setup).
- copy e file: **secondo giro verde** (idempotenti). command: **sempre CHANGED**.
- command vs shell: la pipe è **letterale** con command, **eseguita** con shell.
- -b: whoami passa da **deploy** a **root**.

## Domande di riflessione

**a.** Quando un comando ad-hoc è lo strumento giusto, e quando ti serve invece un
playbook? (Pensa a: una volta sola vs ripetibile, versionato, rivedibile.)

**b.** copy riporta ok al secondo giro, command riporta changed sempre. Collega al
capitolo 5: quale dei due è un **interruttore** e quale un **campanello**, e perché per
command dovresti usare changed_when o — meglio — un modulo dedicato?

**c.** Perché command è il default e non shell? Cosa rischi passando input non fidato a
shell che con command non rischieresti?

## Pulizia

    bash start/nodes.sh down

## Dove porta

Il cenno serve per le cose al volo. Ma per qualcosa da fare ogni giorno, in ordine,
versionato e rivedibile, serve lo **spartito scritto**: il playbook, capitolo 10 —
dove questi stessi moduli smettono di essere cenni sparsi e diventano una partitura.
