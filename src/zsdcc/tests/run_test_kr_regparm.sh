#!/bin/sh
# Regression test runner for ravn/z88dk#5 / #14 (K&R REGPARM-preserve).
#
# Builds the two-TU repro:
#   test_kr_regparm_caller.c  -- ANSI prototype, --sdcccall 1
#   test_kr_regparm_callee.c  -- K&R definition of the same function
# under --sdcccall 1 + --nogcse, runs in z88dk-ticks, checks that
# byte at 0xCFFF == 0xA5.
#
# Pre-fix (sdcc-kr-regparm-preserve-z88dk.patch not applied): the
# K&R callee body uses stack-args, decoy gets zeroed, verifier
# byte != 0xA5, FAIL.
# Post-fix: K&R callee uses register-args matching caller, local
# gets zeroed correctly, verifier byte == 0xA5, PASS.
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

BUILD_DIR=$(mktemp -d -t kr_regparm.XXXXXX)
trap "rm -rf $BUILD_DIR" EXIT

cd "$BUILD_DIR"
cp "$TEST_DIR/test_kr_regparm_caller.c" caller.c
cp "$TEST_DIR/test_kr_regparm_callee.c" callee.c

# --sdcccall 1 + --nogcse triggers the K&R int-promotion path that
# pre-patch silently fell back to stack-args ABI.  -clib=sdcc_iy is
# the production default.
"$ZCC" +z80 -compiler=sdcc -clib=sdcc_iy --opt-code-size -SO3 \
    -Cs"--sdcccall 1" -Cs"--disable-warning 296" \
    -Cs"--max-allocs-per-node 25000" -Cs"--fomit-frame-pointer" \
    -Cs"--nogcse" \
    -m -create-app -o test_kr_regparm caller.c callee.c \
    > build.log 2>&1 || { echo "FAIL: build error"; cat build.log; exit 1; }

# Find the post-main HALT pattern that z88dk-ticks's z80 crt0 emits.
# Same trick as in z88dk-zsdcc's own AES corpus harness.
DONE=$(python3 -c "
import re
d = open('test_kr_regparm.bin', 'rb').read()
m = re.search(b'\\xe5\\xf3\\xe1\\x76', d)
if m: print(f'0x{m.start()+3:04X}')
else: exit(1)
") || { echo "FAIL: cannot find HALT pattern in bin"; exit 1; }

"$TICKS" -mz80 -end "$DONE" -counter 5000000 \
    -output test_kr_regparm.ram test_kr_regparm.bin > ticks.log 2>&1 || true

if [ ! -f test_kr_regparm.ram ]; then
    echo "FAIL: ticks did not produce ram dump"
    cat ticks.log
    exit 1
fi

VERIFIER=$(python3 -c "
d = open('test_kr_regparm.ram', 'rb').read()
print(f'0x{d[0xCFFF]:02X}')
")

if [ "$VERIFIER" = "0xA5" ]; then
    echo "PASS: K&R callee + ANSI caller cross-TU regression (verifier @ 0xCFFF = 0xA5)"
    exit 0
else
    echo "FAIL: verifier byte @ 0xCFFF = $VERIFIER (expected 0xA5)"
    echo "Likely the SDCC K&R-REGPARM-preserve patch is not applied."
    exit 1
fi
