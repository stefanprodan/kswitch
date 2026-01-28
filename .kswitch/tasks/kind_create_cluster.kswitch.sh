#!/usr/bin/env bash
set -euo pipefail

# KSWITCH_TASK: kind create cluster
# KSWITCH_TASK_DESC: Create a local Kubernetes cluster using Kind.

# Inputs

# KSWITCH_INPUT: NAME "Cluster name"
NAME="${NAME:?NAME is required}"

# KSWITCH_INPUT_OPT: IMAGE "Node image (e.g. kindest/node:v1.35.0)"
IMAGE="${IMAGE:-}"

# Commands

echo -e "Creating cluster: \033[32m${NAME}\033[0m"

kind create cluster --name "${NAME}" ${IMAGE:+--image "${IMAGE}"} --wait 5m
