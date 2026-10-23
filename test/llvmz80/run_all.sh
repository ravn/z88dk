#!/bin/sh
# Master runner for z88dk llvmz80 integration tests.
set -e

DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$DIR/../.." && pwd)
WORKSPACE=$(cd "$ROOT/.." && pwd)

# Ensure TMPDIR is strictly within workspace scratch/tmp
TMPDIR="$WORKSPACE/scratch/tmp"
export TMPDIR
mkdir -p "$TMPDIR"

# Locate LLVMZ80EXE
if [ -z "${LLVMZ80EXE:-}" ]; then
    for candidate in \
        "$WORKSPACE/llvm-z80/build-macos-asserts/bin/clang" \
        "$WORKSPACE/llvm-z80/build-linux/bin/clang" \
        "$WORKSPACE/llvm-z80/build-macos/bin/clang" \
        "$WORKSPACE/llvm-z80/build/bin/clang" \
        "$(command -v clang 2>/dev/null)"; do
        if [ -x "$candidate" ] && "$candidate" --version 2>&1 | grep -qi "z80"; then
            LLVMZ80EXE="$candidate"
            break
        fi
    done
fi
if [ -z "${LLVMZ80EXE:-}" ]; then
    echo "ERROR: cannot find llvm-z80 clang; set LLVMZ80EXE"
    exit 1
fi
export LLVMZ80EXE

# Locate zcc and ZCCCFG
ZCC=${ZCC:-"$ROOT/bin/zcc"}
if [ -z "${ZCCCFG:-}" ] && [ -f "$ROOT/lib/config/cpm.cfg" ]; then
    ZCCCFG="$ROOT/lib/config"
fi
export ZCC ZCCCFG
PATH="$ROOT/bin:$PATH"
export PATH

# Locate NTVCM
if [ -z "${NTVCM:-}" ]; then
    for candidate in \
        "$WORKSPACE/ntvcm/ntvcm" \
        "$(command -v ntvcm 2>/dev/null)"; do
        if [ -x "$candidate" ]; then
            NTVCM="$candidate"
            break
        fi
    done
fi
export NTVCM

echo "=== z88dk llvmz80 integration tests ==="
echo "  LLVMZ80EXE : $LLVMZ80EXE"
echo "  ZCC        : $ZCC"
echo "  ZCCCFG     : $ZCCCFG"
echo "  NTVCM      : ${NTVCM:-not found}"
echo "  TMPDIR     : $TMPDIR"
echo ""

TEST_SCRIPTS="zcc_tmpdir.sh zcc_backend_smoke.sh run_minimal.sh"
PASS=0; FAIL=0; SKIP=0

for script_name in $TEST_SCRIPTS; do
    script="$DIR/$script_name"
    if [ ! -f "$script" ]; then
        echo "skip  $script_name (not found)"
        SKIP=$((SKIP + 1))
        continue
    fi

    echo "--- Running $script_name ---"
    if sh "$script"; then
        echo "PASS  $script_name"
        PASS=$((PASS + 1))
    else
        echo "FAIL  $script_name"
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "Results: $PASS PASS, $FAIL FAIL, $SKIP SKIP"
[ "$FAIL" -eq 0 ]
