#!/bin/sh
# Emission-level test: assert llvmz80 backend emits inline LDIR/LDDR when
# memmove/memcpy direction is statically known, and asm_memset / asm_memmove
# calls when it isn't.
#
# Companion to run_minimal.sh (behavioural test).  This file compiles
# memops_emission.c to .s and greps per-function to assert the expected
# instruction appears and the fallback-call does NOT.
#
# Runs at every optimisation level (-O0, -O2, -Os) because loop-idiom
# recognition and GlobalISel inlining decisions can differ by -O.
set -eu

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/test_env.sh"

WORK=$(mktemp -d "$TMPDIR/memops-emission.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
cd "$WORK"

PASS=0
FAIL=0

# $1 = optimisation (O0/O2/Os)
# $2 = function name (asm label without leading _)
# $3 = expected pattern (grep -E) that MUST appear in the function body
# $4 = forbidden pattern that MUST NOT appear in the function body
check_fn() {
    opt=$1
    fn=$2
    want=$3
    forbid=$4
    body=$(awk "/^_${fn}:/{flag=1; next} /^_[a-zA-Z_].*:/ && flag {exit} flag" "mo-$opt.s")
    if [ -z "$body" ]; then
        printf 'FAIL: %s -%s function body not found\n' "$fn" "$opt" >&2
        FAIL=$((FAIL + 1))
        return
    fi
    if ! printf '%s\n' "$body" | grep -qE "$want"; then
        printf 'FAIL: %s -%s missing expected %s\n--- actual:\n%s\n---\n' \
            "$fn" "$opt" "$want" "$body" >&2
        FAIL=$((FAIL + 1))
        return
    fi
    if [ -n "$forbid" ] && printf '%s\n' "$body" | grep -qE "$forbid"; then
        printf 'FAIL: %s -%s contains forbidden %s\n--- actual:\n%s\n---\n' \
            "$fn" "$opt" "$forbid" "$body" >&2
        FAIL=$((FAIL + 1))
        return
    fi
    PASS=$((PASS + 1))
}

for opt in O0 O2 Os; do
    "$ZCC" +cpm -compiler=llvmz80 "-Cg-$opt" -S \
        "$DIR/memops_emission.c" -o "mo-$opt.s" > "mo-$opt.log" 2>&1 || {
        cat "mo-$opt.log"
        exit 1
    }

    # --- Inline-LDDR: dst > src known at compile time ---
    check_fn "$opt" "emit_lddr_fixed_offset" '\<lddr\>' '\<call\>.*memmove'

    # --- Inline-LDIR: dst < src known at compile time ---
    check_fn "$opt" "emit_ldir_fixed_offset" '\<ldir\>' '\<call\>.*memmove'

    # --- Inline-LDIR: memcpy with constant size ---
    check_fn "$opt" "emit_ldir_memcpy_const" '\<ldir\>' '\<call\>.*(memcpy|asm_memcpy)'

    # --- Inline-LDIR: aggregate struct copy ---
    check_fn "$opt" "emit_ldir_aggregate_copy" '\<ldir\>' '\<call\>.*(memcpy|asm_memcpy)'

    # --- Negative control: must call asm_memmove, must NOT inline LDIR/LDDR ---
    # (Direction only knowable at runtime -- backend must defer to the
    # library's internal direction check.)
    check_fn "$opt" "emit_call_memmove_var" \
        '\<call\>.*(asm_memmove|_memmove_callee|___z80_memmove_builtin)' \
        '\<(ldir|lddr)\>'

    # --- asm_memset emission (zero-init via compound literal) ---
    # Accept both the old (___z80_memset_builtin) and native-runtime
    # (asm_memset) symbol so this test passes on both backends during
    # the transition.  Tighten to asm_memset only after upstream merge.
    check_fn "$opt" "emit_call_asm_memset_zero" \
        '\<call\>.*(asm_memset|___z80_memset_builtin)' ''

    # --- asm_memset emission (loop-idiom, 16-bit counter) ---
    # Loop-idiom recognition is an LLVM optimisation pass (-O1+), so at
    # -O0 the loop stays scalar.  Only assert idiom lowering at -O2/-Os.
    if [ "$opt" != "O0" ]; then
        check_fn "$opt" "emit_call_asm_memset_loop" \
            '\<call\>.*(asm_memset|___z80_memset_builtin)' ''

        # --- 8-bit counter loop: accept EITHER inline DJNZ (future) OR
        # memset-idiom lowering.  Today we expect idiom; future DJNZ work
        # will trigger the first alternation. ---
        check_fn "$opt" "emit_call_asm_memset_loop_u8" \
            '(\<djnz\>|\<call\>.*(asm_memset|___z80_memset_builtin))' ''
    else
        # At -O0 just confirm the function stores the fill value so a
        # totally-broken codegen is still caught.
        check_fn "$opt" "emit_call_asm_memset_loop"     ',255\>' ''
        check_fn "$opt" "emit_call_asm_memset_loop_u8"  ',68\>' ''
    fi

    printf 'OK:  memops_emission -%s (%d checks)\n' "$opt" 8
done

printf '\n== memops_emission: %d PASS, %d FAIL ==\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
