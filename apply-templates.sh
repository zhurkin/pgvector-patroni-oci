#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$0")"

python3 <<'PY'
import json
import re
from pathlib import Path


root = Path.cwd()

with (root / "versions.json").open("r", encoding="utf-8") as f:
    versions = json.load(f)

docker_template = (root / "Dockerfile-debian.template").read_text(
    encoding="utf-8"
)

requirements_template = (root / "requirements.in.template").read_text(
    encoding="utf-8"
)


def render(template: str, values: dict[str, str]) -> str:
    result = template

    for key, value in values.items():
        result = result.replace(f"%%{key}%%", str(value))

    unresolved = sorted(set(re.findall(r"%%[A-Z0-9_]+%%", result)))

    if unresolved:
        raise RuntimeError(
            "Unresolved template variables: " + ", ".join(unresolved)
        )

    return result


for major, major_data in versions.items():
    variants = major_data.get("variants", [])

    for variant in variants:
        data = major_data[variant]

        values = {
            "BASE_IMAGE": data["baseImage"],
            "POSTGRES_VERSION": data["postgres"],
            "PGVECTOR_VERSION": data["pgvector"],
            "PATRONI_VERSION": data["patroni"],
            "PIP_VERSION": data["pip"],
            "SETUPTOOLS_VERSION": data["setuptools"],
            "WHEEL_VERSION": data["wheel"],
        }

        target = root / major / variant
        target.mkdir(parents=True, exist_ok=True)

        dockerfile = render(docker_template, values)
        requirements = render(requirements_template, values)

        (target / "Dockerfile").write_text(
            dockerfile,
            encoding="utf-8",
        )

        (target / "requirements.in").write_text(
            requirements,
            encoding="utf-8",
        )

        print(f"generated: {major}/{variant}/Dockerfile")
        print(f"generated: {major}/{variant}/requirements.in")
PY
