#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION=""
RESOURCE_GROUP=""
LOCATION=""
ENVIRONMENT="dev"
MODE="both"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription)
      SUBSCRIPTION="$2"
      shift 2
      ;;
    --resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --location)
      LOCATION="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SUBSCRIPTION" || -z "$RESOURCE_GROUP" || -z "$LOCATION" ]]; then
  echo "Usage: run.sh --subscription <id> --resource-group <name> --location <region> [--environment dev|prod] [--mode validate|whatif|both]" >&2
  exit 1
fi

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Invalid environment: $ENVIRONMENT. Use dev or prod." >&2
  exit 1
fi

if [[ "$MODE" != "validate" && "$MODE" != "whatif" && "$MODE" != "both" ]]; then
  echo "Invalid mode: $MODE. Use validate, whatif, or both." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BICEP_DIR="$REPO_ROOT/bicep"
MAIN_TEMPLATE="$BICEP_DIR/main.bicep"
PARAM_FILE="$BICEP_DIR/main.$ENVIRONMENT.bicepparam"

if [[ ! -f "$MAIN_TEMPLATE" ]]; then
  echo "main.bicep not found at $MAIN_TEMPLATE" >&2
  exit 1
fi

if [[ ! -f "$PARAM_FILE" ]]; then
  echo "Parameter file not found at $PARAM_FILE" >&2
  exit 1
fi

echo "Setting Azure subscription context..."
az account set --subscription "$SUBSCRIPTION" >/dev/null

echo "Compiling Bicep template..."
az bicep build --file "$MAIN_TEMPLATE" >/dev/null

if [[ "$MODE" == "validate" || "$MODE" == "both" ]]; then
  echo "Running deployment validation..."
  az deployment group validate \
    --name "az-tracing-validate-$ENVIRONMENT" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$MAIN_TEMPLATE" \
    --parameters "@$PARAM_FILE" \
    --location "$LOCATION" \
    --output table
fi

if [[ "$MODE" == "whatif" || "$MODE" == "both" ]]; then
  echo "Running deployment what-if..."
  az deployment group what-if \
    --name "az-tracing-whatif-$ENVIRONMENT" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$MAIN_TEMPLATE" \
    --parameters "@$PARAM_FILE" \
    --location "$LOCATION" \
    --output table
fi

echo "Bicep validation workflow completed."
