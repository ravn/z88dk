# VERIFIED discrepancy: clang-z80 `sdcccall(0)` reverses multi-arg stack order vs SDCC

Status: **root-caused + verified, NOT filed** (awaiting user go-ahead per
`feedback_explain_before_filing`). Found 2026-08-03 while getting the z88dk
`test/suites/math` suite green under `-compiler=llvmz80`.

## Symptom
math32 `pow`/`fmod` (non-commutative, 2-arg) compute with swapped operands
under clang: `pow(2,3)` -> 9 (=3^2), `fmod(5.5,2)` -> 2 (=2 mod 5.5). 1-arg
(`sqrt`,`fabs`) and commutative 2-arg (`fmin`,`fmax`) are unaffected.

## Root cause (verified, dispositive)
clang-z80 `sdcccall(0)` (the `__smallc` convention) pushes 2+ stack arguments
in the OPPOSITE order to z88dk's `-compiler=sdcc` (real SDCC).

Differential — identical hand-written asm callee, ONLY the compiler differs:

    ; isub.asm : int isub(int a,int b) = (top-of-stack arg) - (next arg)
    SECTION code_user
    PUBLIC _isub
    _isub:
      pop hl        ; return address
      pop de        ; X = arg at top of stack (lowest address)
      pop bc        ; Y = next arg
      push bc
      push de
      push hl
      ex de,hl      ; hl = X
      or a
      sbc hl,bc     ; hl = X - Y
      ret

    // isub.c
    extern int isub(int,int) __attribute__((sdcccall(0)));   // clang
    // (or) extern int isub(int,int) __smallc;               // sdcc build
    // main: printf("%d\n", isub(1000,7));

Results (z88dk-ticks -b msx):
  -compiler=sdcc     : isub(1000,7) = -993   -> 2nd C arg (7) on top of stack
  -compiler=llvmz80  : isub(1000,7) = +993   -> 1st C arg (1000) on top

Exact ±993 (not garbage) => clang and SDCC place opposite C args at the top of
the stack for sdcccall(0). Independently corroborated by the real math32 cores
(`pow_callee`/`fmod_callee` only give correct answers when args are hand-
swapped).

## Build/repro env
    export PATH=/Users/ravn/z80/z88dk/bin:$PATH
    export ZCCCFG=/Users/ravn/z80/z88dk/lib/config
    export LLVMZ80EXE=/Users/ravn/z80/llvm-z80/build-macos/bin/clang
    zcc +test -compiler=llvmz80 -o isub.bin isub.c isub.asm -create-app
    zcc +test -compiler=sdcc    -o isub.bin isub.c isub.asm -create-app   # __smallc decl
    z88dk-ticks -w 30 -b msx isub.bin

## Nuance to confirm before filing (do NOT overclaim)
- clang's sdcccall(0) DOES match z88dk's *hand-written* classic clib asm
  (str*/mem* work under clang), and only diverges from *SDCC-compiled*
  sdcccall(0) code (the math32 `cm32_sdcc_*` cores are SDCC-built).
- Which order is spec-correct per the SDCC manual (`--sdcccall 0`) is
  UNVERIFIED. Before filing, confirm against SDCC docs which side is
  authoritative; the fix target (clang backend vs a math32 bridge) depends on
  that.

## Why no autopilot workaround
A header macro swap (`#define pow(a,b) pow_callee(b,a)`) or an arg-reordering
bridge would mask a compiler/ABI bug (violates `feedback_file_bugs_not_fixes`)
and would double-swap once the backend is corrected. So pow/fmod stay BLOCKED.

## Separable, safe part (ready, not landed)
sqrt/fmin/fmax/fabs fail for a DIFFERENT, header-only reason: under clang
`__STDC_ABI_ONLY` skips the `#ifndef __STDC_ABI_ONLY` fastcall/callee routing in
`include/math/math_math32.h`, leaving the plain decls with no convention
attribute (clang uses sdcccall(1), cores are sdcccall(0)). Marking those plain
decls `__smallc` under `__LLVMZ80` fixes all four (verified: sqrt(4)~2 within
EPSILON, fabs(-4)=4, fmin(4,2)=2, fmax(4,2)=4). Order-immune (1-arg /
commutative), so unaffected by the sdcccall(0) bug above.
