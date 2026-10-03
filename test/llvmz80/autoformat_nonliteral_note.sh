#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
ROOT=$(CDPATH= cd -- "$DIR/../.." && pwd)
WORKSPACE=$(CDPATH= cd -- "$ROOT/.." && pwd)
TMP_ROOT=${Z80_TEST_TMPDIR:-"$WORKSPACE/scratch/tmp"}
command -v "$ZCC" >/dev/null 2>&1 || {
    echo "SKIP: zcc not found"
    exit 0
}

mkdir -p "$TMP_ROOT"
WORK=$(mktemp -d "$TMP_ROOT/autoformat-note.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"
cd "$WORK"

build_log() {
    TMPDIR="$WORK/tmp" "$ZCC" +cpm -compiler=llvmz80 -Cg-O2 -c \
        -o "$WORK/out.o" "$1" 2>&1
}

fail() {
    echo "FAIL: $1"
    exit 1
}

cat > mixed.c <<'EOF'
#include <stdio.h>
int main(int argc, char **argv) {
    const char *fmt = (argc > 1) ? argv[1] : "%x";
    printf("count=%d\n", argc);
    printf(fmt, argc);
    return 0;
}
EOF
LOG=$(build_log "$WORK/mixed.c") || {
    echo "$LOG"
    fail "mixed-format compile failed"
}
echo "$LOG" | grep -q "not a string literal" || fail "missing nonliteral note"
echo "$LOG" | grep "not a string literal" | grep -q "mixed.c:5" \
    || fail "nonliteral note does not point at the call site"

cat > literal.c <<'EOF'
#include <stdio.h>
int main(void) { printf("a=%d b=%s\n", 1, "x"); return 0; }
EOF
LOG=$(build_log "$WORK/literal.c")
echo "$LOG" | grep -q "not a string literal" && fail "literal-only TU emitted a note"

cat > dynamic.c <<'EOF'
#include <stdio.h>
int main(int argc, char **argv) { printf(argv[0], argc); return 0; }
EOF
LOG=$(build_log "$WORK/dynamic.c")
echo "$LOG" | grep -q "not a string literal" && fail "dynamic-only TU emitted a note"

cat > explicit.c <<'EOF'
#include <stdio.h>
#pragma printf = "%s %f %d %x"
int main(int argc, char **argv) {
    const char *fmt = (argc > 1) ? argv[1] : "%x";
    printf("count=%d\n", argc);
    printf(fmt, argc);
    return 0;
}
EOF
LOG=$(build_log "$WORK/explicit.c")
echo "$LOG" | grep -q "not a string literal" && fail "explicit pragma emitted a note"

echo "PASS: upstream autoformat warns only for mixed literal/runtime formats"
