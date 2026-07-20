#!/bin/sh
# Regression test runner for ravn/z88dk#4 (const-expr (uint16_t)X>>8 sign-extend).
#
# Builds test_const_shift_signext.c under the production zsdcc flags that
# trigger the bug (--sdcccall 1 -SO3 --opt-code-size --std-sdcc23), runs it in
# z88dk-ticks, and checks the verifier byte at 0xCFFF.
#
# Pre-fix (zsdcc 4.5.0 #15242): the const HI byte is baked as 0xFF, so the
#   verifier writes 0xFF (FAIL).
# Post-fix: HI == 0x00, verifier writes 0xA5 (PASS).
#
# Skips silently if zsdcc / zcc / z88dk-ticks are missing.

set -e

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
Z88DK_ROOT="${Z88DK_ROOT:-$TEST_DIR/../../..}"
ZCC="${ZCC:-$Z88DK_ROOT/bin/zcc}"
TICKS="${TICKS:-$Z88DK_ROOT/bin/z88dk-ticks}"
export ZCCCFG="${ZCCCFG:-$Z88DK_ROOT/lib/config}"
export PATH="$Z88DK_ROOT/bin:$PATH"

if [ ! -x "$ZCC" ] || [ ! -x "$TICKS" ]; then
    echo "SKIP: zcc or z88dk-ticks missing"
    exit 0
fi

BUILD_DIR=$(mktemp -d -t const_shift.XXXXXX)
trap "rm -rf $BUILD_DIR" EXIT

cd "$BUILD_DIR"
cp "$TEST_DIR/test_const_shift_signext.c" t.c

"$ZCC" +z80 -compiler=sdcc -clib=sdcc_iy --opt-code-size -SO3 \
    -Cs"--std-sdcc23" -Cs"--sdcccall 1" -Cs"--disable-warning 296" \
    -Cs"--max-allocs-per-node 25000" -Cs"--fomit-frame-pointer" \
    -m -create-app -o test_const_shift t.c \
    > build.log 2>&1 || { echo "FAIL: build error"; cat build.log; exit 1; }

# Find the post-main HALT pattern (push hl; di; pop hl; halt) the crt0 emits.
DONE=$(python3 -c "
import re
d = open('test_const_shift.bin', 'rb').read()
m = re.search(b'\\xe5\\xf3\\xe1\\x76', d)
if m: print(f'0x{m.start()+3:04X}')
else: exit(1)
") || { echo "FAIL: cannot find HALT pattern in bin"; exit 1; }

"$TICKS" -mz80 -end "$DONE" -counter 5000000 \
    -output test_const_shift.ram test_const_shift.bin > ticks.log 2>&1 || true

if [ ! -f test_const_shift.ram ]; then
    echo "FAIL: ticks did not produce ram dump"; cat ticks.log; exit 1
fi

VERIFIER=$(python3 -c "
d = open('test_const_shift.ram', 'rb').read()
print(f'0x{d[0xCFFF]:02X}')
")

if [ "$VERIFIER" = "0xA5" ]; then
    echo "PASS: const-expr (uint16_t)X>>8 folds correctly (verifier @ 0xCFFF = 0xA5)"
    exit 0
else
    echo "FAIL: verifier byte @ 0xCFFF = $VERIFIER (expected 0xA5)"
    echo "ravn/z88dk#4: const ((uint16_t)((0x80|0)|(0<<8))>>8)&0xFF mis-folded (HI=$VERIFIER, want 0x00)."
    exit 1
fi
