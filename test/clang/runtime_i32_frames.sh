#!/bin/sh
# Force IX frame accesses after native calls; test both small and fast cores.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$DIR/test_env.sh" ] && . "$DIR/test_env.sh"
command -v zcc >/dev/null 2>&1 || { echo "SKIP: zcc not on PATH"; exit 0; }
NTVCM=${NTVCM:-ntvcm}
command -v "$NTVCM" >/dev/null 2>&1 || { echo "SKIP: ntvcm not found"; exit 0; }
mkdir -p "$DIR/../../../scratch/tmp"
WORK=$(mktemp -d "$DIR/../../../scratch/tmp/i32-frames.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
for math in small fast; do
    redirects=""
    if [ "$math" = fast ]; then
        redirects="-pragma-redirect:l_divs_32_32x32=l_fast_divs_32_32x32
                   -pragma-redirect:l_divu_32_32x32=l_fast_divu_32_32x32
                   -pragma-redirect:l_mulu_32_32x32=l_fast_mulu_32_32x32"
    fi
    for opt in -O0 -O2 -O3 --opt-code-size; do
        if ! zcc +cpm -compiler=llvmz80 ${ZCC_CLIB:-} "$opt" \
            -Cg-fno-omit-frame-pointer $redirects \
            -create-app -m -o "$WORK/rt" "$DIR/runtime_i32_frames.c" \
            >"$WORK/build.log" 2>&1; then
            cat "$WORK/build.log"
            echo "FAIL: math=$math $opt build failed"
            exit 1
        fi
        if [ "$math" = fast ]; then
            grep -q 'l_fast_divs_32_32x32' "$WORK/rt.map" || {
                echo "FAIL: fast core was not linked"
                exit 1
            }
        fi
        OUT=$("$NTVCM" "$WORK/RT.COM" 2>/dev/null | tr -d '\r')
        for expected in \
            'frame=-142857,-1,71' \
            'negative-divisor=-142857,1,71' \
            'small-dividend=0,-6,71' \
            'multiply=8610071'; do
            if ! printf '%s\n' "$OUT" | grep -qxF "$expected"; then
                echo "FAIL: math=$math $opt got [$OUT], missing [$expected]"
                exit 1
            fi
        done
    done
done
echo "PASS: native i32 small/fast cores preserve IX frames at O0/O2/O3/Oz"
