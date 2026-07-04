# Cap. 23 — Il re di cartone (sicurezza del container)

> Esercizio del **Capitolo 23 — Sicurezza del container** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Avanzato

## Obiettivi

Al termine di questo laboratorio saprai:

- toccare con mano perché root dentro un container è un re di cartone: uid 0 sì, ma il potere reale sta nelle capabilities, nei privilegi e nel filesystem — e nel kernel condiviso con l'host;
- blindare un pod col SecurityContext: utente non-root, niente escalation, filesystem in sola lettura, tutte le capabilities cadute, seccomp attivo — e verificare ogni difesa dall'interno;
- passare dalla difesa pod-per-pod alla difesa su scala con i Pod Security Standards: un'etichetta sul namespace e l'admission rifiuta i pod non conformi prima ancora che nascano.

## Prerequisiti

- Cap. 4 completato (le capabilities sezionate a mano: qui ritroverai lo stesso CapEff esadecimale) e Cap. 21–22 (il minimo privilegio: qui arriva dentro il container).
- Il cluster book-labs acceso.
- Due manifest in start/: king.yaml (dato) e hardened.yaml (TODO). Il posto di blocco (Pod Security Standards) è un'etichetta sul namespace: la applicherai a mano.

## Consegna

1. Il re nudo. Crea il namespace e incorona il re (nessun SecurityContext: gira come root):

       kubectl create namespace throne
       kubectl apply -f king.yaml
       kubectl -n throne wait --for=condition=Ready pod/king --timeout=60s

   Ora guardagli dentro le tasche:

       kubectl -n throne exec king -- id
       kubectl -n throne exec king -- sh -c 'grep -E "CapEff|Seccomp" /proc/self/status'
       kubectl -n throne exec king -- sh -c 'echo tesoro > /root/proof && echo SCRIVIBILE'

   uid=0(root), CapEff 00000000a80425fb (lo stesso numero del cap. 4: un mazzo di capabilities in mano), Seccomp 0 (nessun filtro sulle syscall), e la radice del filesystem è scrivibile. Sembra un re. Sul kernel condiviso con l'host, è un re pericoloso.

2. Spogliare il re. Completa hardened.yaml aggiungendo al container un securityContext che: lo faccia girare come utente non-root (runAsNonRoot true, runAsUser 65534), vieti l'escalation dei privilegi (allowPrivilegeEscalation false), renda la radice in sola lettura (readOnlyRootFilesystem true), faccia cadere TUTTE le capabilities (capabilities.drop ["ALL"]) e attivi il profilo seccomp di default (seccompProfile.type RuntimeDefault). Applica e rifai la stessa ispezione:

       kubectl apply -f hardened.yaml
       kubectl -n throne wait --for=condition=Ready pod/hardened --timeout=60s
       kubectl -n throne exec hardened -- id
       kubectl -n throne exec hardened -- sh -c 'grep -E "CapEff|Seccomp" /proc/self/status'
       kubectl -n throne exec hardened -- sh -c 'echo tesoro > /proof && echo SCRIVIBILE' || echo "bloccato (sola lettura)"

   uid=65534(nobody), CapEff 0000000000000000 (mani vuote), Seccomp 2 (il filtro c'è), e la scrittura fallisce: "Read-only file system". La corona era di cartone.

3. Il posto di blocco (Pod Security Standards). Finora hai blindato un pod alla volta. Ora metti una guardia all'ingresso del namespace: un'unica etichetta che rifiuta in admission qualunque pod non conforme al livello restricted.

       kubectl label namespace throne pod-security.kubernetes.io/enforce=restricted --overwrite

   Nota subito il Warning: denuncia il re già dentro come violazione — ma il re NON viene ucciso. L'admission controlla solo alla nascita:

       kubectl -n throne get pod king

   è ancora Running. Prova invece a far entrare un intruso root NUOVO:

       kubectl -n throne run intruder --image=busybox:stable --restart=Never -- sleep infinity

   Rifiutato in faccia, con la lista esatta di cosa gli manca (allowPrivilegeEscalation, capabilities.drop, runAsNonRoot, seccompProfile). Il pod blindato, invece, passa la guardia — ricrealo sotto restricted per vederlo ammesso:

       kubectl -n throne delete pod hardened
       kubectl apply -f hardened.yaml

   Difesa su scala: non più pod per pod, ma un cancello per l'intero namespace. E di nuovo — come nel cap. 22 — la sicurezza è questione di un'etichetta.

4. Smonta il regno:

       kubectl delete namespace throne

## Le domande per answers.md

- (a) SecurityContext e kernel condiviso (23.1–23.2). Root nel container non è root sull'host (namespace utente, capabilities ridotte già di default): allora perché resta pericoloso? Spiega cosa hai letto nel CapEff (il numero del cap. 4 contro gli zero del pod blindato) e cosa protegge ciascuna difesa: runAsNonRoot, allowPrivilegeEscalation false, readOnlyRootFilesystem, capabilities.drop ALL. Perché, condividendo il kernel con l'host, un'evasione costa più cara che in una VM?
- (b) Seccomp e MAC (23.3–23.4). Cosa dice il campo Seccomp (0 contro 2) e cosa fa RuntimeDefault? In una riga, la differenza tra seccomp (filtra le syscall) e AppArmor/SELinux (Mandatory Access Control su file e risorse). Perché nessuna delle due difese è attiva di default?
- (c) Pod Security Standards (23.5). I tre livelli (privileged / baseline / restricted) e le tre modalità (enforce / audit / warn). Perché l'etichetta non ha sfrattato il re già in esecuzione, e cosa significa questo per chi vuole blindare un cluster già popolato? Il parallelo col cap. 22: difesa pod-per-pod (SecurityContext) contro difesa su scala (PSA sul namespace).

## Criteri di "fatto"

- [ ] Il re nudo: uid 0, CapEff a80425fb, Seccomp 0, radice scrivibile — visto con i tuoi occhi.
- [ ] Il re spogliato: uid non-root, CapEff a zero, Seccomp 2, scrittura rifiutata.
- [ ] Sotto restricted: l'intruso root rifiutato in admission, il pod blindato ammesso.
- [ ] answers.md risponde alle tre domande.
- [ ] Il namespace throne è stato cancellato.
