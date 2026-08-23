# Capitolo 12 — La nave in produzione

**Livello:** Avanzato

Un'immagine che funziona sulla tua macchina non è ancora un'immagine da mettere in
mare. La Parte 3 si chiude portando l'idea fino in fondo: in produzione la nave
deve essere leggera e ben sorvegliata — solo l'equipaggio necessario, niente chiavi
di troppo. La chiave di troppo, quasi sempre, è root: per default un container gira
come root, e un processo compromesso che è root dentro il container è molto più
pericoloso di uno che non lo è. In questo laboratorio costruisci un'immagine di
produzione che gira come utente non privilegiato, proprietario solo di ciò che gli
serve — e verifichi, permesso alla mano, che non può scrivere dove non deve.

## Obiettivi

- Creare un utente non-root dedicato e farci girare l'app (12.2).
- Dare all'utente la proprietà della sola directory dell'app: privilegio minimo
  (12.3).
- Dichiarare l'utente nell'immagine con USER, così vale per ogni container (12.2).
- Vedere la differenza di rischio tra root e non-root nel container (12.1).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter
  usare Docker.
- Il capitolo 2 (i namespace, tra cui lo USER namespace) e il capitolo 11 (il
  Multi-Stage e le immagini leggere): qui aggiungi la sicurezza a runtime.

## Lo scenario

In start/ trovi un Dockerfile incompleto e app.txt. Il Dockerfile costruisce
un'immagine finale `scratch` con un'app statica, ma non abbassa i privilegi e non
dichiara il controllo di salute. Colmi due lacune (TODO 1..2) perché l'immagine
sia da produzione. Immagine usa-e-getta, nessun privilegio sull'host, il demone
condiviso non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap12/start

### Fase 1 — Perché non root (12.1)

Per default il processo di un container è root (uid 0). I namespace (capitolo 2)
lo isolano, ma root nel container resta il punto di partenza per troppi guai: un
bug sfruttato, una capability di troppo, un volume montato male, e root dentro
diventa un problema fuori. La regola di produzione è semplice: gira come utente non
privilegiato, e possiedi solo ciò che ti serve.

### Fase 2 — Un utente dedicato (12.2 — TODO 1)

Apri start/Dockerfile e completa il **TODO 1**: crea un utente non-root che farà
girare l'app.

    USER appuser

### Fase 3 — Proprietà minima (12.3)

Il build stage crea `appuser`; `COPY --chown` assegna la directory dell'app a
quell'utente, così potrà scrivere lì e solo lì.

    COPY --from=build --chown=10001:10001 /app/app.txt /app/app.txt

### Fase 4 — Immagine minimale e salute (12.4 — TODO 2)

Il final stage `scratch` non contiene shell né gestore di pacchetti. Completa il
**TODO 2** dichiarando il probe reale dell'app, che Docker porterà a `healthy`.

    HEALTHCHECK --interval=1s --timeout=1s --retries=5 CMD ["/appbin", "health"]

Quando i due TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- Il Dockerfile dichiara USER per girare non-root (TODO 1).
- Dichiara un HEALTHCHECK reale (TODO 2).
- Il final stage non contiene shell né gestore di pacchetti.
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh costruisce l'immagine e verifica, punto per punto:

- **OK 1** — il container gira come non-root: l'uid dentro non è 0.
- **OK 2** — l'utente è dichiarato nell'immagine: la config riporta USER=appuser,
  quindi vale per ogni container senza doverlo passare a runtime.
- **OK 3** — privilegio minimo: l'utente può scrivere nella sua directory /app, ma
  è respinto quando prova a scrivere in /, di proprietà di root.
- **OK 4** — il controllo dichiarato raggiunge lo stato `healthy`.
- **OK 5** — nel final stage `scratch` non sono eseguibili shell né gestori di
  pacchetti comuni.

## Domande di riflessione

**a.** I namespace isolano il container (capitolo 2), eppure girare come root
dentro è comunque un rischio: perché? Cosa cambia, se il processo viene
compromesso, tra un utente root e uno non privilegiato — e come si combina con
capability e volumi montati?

**b.** USER scrive l'utente nella config dell'immagine, invece di lasciarlo al
--user di docker run. Perché dichiararlo nell'immagine è più sicuro e più
riproducibile? E perché serve comunque il chown: cosa succederebbe all'app se
l'utente non possedesse la sua directory?

**c.** Un'immagine di produzione parte da una base minimale (busybox, o una
distroless) e, con il Multi-Stage del capitolo 11, porta solo l'artefatto. In che
modo «meno cose dentro» (meno binari, meno shell, meno pacchetti) significa meno
superficie d'attacco e meno CVE da inseguire?

## Pulizia

Niente da smontare a mano: l'immagine di prova è rimossa dallo script (docker rmi,
più un trap di sicurezza) a fine esecuzione; il test non lascia container.
L'immagine base busybox resta in cache (condivisa). Il demone non viene mai
riavviato.

## Dove porta

Con questo capitolo la Parte 3 è completa: sai costruire immagini leggere, veloci e
sicure. La **Parte 4** cambia domanda: se il container è effimero, dove vivono i
**dati**? Il **capitolo 13** apre il ciclo di vita dello stato — cosa sopravvive a
un container e cosa no — prima di entrare in volumi e bind mount. Per il
riferimento delle istruzioni, vedi le appendici del volume.
