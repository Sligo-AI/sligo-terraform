# Documentation

This folder is the Jekyll source for the sligo-terraform docs, served via [GitHub Pages](https://sligo-ai.github.io/sligo-terraform/) using the **Sligo Jekyll Theme**.

## GitHub Pages configuration

In the repo: **Settings → Pages → Build and deployment**

- **Source:** Deploy from a branch  
- **Branch:** main (or your default)  
- **Folder:** **/docs** — Jekyll builds from this folder

## Local development

1. **Push the theme first** (one-time): The theme lives in `../sligo-jekyll-theme/`. Push it to a new repo `Sligo-AI/sligo-jekyll-theme` so `remote_theme` works on GitHub Pages.

2. **Run Jekyll from the docs folder:**

   ```bash
   cd docs
   bundle install
   bundle exec jekyll serve
   ```

   Open **http://localhost:4000/sligo-terraform/** (baseurl is `/sligo-terraform`).

3. **Optional – use the local theme** (no remote needed): In `docs/_config.yml`, comment out `remote_theme` and set:

   ```yaml
   theme: sligo-jekyll-theme
   ```

   Then run Jekyll from the **repo root** (so the theme is found):

   ```bash
   bundle install --gemfile=docs/Gemfile
   cd docs && bundle exec jekyll serve
   ```

   If the theme is in the repo at `sligo-jekyll-theme/`, you may need to run from root with a config that points to the theme path (see [Jekyll themes](https://jekyllrb.com/docs/themes/)).

## Theme

- **Remote:** `remote_theme: Sligo-AI/sligo-jekyll-theme` (after the theme repo exists).  
- **Local:** Theme copy is in `../sligo-jekyll-theme/` for reference or local use.

Logo assets are in `assets/images/` (copied from the theme). Navigation and theme options are in `_config.yml`.
