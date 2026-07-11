# Capitolo 11 — Le chiavi del custode

**Livello:** Intermedio

Al capitolo 10 il privilegio era un interruttore acceso in blocco: become: true, e
tutto girava da root. Ora apri quella scatola. **become** non è "diventa root e basta":
è chiedere le chiavi al **custode** dell'edificio — su Linux, quasi sempre **sudo**. Il
custode ha un regolamento (il file **sudoers**): decide *chi* può prendere *quale*
chiave, e se prima deve mostrare un documento (la **password**). Questo capitolo — il
primo della fascia Intermedio — ti fa vedere l'anatomia di become, il regolamento sotto
il cofano, le tre risposte alla password, come diventare un utente *diverso* da root, e
le regole d'oro per non lasciare in giro la chiave universale.

## Obiettivi

- Perché **non** collegarsi direttamente come root (11.1).
- L'**anatomia di become**: become, become_method, become_user, become_flags (11.2).
- **sudoers sotto il cofano**: il cancello che decide chi diventa chi (11.3).
- La **password di sudo**: -K, la variabile (da cifrare), NOPASSWD (11.4).
- **Non solo sudo**: gli altri metodi (11.5).
- **Diventare un utente diverso da root** (11.6).
- Le **regole d'oro** della sicurezza (11.7).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Docker per due nodi. Rete alla prima accensione.
- Il become: true del capitolo 10; l'inventario del capitolo 8.

## Lo scenario

Due nodi, due politiche del custode. **web1** lo raggiungi come **deploy**, che ha un
lasciapassare permanente (NOPASSWD): sale senza mostrare nulla. **web2** lo raggiungi
come **secops**, che può salire ma **deve mostrare la password** ogni volta. Su entrambi
vive **appsvc**, un utente di servizio: diventeremo *lui*, non root, per scrivere i suoi
file.

## Consegna passo-passo

### Fase 0 — Accendi i nodi

    bash start/nodes.sh up

Due container. web1 con l'utente deploy (NOPASSWD), web2 con secops (password), entrambi
con appsvc e con il pacchetto **acl** (serve nella Fase 5).

### Fase 1 — Perché non entrare come root, e l'anatomia di become

Potresti collegarti direttamente come root e finirla lì. Non si fa, per tre ragioni:
l'**audit** (nei log compare "deploy ha fatto sudo X", non un anonimo "root ha fatto X");
il **minimo privilegio** (stai da utente normale e sali solo per i gesti che lo
richiedono); la **superficie d'attacco** (il login SSH di root si disabilita, così una
chiave rubata non è subito la chiave universale). Ansible fa proprio questo: si collega
come utente normale e **sale coi gradi solo quando serve**. Le manopole:

- **become**: true/false — chiedo le chiavi o no.
- **become_method**: come le chiedo (sudo di default).
- **become_user**: chi divento (root di default).
- **become_flags**: opzioni fini passate al metodo.

### Fase 2 — Accendi become e guarda chi diventi (TODO 1)

Apri start/site.yml. Completa il **TODO 1**: accendi become: true sul play. Poi il primo
task chiede al nodo chi sei davvero:

    - name: Confirm we escalated to root
      ansible.builtin.command: id -un
      register: who
      changed_when: false

    - name: Show who connected and who we became
      ansible.builtin.debug:
        msg: "{{ ansible_user }} -> {{ who.stdout }}"

Esegui e leggi il debug:

    "msg": "deploy -> root"
    "msg": "secops -> root"

Due utenti diversi si sono collegati, entrambi sono saliti a root. Il *come*, però, è
stato diverso — ed è la prossima fase.

### Fase 3 — Il regolamento del custode: sudoers

Chi decide se deploy e secops *possono* salire? Il file **sudoers** sul nodo. Leggi le
due politiche:

    cat /etc/sudoers.d/deploy      # deploy ALL=(ALL) NOPASSWD:ALL
    cat /etc/sudoers.d/secops      # secops ALL=(ALL) ALL

Si leggono così: **utente  ospiti=(utenti-bersaglio)  comandi**. deploy può diventare
chiunque (ALL) ed eseguire qualsiasi comando (ALL) **senza password** (NOPASSWD). secops
ha gli stessi permessi **ma senza NOPASSWD**: deve mostrare il documento. Il sudoers è il
cancello: se un utente non ha una riga qui, become fallisce — non c'è chiave che tenga.
(Nota: si scrive con visudo, che valida la sintassi; una riga rotta può chiuderti fuori.)

### Fase 4 — La password di sudo (TODO 2)

web2 (secops) richiede la password. Prova a eseguire senza dargliela:

    ansible-playbook -i start/inventory.ini -l web2 start/site.yml

    fatal: [web2]: FAILED! => {"msg": "Missing sudo password"}

Il custode ti ha fermato al cancello. Ci sono **tre** risposte:

1. **-K** (--ask-become-pass): Ansible te la chiede all'avvio, interattiva. Ottima da
   terminale, inutile in automazione (nessuno digita).
2. La **variabile** ansible_become_password: la scrivi nell'inventario. Comoda per
   l'automazione, ma è una **password in chiaro** — va **cifrata con Vault** (capitolo
   18). Qui, per il lab, la mettiamo in chiaro con questa avvertenza.
3. **NOPASSWD**: nessuna password (è il caso di deploy). Comodissimo, ma è anche il punto
   debole — Domanda b.

Completa il **TODO 2** in start/inventory.ini: dai a web2 la sua
ansible_become_password. Riesegui: ora anche secops passa il cancello.

### Fase 5 — Diventare un utente diverso da root (TODO 3)

become non significa solo "root". Spesso vuoi diventare l'**utente del servizio** — qui
appsvc — per creare i *suoi* file con la *sua* proprietà, senza passare da root e poi
correggere. Completa il **TODO 3**: aggiungi become_user: appsvc al task che scrive il
marcatore:

    - name: Write the ownership marker AS the app user, not root
      ansible.builtin.copy:
        content: "owned by the service account, not root\n"
        dest: /srv/app/owner.txt
        mode: "0640"
      become_user: appsvc

Il play sale a root (become: true), ma **questo task** scende ad appsvc. Verifica:

    stat -c '%U:%G' /srv/app/owner.txt      # -> appsvc:appsvc, non root

**Attenzione a un tranello reale:** diventare un utente *non privilegiato* (root →
appsvc) obbliga Ansible a passargli i file temporanei, e per farlo usa le **ACL**
(setfacl). Se sul nodo manca il pacchetto acl, fallisce con "Failed to set permissions
on the temporary files…". Per questo start/nodes.sh installa acl. È uno dei pochi
requisiti *sui nodi* che Ansible impone.

### Fase 6 — Non solo sudo

sudo è il custode del 99% dei sistemi Linux, ma non l'unico. Cambiando become_method usi
altri portieri:

- **su** (l'anziano, chiede la password del *bersaglio*), **doas** (il minimalista di
  OpenBSD), **pbrun**/**pfexec** (mondi enterprise/Solaris), **runas** (Windows).

Con become_exe e become_flags regoli l'eseguibile e le opzioni. Ma se non hai un motivo
preciso, resta su sudo: è quello che i nodi già conoscono.

### Fase 7 — Le regole d'oro

- **Minimo privilegio**: become dove serve, non "acceso ovunque per comodità". Un task
  che non tocca root non deve salire.
- **NOPASSWD ristretto**: se automatizzi senza password, non dare ALL — elenca i
  **comandi specifici** nel sudoers (Domanda b).
- **Niente login root diretto**: entra da utente, sali con become; disabilita il root via
  SSH.
- **La password in Vault**: mai in chiaro nei file versionati (capitolo 18).
- **become_user mirato**: diventa l'utente giusto per il gesto, non root per tutto.

## Criteri di "fatto"

- Con become: true, il debug mostra **deploy -> root** e **secops -> root**.
- web2 **senza** ansible_become_password → "Missing sudo password"; **con** la variabile
  → passa.
- /srv/app/owner.txt è di **appsvc**, non di root; la cartella /srv/app è di appsvc.
- Rieseguendo → **changed=0** (idempotenza).

## Domande di riflessione

**a.** Perché è meglio collegarsi come utente normale e *salire* con become, invece di
collegarsi direttamente come root? Elenca almeno tre vantaggi concreti (pensa a: chi
compare nei log, cosa succede se la chiave viene rubata, cosa puoi disabilitare su SSH).

**b.** NOPASSWD è comodo — l'automazione non deve digitare nulla — ma ALL=(ALL)
NOPASSWD:ALL è una chiave universale senza serratura. Perché è pericoloso, e come
manterresti l'automazione *senza password* restringendo però cosa può fare? E se invece
scegli di usare la password, dov'è il posto giusto per tenerla (anticipo del cap. 18)?

**c.** Il marcatore viene scritto con become_user: appsvc, non da root. Perché creare un
file *come* l'utente del servizio è meglio che crearlo da root e poi fare chown? (Pensa a
proprietà corretta fin dall'inizio, minimo privilegio, e a cosa può andare storto nel
"poi correggo".)

## Pulizia

    bash start/nodes.sh down

## Dove porta

Hai incontrato la tua prima variabile "seria": ansible_become_password. Il capitolo 12
apre proprio quel mondo — **la gestione maniacale delle variabili**: dove vivono (play,
inventario, riga di comando), i tipi, Jinja2, register e set_fact. E la password che qui
hai lasciato in chiaro troverà la sua cassaforte al capitolo 18, con Ansible Vault.
