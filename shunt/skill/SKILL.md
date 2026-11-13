---
name: shunt
description: Turn token-saving read delegation on or off. Usage /shunt on|off|status.
disable-model-invocation: true
argument-hint: on|off|status
---

Argument: `$ARGUMENTS`

- `on`: run `touch ~/.claude/shunt.on`
- `off`: run `rm -f ~/.claude/shunt.on`
- `status` or empty: run `test -f ~/.claude/shunt.on && echo on || echo off`, then `tail -n 5 ~/.claude/ai-config/shunt/log.jsonl 2>/dev/null`

Then report the state in one line. When on, whole-file reads over `SHUNT_MIN_LINES` (default 350) are blocked in the main agent and redirected to the `bulk-reader` subagent (Haiku). `SHUNT=1` or `SHUNT=0` in the environment overrides the switch for one session.
