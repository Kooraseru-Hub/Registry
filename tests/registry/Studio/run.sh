#!/usr/bin/env bash
set -euo pipefail

suite=${1:-Lookup}
studio=${ROBLOX_STUDIO_EXECUTABLE:-}
duration=${STUDIO_TIMEOUT_SECONDS:-600}
studio_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$studio_dir/../../.." && pwd)

case "$suite" in
    Lookup) script="$studio_dir/run-lookup.lua"; marker=REGISTRY_LOOKUP_OK ;;
    RequireForms) script="$studio_dir/../Benchmark/run-require-forms.lua"; marker=REQUIRE_FORMS_OK ;;
    Matrix) script="$studio_dir/run-matrix.lua"; marker=REGISTRY_MATRIX_OK ;;
    *) printf 'Usage: %s [Lookup|RequireForms|Matrix]\n' "$0" >&2; exit 2 ;;
esac

if [[ ! $duration =~ ^[1-9][0-9]{0,3}$ ]] || (( duration > 3600 )); then
    printf 'STUDIO_TIMEOUT_SECONDS must be between 1 and 3600.\n' >&2
    exit 2
fi

if [[ -z $studio && -n ${LOCALAPPDATA:-} ]]; then
    versions=$(cygpath -u "$LOCALAPPDATA")/Roblox/Versions
    if [[ -d $versions ]]; then
        newest=$(find "$versions" -name RobloxStudioBeta.exe -type f -printf '%T@ %p\n' | sort -nr | sed -n '1p')
        studio=${newest#* }
    fi
fi
if [[ -z $studio || ! -f $(cygpath -u "$studio") ]]; then
    printf 'Roblox Studio was not found. Set ROBLOX_STUDIO_EXECUTABLE to its path.\n' >&2
    exit 1
fi

mkdir -p "$root/build/studio-runner"
run_dir=$(mktemp -d "$root/build/studio-runner/$suite-XXXXXXXX")
log="$run_dir/studio.log"
MSYS2_ARG_CONV_EXCL="*" py -3 "$(cygpath -m "$studio_dir/build.py")" "$(cygpath -m "$run_dir")"

printf 'Running %s in Studio. Log: %s\n' "$suite" "$log"
MSYS2_ARG_CONV_EXCL="*" py -3 - "$(cygpath -m "$studio")" "$(cygpath -m "$run_dir/Registry.rbxlx")" \
    "$(cygpath -m "$script")" "$(cygpath -m "$log")" "$duration" <<'PYTHON'
import subprocess
import sys

studio, place, script, log, duration = sys.argv[1:]
try:
    subprocess.run(
        [studio, "--task", "RunScript", "--localPlaceFile", place, "--runScriptFile", script,
         "--outputFile", log, "--quitAfterExecution"],
        timeout=int(duration),
        startupinfo=subprocess.STARTUPINFO(
            dwFlags=subprocess.STARTF_USESHOWWINDOW, wShowWindow=subprocess.SW_HIDE
        ),
    )
except subprocess.TimeoutExpired:
    sys.exit(f"Studio exceeded {duration}s. See {log}")
PYTHON

if [[ ! -f $log ]] || ! tr -d '\r' < "$log" | grep -Fx "$marker" >/dev/null; then
    if [[ -f $log ]]; then
        tail -n 15 "$log"
    fi
    printf 'Studio did not report success. See %s\n' "$log" >&2
    exit 1
fi
printf 'Passed %s. Log: %s\n' "$suite" "$log"
