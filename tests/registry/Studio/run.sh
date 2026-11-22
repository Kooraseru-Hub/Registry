#!/usr/bin/env bash
set -euo pipefail

studio_node=node
case "$OSTYPE" in
    msys*|cygwin*)
        export PATH="/usr/bin:$PATH"
        windows_path() { cygpath -am "$1"; }
        host_path() { cygpath -u "$1"; }
        ;;
    linux*)
        if ! command -v wslpath >/dev/null || ! command -v node.exe >/dev/null; then
            printf "Studio suites need WSL interop and Windows Node.js on PATH.\n" >&2
            exit 2
        fi
        studio_node=node.exe
        windows_path() { wslpath -am "$(realpath -m "$1")"; }
        host_path() { wslpath -u "$1"; }
        ;;
    *) printf "Studio suites require Windows or WSL with Windows interop.\n" >&2; exit 2 ;;
esac

suite=${1:-Lookup}
studio=${ROBLOX_STUDIO_EXECUTABLE:-}
duration=${STUDIO_TIMEOUT_SECONDS:-600}
studio_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$studio_dir/../../.." && pwd)

case "$suite" in
    Lookup) script="$studio_dir/run-lookup.lua"; marker=REGISTRY_LOOKUP_OK ;;
    RequireForms) script="$root/tests/registry/benchmarks/run-require-forms.lua"; marker=REQUIRE_FORMS_OK ;;
    Matrix) script="$root/tests/registry/benchmarks/run-matrix.lua"; marker=REGISTRY_MATRIX_OK ;;
    *) printf 'Usage: %s [Lookup|RequireForms|Matrix]\n' "$0" >&2; exit 2 ;;
esac

if [[ ! $duration =~ ^[1-9][0-9]{0,3}$ ]] || (( duration > 3600 )); then
    printf 'STUDIO_TIMEOUT_SECONDS must be between 1 and 3600.\n' >&2
    exit 2
fi

if [[ -z $studio && $OSTYPE == linux* && -z ${LOCALAPPDATA:-} ]]; then
    LOCALAPPDATA=$(cmd.exe /d /c "echo %LOCALAPPDATA%" | tr -d '\r')
fi
if [[ -z $studio && -n ${LOCALAPPDATA:-} ]]; then
    versions=$(host_path "$LOCALAPPDATA")/Roblox/Versions
    if [[ -d $versions ]]; then
        newest=$(find "$versions" -name RobloxStudioBeta.exe -type f -printf '%T@ %p\n' | sort -nr | sed -n '1p')
        studio=${newest#* }
    fi
fi
if [[ -n $studio && ! -f $studio ]]; then studio=$(host_path "$studio"); fi
if [[ -z $studio || ! -f $studio ]]; then
    printf 'Roblox Studio was not found. Set ROBLOX_STUDIO_EXECUTABLE to its path.\n' >&2
    exit 1
fi

mkdir -p "$root/build/artifacts/tests"
run_dir=$(mktemp -d "$root/build/artifacts/tests/$suite-XXXXXXXX")
log="$run_dir/studio.log"
node "$studio_dir/build.cjs" "$run_dir"

printf 'Running %s in Studio. Log: %s\n' "$suite" "$log"
if [[ $suite == Matrix && -n ${2:-} ]]; then
    revision=$(git -C "$root" rev-parse --verify HEAD)
    checkout=clean
    if [[ -n $(git -C "$root" status --porcelain) ]]; then checkout=dirty; fi
    studio_digest=$(sha256sum < "$studio")
    started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
fi
MSYS2_ARG_CONV_EXCL="*" "$studio_node" "$(windows_path "$studio_dir/launch.cjs")" "$(windows_path "$studio")" \
    "$(windows_path "$run_dir/Registry.rbxlx")" "$(windows_path "$script")" "$(windows_path "$log")" "$duration" "$suite"

if [[ ! -f $log ]] || ! tr -d '\r' < "$log" | grep -Fx "$marker" >/dev/null; then
    if [[ -f $log ]]; then
        tail -n 15 "$log"
    fi
    printf 'Studio did not report success. See %s\n' "$log" >&2
    exit 1
fi
printf 'Passed %s. Log: %s\n' "$suite" "$log"

if [[ $suite == Matrix && -n ${2:-} ]]; then
    printf 'Rendering benchmark charts\n'
    node "$root/tests/registry/benchmarks/plot-matrix.cjs" "$log" "$2"
    printf '%s\n%s\n%s\nsha256:%s\n' "$started_at" "$revision" "$checkout" "${studio_digest%% *}" > "$2/measurement.txt"
fi
