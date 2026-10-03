#!/bin/sh

LLVMZ80_TEST_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
Z88DK_ROOT=$(CDPATH= cd -- "$LLVMZ80_TEST_DIR/../.." && pwd)
WORKSPACE_ROOT=$(CDPATH= cd -- "$Z88DK_ROOT/.." && pwd)

if [ -z "${ZCC+x}" ]; then
    if [ -x "$Z88DK_ROOT/bin/zcc" ]; then
        ZCC="$Z88DK_ROOT/bin/zcc"
    else
        ZCC=zcc
    fi
fi
ZCCCFG=${ZCCCFG:-"$Z88DK_ROOT/lib/config"}
Z80_TEST_TMPDIR=${Z80_TEST_TMPDIR:-"$WORKSPACE_ROOT/scratch/tmp"}
LLVMZ80EXE=${LLVMZ80EXE:-llvmz80-clang}
NTVCM=${NTVCM:-ntvcm}

for candidate in \
    "$WORKSPACE_ROOT/llvm-z80/build-macos-asserts/bin/clang" \
    "$WORKSPACE_ROOT/llvm-z80/build-macos/bin/clang"
do
    if [ "$LLVMZ80EXE" = llvmz80-clang ] && [ -x "$candidate" ]; then
        LLVMZ80EXE=$candidate
        break
    fi
done

if [ "$NTVCM" = ntvcm ] && [ -x "$WORKSPACE_ROOT/ntvcm/ntvcm" ]; then
    NTVCM="$WORKSPACE_ROOT/ntvcm/ntvcm"
fi

mkdir -p "$Z80_TEST_TMPDIR"
PATH="$Z88DK_ROOT/bin:$PATH"
TMPDIR="$Z80_TEST_TMPDIR"
export PATH TMPDIR ZCC ZCCCFG Z80_TEST_TMPDIR LLVMZ80EXE NTVCM
