# liodiera.github.io

A home page for my interactive study guides, hosted on GitHub Pages at https://liodiera.github.io.

## Add a guide
1. Generate the guide (a single HTML file).
2. From the repo root, run:
   ```powershell
   .\add-page.ps1 "$HOME\Downloads\my-guide.html" -Tags "AI","AI-901"
   ```
3. Commit and push. The guide shows on the home page within a minute or two.

| Option | Default |
|---|---|
| `-Title` | the file's `<title>` |
| `-Description` | the file's first lead paragraph |
| `-Tags` | none |
| `-Slug` | made from the title; becomes the URL `/pages/<slug>/` |
| `-Color` | cover background, e.g. `#E9CD92` |

Running it again with the same slug replaces that guide. Every guide gets a "Home" button at the top that links back to the home page. To add or refresh that button on guides already in `pages/`, run `.\add-page.ps1 -AddHomeLinkToAll`.

## Remove a guide
1. From the repo root, run the script with the guide's slug (run it with no slug to list them):
   ```powershell
   .\remove-page.ps1 networking-101
   ```
   It asks before deleting the guide's folder and its home page entry. Add `-WhatIf` to preview without changing anything.
2. Commit and push. Until you commit, `git restore pages pages.js` brings the guide back.

## Files
- `index.html`: home page
- `pages.js`: list of guides
- `pages/<slug>/index.html`: one guide per folder
