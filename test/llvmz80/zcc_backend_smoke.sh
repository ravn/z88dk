#!/bin/sh
# Verifies zcc -compiler=llvmz80 selects the z80-unknown-none-z88dk triple,
# compiles plain C with __smallc (left-to-right push) and variadic with
# sdcccall(0) (right-to-left push).
set -eu

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"
ROOT=$(CDPATH= cd -- "$DIR/../.." && pwd)
WORKSPACE=$(CDPATH= cd -- "$ROOT/.." && pwd)
TMP_ROOT=${Z80_TEST_TMPDIR:-"$WORKSPACE/scratch/tmp"}
ZCC=${ZCC:-zcc}
command -v "$ZCC" >/dev/null 2>&1 || {
    echo "SKIP: zcc not found"
    exit 0
}
command -v "$LLVMZ80EXE" >/dev/null 2>&1 || {
    echo "SKIP: llvmz80-clang not found"
    exit 0
}

mkdir -p "$TMP_ROOT"
WORK=$(mktemp -d "$TMP_ROOT/zcc-backend.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir "$WORK/tmp"

cat > "$WORK/main.c" <<'EOF'
unsigned sum(unsigned a, unsigned b) { return a + b; }
int main(void) { return 0; }
EOF

# 1. Verify compilation and object file production.
cd "$WORK"
if ! TMPDIR="$WORK/tmp" LLVMZ80EXE="$LLVMZ80EXE" \
        "$ZCC" +cpm -compiler=llvmz80 -v -c "$WORK/main.c" \
        -o "$WORK/main.o" >"$WORK/build.log" 2>&1; then
    cat "$WORK/build.log"
    echo "FAIL: zcc rejected or failed to compile with llvmz80"
    exit 1
fi

[ -f "$WORK/main.o" ] || {
    cat "$WORK/build.log"
    echo "FAIL: zcc did not produce an object file"
    exit 1
}

COMPILE_LINE=$(grep -F -- '-S ' "$WORK/build.log" | grep -F "$LLVMZ80EXE" | head -1 || true)
case "$COMPILE_LINE" in
    *--target=z80-unknown-none-z88dk*) ;;
    *)
        cat "$WORK/build.log"
        echo "FAIL: zcc did not invoke the native z88dk target triple"
        exit 1
        ;;
esac

# 2. Verify IR: plain C has no calling-convention annotation in z88dk (__smallc = CC_C).
if ! "$ZCC" +cpm -compiler=llvmz80 -a -Cg-emit-llvm \
        "$WORK/main.c" -o "$WORK/default.asm" >"$WORK/default.log" 2>&1; then
    cat "$WORK/default.log"
    echo "FAIL: cannot inspect target function ABI"
    exit 1
fi
DEFINITION=$(grep 'define .*@sum(' "$WORK/default.asm" || true)
case "$DEFINITION" in
    *z80_sdcccall0*|*z80_sdcccall1*|*cc2*)
        echo "FAIL: plain C function should use __smallc (no IR annotation): $DEFINITION"
        exit 1
        ;;
    *@sum*)
        ;;
    *)
        echo "FAIL: sum function definition not found in IR"
        exit 1
        ;;
esac

# 3. Verify push order via asm:
#    plain C = __smallc = left-to-right (first arg pushed first)
#    variadic = sdcccall(0) = right-to-left (last arg pushed first)
cat > "$WORK/pushorder.c" <<'EOF'
extern unsigned __attribute__((noinline)) plain_fn(unsigned a, unsigned b);
extern unsigned __attribute__((noinline)) vari_fn(unsigned a, ...);
void push_order_caller(void) { plain_fn(1, 2); vari_fn(3, 4, 5); }
EOF

if ! "$ZCC" +cpm -compiler=llvmz80 -Cg-O1 -a \
        "$WORK/pushorder.c" -o "$WORK/pushorder.asm" >"$WORK/pushorder.log" 2>&1; then
    cat "$WORK/pushorder.log"
    echo "FAIL: could not compile push order test"
    exit 1
fi

# Extract line numbers for key events and compare ordering.
# plain_fn(1,2): __smallc pushes left-to-right → ld hl,1 appears before ld hl,2
ln_plain_1=$(grep -n 'hl,1' "$WORK/pushorder.asm" | head -1 | cut -d: -f1)
ln_plain_2=$(grep -n 'hl,2' "$WORK/pushorder.asm" | head -1 | cut -d: -f1)
ln_call_plain=$(grep -n '_plain_fn' "$WORK/pushorder.asm" | grep 'call' | head -1 | cut -d: -f1)

# vari_fn(3,4,5): sdcccall(0) pushes right-to-left → ld hl,5 appears before ld hl,3
ln_vari_5=$(grep -n 'hl,5' "$WORK/pushorder.asm" | head -1 | cut -d: -f1)
ln_vari_3=$(grep -n 'hl,3' "$WORK/pushorder.asm" | head -1 | cut -d: -f1)
ln_call_vari=$(grep -n '_vari_fn' "$WORK/pushorder.asm" | grep 'call' | head -1 | cut -d: -f1)

if [ -z "$ln_plain_1" ] || [ -z "$ln_plain_2" ] || [ -z "$ln_call_plain" ] || \
   [ -z "$ln_vari_5" ] || [ -z "$ln_vari_3" ] || [ -z "$ln_call_vari" ]; then
    echo "FAIL: expected asm patterns not found in push order test"
    cat "$WORK/pushorder.asm"
    exit 1
fi

# __smallc: arg 1 loaded before arg 2 (both before the call)
if [ "$ln_plain_1" -ge "$ln_plain_2" ] || [ "$ln_plain_2" -ge "$ln_call_plain" ]; then
    echo "FAIL: plain_fn should push arg 1 before arg 2 (__smallc left-to-right)"
    cat "$WORK/pushorder.asm"
    exit 1
fi

# sdcccall(0): arg 5 loaded before arg 3 (both before the call)
if [ "$ln_vari_5" -ge "$ln_vari_3" ] || [ "$ln_vari_3" -ge "$ln_call_vari" ]; then
    echo "FAIL: vari_fn should push arg 5 before arg 3 (sdcccall0 right-to-left)"
    cat "$WORK/pushorder.asm"
    exit 1
fi

echo "PASS: zcc compiles llvmz80 C with the native z88dk target triple"
