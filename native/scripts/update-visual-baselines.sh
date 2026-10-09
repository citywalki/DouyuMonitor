#!/usr/bin/env bash
# macOS/Linux counterpart of update-visual-baselines.ps1. Refreshes the visual
# baselines for this platform (native/tests/visual/baselines/<kernel type>/).
#
# Usage: scripts/update-visual-baselines.sh --approve [configure-preset]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PRESET="macos-arm64-release"

if [[ "${1:-}" != "--approve" ]]; then
    echo "Visual baselines may only be updated after explicit review. Re-run with --approve." >&2
    exit 1
fi
if [[ -n "${2:-}" ]]; then
    PRESET="$2"
fi

export DOUYU_UPDATE_VISUAL_BASELINES=1
cd "${NATIVE_DIR}"

cmake --build --preset "${PRESET}" --target qml_visual_regression_test
ctest --preset "${PRESET}" -R '^qml_visual_regression_test$' --output-on-failure

echo "Visual baselines updated."
echo "Review the changed PNG files under native/tests/visual/baselines before committing."
