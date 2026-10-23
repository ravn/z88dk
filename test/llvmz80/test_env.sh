#!/bin/sh

LLVMZ80_TEST_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
Z88DK_ROOT=$(CDPATH= cd -- "$LLVMZ80_TEST_DIR/../.." && pwd)
ZCC=${ZCC:-"$Z88DK_ROOT/bin/zcc"}
ZCCCFG=${ZCCCFG:-"$Z88DK_ROOT/lib/config"}
# z88dk-ticks is the CP/M emulator shipped with z88dk; -no-cycles suppresses
# its end-of-run cycle count so the program's stdout is the only output.
# This makes the test suite self-contained -- no external CP/M emulator.
TICKS=${TICKS:-"$Z88DK_ROOT/bin/z88dk-ticks"}
: "${LLVMZ80EXE:?Set LLVMZ80EXE to llvm-z80 clang}"
: "${TMPDIR:?Set TMPDIR to a writable temporary directory}"
Z80_TEST_TMPDIR=${Z80_TEST_TMPDIR:-"$TMPDIR"}
export ZCC ZCCCFG LLVMZ80EXE Z80_TEST_TMPDIR TICKS
