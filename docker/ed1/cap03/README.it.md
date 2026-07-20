# Capitolo 3 — Il tetto e l'OOM

**Livello:** Intermedio

I namespace del capitolo 2 decidono *cosa* un processo vede. Ma manca l'altra metà dell'isolamento, e
senza di essa un container sarebbe un vicino pericoloso: *quanto* può consumare. In questo laboratorio
imponi a mano un tetto di memoria a un processo e lo costringi a sfondarlo, per vedere con i tuoi occhi
l'**OOM killer** intervenire — e leggere quell'exit code 137 che ti tornerà davanti in produzione. Tutto
rootless, perché la delega di systemd (§3.7) ti dà un pezzo dell'albero dei cgroup senza bisogno di sudo.

## Obiettivi

- Imporre un tetto di memoria a un cgroup con systemd-run --user, senza sudo (3.4, 3.7).
- Provocare l'OOM killer e riconoscere la sua firma: exit code 137 (3.5).
- Dimostrare che il tetto isola il danno: senza tetto la stessa allocazione è innocua (3.4).
- Collegare il 137 alla causa (128 + 9 = SIGKILL), la diagnosi del capitolo 26 (3.5).

## Prerequisiti

- Un Linux con cgroup v2 (il default oggi: verifica con stat -fc %T /sys/fs/cgroup, deve dire
  cgroup2fs), systemd, python3 e systemd-run: nessun Docker richiesto.
- Il controller memory delegato al tuo utente da systemd (di norma lo è). Nessun root: usiamo la
  delega del §3.7, non /sys/fs/cgroup a mano come root.
- I namespace dei capitoli 1 e 2 come contesto: qui aggiungiamo la seconda scatola del kernel.

## Lo scenario

In start/ trovi iltetto.sh: uno script che dovrebbe imporre un tetto di memoria e osservare l'OOM, ma il
tetto manca, quindi nessun processo viene mai ucciso. Colmi tre lacune (TODO 1..3) perché il tetto morda
e il contrasto lo dimostri.

Prepara l'ambiente:

    cd docker/ed1/cap03/start

### Fase 1 — Due meccanismi, un container (3.1)

Namespace più cgroup è la coppia fondante: i primi isolano la vista, i secondi le risorse. Un container
è un processo con entrambi applicati. Togli i namespace e vede tutto; togli i cgroup e può prendersi
tutto, affamando i vicini. Qui azioni la seconda metà.

### Fase 2 — Il tetto di memoria (3.4 — TODO 1)

Apri start/iltetto.sh e completa il **TODO 1**: dai allo scope un tetto di memoria. Completa l'array CAP
con un limite di 40 MiB e lo swap disabilitato, così il limite morde davvero —

    CAP=(--user --scope -q -p MemoryMax=40M -p MemorySwapMax=0)

MemoryMax è il memory.max del cgroup v2; MemorySwapMax=0 disabilita lo swap, così il processo non può
sfuggire al limite paginando su disco.

### Fase 3 — Sfondare il tetto (3.5 — TODO 2)

Completa il **TODO 2**: esegui l'allocatore vorace (chiede 200 MiB) SOTTO il tetto e registra il suo
exit code in mem.txt come greedy_capped_rc. Quando supera memory.max, l'OOM killer gli manda SIGKILL, e
l'exit code è 137 (128 + 9).

### Fase 4 — Il contrasto (3.4 — TODO 3)

Completa il **TODO 3**: esegui lo *stesso* allocatore vorace SENZA tetto (lo scope NOCAP) e registra il
suo exit code come greedy_uncapped_rc. Dovrebbe essere 0: l'allocazione in sé è innocua, è il tetto a
uccidere. È la prova che il limite fa il suo lavoro, isolando il danno al solo cgroup che sfora.

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- L'array CAP impone MemoryMax=40M e MemorySwapMax=0 (TODO 1).
- greedy_capped_rc registra l'exit code del vorace sotto il tetto (TODO 2).
- greedy_uncapped_rc registra l'exit code del vorace senza tetto (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED: il vorace col tetto è ucciso (137), il frugale sopravvive
  (0), il vorace senza tetto sopravvive (0).

## Come viene verificato

solution/run.sh impone il tetto e verifica, punto per punto:

- **OK 1** — il processo vorace supera memory.max ed è ucciso dall'OOM killer: exit 137.
- **OK 2** — un processo frugale sotto lo stesso tetto sopravvive: exit 0.
- **OK 3** — il cancello è il tetto: senza, la stessa allocazione è innocua (exit 0). Il limite ha
  isolato il danno al solo cgroup che sfora.

## Domande di riflessione

**a.** Perché l'exit code è esattamente 137? Scomponi il numero e collega ogni pezzo a ciò che è
accaduto. Perché, incontrando un container morto con codice 137 nel capitolo 26, saprai già la diagnosi
senza aprire nulla?

**b.** Con il tetto il vorace muore, senza il tetto la stessa allocazione da 200 MiB va a buon fine.
Cosa dimostra questo contrasto sul ruolo del limite? E perché, in produzione, alzare a caso il tetto è
la cura sbagliata?

**c.** Questo laboratorio gira rootless, senza sudo. Grazie a quale meccanismo di systemd (§3.7)?
Perché lo stesso meccanismo è la fondazione su cui poggia il rootless del capitolo 23? E perché una
quota di CPU potrebbe non avere effetto, mentre il tetto di memoria sì?

## Pulizia

Niente da smontare: ogni scope transitorio di systemd-run termina con il suo processo e viene raccolto
da solo, e il test lavora in una cartella temporanea che ripulisce da sé. Nessun cgroup lasciato, nessun
container Docker.

## Dove porta

Con questo capitolo la fondazione è completa: sai *cosa* un container vede (namespace) e *quanto* può
consumare (cgroup). Il **capitolo 4** chiude la teoria con il Copy-on-Write e l'OverlayFS — come una
pila di layer in sola lettura, montata dentro il MNT namespace del capitolo 2, produca l'illusione di
«un altro Linux» senza sprecare disco.
