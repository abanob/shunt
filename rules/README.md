# rules

Global rules for Claude Code, kept in `rules/CLAUDE.md` and loaded in every Claude Code session on a machine where the module is installed. They cover:

- Orchestrator mode: the main session only thinks, plans, briefs and reviews. Coding, editing, writing, research, builds, tests and git operations are delegated to narrowly scoped subagents, each spawned with an explicit non-orchestrator model.
- No AI attribution in git: no Claude or Anthropic co-author trailers and no "Generated with" lines in commits, PRs or code comments.
- No code comments: none inline, block or doc-style.
- Unit tests use `// Arrange`, `// Act` and `// Assert` sections, the only comments allowed.

## Expected benefits

- The same behaviour on every machine and in every project, without copying rules into each repo.
- One place to change a rule: edit `rules/CLAUDE.md`, commit, and every machine picks it up on the next pull.
- Clean history and code: no AI attribution and no comments to remove by hand afterwards.
- A main session that stays small and focused, because the work is delegated to cheaper, specialised subagents.

## How to use

Install it from Git Bash:

```sh
git clone --recurse-submodules https://github.com/abanob/ai-config.git ~/.claude/ai-config
~/.claude/ai-config/install.sh rules
```

The installer adds the line `@ai-config/rules/CLAUDE.md` to `~/.claude/CLAUDE.md`. Claude Code resolves relative imports against the importing file, so no symlink or absolute path is needed. An existing `CLAUDE.md` is backed up as `CLAUDE.md.bak.<timestamp>` before the line is appended, and nothing happens if the line is already there.

To change a rule, edit `rules/CLAUDE.md` and commit. Other machines get it with:

```sh
git -C ~/.claude/ai-config pull --recurse-submodules
```

The import is read when a session starts, so start a new Claude Code session to pick up a change. Personal rules that should not be shared can stay in `~/.claude/CLAUDE.md` itself, next to the import line.
