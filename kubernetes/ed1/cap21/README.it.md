# Capitolo 21 — La stagista e il robot

**Livello:** Avanzato

Lo storage ha separato richiesta e implementazione; ora separi autenticazione e autorizzazione.
Assumi una persona con un certificato e dai a un workload un'identità propria.

## Obiettivi

- Creare un'identità utente mediante chiave, CSR, certificato e kubeconfig dedicato (21.1).
- Dare a un Pod un ServiceAccount e usare il token montato per chiamare l'API (21.2).
- Applicare Role e RoleBinding col minimo privilegio e verificarne i confini (21.3, 21.4).

## Prerequisiti

- Il cluster book-labs raggiungibile con kubectl e openssl sull'host.
- Un'identità amministrativa che possa approvare CSR e creare oggetti RBAC.
- Capitolo 9 completato per autenticazione, autorizzazione e API Server.

## Lo scenario

Completa i TODO 1..3: il ruolo minimo e il binding umano, il ServiceAccount indossato dal Pod e il
binding del robot. run.sh crea il namespace lab-cap21 e file temporanei per la chiave e il kubeconfig.

    cd kubernetes/ed1/cap21/solution
    ./run.sh

### Fase 1 — Assumere la stagista (21.1)

Il test genera una chiave, presenta una CertificateSigningRequest con CN stagista e gruppo tirocinanti,
la approva e costruisce un kubeconfig. Nessun oggetto User viene creato: l'identità vive nel certificato.

### Fase 2 — La job description minima (21.3, 21.4)

Prima del binding, la stagista autenticata riceve Forbidden. Dopo il binding può leggere i Pod in
lab-cap21, ma non crearli, non leggere Secret e non attraversare il confine del namespace.

### Fase 3 — Il robot (21.2, 21.3)

Il Pod usa il token del proprio ServiceAccount per chiamare l'API. La stessa richiesta restituisce 403
prima del binding e una PodList dopo: è la controprova del permesso appena aggiunto.

## Criteri di "fatto"

- [ ] I tre TODO sono completati.
- [ ] La stagista è riconosciuta e resta confinata alla job description.
- [ ] Il robot passa da 403 a PodList soltanto dopo il binding.
- [ ] run.sh stampa OK 1..6 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 verifica nome e gruppo nel certificato firmato.
- OK 2 è il primo cancello: autenticazione senza autorizzazione resta negata.
- OK 3 verifica i verbi concessi sui Pod.
- OK 4 verifica i confini di verbo, risorsa e namespace.
- OK 5 è il secondo cancello: il robot riceve 403 senza binding.
- OK 6 verifica la PodList tramite il token montato dopo il binding.

## Domande di riflessione

**a.** Dove esiste la stagista, perché gli utenti umani non sono oggetti API e cosa implica per la revoca?

**b.** Come si legge il Role come tripla verbi-risorse-namespace e quale parete ferma ogni richiesta negata?

**c.** Come differiscono certificato umano e token del ServiceAccount, e perché ogni workload dovrebbe
avere un'identità distinta?

## Pulizia

run.sh elimina la CSR, il namespace lab-cap21 e la directory temporanea con chiave, certificato e
kubeconfig. Non lascia credenziali nel repository.

## Dove porta

Hai attraversato separatamente autenticazione e autorizzazione. I capitoli successivi useranno questi
confini per proteggere configurazioni, segreti e comunicazioni fra workload.
