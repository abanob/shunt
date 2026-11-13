# shunt

Token-saving read delegation for Claude Code. When enabled, whole-file reads over `SHUNT_MIN_LINES` (default 350) in the main agent are blocked by a `PreToolUse` hook and redirected to the `bulk-reader` subagent (Haiku), which answers a precise question instead of loading the file into the main context.

## Expected benefits

- A smaller main context: large files are read by the `bulk-reader` subagent on Haiku, and only its answer reaches the main session.
- Lower usage of the main model's quota on bulk reading, and fewer context compactions in long sessions.
- No change of habit needed: the hook catches whole-file `Read` calls and `cat`/`less`/`more` via Bash, while targeted reads (`offset`/`limit`), piped commands and subagent reads still go through.
- A way to check the effect: `bench/` runs an A/B benchmark with and without the hook, and blocked reads are logged to `log.jsonl`.

## How to use

### Install

```sh
git clone --recurse-submodules https://github.com/abanob/ai-config.git ~/.claude/ai-config
~/.claude/ai-config/install.sh shunt
```

Requires `jq`. `~/.claude/ai-config/install.sh shunt` symlinks the `/shunt` skill and the `bulk-reader` agent into `~/.claude` and adds the hook to `~/.claude/settings.json` if missing.

### Use

- `/shunt on|off|status`: toggles `~/.claude/shunt.on` (per device)
- `SHUNT=1` / `SHUNT=0`: override for one session
- `SHUNT_MIN_LINES=<n>`: change the threshold
- Blocked reads are logged to `log.jsonl` (not synced)

### Layout

- `hook.sh`: the PreToolUse hook (Read and `cat`/`less`/`more` via Bash)
- `skill/SKILL.md`: the `/shunt` command
- `agents/bulk-reader.md`: the Haiku reader subagent
- `test.sh`: hook unit tests
- `bench/`: A/B benchmark against an Express checkout (`bench/repo`, submodule). Run `bench/run.sh [runs]`; results go to `bench/results/` (not synced)

### Sync

```sh
git -C ~/.claude/ai-config pull --recurse-submodules
```
