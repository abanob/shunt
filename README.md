# ai-config

Global Claude Code configuration, kept in one repo and installed into `~/.claude`.

## Modules

| Module | Path | What it does |
| :- | :- | :- |
| rules | `rules/CLAUDE.md` | Global rules loaded in every Claude Code session |
| shunt | `shunt/` | Token-saving read delegation: a hook, a `/shunt` skill and a `bulk-reader` subagent. See `shunt/README.md` |

## Install

```sh
git clone --recurse-submodules https://github.com/abanob/ai-config.git ~/.claude/ai-config
~/.claude/ai-config/install.sh
```

Install a single module with `install.sh rules` or `install.sh shunt` (`all` is the default). The installer is idempotent. `shunt` requires `jq`.

- `rules` adds the line `@ai-config/rules/CLAUDE.md` to `~/.claude/CLAUDE.md`. Claude Code resolves relative imports against the importing file, so no symlink or absolute path is needed. An existing `CLAUDE.md` is backed up as `CLAUDE.md.bak.<timestamp>` before the line is appended, and nothing happens if the line is already there.
- `shunt` links the skill and agent into `~/.claude`, and registers the hook in `~/.claude/settings.json`. It also removes the hook entry of the old `~/.claude/shunt` location. On Windows Git Bash, `ln -s` may copy instead of linking; the installer warns when that happens, and you then re-run it after each pull.

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
