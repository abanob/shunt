#!/bin/sh
cd "$(dirname "$0")"
runs=${1:-3}; out=results/$(date +%Y%m%d-%H%M%S); mkdir -p "$out"
jobs=""
for c in 0 1; do for id in $(jq -r '.[].id' tasks.json); do i=1; while [ $i -le "$runs" ]; do
  jobs="$jobs $c:$id:$i"; i=$((i+1)); done; done; done
printf '%s\n' $jobs | xargs -P "${PARALLEL:-4}" -I{} sh -c '
  c=${1%%:*}; rest=${1#*:}; id=${rest%%:*}; i=${rest#*:}
  p=$(jq -r --arg id "$id" ".[] | select(.id==\$id) | .prompt" tasks.json)
  start=$(date +%s)
  (cd repo && SHUNT=$c claude -p "$p" --output-format json --allowedTools "Read,Grep,Glob,Agent,Task,Bash(cat:*),Bash(grep:*)" < /dev/null 2>/dev/null) > "$2/$c-$id-$i.json"
  echo "done shunt=$c $id #$i ($(( $(date +%s) - start ))s)"
' _ {} "$out"
python3 -I report.py "$out"
