; itoa / ltoa / ultoa bridges for ravn/llvm-z80 clang.
;
; WHY THIS FILE EXISTS
;   These are non-standard but widely used conversion functions.  z88dk
;   exports `asm_itoa`, `asm_ltoa`, `asm_ultoa` (the register-ABI workers)
;   but has no `___itoa` / `___ltoa` / `___ultoa` adapters for the llvmz80
;   register calling convention.  Without them, any program calling itoa/ltoa/
;   ultoa fails to link with "undefined symbol: ___itoa".
;
; ARG ORDERING — the key detail
;   z88dk stdlib.h declares these via __ZPROTO3 which, for llvmz80, REVERSES
;   the argument order for the low-level entry point:
;
;     itoa(num, buf, radix) -> __itoa(radix, buf, num)  [i.e. ___itoa]
;
;   So clang generates (verified 2026-07-21 from zcc -S output):
;
;     ld hl, num    ; push num (arg3 reversed = stacked)
;     push hl
;     ld hl, radix  ; HL = radix  (arg1 reversed = first register arg)
;     ld de, buf    ; DE = buf    (arg2 = second register arg)
;     call ___itoa
;
;   For ltoa/ultoa, num is long (32-bit); clang pushes num_hi first (deepest)
;   then num_lo (nearest top, just above ret_addr):
;
;     ld hl, num_hi; push hl   ; deepest
;     ld hl, num_lo; push hl   ; nearest top
;     ld hl, radix
;     ld de, buf
;     call ___ltoa
;
; CALLING CONVENTION (ravn/llvm-z80 sdcccall(1)):
;   return 16-bit: in DE (callee-cleans stacked args)
;   asm_itoa:  HL=num, BC=radix, DE=buf  (per z88dk libsrc/stdlib/z80/asm_itoa.asm)
;   asm_ltoa:  DE=num_hi, HL=num_lo, IX=buf, BC=radix
;   asm_ultoa: same layout as asm_ltoa

SECTION code_l_clang

PUBLIC ___itoa
PUBLIC ___ltoa
PUBLIC ___ultoa

EXTERN asm_itoa
EXTERN asm_ltoa
EXTERN asm_ultoa

; ---- itoa(int num, char *buf, int radix) ----
; entry (from clang ZPROTO3-reversed __itoa call):
;   HL=radix, DE=buf, stack: [ret][num]  (callee-cleans num = 2 bytes)
; asm_itoa wants: HL=num, BC=radix, DE=buf
___itoa:
    push ix             ; save IX;  stack: [savedIX][ret][num]
    ld ix, 0
    add ix, sp          ; IX = frame base
    ; (ix+0)=savedIX, (ix+2)=ret, (ix+4)=num_lo, (ix+5)=num_hi
    ld c, l             ; C = radix_lo  (HL carries radix at entry)
    ld b, h             ; B = radix_hi  -> BC = radix
    ld h, (ix+5)        ; H = num_hi    (from stack)
    ld l, (ix+4)        ; L = num_lo    -> HL = num
    ; HL=num, BC=radix, DE=buf -- matches asm_itoa entry
    call asm_itoa       ; HL = ptr to NUL terminator in buf
    pop ix              ; restore IX;  stack: [ret][num]
    ; callee-clean: drop num (2 bytes)
    pop hl              ; HL = ret addr; stack: [num]
    inc sp
    inc sp              ; drop num; stack: []
    push hl             ; stack: [ret]
    ex de, hl           ; DE = result (clang 16-bit return in DE)
    ret

; ---- ltoa(long num, char *buf, int radix) ----
; entry (from clang ZPROTO3-reversed __ltoa call):
;   HL=radix, DE=buf, stack: [ret][num_lo][num_hi]  (callee-cleans 4 bytes)
; asm_ltoa wants: DE=num_hi, HL=num_lo, IX=buf, BC=radix
___ltoa:
    push ix             ; save IX;  stack: [savedIX][ret][num_lo][num_hi]
    ld ix, 0
    add ix, sp          ; IX = frame base
    ; (ix+0)=savedIX, (ix+2)=ret, (ix+4)=num_lo, (ix+6)=num_hi
    ld c, l             ; C = radix_lo
    ld b, h             ; B = radix_hi -> BC = radix
    ; Move DE (buf) into IX; we need IX=buf for asm_ltoa
    push de             ; push buf;  IX will be set
    pop ix              ; IX = buf;  stack still [savedIX][ret][num_lo][num_hi]
    ; IX now = buf; saved IX is at memory location SP+0 (savedIX on stack)
    ; Read num from stack using HL arithmetic (IX is no longer frame ptr)
    ld hl, 4
    add hl, sp          ; HL = &num_lo on stack (SP+4)
    ld e, (hl)
    inc hl
    ld d, (hl)          ; DE = num_lo (16-bit)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a             ; HL = num_hi (16-bit)
    ; asm_ltoa wants DE=num_hi, HL=num_lo; swap:
    ex de, hl           ; DE=num_hi, HL=num_lo
    call asm_ltoa       ; HL = NUL ptr;  clobbers af,bc,de,hl,bc',de',hl'
    ex de, hl           ; DE = result (16-bit return)
    pop ix              ; restore saved IX;  stack: [ret][num_lo][num_hi]
    ; callee-clean: drop num (4 bytes = 2 words)
    pop hl              ; HL = ret addr; stack: [num_lo][num_hi]
    inc sp
    inc sp              ; drop num_lo
    inc sp
    inc sp              ; drop num_hi;  stack: []
    push hl             ; stack: [ret]
    ret

; ---- ultoa(unsigned long num, char *buf, int radix) ----
; identical layout to ltoa but unsigned -- calls asm_ultoa
___ultoa:
    push ix
    ld ix, 0
    add ix, sp
    ld c, l
    ld b, h
    push de
    pop ix
    ld hl, 4
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ex de, hl
    call asm_ultoa
    ex de, hl
    pop ix
    pop hl
    inc sp
    inc sp
    inc sp
    inc sp
    push hl
    ret
