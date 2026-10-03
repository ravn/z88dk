#!/bin/sh
# Shared environment resolution for test/clang/ and test/llvmz80/ scripts.
# Discovers repo-relative paths for zcc, ZCCCFG, LLVMZ80EXE, LLVM_Z80_BUILD and NTVCM so
# tests can be run standalone without requiring manual PATH or env setup.

_ENV_DIR="${DIR:-$(cd "$(dirname "$0")" && pwd)}"
_REPO_ROOT=$(cd "$_ENV_DIR/../.." 2>/dev/null && pwd)
_WORKSPACE_ROOT=$(cd "$_REPO_ROOT/.." 2>/dev/null && pwd)

# 1. zcc on PATH
if ! command -v zcc >/dev/null 2>&1; then
    if [ -x "$_REPO_ROOT/bin/zcc" ]; then
        PATH="$_REPO_ROOT/bin:$PATH"
        export PATH
    fi
fi

# 2. ZCCCFG
if [ -z "$ZCCCFG" ] && [ -d "$_REPO_ROOT/lib/config" ]; then
    export ZCCCFG="$_REPO_ROOT/lib/config"
fi

# 3. LLVMZ80EXE
if [ -z "$LLVMZ80EXE" ] && [ -n "$LLVM_Z80_BUILD" ]; then
    LLVMZ80EXE="$LLVM_Z80_BUILD/bin/clang"
fi
if [ -n "$LLVMZ80EXE" ] && [ ! -x "$LLVMZ80EXE" ]; then
    echo "ERROR: LLVMZ80EXE is not executable: $LLVMZ80EXE" >&2
    return 1
fi
if [ -z "$LLVMZ80EXE" ]; then
    for _cand in \
        "$_WORKSPACE_ROOT/llvm-z80/build-macos-asserts/bin/clang" \
        "$_REPO_ROOT/bin/llvmz80-clang" \
        "$_WORKSPACE_ROOT/llvm-z80/build-macos/bin/clang" \
        "$_WORKSPACE_ROOT/llvm-z80/build/bin/clang" \
        "$(command -v llvmz80-clang 2>/dev/null)" \
        "$(command -v clang 2>/dev/null)"; do
        if [ -n "$_cand" ] && [ -x "$_cand" ] && "$_cand" --version 2>&1 | grep -q "z80\|Z80"; then
            export LLVMZ80EXE="$_cand"
            break
        fi
    done
fi
if [ -n "$LLVMZ80EXE" ]; then
    LLVMZ80EXE=$(cd "$(dirname "$LLVMZ80EXE")" && pwd)/$(basename "$LLVMZ80EXE")
    LLVM_Z80_BUILD=${LLVM_Z80_BUILD:-$(cd "$(dirname "$LLVMZ80EXE")/.." && pwd)}
    export LLVMZ80EXE LLVM_Z80_BUILD
fi

# 4. NTVCM emulator
if [ -z "$NTVCM" ] || ! command -v "$NTVCM" >/dev/null 2>&1; then
    for _cand in \
        "$_WORKSPACE_ROOT/ntvcm/ntvcm" \
        "$_WORKSPACE_ROOT/../ntvcm/ntvcm" \
        "$(command -v ntvcm 2>/dev/null)"; do
        if [ -n "$_cand" ] && [ -x "$_cand" ]; then
            export NTVCM="$_cand"
            break
        fi
    done
fi
