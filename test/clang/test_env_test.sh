#!/bin/sh
# Check discovery and explicit overrides without depending on installed tools.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$DIR/../../../scratch/tmp"
WORK=$(mktemp -d "$DIR/../../../scratch/tmp/test-env.XXXXXX")
WORK=$(cd "$WORK" && pwd)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/z88dk/test/clang" \
    "$WORK/llvm-z80/build-macos-asserts/bin" "$WORK/llvm-z80/build/bin" \
    "$WORK/override/bin"
printf '#!/bin/sh\necho "clang Z80 test fixture"\n' \
    > "$WORK/llvm-z80/build-macos-asserts/bin/clang"
cp "$WORK/llvm-z80/build-macos-asserts/bin/clang" "$WORK/override/bin/clang"
cp "$WORK/llvm-z80/build-macos-asserts/bin/clang" "$WORK/llvm-z80/build/bin/clang"
chmod +x "$WORK/llvm-z80/build-macos-asserts/bin/clang" \
    "$WORK/llvm-z80/build/bin/clang" "$WORK/override/bin/clang"
HELPER="$DIR/test_env.sh"

check_selection() (
    expected=$1
    DIR="$WORK/z88dk/test/clang"
    . "$HELPER"
    [ "$LLVMZ80EXE" = "$expected/bin/clang" ] && \
        [ "$LLVM_Z80_BUILD" = "$expected" ] || {
        echo "FAIL: compiler=$LLVMZ80EXE build=$LLVM_Z80_BUILD expected=$expected"
        exit 1
    }
)

unset LLVMZ80EXE LLVM_Z80_BUILD
check_selection "$WORK/llvm-z80/build-macos-asserts"
LLVM_Z80_BUILD="$WORK/override"
check_selection "$WORK/override"
unset LLVM_Z80_BUILD
LLVMZ80EXE="$WORK/override/bin/../bin/clang"
check_selection "$WORK/override"

LLVMZ80EXE="$WORK/missing-clang"
if (DIR="$WORK/z88dk/test/clang"; . "$HELPER") >"$WORK/error.log" 2>&1; then
    echo "FAIL: invalid explicit compiler was silently replaced"
    exit 1
fi
grep -qF "LLVMZ80EXE is not executable" "$WORK/error.log" || {
    cat "$WORK/error.log"
    echo "FAIL: missing explicit compiler diagnostic"
    exit 1
}
unset LLVMZ80EXE
LLVM_Z80_BUILD="$WORK/missing-build"
if (DIR="$WORK/z88dk/test/clang"; . "$HELPER") >"$WORK/error.log" 2>&1; then
    echo "FAIL: invalid explicit build was silently replaced"
    exit 1
fi
grep -qF "$WORK/missing-build/bin/clang" "$WORK/error.log" || {
    cat "$WORK/error.log"
    echo "FAIL: missing explicit build diagnostic"
    exit 1
}
echo "PASS: shared toolchain discovery and explicit overrides"
