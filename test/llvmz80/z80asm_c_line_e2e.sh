#!/bin/sh
# End-to-end test: C -> zcc +cpm -compiler=llvmz80 -Cg-g
# -> z80asm -debug -> .map with __C_LINE_* symbols, then ntvcm execution.
#
# Run by test/llvmz80/run_all.sh, not LLVM's self-contained lit suite.
set -eu
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"

for tool in z88dk-z80asm "$ZCC" "$NTVCM" "$LLVMZ80EXE"; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "SKIP: required tool not found: $tool"
    exit 0
  }
done

WORK=$(mktemp -d "$Z80_TEST_TMPDIR/llvmz80-c-line.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"
cd "$WORK"

cat > "$WORK/hello.c" << 'EOF'
#include <stdio.h>

int main(void) {
    printf("Hello, World!\n");
    return 0;
}
EOF

# Compile: C -> CP/M .com binary + .map with C_LINE debug symbols.
# -Cg-g passes -g to clang so DebugLoc is available for C_LINE emission.
TMPDIR="$WORK/tmp" "$ZCC" +cpm -compiler=llvmz80 -Cg-g -create-app \
  -o "$WORK/hello" -debug -m "$WORK/hello.c"

# Run under CP/M emulator and capture output.
OUTPUT=$(TMPDIR="$WORK/tmp" "$NTVCM" "$WORK/HELLO.COM")
echo "ntvcm output: $OUTPUT"

echo "$OUTPUT" | grep -q "Hello, World!" || {
  echo "FAIL: expected 'Hello, World!' in output, got: $OUTPUT"
  exit 1
}

# Map file must contain __C_LINE_ entries for hello.c.
MAP="$WORK/hello.map"

grep "__C_LINE_" "$MAP" | grep -q "hello.c" || {
  echo "FAIL: no __C_LINE_ entries referencing hello.c in map"
  grep "__C_LINE_" "$MAP" | head -5
  exit 1
}

# printf call is on line 4, return on line 5 — both must appear.
grep -q "__C_LINE_4_" "$MAP" || {
  echo "FAIL: no C_LINE entry for line 4 (printf)"
  grep "__C_LINE_" "$MAP" | head -10
  exit 1
}

grep -q "__C_LINE_5_" "$MAP" || {
  echo "FAIL: no C_LINE entry for line 5 (return)"
  grep "__C_LINE_" "$MAP" | head -10
  exit 1
}

# Show the debug address map for hello.c lines.
echo "PASS: C_LINE address map for hello.c:"
grep "__C_LINE_" "$MAP" | grep "hello.c"
