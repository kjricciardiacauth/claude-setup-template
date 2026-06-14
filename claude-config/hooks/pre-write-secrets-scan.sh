#!/usr/bin/env bash
# Hook: PreToolUse / Write|Edit - block writing live secrets into any file.
# Mac/Linux version of pre-write-secrets-scan.ps1. Fail-open. ASCII-only.
set -uo pipefail
input_json=$(cat)
[ -z "$input_json" ] && exit 0
blob=$(echo "$input_json" | jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string)] | map(select(. != null)) | join("\n")' 2>/dev/null)
[ -z "$blob" ] && exit 0

declare -a hits=()
add() { echo "$blob" | grep -Eq "$2" && hits+=("$1"); }
add 'Private key block'       '-----BEGIN (RSA |EC |OPENSSH |PGP |DSA )?PRIVATE KEY-----'
add 'AWS access key id'       'AKIA[0-9A-Z]{16}'
add 'Anthropic API key'       'sk-ant-[A-Za-z0-9_-]{24,}'
add 'OpenAI-style key'        'sk-[A-Za-z0-9]{32,}'
add 'GitHub token'            '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}'
add 'GitHub fine-grained PAT' 'github_pat_[A-Za-z0-9_]{50,}'
add 'Slack token'             'xox[baprs]-[A-Za-z0-9-]{12,}'
add 'Google API key'          'AIza[0-9A-Za-z_-]{35}'
add 'Stripe live key'         '(sk|rk)_live_[0-9a-zA-Z]{24,}'
[ ${#hits[@]} -eq 0 ] && exit 0

fp=$(echo "$input_json" | jq -r '.tool_input.file_path // "the target file"' 2>/dev/null)
joined=$(IFS=', '; echo "${hits[*]}")
reason="BLOCKED by secrets-scan: content being written to '$fp' looks like a live secret ($joined). Never write real credentials into a file. Put it in an environment variable or a gitignored .env / your secret manager and reference it via the environment. If this is a redacted placeholder, rephrase so it does not match a real-key shape."
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r}}'
exit 0
