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

# ---- select the C library the suite builds against ----
# TEST_CLIB picks which z88dk clib every test links.  The same testcases run
# unchanged against each; each test appends $ZCC_CLIB to its `zcc` line.
#   classic   (default) -> the classic clib (-clib=default), the supported path
#   newlib_iy           -> newlib via -compiler=llvmz80 (SANCTIONED clang route,
#                          Phase C): clang -E preprocesses _DEVELOPMENT headers
#                          with -D__LLVMZ80, no z88dk-ucpp -D__SDCC choke
#   newlib_ix           -> same, IX/IY free marker (links the same sdcc_ix lib)
#   sdcc_iy / sdcc_ix   -> UNSUPPORTED override: -clib=sdcc_iy -compiler=llvmz80
#                          (the sdcc CLIB line forces -compiler=sdcc, so the
#                          ucpp -D__SDCC pass runs and __smallc/__attribute__
#                          sources cannot compile).  Kept for A/B only.
# See tasks/plan-newlib-llvmz80-support-2026-07-22.md.  Tests that are specific
# to the classic clib self-SKIP when TEST_CLIB is a newlib variant (they read
# $TEST_CLIB).
TEST_CLIB=${TEST_CLIB:-classic}
case "$TEST_CLIB" in
    classic)    ZCC_CLIB="" ;;
    newlib_iy)  ZCC_CLIB="-clib=newlib_iy" ;;
    newlib_ix)  ZCC_CLIB="-clib=newlib_ix" ;;
    sdcc_iy)    ZCC_CLIB="-clib=sdcc_iy" ;;
    sdcc_ix)    ZCC_CLIB="-clib=sdcc_ix" ;;
    *) echo "ERROR: unknown TEST_CLIB=$TEST_CLIB (classic|newlib_iy|newlib_ix|sdcc_iy|sdcc_ix)"; exit 1 ;;
esac
export TEST_CLIB ZCC_CLIB

echo "=== z88dk llvmz80 integration tests ==="
echo "  LLVMZ80EXE : $LLVMZ80EXE"
echo "  ZCCCFG     : $ZCCCFG"
echo "  NTVCM      : ${NTVCM:-not found (tests that need it will SKIP)}"
echo "  TEST_CLIB  : $TEST_CLIB ${ZCC_CLIB:+($ZCC_CLIB)}"
echo ""

PASS=0; FAIL=0; SKIP=0; XFAIL=0; XPASS=0

# Tests that do not apply to the newlib path (classic-specific behaviour) or hit
# a known, still-unfixed newlib gap.  Skipped only when TEST_CLIB is a newlib
# variant, with a reason, so the newlib run stays green while the gaps stay
# visible.  Fix phases are in tasks/plan-newlib-llvmz80-support-2026-07-22.md.
newlib_skip_reason() {
    # Genuine gaps that remain on the SANCTIONED newlib route (newlib_iy/_ix,
    # -compiler=llvmz80) after Phase C landed the compiler.h __LLVMZ80 mapping.
    case "$1" in
        runtime_file.sh)        echo "newlib disk FILE* UNSUPPORTED: asm_target_open hook unimplemented tree-wide (newlib 'last mile', z88dk/z88dk#1426); use classic clib for CP/M files -- ravn/z88dk #34 (wontfix)"; return 0 ;;
        # (The clang integer-helper libcalls __mulhi3/__divsi3/__divmodsi4/...
        # are now provided on the newlib route by llvmz80_imath.lib -- see
        # libsrc/l/llvmz80/newlib/ -- so runtime_qsort/intdiv/long PASS.
        #  runtime_printf_ieee now PASSES on newlib too: the __LLVMZ80_IEEE_PRINTF
        #  route is wired into the newlib _DEVELOPMENT stdio.h + the
        #  llvmz80_printf_newlib.lib shim -- ravn/z88dk #35.)
    esac
    # The UNSUPPORTED sdcc_iy/sdcc_ix override forces -compiler=sdcc, so a
    # z88dk-ucpp -D__SDCC pass runs first and chokes on source-level __smallc /
    # __attribute__((...)); those sources cannot even compile there.  Skip the
    # extra source-feature tests on that route only (they PASS on newlib_iy).
    case "$TEST_CLIB" in
        sdcc_iy|sdcc_ix)
            case "$1" in
                runtime_qsort.sh)   echo "sdcc_iy override: __smallc rejected by ucpp -D__SDCC pass"; return 0 ;;
                runtime_intdiv.sh)  echo "sdcc_iy override: __attribute__ rejected by ucpp -D__SDCC pass"; return 0 ;;
                runtime_attr.sh)    echo "sdcc_iy override: __attribute__ rejected by ucpp -D__SDCC pass"; return 0 ;;
                nontrivial_demo.sh) echo "sdcc_iy override: compiler-selection ICE on the ucpp path"; return 0 ;;
                runtime_stdmisc.sh) echo "sdcc_iy override: runtime output mismatch on the ucpp path"; return 0 ;;
                runtime_strerror.sh)echo "sdcc_iy override: strerror differs on the ucpp path"; return 0 ;;
                runtime_long.sh)    return 1 ;;  # passes on sdcc_iy (ucpp __SDCC routes long math)
            esac ;;
    esac
    return 1
}

for script in "$DIR"/*.sh; do
    name=$(basename "$script")
    # Skip harness scripts, not just this file: run_matrix.sh calls run_all.sh,
    # so treating it as a test would recurse infinitely (a fork bomb).
    case "$name" in
        "$SELF"|run_all.sh|run_matrix.sh) continue ;;
    esac

    if [ "$TEST_CLIB" != "classic" ]; then
        if reason=$(newlib_skip_reason "$name"); then
            echo "skip  $name (newlib: $reason)"
            SKIP=$((SKIP + 1))
            continue
        fi
    fi

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
