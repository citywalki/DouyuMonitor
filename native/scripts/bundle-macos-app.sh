#!/usr/bin/env bash
# Builds the self-contained macOS .app: Releases the Qt app, deploys Qt via
# macdeployqt, vendors the libmpv dependency tree into Contents/Frameworks,
# copies the StreamGet service and applies an ad-hoc signature.
#
# Usage: scripts/bundle-macos-app.sh [configure-preset] [build-dir]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PRESET="${1:-macos-arm64-release}"
BUILD_DIR="${2:-${NATIVE_DIR}/out/build/${PRESET}}"
APP_BUNDLE="${BUILD_DIR}/douyu_monitor_native.app"
OUTPUT_DIR="${NATIVE_DIR}/out/installer"
SERVICE_DIR="${NATIVE_DIR}/out/service/streamget_service"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This script only runs on macOS." >&2
    exit 1
fi

cmake --preset "${PRESET}"
cmake --build --preset "${PRESET}" --target douyu_monitor_native

if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "Application bundle not found: ${APP_BUNDLE}" >&2
    exit 1
fi

QT_ROOT="$(cmake -N -LA "${BUILD_DIR}" | awk -F= '/^QT_ROOT:.*=/{print $2}')"
if [[ -z "${QT_ROOT}" || ! -x "${QT_ROOT}/bin/macdeployqt" ]]; then
    echo "macdeployqt not found (QT_ROOT='${QT_ROOT}'). Install Qt with Homebrew." >&2
    exit 1
fi

EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/douyu_monitor_native"
FRAMEWORKS="${APP_BUNDLE}/Contents/Frameworks"
mkdir -p "${FRAMEWORKS}"

# Qt frameworks are deployed by macdeployqt and already use @executable_path.
# Signing is done here, in dependency order, because macdeployqt's own signing
# step chokes on the frozen StreamGet service layout.
# The application's QML is compiled into the binary, so macdeployqt needs the
# QML source directory to discover the QtQuick modules it must deploy.
"${QT_ROOT}/bin/macdeployqt" "${APP_BUNDLE}" -verbose=1 -always-overwrite -no-codesign \
    -qmldir="${NATIVE_DIR}/app/qml"

declare -A resolved=()

# Maps a load command to the file it must be satisfied with, or fails when the
# reference is a system library or already relative to the bundle.
resolve_reference()
{
    local reference="$1"
    local name="${reference##*/}"

    case "${reference}" in
        /usr/lib/*|/System/*|@executable_path/*|@loader_path/*) return 1 ;;
        *.framework/*|*.framework) return 1 ;;
    esac

    if [[ -e "${FRAMEWORKS}/${name}" ]]; then
        printf '%s\n' "${FRAMEWORKS}/${name}"
        return 0
    fi

    if [[ -n "${resolved[${name}]:-}" ]]; then
        printf '%s\n' "${resolved[${name}]}"
        return 0
    fi

    local candidate=""
    if [[ "${reference}" = /* && -e "${reference}" ]]; then
        candidate="${reference}"
    else
        candidate="$(find "${BREW_PREFIX}/opt" -maxdepth 4 -name "${name}" -path '*/lib/*' 2>/dev/null | head -1)"
    fi
    [[ -n "${candidate}" ]] || return 1

    resolved["${name}"]="${candidate}"
    printf '%s\n' "${candidate}"
}

# Copies every non-system dependency of the bundle into Contents/Frameworks and
# points the load commands at @executable_path/../Frameworks so no Homebrew
# prefix is required at run time.
vendor_dependencies()
{
    # macdeployqt already copies the non-Qt dependency tree but leaves some
    # libraries pointing at @rpath, so every bundled Mach-O is walked, not just
    # the executable.
    local pending=("${EXECUTABLE}")
    local bundled
    while IFS= read -r bundled; do
        [[ -f "${bundled}" ]] || continue
        if file "${bundled}" | grep -q 'Mach-O'; then
            pending+=("${bundled}")
        fi
    done < <(find "${FRAMEWORKS}" -depth -type f 2>/dev/null)
    declare -A visited=()

    while ((${#pending[@]} > 0)); do
        local target="${pending[0]}"
        pending=("${pending[@]:1}")
        [[ -n "${visited[${target}]:-}" ]] && continue
        visited["${target}"]=1

        local reference source_path base vendored
        while IFS= read -r reference; do
            [[ -n "${reference}" ]] || continue
            source_path="$(resolve_reference "${reference}")" || continue
            base="$(basename "${source_path}")"
            vendored="${FRAMEWORKS}/${base}"
            if [[ ! -e "${vendored}" ]]; then
                cp -f "${source_path}" "${vendored}"
                chmod u+w "${vendored}"
                install_name_tool -id "@executable_path/../Frameworks/${base}" "${vendored}"
                pending+=("${vendored}")
            fi
            install_name_tool -change "${reference}" \
                "@executable_path/../Frameworks/${base}" "${target}"
        done < <(otool -L "${target}" | tail -n +2 | awk '{print $1}' | sort -u)
    done
}

vendor_dependencies

# Normalize the install names of everything vendored so no Homebrew prefix
# survives in the bundle.
for library in "${FRAMEWORKS}"/*.dylib; do
    [[ -e "${library}" ]] || continue
    install_name_tool -id "@executable_path/../Frameworks/$(basename "${library}")" "${library}"
done

sign_file()
{
    codesign --force --sign - "$1" >/dev/null 2>&1 || true
}

# Signs every Mach-O below a path, deepest first, so nested code is valid
# before its container is sealed.
sign_macho_tree()
{
    local root="$1"
    [[ -e "${root}" ]] || return 0
    local candidate
    while IFS= read -r candidate; do
        [[ -f "${candidate}" ]] || continue
        if file "${candidate}" | grep -q 'Mach-O'; then
            sign_file "${candidate}"
        fi
    done < <(find "${root}" -depth -type f 2>/dev/null)
}

# macdeployqt rewrote install names in the deployed frameworks and plug-ins,
# which invalidates their signatures; -no-codesign left them for this pass.
sign_macho_tree "${FRAMEWORKS}"
sign_macho_tree "${APP_BUNDLE}/Contents/PlugIns"
while IFS= read -r framework; do
    sign_file "${framework}"
done < <(find "${FRAMEWORKS}" -depth -type d -name '*.framework' 2>/dev/null)

if [[ -d "${SERVICE_DIR}" ]]; then
    # Resources, not MacOS: codesign rejects nested directories below
    # Contents/MacOS because it validates them as nested bundles.
    rm -rf "${APP_BUNDLE}/Contents/MacOS/streamget_service"
    rm -rf "${APP_BUNDLE}/Contents/Resources/streamget_service"
    cp -R "${SERVICE_DIR}" "${APP_BUNDLE}/Contents/Resources/streamget_service"
    sign_macho_tree "${APP_BUNDLE}/Contents/Resources/streamget_service"
    echo "Bundled StreamGet service from ${SERVICE_DIR}"
else
    echo "Warning: StreamGet service not built; run scripts/build-streamget-service.sh" >&2
fi

codesign --force --sign - "${APP_BUNDLE}"
if ! codesign --verify --deep --strict "${APP_BUNDLE}"; then
    echo "Bundled application failed code signature verification" >&2
    exit 1
fi
echo "Code signature verified"

mkdir -p "${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}/DouyuMonitor.app"
cp -R "${APP_BUNDLE}" "${OUTPUT_DIR}/DouyuMonitor.app"
echo "Wrote ${OUTPUT_DIR}/DouyuMonitor.app"
