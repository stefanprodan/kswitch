#!/usr/bin/env bash
set -euo pipefail

# KSWITCH_TASK: kind delete cluster
# KSWITCH_TASK_DESC: Delete a local Kubernetes cluster created with Kind.

# Inputs

# KSWITCH_INPUT: NAME "Cluster name"
NAME="${NAME:?NAME is required}"

# Commands

echo -e "Deleting cluster: \033[31m${NAME}\033[0m"

kind delete cluster --name "${NAME}"
