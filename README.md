# ai-config

Global Claude Code configuration, kept in one repo and installed into `~/.claude`.

## Modules

| Module | Path | What it does |
| :- | :- | :- |
| rules | [`rules/`](rules/README.md) | Global rules loaded in every Claude Code session, kept in `rules/CLAUDE.md` |
| shunt | [`shunt/`](shunt/README.md) | Token-saving read delegation: a hook, a `/shunt` skill and a `bulk-reader` subagent |
| llm-gateway | [`llm-gateway/`](llm-gateway/README.md) | Local gateway that sends cheap or mechanical work from Claude Code to free-tier models: an MCP server with `ask_model` and `list_models` in front of a LiteLLM proxy |

## Install

```sh
git clone --recurse-submodules https://github.com/abanob/ai-config.git ~/.claude/ai-config
~/.claude/ai-config/install.sh
```

Install a single module with `install.sh rules`, `install.sh shunt` or `install.sh llm-gateway` (`all` is the default). The installer is idempotent. `shunt` requires `jq`; `llm-gateway` requires Python 3.10 or newer.

- `rules` adds the line `@ai-config/rules/CLAUDE.md` to `~/.claude/CLAUDE.md`. Claude Code resolves relative imports against the importing file, so no symlink or absolute path is needed. An existing `CLAUDE.md` is backed up as `CLAUDE.md.bak.<timestamp>` before the line is appended, and nothing happens if the line is already there.
- `shunt` links the skill and agent into `~/.claude`, and registers the hook in `~/.claude/settings.json`. It also removes the hook entry of the old `~/.claude/shunt` location. On Windows Git Bash, `ln -s` may copy instead of linking; the installer warns when that happens, and you then re-run it after each pull.
- `llm-gateway` creates `llm-gateway/.venv` and installs its Python dependencies if they are missing, creates `llm-gateway/.env` from `.env.example` if there is none, and prints the next steps (fill in keys, start the proxy, register the MCP server). It does not touch `~/.claude`. It is not part of `all`: it downloads a large dependency tree (LiteLLM with its proxy extras), its scripts are for Windows PowerShell, and it is useless until provider keys are added, so it is installed only on request.

## Upgrading from shunt

For a machine that already has the old clone at `~/.claude/shunt`:

```sh
mv ~/.claude/shunt ~/.claude/ai-config
git -C ~/.claude/ai-config remote set-url origin https://github.com/abanob/ai-config.git
git -C ~/.claude/ai-config pull --recurse-submodules
~/.claude/ai-config/install.sh
```

The installer replaces the dangling `~/.claude/skills/shunt` symlink and `~/.claude/agents/bulk-reader.md` link, and swaps the old hook entry in `~/.claude/settings.json` for the new one. The previous `log.jsonl` moves with the clone to `~/.claude/ai-config/log.jsonl`; move it into `shunt/` or delete it. If the pull leaves a stale `bench/repo` directory at the repo root, delete it.

## Sync

```sh
git -C ~/.claude/ai-config pull --recurse-submodules
```

## Rules

- Orchestrator mode: the main session only thinks, plans, briefs and reviews. Coding, editing, writing, research, builds, tests and git operations are delegated to narrowly scoped subagents, each spawned with an explicit non-orchestrator model.
- No AI attribution in git: no Claude or Anthropic co-author trailers and no "Generated with" lines in commits, PRs or code comments.
- No code comments: none inline, block or doc-style.
- Unit tests use `// Arrange`, `// Act` and `// Assert` sections, the only comments allowed.

## Module rules

Every module in this repo follows these rules. `check.sh` enforces the ones that can be checked automatically; it runs in CI on every push and pull request to `main`, and should be run locally before committing.

1. Every module lives in its own top-level folder; nothing module-specific sits at the repo root.
2. Every module folder has a `README.md` with at least: what the module is (the opening paragraph), a `## Expected benefits` section and a `## How to use` section.
3. Every module is listed in the modules table above, linking to its README.
4. Every module that installs something has an entry in `install.sh`, installable by its folder name, and idempotent.
5. No secrets and no machine-specific or personal paths in the repo (write `~/.claude/ai-config` or `$HOME` instead of an absolute user-profile path). Each module's `.gitignore` covers its own local state: `.env`, virtual environments, logs, caches.
6. The global rules in `rules/CLAUDE.md` apply to module code too: no code comments except `Arrange`, `Act` and `Assert` in unit tests, and no AI attribution.

`check.sh` treats every top-level folder that holds tracked or new, non-ignored files as a module, except folders whose name starts with a dot (such as `.github`). It reports, one line per violation: a module without `README.md`, a module README missing one of the two required headings, a module not linked in the modules table, a `.env` file that is tracked or not ignored, and a file containing a Windows user-profile path or a `/home/<user>` or `/Users/<user>` path. Rules 4, 5 (secrets and ignores) and 6 are checked in review.

```sh
./check.sh
```
