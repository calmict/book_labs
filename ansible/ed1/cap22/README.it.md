# Capitolo 22 — Quando salta una corda

**Livello:** Avanzato

Sai scoprire la flotta (cap. 21) e agirci sopra. Ma un'orchestra vera suona in un mondo
imperfetto: una corda salta a metà concerto, un leggio cade, un musicista sbaglia l'attacco. La
domanda non è *se* qualcosa andrà storto su uno dei mille nodi dell'appello, ma *cosa fa il
direttore quando succede*. Di default Ansible, davanti a un errore, si ferma su quell'host —
prudente, ma non basta. Questo capitolo ti dà gli strumenti della resilienza: recuperare con
block/rescue/always, riprovare ciò che è lento, ridefinire cosa conta come errore, e — quando
serve — fermare tutto in fretta prima che il disastro si propaghi.

## Obiettivi

- Il comportamento di default: **fermarsi su quell'host** (22.1).
- **block, rescue, always**: il try/catch/finally di Ansible (22.2).
- **ignore_errors**: continuare nonostante tutto, con giudizio (22.3).
- **failed_when e changed_when**: ridefinire successo e cambiamento (22.4).
- Riprovare ciò che è lento: **until, retries, delay** (22.5).
- Fallire in fretta: **any_errors_fatal e max_fail_percentage** (22.6).
- Validare prima di agire: **assert e fail** (22.7).
- Gli handler e i fallimenti: **force_handlers** (22.8).
- Le **buone abitudini** con la gestione degli errori (22.9).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Gli handler del capitolo 14 (qui tornano, e imparano a sopravvivere ai fallimenti).
- (Nessun nodo: come al capitolo 13, tutto si risolve sul control node — più host locali,
  connection: local — così vedi l'isolamento per-host senza container.)

## Lo scenario

Un inventario di quattro host locali (web1, web2, web3, db1). Un deploy che *deve* essere
resiliente: valida i presupposti prima di toccare qualcosa, prova il passo rischioso con una
rete di sicurezza, aspetta un servizio lento con pazienza, e ignora ciò che non è critico. Su un
host (db1) il deploy fallisce apposta: guardi come il play *non* crolla, ma recupera.

Prepara l'ambiente:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start

### Fase 1 — Il default: fermarsi su quell'host (22.1)

Senza reti, se un task fallisce su un host, Ansible *smette con quell'host* e prosegue con gli
altri. Isolamento per-host: db1 può cadere mentre web1/web2/web3 continuano. È prudente ma cieco
— l'host caduto resta a metà, e tu non hai deciso *cosa* fare del suo fallimento. Il resto del
capitolo è: prendere quella decisione.

### Fase 2 — Validare prima di agire: assert (22.7 — TODO 3)

La prima resilienza è non partire se le premesse sono sbagliate. Completa il **TODO 3** in
site.yml: un assert che controlla deploy_env *prima* di qualunque azione —

    - name: deploy_env must be one we know
      ansible.builtin.assert:
        that: deploy_env in ['dev', 'staging', 'prod']
        fail_msg: "invalid deploy_env '{{ deploy_env }}'"

Con un valore buono, prosegue. Con -e deploy_env=banana, *fallisce subito* e non scrive un solo
file: meglio fermarsi in porta che a metà deploy. (assert per una condizione; fail per abortire
con un messaggio quando la logica lo decide.) Domanda a.

### Fase 3 — block, rescue, always (22.2 — TODO 1)

Il cuore: il try/catch/finally di Ansible. Completa il **TODO 1**: avvolgi il deploy in
block/rescue/always —

    - name: Deploy with rollback safety
      block:
        - name: Deploy the app
          ansible.builtin.copy: { content: "deployed {{ deploy_env }}\n", dest: "{{ lab }}/{{ inventory_hostname }}.deployed", mode: "0644" }
        - name: Simulate a mid-deploy failure on one host
          ansible.builtin.command: /bin/false
          when: inventory_hostname == fail_host
          changed_when: false
      rescue:
        - name: Roll back
          ansible.builtin.copy: { content: "rolled back\n", dest: "{{ lab }}/{{ inventory_hostname }}.rollback", mode: "0644" }
      always:
        - name: Clean up (always runs)
          ansible.builtin.copy: { content: "cleaned up\n", dest: "{{ lab }}/{{ inventory_hostname }}.cleanup", mode: "0644" }

- **block**: il gruppo di task "normali" (il try).
- **rescue**: gira *solo se* qualcosa nel block è fallito (il catch) — qui il rollback. E
  l'errore è *gestito*: l'host non risulta fallito, il play continua.
- **always**: gira *comunque*, successo o fallimento (il finally) — la pulizia che non puoi
  saltare.

Su db1 il deploy fallisce → scatta rescue (rollback) + always (cleanup). Su web* il deploy riesce
→ niente rescue, ma always pulisce lo stesso. Domanda b.

### Fase 4 — Riprovare ciò che è lento: until, retries, delay (22.5 — TODO 2)

Un servizio che parte in dieci secondi non è *rotto*: è lento. Fallire al primo colpo sarebbe
sbagliato. Completa il **TODO 2**: un health check che riprova finché non passa —

    - name: Health check (slow - retry until healthy)
      ansible.builtin.shell: 'f="{{ lab }}/{{ inventory_hostname }}.hc"; echo x >> "$f"; test "$(wc -l < "$f")" -ge 3'
      register: hc
      until: hc.rc == 0
      retries: 5
      delay: 0
      changed_when: false

**until** è la condizione da raggiungere; **retries** quante volte riprovare; **delay** l'attesa
tra un tentativo e l'altro. Il check qui passa solo al terzo colpo: Ansible riprova (FAILED -
RETRYING...) e va avanti quando è sano, invece di arrendersi subito.

### Fase 5 — Ridefinire successo e ignorare (22.3, 22.4)

Due strumenti dati nel play, che rovesciano il concetto di errore:

- **failed_when**: *tu* decidi cosa è un fallimento. Un grep che non trova nulla esce con rc=1,
  ma "non trovato" spesso è la risposta giusta, non un errore: failed_when: false lo tratta come
  successo. (Il gemello changed_when del cap. 5/9 fa lo stesso col colore giallo.)
- **ignore_errors**: un passo *non critico* (mandare una metrica) può fallire senza affondare il
  deploy. ignore_errors: true prosegue. Ma con giudizio: ignorare un errore critico è come
  togliere la spia dell'olio — il problema resta, tu non lo vedi più. Domanda c.

### Fase 6 — Gli handler e i fallimenti: force_handlers (22.8)

Ricordi gli handler (cap. 14): girano a fine play, solo se notificati. Ma se un task *dopo* la
notifica fallisce, il play si ferma *prima* di lanciarli — e il reload che avevi già guadagnato
va perso. **force_handlers: true** li lancia comunque. Lo dimostra handlers.yml:

    ansible-playbook -i inventory.ini handlers.yml       # fallisce apposta...
    cat "$CAP22_LAB/fh.done"                              # ...ma l'handler e' girato lo stesso

### Fase 7 — Fallire in fretta per proteggere la flotta (22.6)

A volte *non* vuoi che gli altri host proseguano. Se il rollout è avvelenato, ogni host in più
che lo riceve è un danno in più. Lo dimostra failfast.yml con **any_errors_fatal: true**:

    ansible-playbook -i inventory.ini failfast.yml

db1 fallisce il precheck → "NO MORE HOSTS LEFT": l'azione pericolosa non raggiunge *nessuno*,
nemmeno i web sani. Il fratello graduato è **max_fail_percentage**: "abortisci se più del 20%
fallisce" — tolleri qualche perdita, ti fermi prima dell'emorragia. Default (fermarsi solo su
quell'host) per l'indipendenza; any_errors_fatal per le operazioni tutto-o-niente.

### Fase 8 — Le buone abitudini (22.9)

- **Non ignorare per pigrizia.** ignore_errors e failed_when: false sono bisturi, non tappeti
  sotto cui nascondere: usali dove il "fallimento" davvero non conta, mai per zittire un errore
  vero.
- **Rescue che pulisce davvero.** Un rescue che scrive "rolled back" ma non ripristina è teatro:
  fai in modo che always e rescue riportino il sistema a uno stato noto.
- **Valida in porta** (assert/fail): mille controlli a valle costano meno di un deploy sbagliato
  a metà.
- **Fail-fast per il tutto-o-niente, per-host per l'indipendente**: scegli in base a *quanto un
  host dipende dagli altri*.

## Criteri di "fatto"

- assert (TODO 3) blocca deploy_env=banana *prima* di scrivere qualsiasi file; con un valore
  valido prosegue.
- block/rescue/always (TODO 1): su db1 esistono i marker rollback e cleanup; su web1 esistono
  deployed e cleanup ma *non* rollback; il play non risulta fallito (rescued=1 su db1).
- until (TODO 2): l'health check passa dopo alcuni tentativi invece di fallire subito.
- ignore_errors lascia il play a failed=0 (ignored maggiore o uguale a 1); failed_when: false
  tratta rc=1 come successo.
- handlers.yml: fh.done esiste nonostante il fallimento (force_handlers).
- failfast.yml: con any_errors_fatal il rollout non raggiunge nessun host.

(Nota: questo capitolo *non* è sull'idempotenza — il deploy fallisce e recupera apposta a ogni
giro; il punto è come reagisce, non che converga a changed=0.)

## Domande di riflessione

**a.** assert e fail fermano il play *prima* di agire. Perché "validare in porta" è più economico
che gestire l'errore a valle, e qual è la differenza di intento tra assert (una precondizione che
*deve* valere) e un semplice when che salta il task se la condizione è falsa?

**b.** In block/rescue/always, rescue trasforma un host *fallito* in un host *gestito* (il play
continua, l'host non risulta failed). In cosa è diverso da ignore_errors, che pure "continua
nonostante l'errore"? Quando un fallimento va *recuperato* (rescue) e quando va *ignorato*
(ignore_errors), e perché confonderli è pericoloso?

**c.** Il default isola i fallimenti per-host (uno cade, gli altri continuano); any_errors_fatal
fa il contrario (uno cade, tutti si fermano). Nessuno dei due è "giusto" in assoluto: da cosa
dipende la scelta? Fai un esempio in cui l'indipendenza per-host è ciò che vuoi, e uno in cui è
esattamente ciò che ti rovina.

## Pulizia

Niente da smontare: nessun nodo, nessun container. I marker finiscono in /tmp/cap22-lab (o dove
punti CAP22_LAB); cancellali se vuoi.

## Dove porta

Sai far sopravvivere un playbook agli imprevisti. Ma il modo migliore di gestire un errore è
*non commetterlo*: il **capitolo 23** apre linting e check mode — ansible-lint che ti corregge
prima di eseguire, e il modo "prova a vuoto" che ti mostra cosa cambierebbe senza toccare niente.
Dagli strumenti che reagiscono agli errori, a quelli che li prevengono.
