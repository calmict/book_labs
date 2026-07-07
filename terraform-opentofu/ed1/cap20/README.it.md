# Capitolo 20 — I gemelli e il lucchetto

**Livello:** Cloud Architect
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** la storia: perché esiste un fork (20.1), il 95% identico: la compatibilità (20.2), il 5% che conta: le caratteristiche proprie — cifratura nativa dello stato (20.3), come scegliere, con la testa (20.4)

## L'idea

Per diciannove capitoli abbiamo detto "un linguaggio, due binari": ogni comando
tofu ha il suo gemello terraform. Questo capitolo mantiene la promessa e le mette
il confine. Perché i due binari *sono* gemelli — nati dallo stesso codice — ma da
un certo punto in poi hanno preso strade diverse.

La storia in breve (20.1): nel 2023 HashiCorp cambiò la licenza di Terraform, da
open source a una licenza restrittiva (la BSL). La comunità reagì con un *fork* —
una copia del codice che riparte per conto suo — messo sotto la Linux Foundation
e ribattezzato **OpenTofu**, con licenza aperta (MPL). Da lì, due binari gemelli
che condividono quasi tutto e divergono su poco.

Il "quasi tutto" è il **95%** (20.2): stesso HCL, stessi provider, stessi
comandi, gli stessi concetti di tutto questo manuale. Lo verificherai lanciando
la *stessa* configurazione con entrambi i binari e ottenendo lo stesso risultato
— la prova concreta di ciò che diciamo dal capitolo 6.

Il "poco" è il **5% che conta** (20.3), e il suo pezzo grosso è un vecchio conto
in sospeso. Il capitolo 11 ci aveva lasciato un problema aperto: lo stato
custodisce i segreti *in chiaro*. OpenTofu lo risolve con una feature che
Terraform non ha: la **cifratura nativa dello stato**. Cifrerai il taccuino con
una passphrase, vedrai il segreto sparire dal file, e — la prova del confine —
vedrai che terraform quel taccuino non riesce nemmeno più a leggerlo. Il lucchetto
che solo uno dei due gemelli possiede.

## Obiettivi

Alla fine saprai:

- raccontare perché esiste OpenTofu (il cambio di licenza del 2023 e il fork);
- verificare il 95%: la stessa configurazione gira identica su tofu e terraform;
- cifrare lo stato con la cifratura nativa di OpenTofu, tenendo la passphrase
  *fuori* dal codice (variabile d'ambiente);
- dimostrare il 5%: uno stato cifrato è illeggibile senza passphrase, e
  illeggibile del tutto per terraform;
- scegliere tra i due binari con criterio.

## Prerequisiti

- OpenTofu installato — vedi SETUP.md. Per la parte sul confine serve *anche*
  terraform installato (opzionale: se non ce l'hai, quelle prove le leggi).
- Nessun Docker, nessuna porta: questo capitolo lavora solo su stato e binari.
- Il capitolo 11 (lo stato tiene i segreti in chiaro): qui si chiude quel conto.

## Consegna

### Fase 0 — Il segreto in chiaro (l'eco del capitolo 11)

In start/ c'è una configurazione minima: una random_password — un segreto che,
generato, finisce nello stato. Applicala e guarda il taccuino:

    cd start
    tofu init
    tofu apply
    grep -o '"bcrypt_hash"' terraform.tfstate

Il segreto è lì, nel file, in chiaro: esattamente il problema che il capitolo 11
aveva lasciato aperto. Chiunque legga terraform.tfstate lo legge. Distruggi e
ripulisci prima di procedere:

    tofu destroy
    rm -f terraform.tfstate*

### Fase 1 — Il 95%: gli stessi gesti, due binari (20.2)

Se hai entrambi i binari, prova la promessa del manuale. Con OpenTofu:

    tofu init && tofu apply

poi ripulisci lo stato e rifai gli *stessi identici comandi* con Terraform:

    rm -rf .terraform* terraform.tfstate*
    terraform init && terraform apply

Stesso HCL, stesso provider, stesso comportamento: nessuna riga da cambiare.
Questo è il 95% — la ragione per cui in tutto il manuale abbiamo scritto "tofu"
sapendo che "terraform" avrebbe fatto lo stesso.

### Fase 2 — Il 5%: cifrare il taccuino (20.3, TODO)

Ora il pezzo che *solo* OpenTofu ha. La cifratura nativa dello stato si configura
con un blocco encryption — ma la sua parte segreta, la passphrase, non deve mai
finire nel codice. Il modo pulito è passare tutta la configurazione di cifratura
dalla variabile d'ambiente TF_ENCRYPTION. In start/encryption.hcl.example trovi
il modello: key_provider (deriva una chiave dalla passphrase), method
(l'algoritmo AES-GCM), e state (applica il metodo allo stato). Il TODO: scegli una
tua passphrase (almeno 16 caratteri) ed esportala — *senza scriverla in nessun
file versionato*:

    export TF_ENCRYPTION='key_provider "pbkdf2" "k" { passphrase = "scegli-una-frase-lunga-tua" }
    method "aes_gcm" "m" { keys = key_provider.pbkdf2.k }
    state { method = method.aes_gcm.m }'

Ora applica di nuovo, e riguarda il taccuino:

    tofu apply
    head -c 80 terraform.tfstate
    grep -o '"bcrypt_hash"' terraform.tfstate || echo "nessun segreto in chiaro"

Il file è un *envelope* cifrato: niente version, niente resources, niente
bcrypt_hash in chiaro. Il segreto del capitolo 11 è al sicuro a riposo. E nota il
punto chiave: la passphrase è nell'ambiente, non nel repository — come i tfvars
del capitolo 14, il segreto non viaggia mai col codice.

### Fase 3 — Le due prove del confine

Prova uno: senza passphrase, nemmeno tu leggi più il taccuino.

    unset TF_ENCRYPTION
    tofu state list

Errore: This state file is encrypted and can not be read without an encryption
configuration. La cifratura non è cosmetica: senza la chiave, lo stato è opaco
anche a te. (Riesporta TF_ENCRYPTION per continuare a lavorare.)

Prova due: il gemello resta fuori. Con lo stato cifrato sul disco, chiedi a
terraform di leggerlo:

    terraform init
    terraform show

Errore: Unsupported state file format. Terraform non ha la cifratura nativa: quel
taccuino, per lui, è illeggibile. È il 5% reso concreto — cifrare lo stato è una
porta che si apre in una sola direzione: una volta dentro OpenTofu, tornare a
Terraform non è più gratis.

### Fase 4 — Scegliere con la testa (20.4, si riflette)

Il 95% dice che, per la maggior parte dei progetti, la scelta è reversibile e a
basso rischio: prendi il binario che preferisci. Il 5% dice *quando* la scelta
pesa: se ti servono le feature proprie di OpenTofu — la cifratura nativa dello
stato in testa a tutte — stai scegliendo OpenTofu davvero, e il ritorno costa. La
regola del manuale: scegli sul 5%, non sul 95%. Guarda che cosa ti serve *di
diverso*, perché è lì che i gemelli smettono di esserlo.

### Pulizia

    export TF_ENCRYPTION='...la tua...'   # serve per poter distruggere lo stato cifrato
    tofu destroy
    rm -f terraform.tfstate* && rm -rf .terraform*
    unset TF_ENCRYPTION

## Criteri di "fatto"

- Nella Fase 0, bcrypt_hash compariva in chiaro nello stato non cifrato.
- La stessa configurazione girava identica con tofu e con terraform (Fase 1).
- Con TF_ENCRYPTION impostata, lo stato diventava un envelope cifrato: nessun
  segreto in chiaro.
- Senza passphrase, tofu rifiutava di leggere lo stato; terraform lo rifiutava
  del tutto (Unsupported state file format).
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Il fork e i due binari: racconta in tre righe perché esiste OpenTofu (che
cosa accadde nel 2023) e che cosa significano, in pratica, il 95% e il 5%. Nella
Fase 1, che cosa hai dovuto cambiare nel codice per passare da tofu a terraform —
e perché la risposta è la tesi di tutto il manuale?

**b.** Il lucchetto e il capitolo 11: che problema, lasciato aperto nel capitolo
11, risolve la cifratura nativa dello stato? Perché la passphrase è passata da
TF_ENCRYPTION e non scritta nel blocco encryption dentro un file — quale principio
(già visto coi tfvars del capitolo 14) stai rispettando?

**c.** La porta a senso unico: hai visto terraform fallire su uno stato cifrato
con Unsupported state file format. Perché questo rende la cifratura una scelta che
*lega* a OpenTofu, mentre il resto del 95% no? Come cambia questo la regola
"scegli sul 5%, non sul 95%"?
