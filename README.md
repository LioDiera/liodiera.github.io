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

Running it again with the same slug replaces that guide.

## Files
- `index.html`: home page
- `pages.js`: list of guides
- `pages/<slug>/index.html`: one guide per folder
