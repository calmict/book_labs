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
un'immagine che funziona, ma gira come root: non crea un utente, non assegna la
proprietà e non abbassa i privilegi. Colmi tre lacune (TODO 1..3) perché l'immagine
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

    RUN adduser -D appuser

### Fase 3 — Proprietà minima (12.3 — TODO 2)

Completa il **TODO 2**: dai a quell'utente la proprietà della directory dell'app,
così potrà scrivere lì e solo lì.

    RUN chown -R appuser /app

### Fase 4 — Abbassare i privilegi (12.2 — TODO 3)

Completa il **TODO 3**: dichiara USER, così ogni container nato dall'immagine parte
come utente non privilegiato — non a runtime, ma scritto nell'immagine.

    USER appuser

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- Il Dockerfile crea un utente non-root (TODO 1).
- Assegna a quell'utente la proprietà della directory dell'app (TODO 2).
- Dichiara USER per girare non-root (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh costruisce l'immagine e verifica, punto per punto:

- **OK 1** — il container gira come non-root: l'uid dentro non è 0.
- **OK 2** — l'utente è dichiarato nell'immagine: la config riporta USER=appuser,
  quindi vale per ogni container senza doverlo passare a runtime.
- **OK 3** — privilegio minimo: l'utente può scrivere nella sua directory /app, ma
  è respinto quando prova a scrivere in /, di proprietà di root.

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
