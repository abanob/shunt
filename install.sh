#!/bin/sh
set -e
what=${1:-all}
D="$HOME/.claude"
R="$D/ai-config"

install_rules() {
  mkdir -p "$D"
  line="@ai-config/rules/CLAUDE.md"
  f="$D/CLAUDE.md"
  if [ -f "$f" ] && grep -qxF "$line" "$f"; then
    echo "rules: already set up"
    return
  fi
  if [ -f "$f" ]; then
    cp "$f" "$f.bak.$(date +%Y%m%d-%H%M%S)"
    printf '\n%s\n' "$line" >> "$f"
  else
    printf '%s\n' "$line" > "$f"
  fi
  echo "rules: $f now imports rules/CLAUDE.md"
}

link() {
  src=$1; dst=$2
  if [ -d "$dst" ] && [ ! -L "$dst" ]; then rm -rf "$dst"; fi
  ln -sfn "$src" "$dst"
  if [ ! -L "$dst" ]; then
    echo "warning: $dst is a copy, not a symlink (Windows without symlink support). Re-run install.sh after each pull." >&2
  fi
}

install_shunt() {
  command -v jq >/dev/null || { echo "shunt: jq is required" >&2; exit 1; }
  S="$R/shunt"
  git -C "$R" submodule update --init
  mkdir -p "$D/skills" "$D/agents"
  link "$S/skill" "$D/skills/shunt"
  link "$S/agents/bulk-reader.md" "$D/agents/bulk-reader.md"
  f="$D/settings.json"
  [ -f "$f" ] || echo '{}' > "$f"
  old='$HOME/.claude/shunt/hook.sh'
  new='$HOME/.claude/ai-config/shunt/hook.sh'
  if jq -e --arg c "$old" '.hooks.PreToolUse[]?.hooks[]? | select(.command == $c)' "$f" >/dev/null; then
    jq --arg c "$old" '.hooks.PreToolUse |= (map(.hooks |= map(select(.command != $c))) | map(select((.hooks | length) > 0)))' "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
    echo "shunt: removed old hook entry"
  fi
  if ! jq -e --arg c "$new" '.hooks.PreToolUse[]?.hooks[]? | select(.command == $c)' "$f" >/dev/null; then
    jq --arg c "$new" '.hooks.PreToolUse += [{"matcher":"Read|Bash","hooks":[{"type":"command","command":$c}]}]' "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
  fi
  echo "shunt installed. Toggle with /shunt on|off|status"
}

install_llm_gateway() {
  G="$R/llm-gateway"
  py=""
  for c in python3 python; do
    if "$c" -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then py=$c; break; fi
  done
  [ -n "$py" ] || { echo "llm-gateway: Python 3.10 or newer is required" >&2; exit 1; }
  if [ ! -d "$G/.venv" ]; then
    "$py" -m venv "$G/.venv" 2>/dev/null || { rm -rf "$G/.venv"; "$py" -m venv --without-pip "$G/.venv"; }
  fi
  vpy="$G/.venv/Scripts/python.exe"
  [ -f "$vpy" ] || vpy="$G/.venv/bin/python"
  if "$vpy" -c 'import litellm, mcp, httpx, pytest' 2>/dev/null; then
    echo "llm-gateway: dependencies already installed"
  elif "$vpy" -m pip --version >/dev/null 2>&1; then
    "$vpy" -m pip install "litellm[proxy]" "mcp>=2" httpx pytest
  else
    "$py" -m pip --python "$vpy" install "litellm[proxy]" "mcp>=2" httpx pytest
  fi
  if [ ! -f "$G/.env" ]; then
    cp "$G/.env.example" "$G/.env"
    echo "llm-gateway: created $G/.env"
  fi
  printf '%s\n' "llm-gateway ready. Next steps, detailed in llm-gateway/README.md:" \
    "  1. Put LITELLM_MASTER_KEY and at least one provider key in $G/.env" \
    "  2. In PowerShell, from the llm-gateway folder, start the proxy: .\\scripts\\start-gateway.ps1" \
    "  3. In another window, check it: .\\scripts\\check-gateway.ps1" \
    "  4. Register the MCP server with the claude mcp add command from the README, then restart Claude Code"
}

case "$what" in
  all) install_rules; install_shunt ;;
  rules) install_rules ;;
  shunt) install_shunt ;;
  llm-gateway) install_llm_gateway ;;
  *) echo "usage: install.sh [all|rules|shunt|llm-gateway]" >&2; exit 1 ;;
esac
