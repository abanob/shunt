#!/bin/sh
case "${SHUNT:-}" in
  0) exit 0 ;;
  1) ;;
  *) [ -f "$HOME/.claude/shunt.on" ] || exit 0 ;;
esac
input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.agent_id // empty')" ] && exit 0
min=${SHUNT_MIN_LINES:-350}
tool=$(printf '%s' "$input" | jq -r '.tool_name')
cwd=$(printf '%s' "$input" | jq -r '.cwd')
files=""
if [ "$tool" = Read ]; then
  printf '%s' "$input" | jq -e '.tool_input | has("offset") or has("limit")' >/dev/null && exit 0
  files=$(printf '%s' "$input" | jq -r '.tool_input.file_path')
elif [ "$tool" = Bash ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command')
  case "$cmd" in *'|'*|*'>'*|*';'*|*'&&'*) exit 0 ;; esac
  set -f; set -- $cmd; set +f
  case "$1" in cat|less|more) shift ;; *) exit 0 ;; esac
  for a in "$@"; do case "$a" in -*) ;; *) files="$files
$a" ;; esac; done
fi
cd "$cwd" 2>/dev/null || true
printf '%s\n' "$files" | while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  n=$(wc -l < "$f" | tr -d ' ')
  [ "$n" -gt "$min" ] || continue
  jq -nc --arg f "$f" --argjson n "$n" --arg cwd "$cwd" --arg t "$tool" \
    '{ts: (now|todate), tool: $t, cwd: $cwd, file: $f, lines: $n}' >> "$HOME/.claude/ai-config/shunt/log.jsonl"
  echo "shunt: $f has $n lines (limit $min). Do not read it whole. Delegate to the bulk-reader subagent (Agent tool, subagent_type \"bulk-reader\") with a precise question, batching all files you need into one call. If you need exact text to edit, Read only that section with offset/limit." >&2
  exit 2
done
