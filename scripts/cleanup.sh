#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-${rg:-Lab_ARSDual}}"

printf 'This will delete resource group "%s" and all lab resources. Continue? [y/N] ' "$RESOURCE_GROUP"
read -r answer
case "$answer" in
  [yY]|[yY][eE][sS])
    az group delete --name "$RESOURCE_GROUP" --yes --no-wait
    printf 'Deletion started for resource group "%s".\n' "$RESOURCE_GROUP"
    ;;
  *)
    printf 'Cleanup cancelled.\n'
    ;;
esac
