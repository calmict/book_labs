# book_labs

[🇬🇧 English](README.md) · 🇮🇹 Italiano

Esercizi pratici della collana di manuali **Calm ICT** — [calmict.com](https://calmict.com)

---

## Cos'è

Questo repository raccoglie gli esercizi pratici che accompagnano i manuali
tecnici Calm ICT. Ogni manuale ha la sua cartella e gli esercizi sono
organizzati per capitolo, così scarichi solo ciò che ti serve e lavori in
parallelo al libro.

- **Autoconsistenti:** ogni esercizio gira in un ambiente locale gratuito e
  riproducibile (per completarlo non servono risorse cloud a pagamento).
- **Soluzioni testate:** ogni esercizio include una soluzione funzionante e
  verificata.
- **Link stabili:** l'URL citato in un manuale pubblicato non cambia mai.

## Struttura del repository

    book_labs/
    ├── kubernetes/            # esercizi del manuale Kubernetes
    │   ├── README.md          # indice dei capitoli + setup consigliato
    │   ├── SETUP.md           # guida ambiente riproducibile (non vincolante)
    │   └── ed1/               # 1ª edizione — congelata alla pubblicazione del manuale
    │       └── capNN/
    │           ├── README.it.md   # consegna (italiano)
    │           ├── README.en.md   # consegna (inglese)
    │           ├── start/         # file di partenza — condivisi, neutri rispetto alla lingua
    │           └── solution/      # soluzione testata — condivisa, neutra rispetto alla lingua
    ├── ansible/               # esercizi del manuale Ansible
    └── terraform-opentofu/    # esercizi del manuale Terraform/OpenTofu

**Lingue.** I nomi delle cartelle e il codice/manifest sono in inglese e
condivisi tra le lingue (un file deployment.yaml è identico in qualsiasi
lingua). Solo le consegne leggibili sono bilingui, con il suffisso
README.it.md / README.en.md.

**Edizioni.** Tutto ciò che è citato dalla 1ª edizione di un manuale vive nella
cartella ed1/ e viene congelato alla pubblicazione di quell'edizione.
Un'edizione successiva si aggiunge come nuova cartella edN/, lasciando intatta
la precedente, così ogni link di un libro già pubblicato continua a funzionare
per sempre.

## Come si usa

Scarica solo il manuale e l'edizione che ti servono (sparse checkout):

    git clone --filter=blob:none --sparse https://github.com/calmict/book_labs.git
    cd book_labs
    git sparse-checkout set kubernetes/ed1

Per aggiornare in seguito basta un git pull.

Ogni cartella esercizio ha un README con la consegna, gli obiettivi, i
prerequisiti e le istruzioni passo-passo. Apri la cartella start/, svolgi il
lavoro e confronta con solution/ quando hai finito.

## Licenza

Il **codice** degli esercizi in questo repository è rilasciato sotto
[Licenza MIT](LICENSE). Il testo dei manuali è un'opera separata e **non** è
coperto da questa licenza.

---

Sito di riferimento: [calmict.com](https://calmict.com)
