#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: render-dot <file.dot>" >&2
  exit 1
fi

DOT_FILE="$1"

if [ ! -f "$DOT_FILE" ]; then
  echo "Error: file not found: $DOT_FILE" >&2
  exit 1
fi

OUT_DIR="$(mktemp -d)"
OUT_FILE="$OUT_DIR/$(basename "${DOT_FILE%.dot}.svg")"

dot -Tsvg "$DOT_FILE" -o "$OUT_FILE"

echo "Rendered to $OUT_FILE"

librewolf "$OUT_FILE" >/dev/null 2>&1 &
