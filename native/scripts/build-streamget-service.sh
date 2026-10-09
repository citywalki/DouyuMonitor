#!/usr/bin/env bash
# macOS/Linux counterpart of build-streamget-service.ps1. Produces the frozen
# service directory consumed by the CMake copy step and by
# scripts/bundle-macos-app.sh: native/out/service/streamget_service/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${NATIVE_DIR}/.." && pwd)"
VENV_PYTHON="${NATIVE_DIR}/.venv/bin/python"
SERVICE_SCRIPT="${NATIVE_DIR}/service/streamget_service.py"
DIST_DIR="${NATIVE_DIR}/out/service"
WORK_DIR="${NATIVE_DIR}/out/pyinstaller"
OUTPUT_DIR="${DIST_DIR}/streamget_service"
OUTPUT_BINARY="${OUTPUT_DIR}/streamget_service"

if [[ ! -x "${VENV_PYTHON}" ]]; then
    echo "Python virtual environment not found: ${VENV_PYTHON}" >&2
    echo "Run scripts/bootstrap-streamget-service.sh first." >&2
    exit 1
fi

mkdir -p "${DIST_DIR}" "${WORK_DIR}"
"${VENV_PYTHON}" -m PyInstaller --noconfirm --clean --onedir --log-level WARN \
    --name streamget_service \
    --paths "${REPO_ROOT}" \
    --distpath "${DIST_DIR}" \
    --workpath "${WORK_DIR}" \
    --specpath "${WORK_DIR}" \
    --add-data "${NATIVE_DIR}/app/resources/hamster_agent_roster.json:native/app/resources" \
    "${SERVICE_SCRIPT}"

if [[ ! -x "${OUTPUT_BINARY}" ]]; then
    echo "PyInstaller failed to build the streamget_service directory" >&2
    exit 1
fi

echo "${OUTPUT_BINARY}"
