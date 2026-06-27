# Contributing / Maintenance

> Maintenance notes for the Calm ICT manual series. Primarily a checklist for
> the maintainer; external contributions are not the main purpose of this repo.
> Italian notes follow each section.

## Branch & commits

- \`main\` is the published branch. Work directly on \`main\` for now (single
  maintainer); switch to feature branches if collaborators join.
- Commit messages: short imperative subject, prefixed by the area touched.
  Examples: \`kubernetes(ed1/cap03): add deployment exercise\`,
  \`docs: fix sparse-checkout command\`, \`ci: add kubeconform job\`.

*IT — \`main\` è il ramo pubblicato. Per ora si lavora direttamente su \`main\`.
Messaggi di commit brevi, all'imperativo, con prefisso dell'area toccata.*

## Adding an exercise (the recurring task)

For each chapter \`capNN\` of a manual edition:

1. Create \`<manual>/edN/capNN/\` with:
   - \`README.it.md\` and \`README.en.md\` — the brief (title, level, objectives,
     prerequisites, step-by-step instructions, definition of done).
   - \`start/\` — starting files (incomplete manifests to complete).
   - \`solution/\` — the working, **tested** solution.
2. **Test the solution** in the recommended local environment before committing.
3. Each brief should link back to the chapter it accompanies, so a reader who
   lands here from GitHub (without the book) understands the context.
4. Commit with a clear message.

*IT — Per ogni capitolo: cartella \`capNN/\` con consegne bilingui, \`start/\` e
\`solution/\`. La soluzione va TESTATA prima del commit. Ogni consegna rimanda al
capitolo del manuale che accompagna.*

## Language convention

- Folder names and code/manifests: **English**, shared across languages.
- Human-readable briefs and docs: **bilingual** via \`*.it.md\` / \`*.en.md\`.
- The root \`README.md\` is English with a language selector to \`README.it.md\`.

*IT — Cartelle e codice in inglese e condivisi; consegne e documentazione
bilingui con suffisso; README di radice in inglese con selettore di lingua.*

## Editions & immutability

- Everything cited by a **published** edition lives under \`edN/\` and is frozen.
- A new edition is a copy \`edN\` → \`ed(N+1)\`; never edit a published \`edN/\`.
- Until a manual is actually published on KDP, its \`edN/\` is still malleable.

*IT — Tutto ciò che è citato da un'edizione PUBBLICATA è congelato sotto \`edN/\`.
Finché il manuale non è pubblicato davvero, \`edN/\` resta modificabile.*

## Validation (CI)

GitHub Actions validates touched exercises on push and pull request. Tools differ
per technology (YAML lint always; plus kubeconform / ansible-lint /
\`terraform|tofu validate\`). See \`.github/workflows/validate.yml\`.

*IT — La CI valida gli esercizi toccati ad ogni push/PR. Strumenti diversi per
tecnologia. Vedi il workflow.*
