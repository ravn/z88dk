
; ravn/llvm-z80 compiler-rt 32-bit integer division/remainder helpers.
;
; The llvm-z80 backend emits calls to the compiler-rt names __divsi3 /
; __modsi3 / __udivsi3 / __umodsi3 for 32-bit `long` divide/modulo.  z88dk
; already ships the optimized cores l_div[su]_32_32x32; these thin bridges
; adapt the llvm-z80 runtime ABI to the core ABI and share the single core.
;
; ---- llvm-z80 runtime ABI (verified by disassembling `long add2(long a,long b)
;      { return a+b; }` and `long dv(long,long){return a/b;}` under
;      `zcc +cpm -compiler=llvmz80 -O2`) ----
;   32-bit values live in registers as HL:DE with HL = HIGH word, DE = LOW word
;   (this is the OPPOSITE half-order of the z88dk core's DE:HL layout).
;   enter: HL:DE     = arg1 = dividend a   (HL=bits16..31, DE=bits0..15)
;          stack     = ret, b_lo, b_hi     = arg2 = divisor b (little-endian)
;          IX        = caller frame pointer, MUST be preserved
;   exit : HL:DE     = result (quotient for div, remainder for mod)
;          caller cleans the 2 pushed divisor words (`pop af; pop af`), so this
;          routine must NOT consume them off the stack.
;
; ---- core ABI (libsrc/math/integer/l_divs_32_32x32.asm) ----
;   compute: dehl  = dehl' / dehl,  dehl' = dehl' % dehl
;   core 32-bit layout is DE:HL with DE = HIGH word, HL = LOW word.
;   dividend in the ALTERNATE bank dehl', divisor in the MAIN bank dehl;
;   quotient returned in main dehl, remainder in alternate dehl'.
;   alters: af, bc, de, hl, bc', de', hl', ix.
;
; The llvm-z80 HL:DE layout is the byte-swap of the core's DE:HL layout, so a
; single `ex de,hl` converts between them (applied to the dividend on the way
; in and to the result on the way out).
;
; Worked example a=1000000 (0x000F4240), b=7:
;   entry HL=0x000F (hi), DE=0x4240 (lo). `ex de,hl` -> DE=0x000F,HL=0x4240
;   (core layout). `exx` -> dehl' = dividend. Divisor b_lo=0x0007 at (ix+4),
;   b_hi=0x0000 at (ix+6) -> main HL=0x0007,DE=0x0000 = core divisor 7.
;   Core -> main dehl = 142857 (0x0002:0x2E49), alt dehl' = 1 (remainder).
;   `ex de,hl` -> HL=0x0002,DE=0x2E49 = llvm-z80 quotient 142857.

INCLUDE "config_private.inc"

SECTION code_clib
SECTION code_l_clang

PUBLIC ___divsi3
PUBLIC ___modsi3
PUBLIC ___udivsi3
PUBLIC ___umodsi3

EXTERN l_divs_32_32x32
EXTERN l_divu_32_32x32

; ---- signed ----

___divsi3:
   ex de,hl                     ; llvm-z80 HL:DE -> core DE:HL (dividend a)
   exx                          ; dehl' = dividend a (into alternate bank)
   push ix                      ; save caller frame ptr (core trashes IX)
   ld ix,0
   add ix,sp                    ; IX -> [saved IX]; +2 ret, +4 b_lo, +6 b_hi
   ld l,(ix+4)
   ld h,(ix+5)                  ; HL = b_lo (core low word)
   ld e,(ix+6)
   ld d,(ix+7)                  ; main dehl = divisor b (not popped: caller owns)
   call l_divs_32_32x32         ; main dehl = quotient, dehl' = remainder
   pop ix                       ; restore caller frame ptr
   ex de,hl                     ; core DE:HL -> llvm-z80 HL:DE (quotient)
   ret

___modsi3:
   ex de,hl                     ; dividend a -> core layout
   exx                          ; dehl' = dividend a
   push ix
   ld ix,0
   add ix,sp
   ld l,(ix+4)
   ld h,(ix+5)
   ld e,(ix+6)
   ld d,(ix+7)                  ; main dehl = divisor b
   call l_divs_32_32x32         ; dehl' = remainder
   pop ix
   exx                          ; active dehl = remainder (core layout)
   ex de,hl                     ; -> llvm-z80 HL:DE
   ret

; ---- unsigned ----

___udivsi3:
   ex de,hl
   exx
   push ix
   ld ix,0
   add ix,sp
   ld l,(ix+4)
   ld h,(ix+5)
   ld e,(ix+6)
   ld d,(ix+7)
   call l_divu_32_32x32
   pop ix
   ex de,hl
   ret

___umodsi3:
   ex de,hl
   exx
   push ix
   ld ix,0
   add ix,sp
   ld l,(ix+4)
   ld h,(ix+5)
   ld e,(ix+6)
   ld d,(ix+7)
   call l_divu_32_32x32
   pop ix
   exx
   ex de,hl
   ret
