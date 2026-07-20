; compiler-rt-named 16-bit integer helpers for ravn/llvm-z80 clang.
;
; WHY THIS FILE EXISTS
;   ravn/llvm-z80's Z80 backend emits standard LLVM libcall (libgcc/
;   compiler-rt) names for the integer runtime ops it cannot inline:
;   __divhi3 / __modhi3 / __udivhi3 / __umodhi3 / __mulhi3 (HImode == 16-bit;
;   hard-coded in Z80InstructionSelector.cpp).  z88dk's own l/clang runtime
;   instead shipped SDCC-style wrapper names (__sdivs, __srems, __smulu, ...),
;   so NONE of the compiler-rt names resolved -- e.g. `e.c: undefined symbol:
;   ___divhi3` the moment a program did a 16-bit divide.  These wrappers close
;   that gap by exporting the names the compiler actually calls.
;
; ABI (verified against this clang, 2026-07-10, by disassembling a real call
; site in divtest.c and cross-checking `keep(a,b){opaque();return a+b;}`):
;   * arguments:   arg1 in HL, arg2 in DE.
;   * RETURN VALUE IN DE  (not HL!).  At the call site clang does
;     `ld hl,(a); call ___divhi3; ld (result),de` -- it reads the result out
;     of DE.  `keep` likewise ends `add hl,de; ex de,hl; ret`, returning in DE.
;   * no callee-saved general registers: `keep` spills both HL (stack) and DE
;     (bss) across an opaque call, so HL/DE/BC/AF are all caller-saved.  IX/IY
;     are reserved and the cores never touch them.
;
; The z88dk small integer cores (selected here via __CLIB_OPT_IMATH=0) take
; exactly (HL=arg1, DE=arg2) already, but return the PRIMARY result in HL:
;   l_divs_16_16x16 :  hl = quotient , de = remainder   (signed)
;   l_divu_16_16x16 :  hl = quotient , de = remainder   (unsigned)
;   l_mulu_16_16x16 :  hl = product                     (low 16 bits)
; Since clang wants the result in DE, the quotient/product wrappers move HL->DE
; with `ex de,hl`; the modulo wrappers need no fixup because the remainder is
; already in DE, so they tail-call.  (Low-16 multiply is sign-agnostic, so the
; unsigned mul core serves __mulhi3.)
;
; Worked example (divtest.c, a=4200 in HL, b=7 in DE):
;   __divhi3 -> core: hl=600 (quot), de=0 (rem); ex de,hl -> DE=600  => 4200/7=600
;   __modhi3 -> core: hl=600, de=0;              (no swap)   DE=0     => 4200%7=0

SECTION code_l_clang

PUBLIC ___divhi3
PUBLIC ___udivhi3
PUBLIC ___mulhi3
PUBLIC ___umulhi3
PUBLIC ___modhi3
PUBLIC ___umodhi3

; -Os/-Oz emits the plain names above; any non-size opt level (zcc maps every
; non-`--opt-code-size` build to clang `-O3`, see src/zcc/zcc.c) makes the
; backend rename the div/mod libcalls to the "_fast" repeated-subtraction
; variants (selectDivModRuntimeName in Z80InstructionSelector.cpp).  The ABI is
; identical -- only the symbol name changes -- so the _fast entries are plain
; aliases of the cores below (z88dk has no bounded fast core; the shared
; l_div[su]_16_16x16 gives the same result).  Mul has no _fast variant.
PUBLIC ___divhi3_fast
PUBLIC ___udivhi3_fast
PUBLIC ___modhi3_fast
PUBLIC ___umodhi3_fast

EXTERN l_divs_16_16x16
EXTERN l_divu_16_16x16
EXTERN l_mulu_16_16x16

; int __divhi3(int a, int b)  ->  a / b  (signed), result in DE
___divhi3:
___divhi3_fast:
   call l_divs_16_16x16     ; hl = quotient, de = remainder
   ex de,hl                 ; DE = quotient (clang's return register)
   ret

; unsigned __udivhi3(unsigned a, unsigned b)  ->  a / b, result in DE
___udivhi3:
___udivhi3_fast:
   call l_divu_16_16x16     ; hl = quotient, de = remainder
   ex de,hl                 ; DE = quotient
   ret

; int __mulhi3(int a, int b)  ->  a * b  (low 16 bits), result in DE
; unsigned __umulhi3 aliases it: the low 16 bits of a product are sign-agnostic.
___mulhi3:
___umulhi3:
   call l_mulu_16_16x16     ; hl = product
   ex de,hl                 ; DE = product
   ret

; int __modhi3(int a, int b)  ->  a % b  (signed), result in DE
___modhi3:
___modhi3_fast:
   jp l_divs_16_16x16       ; de = remainder already -> tail-call

; unsigned __umodhi3(unsigned a, unsigned b)  ->  a % b, result in DE
___umodhi3:
___umodhi3_fast:
   jp l_divu_16_16x16       ; de = remainder already -> tail-call
