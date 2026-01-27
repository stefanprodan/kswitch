#!/bin/bash
set -euo pipefail

# KSWITCH_TASK: test script
# KSWITCH_TASK_DESC: Test task that prints the env, waits and exits with specified code.

# Inputs

# KSWITCH_INPUT_OPT: WAIT "Wait time in seconds (default: 10)"
WAIT="${WAIT:-10}"

# KSWITCH_INPUT_OPT: EXIT "Exit code (default: 1)"
EXIT="${EXIT:-1}"

# Commands

echo ""
echo -e "\033[32m=== Environment ===\033[0m"
echo ""
env | sort | awk -F= '{v=$2; printf "\033[33m%s\033[0m=%s\n", $1, (length(v)>25 ? substr(v,1,40)"..." : v)}'

echo ""
echo -e "\033[32m=== PATH ===\033[0m"
echo ""
echo "$PATH" | tr ':' '\n' | while read -r p; do echo " ${p:0:40}"; done

echo ""
echo -e "\033[34m=== Simulating Work ===\033[0m"
echo ""
for i in $(seq 1 "$WAIT"); do
    echo ">>> Progress: $i/$WAIT"
    sleep 1
done

echo ""
echo -e "\033[31m=== Simulating Exit ===\033[0m"
echo ""
echo -e "code $EXIT"
echo ""

exit "$EXIT"
