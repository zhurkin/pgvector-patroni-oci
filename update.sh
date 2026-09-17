#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$0")"

command -v docker >/dev/null 2>&1 || {
    echo "docker is required" >&2
    exit 1
}

command -v python3 >/dev/null 2>&1 || {
    echo "python3 is required" >&2
    exit 1
}

bash ./apply-templates.sh

while IFS=$'\t' read -r \
    major \
    variant \
    base_image \
    patroni_version \
    pip_version \
    setuptools_version \
    wheel_version
do
    target="${major}/${variant}"
    requirements_in="${target}/requirements.in"
    requirements_lock="${target}/requirements.lock"

    echo
    echo "==> resolving ${major}/${variant}"
    echo "    base:    ${base_image}"
    echo "    patroni: ${patroni_version}"

    tmp="$(mktemp)"

    cleanup() {
        rm -f "$tmp"
    }

    trap cleanup RETURN

    docker run \
        --rm \
        --user 0:0 \
        --entrypoint /bin/sh \
        -e "PIP_VERSION=${pip_version}" \
        -e "SETUPTOOLS_VERSION=${setuptools_version}" \
        -e "WHEEL_VERSION=${wheel_version}" \
        -v "$(pwd)/${requirements_in}:/tmp/requirements.in:ro" \
        "${base_image}" \
        -ec '
            apt-get update >&2

            apt-get install -y --no-install-recommends \
                python3 \
                python3-venv \
                python3-pip \
                python3-dev \
                build-essential \
                >&2

            python3 -m venv /tmp/lock-venv

            /tmp/lock-venv/bin/python -m pip install \
                --no-cache-dir \
                --upgrade \
                "pip==${PIP_VERSION}" \
                "setuptools==${SETUPTOOLS_VERSION}" \
                "wheel==${WHEEL_VERSION}" \
                >&2

            /tmp/lock-venv/bin/python -m pip install \
                --no-cache-dir \
                --prefer-binary \
                -r /tmp/requirements.in \
                >&2

            /tmp/lock-venv/bin/python -m pip freeze \
                | grep -Ev "^(pip|setuptools|wheel)=="
        ' > "$tmp"

    LC_ALL=C sort -f "$tmp" -o "$tmp"

    if ! grep -Fxq "patroni==${patroni_version}" "$tmp"; then
        echo "ERROR: resolved Patroni version does not match versions.json" >&2
        exit 1
    fi

    {
        echo '#'
        echo '# NOTE: THIS FILE IS GENERATED VIA "update.sh"'
        echo '#'
        echo '# PLEASE DO NOT EDIT IT DIRECTLY.'
        echo '#'
        echo
        cat "$tmp"
    } > "$requirements_lock"

    echo "generated: ${requirements_lock}"
done < <(
    python3 <<'PY'
import json

with open("versions.json", "r", encoding="utf-8") as f:
    versions = json.load(f)

for major, major_data in versions.items():
    for variant in major_data.get("variants", []):
        data = major_data[variant]

        print(
            major,
            variant,
            data["baseImage"],
            data["patroni"],
            data["pip"],
            data["setuptools"],
            data["wheel"],
            sep="\t",
        )
PY
)

echo
echo "Done."
