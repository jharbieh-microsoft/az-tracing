#!/usr/bin/env bash
set -euo pipefail

PRINCIPAL=""
SCOPE=""
ROLES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --principal)
      PRINCIPAL="$2"
      shift 2
      ;;
    --scope)
      SCOPE="$2"
      shift 2
      ;;
    --roles)
      ROLES="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PRINCIPAL" || -z "$SCOPE" || -z "$ROLES" ]]; then
  echo "Usage: verify-principal.sh --principal <principal-id> --scope <scope-id> --roles \"Role A,Role B\"" >&2
  exit 1
fi

mapfile -t EXPECTED < <(echo "$ROLES" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d')
if [[ ${#EXPECTED[@]} -eq 0 ]]; then
  echo "No expected roles provided." >&2
  exit 1
fi

mapfile -t ASSIGNED < <(az role assignment list --assignee "$PRINCIPAL" --scope "$SCOPE" --query "[].roleDefinitionName" -o tsv)

echo "Assigned roles at scope:"
if [[ ${#ASSIGNED[@]} -eq 0 ]]; then
  echo "  (none)"
else
  printf '%s\n' "${ASSIGNED[@]}" | sort -u | sed 's/^/  /'
fi

MISSING=()
for role in "${EXPECTED[@]}"; do
  found=false
  for assigned in "${ASSIGNED[@]}"; do
    if [[ "$assigned" == "$role" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" == false ]]; then
    MISSING+=("$role")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Missing required roles:"
  printf '%s\n' "${MISSING[@]}" | sed 's/^/  /'
  exit 2
fi

echo "All expected roles are assigned at the target scope."
