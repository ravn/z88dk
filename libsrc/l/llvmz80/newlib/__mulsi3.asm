
; ravn/llvm-z80 compiler-rt 32-bit integer MULTIPLY helper for the newlib route.
;
; NEWLIB-ONLY (no classic counterpart yet): the llvm-z80 backend emits __mulsi3
; for 32-bit `long` multiply at every opt level, but neither the classic nor the
; newlib clib provided it -- `long * long` failed to link on BOTH paths
; (undefined symbol ___mulsi3).  This closes it for the newlib route by adapting
; the same register/bank dance as ../__divsi3.asm to the bundled newlib core
; l_mulu_32_32x32.  (The classic path still lacks __mulsi3 -- a separate,
; pre-existing gap to fix in ../__divsi3.asm's neighbourhood if wanted.)
;
; ---- llvm-z80 runtime ABI (identical to __divsi3's, verified there) ----
;   32-bit values live in HL:DE with HL = HIGH word, DE = LOW word.
;   enter: HL:DE      = arg1 = multiplicand a  (HL=bits16..31, DE=bits0..15)
;          stack      = ret, b_lo, b_hi        = arg2 = multiplier b (LE words)
;          IX         = caller frame ptr, MUST be preserved
;   exit : HL:DE      = product (low 32 bits)
;          caller cleans the 2 pushed multiplier words (`pop af; pop af`).
;
; ---- core ABI (libsrc/math/integer/l_mulu_32_32x32.asm) ----
;   compute: dehl = dehl * dehl'   (low 32 bits of the product, in main dehl)
;   core 32-bit layout DE:HL = DE HIGH word, HL LOW word (byte-swap of llvm-z80
;   HL:DE, so a single `ex de,hl` converts).  Multiplicand goes in the ALTERNATE
;   bank dehl', multiplier in the MAIN bank dehl.  Alters af,bc,de,hl + alts + IX.
;
; __umulsi3 aliases __mulsi3: the low 32 bits of a product are sign-agnostic
; (same reasoning as the 16-bit __mulhi3/__umulhi3 pair).
;
; Worked example a=-1000000 (0xFFF0BDC0), b=7:  product -7000000 (0xFF959F80).
;   entry HL=0xFFF0 (hi), DE=0xBDC0 (lo). ex de,hl -> DE=0xFFF0,HL=0xBDC0
;   (core layout). exx -> dehl' = a. Multiplier b_lo=0x0007,b_hi=0x0000 ->
;   main HL=0x0007,DE=0x0000 = core multiplier 7. Core -> main dehl =
;   0x9F80:0xFF95 ... ex de,hl -> HL:DE = 0xFF95:0x9F80 = -7000000.

SECTION code_clib
SECTION code_l_clang

PUBLIC ___mulsi3
PUBLIC ___umulsi3

EXTERN l_mulu_32_32x32

___mulsi3:
___umulsi3:
   ex de,hl                     ; llvm-z80 HL:DE -> core DE:HL (multiplicand a)
   exx                          ; dehl' = multiplicand a (into alternate bank)
   push ix                      ; save caller frame ptr (core trashes IX)
   ld ix,0
   add ix,sp                    ; IX -> [saved IX]; +2 ret, +4 b_lo, +6 b_hi
   ld l,(ix+4)
   ld h,(ix+5)                  ; HL = b_lo (core low word)
   ld e,(ix+6)
   ld d,(ix+7)                  ; main dehl = multiplier b (not popped: caller owns)
   call l_mulu_32_32x32         ; main dehl = product (low 32 bits)
   pop ix                       ; restore caller frame ptr
   ex de,hl                     ; core DE:HL -> llvm-z80 HL:DE (product)
   ret
