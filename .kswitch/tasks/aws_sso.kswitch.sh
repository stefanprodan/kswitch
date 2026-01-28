#!/usr/bin/env bash
set -euo pipefail

# KSWITCH_TASK: aws sso login
# KSWITCH_TASK_DESC: Login to AWS SSO for all profiles in ~/.aws/config

CONFIG_FILE="${HOME}/.aws/config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: AWS config file not found at $CONFIG_FILE"
    exit 1
fi

# Parse profile names from config (handles both [profile name] and [default])
profiles=()
while IFS= read -r line; do
    if [[ "$line" =~ ^\[profile[[:space:]]+([^\]]+)\]$ ]]; then
        profiles+=("${BASH_REMATCH[1]}")
    elif [[ "$line" == "[default]" ]]; then
        profiles+=("default")
    fi
done < "$CONFIG_FILE"

if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "No profiles found in $CONFIG_FILE"
    exit 0
fi

echo "Found ${#profiles[@]} profile(s): ${profiles[*]}"
echo

# Build command with all --profile flags
cmd=(aws sso login)
for profile in "${profiles[@]}"; do
    cmd+=(--profile "$profile")
done

echo "Running: ${cmd[*]}"
"${cmd[@]}"
