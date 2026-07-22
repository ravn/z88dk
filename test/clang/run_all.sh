#!/bin/sh
# Master runner for the ravn/llvm-z80 + z88dk integration test suite.
#
# Auto-detects LLVMZ80EXE and NTVCM from environment or well-known paths,
# then runs every *.sh in this directory (except itself).
#
# Exit code: 0 if all tests PASS or SKIP, 1 if any FAILs.
#
# Usage (all vars optional if binaries are findable):
#   LLVMZ80EXE=/path/to/clang NTVCM=/path/to/ntvcm ./run_all.sh
set -e

DIR=$(cd "$(dirname "$0")" && pwd)
SELF=$(basename "$0")

# ---- locate LLVMZ80EXE ----
if [ -z "$LLVMZ80EXE" ]; then
    for candidate in \
        "/Users/ravn/z80/llvm-z80/build-macos/bin/clang" \
        "/home/ravn/z80/llvm-z80/build/bin/clang" \
        "$(command -v clang 2>/dev/null)"; do
        if [ -x "$candidate" ] && "$candidate" --version 2>&1 | grep -q "z80\|Z80"; then
            LLVMZ80EXE="$candidate"
            break
        fi
    done
fi
if [ -z "$LLVMZ80EXE" ]; then
    echo "ERROR: cannot find ravn/llvm-z80 clang; set LLVMZ80EXE"
    exit 1
fi
export LLVMZ80EXE

# ---- locate zcc (z88dk) ----
if [ -z "$ZCCCFG" ]; then
    # Derive from LLVMZ80EXE path: go up from bin/ to find lib/config/
    Z88DK_ROOT=$(dirname "$LLVMZ80EXE")
    Z88DK_ROOT=$(cd "$Z88DK_ROOT/.." 2>/dev/null && pwd)
    # Try parent directories
    for d in "$Z88DK_ROOT" "$(dirname "$Z88DK_ROOT")" "/Users/ravn/z80/z88dk" "/home/ravn/z80/z88dk"; do
        if [ -f "$d/lib/config/cpm.cfg" ]; then
            ZCCCFG="$d/lib/config/"
            PATH="$d/bin:$PATH"
            break
        fi
    done
fi
if [ -z "$ZCCCFG" ]; then
    echo "ERROR: cannot find z88dk; set ZCCCFG"
    exit 1
fi
export ZCCCFG
export PATH

# ---- locate NTVCM ----
if [ -z "$NTVCM" ]; then
    for candidate in \
        "/Users/ravn/z80/ntvcm/ntvcm" \
        "/home/ravn/z80/ntvcm/ntvcm" \
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
echo "  ZCCCFG     : $ZCCCFG"
echo "  NTVCM      : ${NTVCM:-not found (tests that need it will SKIP)}"
echo ""

PASS=0; FAIL=0; SKIP=0; XFAIL=0; XPASS=0

for script in "$DIR"/*.sh; do
    name=$(basename "$script")
    [ "$name" = "$SELF" ] && continue

    result=$(sh "$script" 2>&1 | tail -1)
    case "$result" in
        PASS:*|PASS\ *)
            echo "PASS  $name"
            PASS=$((PASS + 1))
            ;;
        # XFAIL: a known, documented gap that is EXPECTED to fail (e.g. a
        # deliberately-absent classic-clib function).  Ignored — not a failure.
        XFAIL:*|XFAIL\ *)
            echo "xfail $name ($result)"
            XFAIL=$((XFAIL + 1))
            ;;
        # XPASS: an xfail test that UNEXPECTEDLY succeeded — the gap closed;
        # surface it so the xfail note can be retired.  Counts as a failure.
        XPASS:*|XPASS\ *)
            echo "XPASS $name -- $result  (unexpected: gap closed, retire the xfail)"
            FAIL=$((FAIL + 1))
            ;;
        SKIP:*|SKIP\ *)
            echo "skip  $name ($result)"
            SKIP=$((SKIP + 1))
            ;;
        *)
            echo "FAIL  $name -- $result"
            FAIL=$((FAIL + 1))
            ;;
    esac
done

echo ""
echo "Results: $PASS PASS, $FAIL FAIL, $SKIP SKIP, $XFAIL XFAIL"
[ "$FAIL" -eq 0 ]
