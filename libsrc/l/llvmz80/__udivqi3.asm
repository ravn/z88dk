
; ravn/llvm-z80 compiler-rt 8-bit unsigned division/remainder helpers.
;
; Under -Os/-Oz the llvm-z80 backend replaces the inline 8-bit restoring
; divide with a call to the compiler-rt names __udivqi3 / __umodqi3 to save a
; few bytes (Z80InstructionSelector.cpp selectUDivMod8, hasOptSize path).
; Signed 8-bit divide is lowered to negate + unsigned divide, so it also routes
; through these two symbols.  z88dk ships the optimized core
; l_fast_divu_8_8x8; these bridges adapt the register ABI.
;
; ---- llvm-z80 runtime ABI (Z80InstructionSelector.cpp:505) ----
;   enter : A = dividend, E = divisor
;   exit  : A = result (quotient for __udivqi3, remainder for __umodqi3)
;
; ---- core ABI (libsrc/math/integer/fast/l_fast_divu_8_8x8.asm) ----
;   enter : L = dividend, E = divisor
;   exit  : L = quotient, E = remainder (H=0, D=0, A=0, carry reset)
;   uses  : af, b, de, hl
;
; Worked example a=200, b=7:
;   __udivqi3: A=200 -> L=200; core -> L=28 (quotient), E=4 (remainder);
;              return A=L=28.
;   __umodqi3: A=200 -> L=200; core -> E=4; return A=E=4.

INCLUDE "config_private.inc"

SECTION code_clib
SECTION code_l_clang

PUBLIC ___udivqi3
PUBLIC ___umodqi3

EXTERN l_fast_divu_8_8x8

___udivqi3:
   ld l,a                       ; L = dividend (E already = divisor)
   call l_fast_divu_8_8x8       ; L = quotient, E = remainder
   ld a,l                       ; A = quotient
   ret

___umodqi3:
   ld l,a                       ; L = dividend
   call l_fast_divu_8_8x8       ; E = remainder
   ld a,e                       ; A = remainder
   ret
