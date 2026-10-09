#!/usr/bin/env bash
# macOS/Linux counterpart of bootstrap-streamget-service.ps1: creates the
# native/.venv used by the StreamGet service tests and packaging scripts.
set -euo pipefail

PYTHON_BIN="${PYTHON:-python3}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_DIR="${NATIVE_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python"

if [[ ! -x "${VENV_PYTHON}" ]]; then
    "${PYTHON_BIN}" -m venv "${VENV_DIR}"
    if [[ ! -x "${VENV_PYTHON}" ]]; then
        echo "Failed to create native Python virtual environment" >&2
        exit 1
    fi
fi

for requirements in service/requirements.txt service/requirements-build.txt; do
    "${VENV_PYTHON}" -m pip install --requirement "${NATIVE_DIR}/${requirements}"
done

echo "${VENV_PYTHON}"
