#!/bin/sh
cd "$(dirname "$0")" || exit 1
fail=0
err() { echo "FAIL: $1"; fail=1; }
files=$(git ls-files --cached --others --exclude-standard)
modules=$(printf '%s\n' "$files" | grep / | cut -d/ -f1 | grep -v '^\.' | sort -u)
for m in $modules; do
  r="$m/README.md"
  if [ ! -f "$r" ]; then
    err "$m/ has no README.md"
  else
    grep -q '^## Expected benefits' "$r" || err "$r has no '## Expected benefits' section"
    grep -q '^## How to use' "$r" || err "$r has no '## How to use' section"
  fi
  grep -q "^|.*($m/README.md)" README.md || err "$m is not linked as $m/README.md in the root README modules table"
done
printf '%s\n' "$files" | grep -E '(^|/)\.env$' | while read -r f; do echo "FAIL: $f is a .env file and must not be committed"; done | grep . && fail=1
hits=$(git grep --untracked -nIE '[A-Za-z]:[\\/]+Users[\\/]+[A-Za-z0-9_.-]|(^|[^A-Za-z0-9_.-])/(home|Users)/[A-Za-z0-9_.-]+')
[ -n "$hits" ] && printf '%s\n' "$hits" | while read -r h; do echo "FAIL: personal path in $h"; done && fail=1
[ "$fail" = 0 ] && echo "check: all module rules pass ($(echo $modules | tr ' ' ','))"
exit $fail
