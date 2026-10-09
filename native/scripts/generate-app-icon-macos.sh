#!/usr/bin/env bash
# Renders app/assets/douyu_monitor.svg into the .icns consumed by the macOS
# bundle (native/CMakeLists.txt, MACOSX_BUNDLE_ICON_FILE).
#
# Requires macOS tooling only: qlmanage, sips, iconutil.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_SVG="${NATIVE_DIR}/app/assets/douyu_monitor.svg"
OUTPUT_ICNS="${NATIVE_DIR}/app/assets/douyu_monitor.icns"

if [[ ! -f "${SOURCE_SVG}" ]]; then
    echo "Source icon not found: ${SOURCE_SVG}" >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

qlmanage -t -s 1024 -o "${WORK_DIR}" "${SOURCE_SVG}" >/dev/null
RENDERED="${WORK_DIR}/$(basename "${SOURCE_SVG}").png"
if [[ ! -f "${RENDERED}" ]]; then
    echo "qlmanage did not render ${SOURCE_SVG}" >&2
    exit 1
fi

ICONSET="${WORK_DIR}/douyu_monitor.iconset"
mkdir -p "${ICONSET}"
for size in 16 32 128 256 512; do
    sips -z "${size}" "${size}" "${RENDERED}" \
        --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "${double}" "${double}" "${RENDERED}" \
        --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "${ICONSET}" -o "${OUTPUT_ICNS}"
echo "Wrote ${OUTPUT_ICNS}"

# Runtime QIcon source for the macOS/Linux status item and window icon.
OUTPUT_PNG="${NATIVE_DIR}/app/assets/douyu_monitor.png"
sips -z 128 128 "${RENDERED}" --out "${OUTPUT_PNG}" >/dev/null
echo "Wrote ${OUTPUT_PNG}"
