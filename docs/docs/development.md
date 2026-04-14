# Development workflow

## Prerequisites

- [Bun](https://bun.sh/) for JavaScript tooling and workspace installs (`CLAUDE.md` in the repo root).
- **Python** for the MkDocs site: the repo uses [mise](https://mise.jdx.dev/) with **`_.python.venv`** pointing at a root **`.venv/`**, **`uv`** for `uv pip install`, and **`.python-version`** so everyone pins the same Python line. Root `requirements.txt` pulls in `docs/requirements.txt` so `mise run i` installs MkDocs and the theme in that venv.

## Install and common commands

```bash
bun install
bun run fix:format   # Biome format
bun run lint         # Biome lint (+ other lint tasks via npm-run-all)
```

Spelling is enforced in places (for example via **cspell** in staged workflows). If you add new proper nouns or technical tokens, update the repository cspell configuration so `bun run lint` stays green.

## Git commits

Commit messages follow **Conventional Commits**, for example:

```text
feat(tribunal): describe the change
fix: repair hook path resolution
docs: update plugin README
```

Supported types include `feat`, `fix`, `chore`, `docs`, `style`, and `refactor`, as noted in `AGENTS.md`.

## Releases

Version numbers and changelog entries for published packages are handled by **release-please**. Do not hand-edit generated changelog sections for releases unless you know that workflow expects it.

## Git worktrees

For parallel branches without constant `git stash`, use worktrees:

```bash
git worktree add .worktrees/my-feature -b my-feature
cd .worktrees/my-feature
```

## Hooks and scripts

Hook entries point at scripts under the plugin. From the repository root, sanity-check a script path and that it is executable:

```bash
ls -la plugins/<plugin>/scripts/<script>.sh
chmod +x plugins/<plugin>/scripts/<script>.sh   # if needed
bash plugins/<plugin>/scripts/<script>.sh       # dry run
```

If a skill does not seem to load, inspect the YAML **frontmatter** on `SKILL.md`: the `description` should be specific and action-oriented so the host can decide when to attach it.

## Documentation site (`docs/`)

From the **repository root** (recommended):

```bash
mise run i           # uv pip install -r requirements.txt → .venv
mise run docs-serve
```

That uses **`mkdocs … -f docs/mkdocs.yml`** so MkDocs resolves `docs_dir` relative to this project’s `docs/` folder while dependencies live in the root **`.venv/`**.

Without mise, activate a venv and run the same `uv pip install -r requirements.txt` then `mkdocs serve -f docs/mkdocs.yml` from the root; see `docs/README.md`.

Built static output goes to **`docs/site/`**; that directory is ignored by git so local builds do not dirty the worktree.
