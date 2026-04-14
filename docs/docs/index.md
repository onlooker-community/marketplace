# Onlooker Marketplace

This site is **for people working in this repository**: layout of the monorepo, how plugins are structured, and how we develop and ship changes. End-user installation and marketing content live on the main Onlooker site, not here.

## What this repository is

The [onlooker-community/marketplace](https://github.com/onlooker-community/marketplace) repository is a **monorepo of Claude Code plugins** for the Onlooker ecosystem. Each plugin under `plugins/<name>/` is a self-contained package (metadata, skills, commands, agents, hooks, and docs) that users install via Claude Code’s `/plugin` flows.

## Where to go next

| Topic | Page |
| ----- | ---- |
| Directory layout and plugin anatomy | [Repository layout](architecture.md) |
| Formatting, linting, commits, worktrees, common failures | [Development workflow](development.md) |
| Plugins in this repo and where to read more | [Plugin catalog](plugins.md) |

## Preview these docs locally

From the **repository root**, with [mise](https://mise.jdx.dev/) configured for this repo:

```bash
mise run i
mise run docs-serve
```

That installs Python packages from `requirements.txt` into the mise-managed **`.venv/`** and serves MkDocs using **`docs/mkdocs.yml`**. See **`docs/README.md`** for details and for a non-mise `uv`/`pip` flow.