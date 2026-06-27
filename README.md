# book_labs

🇬🇧 English · [🇮🇹 Italiano](README.it.md)

Hands-on exercises for the **Calm ICT** manual series — [calmict.com](https://calmict.com)

---

## What this is

This repository hosts the practical exercises that accompany the Calm ICT
technical manuals. Each manual has its own folder, and the exercises are
organised by chapter so you can pull only what you need and work through them
alongside the book.

- **Self-contained:** every exercise runs in a free, reproducible local
  environment (no paid cloud resources required to complete it).
- **Tested solutions:** each exercise ships with a working, tested solution.
- **Stable links:** the URL cited in a published manual never changes.

## Repository layout

\`\`\`
book_labs/
├── kubernetes/            # exercises for the Kubernetes manual
│   ├── README.md          # chapter index + recommended setup
│   ├── SETUP.md           # reproducible environment guide (non-binding)
│   └── ed1/               # 1st edition — frozen once the manual is published
│       └── capNN/
│           ├── README.it.md   # brief (Italian)
│           ├── README.en.md   # brief (English)
│           ├── start/         # starting files — shared, language-neutral
│           └── solution/      # tested solution — shared, language-neutral
├── ansible/               # (coming with the Ansible manual)
└── terraform-opentofu/    # (coming with the Terraform/OpenTofu manual)
\`\`\`

**Languages.** Folder names and code/manifests are in English and shared across
languages (a \`deployment.yaml\` is the same in any language). Only the human-
readable briefs are bilingual, via the \`README.it.md\` / \`README.en.md\` suffix.

**Editions.** Everything cited by the 1st edition of a manual lives under
\`edN/\` and is frozen once that edition is published. A later edition is added
as a new \`edN/\` folder, leaving the previous one untouched, so every link in an
already-published book keeps working forever.

## How to use it

Pull only the manual and edition you need (sparse checkout):

\`\`\`bash
git clone --filter=blob:none --sparse https://github.com/calmict/book_labs.git
cd book_labs
git sparse-checkout set kubernetes/ed1
\`\`\`

To update later: \`git pull\`.

Each exercise folder has a \`README\` with the brief, objectives, prerequisites
and step-by-step instructions. Open \`start/\`, do the work, and compare with
\`solution/\` when you are done.

## License

The exercise **code** in this repository is released under the
[MIT License](LICENSE). The text of the manuals is a separate work and is **not**
covered by this license.

---

Reference site: [calmict.com](https://calmict.com)
