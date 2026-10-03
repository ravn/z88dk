#!/bin/sh
# Ensure math32 archives track assembly and source-list inputs in make.
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$DIR/../.." && pwd)
MATH32_DIR="$REPO/libsrc/math/float/math32"
LIBSRC_DIR=$(cd "$MATH32_DIR/../../.." && pwd)
ARCHIVES="math32.lib math32_ixiy.lib math32_z80n.lib math32_z180.lib
math32_ez80_z80.lib math32_r2ka.lib math32_r4k.lib math32_r6k.lib
math32_kc160.lib math32_8085.lib math32_8080.lib math32_gbz80.lib
math32_vm1.lib"

set -- $ARCHIVES
TARGETS=
for archive do
    TARGETS="$TARGETS $LIBSRC_DIR//$archive"
done
DATABASE=$(make -C "$MATH32_DIR" -pn $TARGETS)

for archive do
    target="$LIBSRC_DIR//$archive:"
    RULE=$(printf '%s\n' "$DATABASE" | awk -v target="$target" \
        '$1 == target { print; exit }')
    [ -n "$RULE" ] || {
        echo "FAIL: make database has no rule for $archive"
        exit 1
    }
    for input in \
        "$MATH32_DIR/asm/f32_fpclassify.asm" \
        "$MATH32_DIR/newlibfiles_z80.lst"
    do
        printf '%s\n' "$RULE" | grep -Fq "$input" || {
            echo "FAIL: $archive does not depend on $input"
            exit 1
        }
    done
done

echo "PASS: all math32 archives track assembly sources and list files"
