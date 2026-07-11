# Capitolo 18 — La cassaforte

**Livello:** Avanzato

Al capitolo 11 hai chiesto le chiavi al custode: become, e per il nodo con sudo a
password l'hai fatto funzionare — ma la password l'hai scritta *in chiaro*
nell'inventario, con la promessa "un giorno la cifreremo". Quel giorno è oggi. Un
playbook finisce in un repository Git, e Git *non dimentica*: una password committata
in chiaro resta nella cronologia per sempre, anche se la cancelli domani. Questo
capitolo — il primo della fascia Avanzato — apre la cassaforte di Ansible: **Ansible
Vault**, che cifra i segreti *dentro* i tuoi file, così che il repository resti
condivisibile e il segreto resti segreto.

## Obiettivi

- Il **peccato originale**: il segreto in chiaro, e perché Git lo rende eterno (18.1).
- La **cifratura con una parola d'ordine** (18.2) e i **comandi** di ansible-vault (18.3).
- **Com'è fatto** un file cifrato (18.4).
- Cifrare il **singolo segreto** con encrypt_string (18.5).
- **Eseguire** un playbook con dati cifrati: password interattiva, file, config (18.6).
- Più segreti, più password: i **vault-id** (18.7).
- I **limiti** di Vault e cosa viene dopo (18.8); le **buone abitudini** (18.9).

## Prerequisiti

- Il venv del capitolo 6 (o start/requirements.txt).
- Il nodo con sudo *a password* del capitolo 11: qui torna secops (sudo con
  password), ed è la sua password che finalmente mettiamo in cassaforte.
- Docker per il nodo effimero; ansible-vault è già dentro ansible-core.

## Lo scenario

Un solo nodo, cap18-web1, raggiunto come **secops**: per diventare root serve la
password di sudo (secops-pw) — esattamente come al capitolo 11. Lì quella password
stava *in chiaro* in group_vars. Qui la chiudi in un file cifrato (vault.yml), la fai
riferire da un file in chiaro (vars.yml), e il playbook diventa root *senza che il
segreto compaia mai in chiaro* — né nel repository, né nell'output.

La **parola d'ordine del vault** di questo laboratorio è lab-vault-pass (nella realtà
non si scrive in una consegna: si custodisce a parte). È la chiave che apre la
cassaforte; la password di sudo secops-pw è ciò che *dentro* la cassaforte sta al
sicuro.

## Consegna passo-passo

Prepara l'ambiente:

    python3 -m venv venv && . venv/bin/activate
    pip install -r start/requirements.txt
    cd start
    ./nodes.sh up

### Fase 1 — Il peccato originale (18.1)

Apri start/group_vars/web/vars.yml: c'è ancora la vergogna del capitolo 11 —

    ansible_become_password: secops-pw

In chiaro. Chiunque legga il repository legge la password; e se la committi, resta nella
cronologia di Git *per sempre*. Questa è la fotografia da cui partiamo — Domanda a.

### Fase 2 — La cassaforte e la chiave d'indirezione (18.2, 18.3 — TODO 1)

La cura ha due mosse. Primo: **separa** il segreto dal resto. In group_vars/web/ il file
in chiaro vars.yml conterrà solo un *rimando*, e un file cifrato vault.yml conterrà il
valore vero. Completa il **TODO 1**.

In vars.yml togli la password e metti l'indirezione (convenzione: il nome della
variabile segreta comincia per vault_):

    ansible_become_password: "{{ vault_become_password }}"

Poi crea il file cifrato con il valore vero:

    ansible-vault create group_vars/web/vault.yml

(ti chiede la parola d'ordine — usa lab-vault-pass — e apre l'editor; scrivi dentro:)

    vault_become_password: secops-pw

Se preferisci partire da un file in chiaro e cifrarlo *sul posto*:

    ansible-vault encrypt group_vars/web/vault.yml

I comandi della cassaforte (18.3): **create** (nuovo, cifrato), **encrypt** (cifra un
file esistente), **view** (leggi senza modificare), **edit** (modifica in cifrato),
**decrypt** (torna in chiaro), **rekey** (cambia la parola d'ordine). Perché due file e
non uno solo cifrato? Perché così, con git diff, *vedi la struttura* (quali variabili
esistono) senza vedere i valori, e sai a colpo d'occhio quali sono i segreti —
Domanda b.

### Fase 3 — Com'è fatta la cassaforte (18.4)

Guardala da fuori e da dentro:

    ansible-vault view group_vars/web/vault.yml     # dentro: il valore in chiaro
    head -1 group_vars/web/vault.yml                 # da fuori: solo cifratura

La prima riga è la firma:

    $ANSIBLE_VAULT;1.1;AES256

Un'intestazione (formato 1.1, cifrario AES256) seguita dal blob esadecimale. Nessun
valore leggibile: quello che Git registra è *questo*, non secops-pw.

### Fase 4 — Cifrare il singolo segreto: encrypt_string (18.5 — TODO 2)

A volte non vuoi un file intero cifrato, ma *un solo valore* incastonato tra variabili
in chiaro. È il lavoro di **encrypt_string**: produce un blocco !vault che incolli
dentro un file di variabili normale. Completa il **TODO 2**.

Genera il segreto cifrato (un token applicativo) col suo nome di variabile:

    ansible-vault encrypt_string --name app_api_token 'tkn-9f3a-SECRET'

Incolla l'uscita in group_vars/web/vars.yml, al posto del token in chiaro: sarà una
cosa così —

    app_api_token: !vault |
              $ANSIBLE_VAULT;1.1;AES256
              66353933... (righe esadecimali)

Il task già presente nel playbook lo scrive in /etc/myapp/token (di root, via become):
a runtime Ansible lo decifra, ma nel file resta cifrato. File intero cifrato *oppure*
singola stringa inline: due strumenti, stessa cassaforte.

### Fase 5 — Eseguire con dati cifrati (18.6)

Il playbook ora *contiene* segreti cifrati: Ansible deve sapere la parola d'ordine per
decifrarli. Tre modi, dallo scomodo al comodo:

    # scrivi la parola d'ordine in un file usa-e-getta (mai committato)
    echo 'lab-vault-pass' > vpass.txt

    ansible-playbook -i inventory.ini site.yml --ask-vault-pass          # te la chiede a mano
    ansible-playbook -i inventory.ini site.yml --vault-password-file vpass.txt   # da file
    # oppure in ansible.cfg:  vault_password_file = ./vpass.txt

Senza la parola d'ordine, Ansible si ferma subito e onestamente:

    ERROR! Attempting to decrypt but no vault secrets found

Con la parola d'ordine, il play gira: diventa root con la password *presa dalla
cassaforte*, scrive il marker, e la prova del nove — rieseguendo, **changed=0**. Il
segreto ha fatto il suo lavoro senza mai mostrarsi.

### Fase 6 — Più segreti, più password: i vault-id (18.7 — TODO 3)

Finora una sola parola d'ordine per tutto. Ma dev e prod non dovrebbero condividere la
stessa chiave: chi lavora in sviluppo non deve poter aprire la cassaforte di
produzione. I **vault-id** danno a ogni cassaforte un'**etichetta** con la sua chiave.
Completa il **TODO 3**: cifra prod_secret.yml etichettandolo prod.

    ansible-vault encrypt --encrypt-vault-id prod --vault-id prod@prompt prod_secret.yml

L'intestazione ora *porta l'etichetta*:

    $ANSIBLE_VAULT;1.2;AES256;prod

(nota il formato **1.2**: la versione che aggiunge l'etichetta). Ed esegui prod.yml
passando *tutte* le identità che possiedi — Ansible prova quella giusta per ogni blocco:

    echo 'prod-pass' > prod-pass.txt
    ansible-playbook -i inventory.ini prod.yml \
        --vault-id lab@vpass.txt --vault-id prod@prod-pass.txt

Un solo run, due chiavi: lab apre il vault della become password, prod apre il
segreto di produzione. La parola d'ordine dell'etichetta prod in questo laboratorio è
prod-pass.

### Fase 7 — I limiti, e le buone abitudini (18.8, 18.9)

- **Vault cifra il *contenuto*, non l'*esistenza*.** Chi ha il repository vede *che* c'è
  un segreto e come si chiama la variabile; non ne vede il valore. E chiunque abbia la
  parola d'ordine ha tutto: Vault è una cassaforte, non un sistema di permessi.
- **La parola d'ordine è il vero segreto ora.** Non committarla mai (il file vpass.txt
  non si versiona); in produzione arriva da un gestore esterno — è il capitolo 19.
- **Buone abitudini** (18.9): separa vault.yml (cifrato) da vars.yml (in chiaro con i
  rimandi); prefissa le variabili segrete con vault_; cifra *il minimo
  indispensabile*, non l'intero progetto; ruota le chiavi con rekey; e un segreto
  committato in chiaro *anche una sola volta* va considerato **compromesso** e cambiato —
  Git non dimentica.

## Criteri di "fatto"

- In group_vars/web/vars.yml non c'è **nessuna** password in chiaro: solo l'indirezione
  {{ vault_become_password }} e il blocco !vault inline.
- group_vars/web/vault.yml è cifrato (prima riga $ANSIBLE_VAULT;1.1;AES256);
  ansible-vault view mostra il valore.
- Il playbook diventa root con la password presa dal vault e scrive il marker
  root:root; rieseguendo → **changed=0**.
- Senza parola d'ordine il playbook fallisce con "Attempting to decrypt but no vault
  secrets found".
- Il segreto etichettato prod ha l'intestazione ;1.2;AES256;prod e si decifra con la
  sua vault-id.

## Domande di riflessione

**a.** La password del capitolo 11 stava in chiaro nell'inventario e "funzionava".
Perché committarla anche una sola volta è un problema che *cancellarla domani* non
risolve? Cosa registra Git, e cosa dovresti fare del segreto una volta che è finito
nella cronologia?

**b.** Potresti cifrare un unico grande file con tutte le variabili, segrete e no.
Perché conviene invece separare vault.yml (cifrato) da vars.yml (in chiaro, coi rimandi
{{ vault_* }})? Cosa guadagni quando fai git diff o rileggi il progetto tra sei
mesi?

**c.** Vault cifra il *valore* del segreto, ma chiunque abbia la parola d'ordine lo
apre, e chiunque abbia il repository vede *che* quel segreto esiste. Perché Vault non è
un sistema di controllo accessi, e quale problema — quello della *parola d'ordine
stessa* — resta aperto e ti porta dritto al capitolo 19?

## Pulizia

    ./nodes.sh down        # rimuove cap18-web1

Il file vpass.txt con la parola d'ordine è locale e usa-e-getta: non finisce mai nel
repository.

## Dove porta

Hai chiuso il conto aperto dal capitolo 11: la password non è più in chiaro. Ma resta
il paradosso: la cassaforte è al sicuro, e la sua **chiave** — la parola d'ordine del
vault — dov'è? Se la scrivi in un file accanto al playbook, hai solo spostato il
problema. Il **capitolo 19** affronta proprio questo: la gestione delle chiavi in
produzione, dove il segreto che apre gli altri segreti non vive più su disco, ma arriva
a runtime da un gestore esterno.
