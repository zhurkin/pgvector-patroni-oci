#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

PGVECTOR_IMAGE=$(python3 - "$ROOT_DIR/versions.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

pg = data["pgvector"]
print(f'{pg["image"]}:{pg["tag"]}')
PY
)

python3 - "$ROOT_DIR/Dockerfile.template" "$ROOT_DIR/Dockerfile" "$PGVECTOR_IMAGE" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
image = sys.argv[3]

text = src.read_text(encoding="utf-8")
text = text.replace("@@PGVECTOR_IMAGE@@", image)
dst.write_text(text, encoding="utf-8")
PY

echo "Generated Dockerfile using ${PGVECTOR_IMAGE}"
