# Capitolo 6 — La bacchetta

**Livello:** Fondamentale

Per cinque capitoli hai studiato la partitura senza mai alzare la bacchetta. Adesso
la prendi in mano: **installi Ansible**. Ma da bravo direttore non sporchi il palco
— lo installi in un ambiente **isolato** (un virtualenv), così non tocchi il Python
di sistema. Poi accordi i musicisti: **prepari i nodi** che dai prossimi capitoli
configurerai.

## Obiettivi

- **ansible-core** contro il pacchetto **ansible**: il motore + i moduli
  ansible.builtin, contro il bundle con centinaia di collection della community.
- I metodi di installazione (sistema / pip / pipx) e perché il **venv** è la tua
  salvezza (isolamento).
- Installare ansible-core in un venv e renderlo **riproducibile** con un
  requirements.txt.
- **Verificare**: ansible --version, la famiglia di comandi, lo smoke test
  ansible localhost -m ping.
- **Preparare i nodi target**: il laboratorio che userai da qui in poi.

## Prerequisiti

- python3 (3.9+) con il modulo venv.
- Docker per i nodi target.
- Rete: pip scarica ansible-core, e la preparazione dei nodi scarica sshd + python.

## Consegna passo-passo

### Fase 1 — Il palco pulito (il virtualenv)

Apri start/setup.sh e completa il **TODO 1**: crea un virtualenv e attivane l'uso.

    python3 -m venv .venv
    . .venv/bin/activate

Perché un venv? Perché installare Ansible nel Python di *sistema* lo sporca e crea
conflitti fra progetti; il venv è una scatola isolata che puoi buttare quando vuoi.
(In alternativa, **pipx** installa Ansible come app isolata con un comando: ottimo
in produzione; qui usiamo un venv esplicito per *vederlo*.)

### Fase 2 — Riproducibilità (requirements.txt)

Completa il **TODO 2** in start/requirements.txt: **pinna** la versione di
ansible-core, così chiunque ricostruisce l'ambiente identico al tuo.

    ansible-core==2.15.13

Poi installa da lì:

    pip install -r requirements.txt

Distinzione chiave: **ansible-core** è il motore più i moduli ansible.builtin; il
pacchetto **ansible** è core *più* centinaia di collection della community
(community.general, ansible.posix…). Per questi esercizi ci basta il core.

### Fase 3 — La verifica e l'anatomia dei comandi

    ansible --version

Ti dice il core installato, il Python usato e il file di configurazione attivo. Poi
la **famiglia** di comandi, ognuno un mestiere:

- ansible — un ordine al volo (ad-hoc, capitolo 9)
- ansible-playbook — esegue i playbook (capitolo 10)
- ansible-config — ispeziona la configurazione (capitolo 7)
- ansible-doc — la documentazione dei moduli
- ansible-galaxy — collection e ruoli (capitoli 16-17)

Ora lo **smoke test**, senza toccare nessun server:

    ansible localhost -m ping

Risposta: pong. Hai appena eseguito il tuo primo modulo. Ricordi il "viaggio di un
task" del capitolo 2? Qui è automatizzato — e localhost è un caso speciale che non
passa nemmeno da SSH.

### Fase 4 — Core contro pacchetto, coi numeri

Con un collection path isolato, conta i moduli del **solo core**:

    ANSIBLE_COLLECTIONS_PATH=/tmp/empty ansible-doc -l | wc -l

Circa **74**, tutti ansible.builtin (ping, copy, file, service, apt, command…). Il
pacchetto ansible completo ne aggiunge centinaia: sono le collection della
community. Il core è piccolo e stabile di proposito; le collection le installi
quando ti servono (capitolo 17).

### Fase 5 — Accordare i musicisti (i nodi target)

Un managed node, lo sai dal capitolo 2, ha bisogno solo di SSH e Python. Preparane
due:

    bash start/nodes.sh up

Crea cap06-web e cap06-db, con sshd + python3. Verifica che rispondano:

    ssh -p 2206 -i /tmp/cap06-lab/key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 hostname
    ssh -p 2207 -i /tmp/cap06-lab/key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 hostname

Sono pronti: al capitolo 8 li metterai in un **inventario** e Ansible li chiamerà
per nome.

## Criteri di "fatto"

- Il venv esiste e ansible --version mostra **ansible-core**.
- I **cinque comandi** CLI rispondono.
- ansible localhost -m ping → **pong**.
- I due nodi target sono **raggiungibili in SSH**.

## Domande di riflessione

**a.** Perché conviene installare Ansible in un venv (o con pipx) invece che nel
Python di sistema? Cosa può rompersi se lo metti nel sistema?

**b.** Che differenza c'è tra ansible-core e il pacchetto ansible, e perché per
questi esercizi basta il core? Quando ti servirebbe il bundle completo?

**c.** ansible localhost -m ping ha funzionato senza inventario e senza SSH. Perché
localhost è un caso speciale, e cosa manca ancora — che vedrai al capitolo 8 — per
pingare cap06-web?

## Pulizia

    bash start/nodes.sh down
    deactivate 2>/dev/null; rm -rf .venv

## Dove porta

Hai il direttore (Ansible) e i musicisti (i nodi). Al capitolo 7 gli dai lo spartito
delle regole (ansible.cfg); all'8 la rubrica (l'inventario) per chiamarli per nome;
al 9 il primo ordine ad-hoc — un ping su cap06-web, non più solo su localhost.
