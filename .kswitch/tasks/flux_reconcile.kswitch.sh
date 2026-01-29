#!/usr/bin/env bash
set -euo pipefail

# KSWITCH_TASK: flux reconcile
# KSWITCH_TASK_DESC: Trigger a reconcile using the flux-operator CLI.

# Inputs

# KSWITCH_INPUT: NAME "Resource name"
NAME="${NAME:?NAME is required}"

# KSWITCH_INPUT_OPT: NAMESPACE "Target namespace (default: flux-system)"
NAMESPACE="${NAMESPACE:-flux-system}"

# KSWITCH_INPUT_OPT: KIND "Resource kind (default: Kustomization)"
KIND="${KIND:-Kustomization}"

FORCE_FLAG=""
if [[ "${KIND}" == "HelmRelease" || "${KIND}" == "hr" ]]; then
    FORCE_FLAG="--force"
fi

# Commands

echo -e "Reconciling: \033[32m${KIND}/${NAMESPACE}/${NAME}\033[0m"
echo -e "Context: \033[32m$(kubectl config current-context)\033[0m"

flux-operator reconcile resource "${KIND}/${NAME}" -n "${NAMESPACE}" ${FORCE_FLAG}
