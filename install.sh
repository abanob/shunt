#!/bin/sh
set -e
D="$HOME/.claude"; S="$D/shunt"
git -C "$S" submodule update --init
mkdir -p "$D/skills" "$D/agents"
[ -L "$D/skills/shunt" ] || rm -rf "$D/skills/shunt"
ln -sfn "$S/skill" "$D/skills/shunt"
ln -sf "$S/agents/bulk-reader.md" "$D/agents/bulk-reader.md"
f="$D/settings.json"; [ -f "$f" ] || echo '{}' > "$f"
jq -e '.hooks.PreToolUse[]?.hooks[]? | select(.command == "$HOME/.claude/shunt/hook.sh")' "$f" >/dev/null || {
  jq '.hooks.PreToolUse += [{"matcher":"Read|Bash","hooks":[{"type":"command","command":"$HOME/.claude/shunt/hook.sh"}]}]' "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
}
echo "shunt installed. Toggle with /shunt on|off|status"
