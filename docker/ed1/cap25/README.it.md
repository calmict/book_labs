# Capitolo 25 — Il diario di bordo e i quadranti

**Livello:** Avanzato

La sicurezza previene; l'osservabilità fa vedere. Quando un servizio in produzione si
comporta male, la prima domanda è sempre la stessa: cosa sta facendo? Docker risponde
con due strumenti. Il diario di bordo sono i log: tutto ciò che il container scrive su
standard output e standard error viene catturato dal demone e reso disponibile con
docker logs — anche a posteriori, anche dopo che il processo è morto. I quadranti sono
le metriche: docker stats mostra in tempo reale CPU, memoria, rete di ogni container. In
questo laboratorio leggi il diario di un container — sia stdout sia stderr — scopri dove
Docker lo conserva (il logging driver) e leggi i suoi consumi dal vivo.

## Obiettivi

- Recuperare con docker logs ciò che un container scrive su stdout e stderr (25.1).
- Riconoscere il logging driver che conserva quei log — il json-file di default (25.2).
- Leggere le metriche dal vivo di un container con docker stats (25.3).
- Inquadrare l'osservabilità in produzione (25.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Il capitolo 7 (il ciclo di vita e gli exit code): qui aggiungi cosa il container dice
  di sé mentre vive.

## Lo scenario

In start/ trovi iobs.sh: uno script che avvia un container che scrive su stdout e stderr
e dovrebbe leggerne i log, il driver e i consumi — ma le tre letture mancano. Colmi tre
lacune (TODO 1..3). Container usa-e-getta (--rm/rm), il demone non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap25/start

### Fase 1 — Il diario: docker logs (25.1 — TODO 1)

Apri start/iobs.sh e completa il **TODO 1**: leggi i log del container. Docker cattura sia
stdout sia stderr; unendo i due stream (2>&1) li recuperi entrambi.

    logs=$(docker logs "$C" 2>&1)

### Fase 2 — Dove finisce il diario (25.2 — TODO 2)

Completa il **TODO 2**: leggi il logging driver del container. È chi conserva i log —
per default json-file, cioè file JSON su disco gestiti dal demone.

    driver=$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' "$C")

### Fase 3 — I quadranti: docker stats (25.3 — TODO 3)

Completa il **TODO 3**: leggi una metrica dal vivo, l'uso di memoria. docker stats dà i
consumi in tempo reale; con --no-stream ne prendi un'istantanea.

    mem=$(docker stats --no-stream --format '{{.MemUsage}}' "$C")

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- iobs.sh legge i log del container (stdout e stderr) (TODO 1).
- Legge il logging driver (TODO 2).
- Legge l'uso di memoria con docker stats (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — docker logs recupera sia la riga scritta su stdout sia quella su stderr.
- **OK 2** — il logging driver del container è json-file (dove i log sono conservati).
- **OK 3** — docker stats riporta una metrica dal vivo: l'uso di memoria del container.

## Domande di riflessione

**a.** La buona pratica è scrivere i log su stdout/stderr, non su un file dentro il
container: perché? Cosa fa Docker con quei due stream, e come si lega questo al fatto che
il container è effimero (capitolo 13) — un file di log dentro sparirebbe con lui, uno
stream catturato dal demone no?

**b.** Il driver json-file di default scrive i log su disco (sotto /var/lib/docker), e
senza rotazione crescono senza limite fino a riempire il disco. Come si limita (opzioni
max-size/max-file), e a cosa servono gli altri driver — journald, syslog, fluentd, i
driver dei cloud — quando i log devono uscire dall'host verso un sistema centralizzato?

**c.** docker stats e docker top danno una fotografia dal vivo, ma non uno storico né
allarmi. Perché in produzione servono strumenti di monitoraggio continui (Prometheus,
Grafana, gli agent del cloud) sopra a questi comandi, e come questa esigenza si amplifica
passando da un host a un cluster orchestrato?

## Pulizia

Niente da smontare a mano: il container è rimosso dallo script (docker rm -f, più un trap
di sicurezza). L'immagine base busybox resta in cache. Il demone non viene mai riavviato.

## Dove porta

Sai leggere cosa un container dice di sé. Il **capitolo 26** mette questi strumenti al
lavoro nel caso peggiore: il troubleshooting — container che non dicono nulla (i log
vuoti), container che ripartono all'infinito (il crash loop) — e come si arriva alla
causa. Per il riferimento dei comandi, vedi le appendici del volume.
