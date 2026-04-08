#!/usr/bin/env bash
set -euo pipefail

INPUT=""
OUTPUT=""
TITLE=""
FONT_SIZE="11"
LINE_SPACING="1.3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --title)
      TITLE="$2"
      shift 2
      ;;
    --font-size)
      FONT_SIZE="$2"
      shift 2
      ;;
    --line-spacing)
      LINE_SPACING="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
  echo "Usage: generate.sh --input <path> --output <path> [--title <text>] [--font-size <num>] [--line-spacing <num>]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/generate_pdf.py"

if [[ ! -f "$PYTHON_SCRIPT" ]]; then
  echo "Python generator script not found: $PYTHON_SCRIPT" >&2
  exit 1
fi

ARGS=(--input "$INPUT" --output "$OUTPUT" --font-size "$FONT_SIZE" --line-spacing "$LINE_SPACING")
if [[ -n "$TITLE" ]]; then
  ARGS+=(--title "$TITLE")
fi

python "$PYTHON_SCRIPT" "${ARGS[@]}"
