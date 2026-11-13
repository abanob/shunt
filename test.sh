#!/bin/sh
H="$(dirname "$0")/hook.sh"; R="$(cd "$(dirname "$0")/bench/repo" && pwd)"; fail=0
t(){ printf '%s' "$3" | SHUNT=$1 "$H" 2>/dev/null; got=$?; if [ "$got" = "$2" ]; then echo "ok   $4"; else echo "FAIL $4 (got $got)"; fail=1; fi; }
j(){ jq -nc --arg r "$R" "$1"; }
t 1 2 "$(j '{tool_name:"Read",cwd:$r,tool_input:{file_path:($r+"/lib/response.js")}}')" "big read blocked"
t 0 0 "$(j '{tool_name:"Read",cwd:$r,tool_input:{file_path:($r+"/lib/response.js")}}')" "switch off"
t 1 0 "$(j '{tool_name:"Read",cwd:$r,tool_input:{file_path:($r+"/lib/view.js")}}')" "small read allowed"
t 1 0 "$(j '{tool_name:"Read",cwd:$r,tool_input:{file_path:($r+"/lib/response.js"),offset:100,limit:20}}')" "targeted read allowed"
t 1 0 "$(j '{tool_name:"Read",agent_id:"x",cwd:$r,tool_input:{file_path:($r+"/lib/response.js")}}')" "subagent read allowed"
t 1 2 "$(j '{tool_name:"Bash",cwd:$r,tool_input:{command:"cat -n lib/view.js lib/response.js"}}')" "bash cat blocked"
t 1 0 "$(j '{tool_name:"Bash",cwd:$r,tool_input:{command:"cat lib/response.js | grep send"}}')" "piped cat allowed"
t 1 0 "$(j '{tool_name:"Bash",cwd:$r,tool_input:{command:"ls -la"}}')" "other bash allowed"
exit $fail
