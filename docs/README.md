# Developer documentation (MkDocs)

This directory builds a **small static site** for contributors: repository layout, plugin conventions, and development commands. It is not the public marketing site.

Python dependencies for MkDocs are listed in `requirements.txt` here; the repository root `requirements.txt` includes them via `-r docs/requirements.txt` so **`mise run install`** (or **`mise run i`**) at the repo root installs everything into the mise-managed **`.venv/`** at the root (see root `mise.toml` and the [mise Python guide](https://mise.jdx.dev/lang/python.html)).

## Setup with mise (recommended)

From the **repository root**, with [mise](https://mise.jdx.dev/) installed:

```bash
mise trust   # once per clone, if mise prompts for config trust
mise install # installs python + uv from mise.toml
mise run i   # uv pip install -r requirements.txt → doc tooling into .venv
mise run docs-serve
```

Open the URL MkDocs prints (by default `http://127.0.0.1:8000/`).

`mise run docs-serve` and `mise run docs-build` run **`uv pip install -r requirements.txt`** first so the root `.venv` stays in sync with `requirements.txt`, then invoke MkDocs with **`-f docs/mkdocs.yml`** so paths in `mkdocs.yml` resolve correctly without changing your shell cwd.

## Setup without mise

Use Python 3.x and [uv](https://docs.astral.sh/uv/) (or `pip`) from the **repository root**:

```bash
uv venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
uv pip install -r requirements.txt
mkdocs serve -f docs/mkdocs.yml
```

## Build

From the repository root (with the same `.venv` active or `uv` on your `PATH`):

```bash
mkdocs build --strict -f docs/mkdocs.yml
```

Or `mise run docs-build`.

Output is written to `docs/site/` (ignored by git).

## Configuration

- `mkdocs.yml` — site nav, theme, Markdown extensions
- `docs/*.md` — page sources (MkDocs `docs_dir` is the nested `docs/` folder next to `mkdocs.yml`)

