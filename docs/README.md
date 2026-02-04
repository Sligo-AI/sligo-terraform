# Documentation

This folder is the Jekyll source for the sligo-terraform docs, served via [GitHub Pages](https://sligo-ai.github.io/sligo-terraform/) using the **Sligo Jekyll Theme**.

## GitHub Pages configuration

In the repo: **Settings → Pages → Build and deployment**

- **Source:** Deploy from a branch  
- **Branch:** main (or your default)  
- **Folder:** **/docs** — Jekyll builds from this folder

## Local development

1. **Run Jekyll from the docs folder:**

   ```bash
   cd docs
   bundle install
   bundle exec jekyll serve
   ```

   Open **http://localhost:4000/sligo-terraform/** (baseurl is `/sligo-terraform`).

   The theme is loaded from **Sligo-AI/sligo-jekyll-theme** via `remote_theme` (same as on GitHub Pages).

## Theme

- **Repo:** [Sligo-AI/sligo-jekyll-theme](https://github.com/Sligo-AI/sligo-jekyll-theme) — the theme lives in its own repo; this repo does not contain a copy.
- **Config:** `remote_theme: Sligo-AI/sligo-jekyll-theme` in `_config.yml`.

Logo assets are in `assets/images/`. Navigation and theme options are in `_config.yml`.
