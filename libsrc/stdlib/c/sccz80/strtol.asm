

; long strtol( const char * restrict nptr, char ** restrict endptr, int base)

SECTION code_clib
SECTION code_stdlib

PUBLIC strtol

EXTERN asm_strtol

strtol:
IF __CPU_INTEL__ || __CPU_GBZ80__
   ld hl,2
   add hl,sp
   ld c,(hl)
   inc hl
   ld b,(hl)
   inc hl
   ld e,(hl)
   inc hl
   ld d,(hl)
   inc hl
   ld a,(hl+)
   ld h,(hl)
   ld l,a
   jp  asm_strtol
ELSE
   pop af
   pop bc
   pop de
   pop hl
   
   push hl
   push de
   push bc
   push af
   push ix
   call asm_strtol
   pop ix
   ret
ENDIF

; SDCC bridge for Classic
IF __CLASSIC
PUBLIC _strtol
defc _strtol = strtol
ENDIF

; Clang (llvmz80) bridge for Classic
; ZPROTO3 call: ___strtol(base, endptr, nptr) -- all args reversed
;   HL = base, DE = endptr, [SP+0]=ret_addr, [SP+2]=nptr (caller does pop af after ret)
; asm_strtol expects: HL=nptr, DE=endptr, BC=base
; Returns (llvmz80 32-bit): DE=low word, HL=high word
;   asm_strtol returns sccz80 dehl: DE=high, HL=low -- bridge swaps with ex de,hl
IF __CLASSIC
PUBLIC ___strtol
___strtol:
   ld c,l
   ld b,h              ; BC = base
   push de             ; save endptr; SP = entry_SP-2
   ld hl,4
   add hl,sp           ; HL = &nptr = entry_SP+2
   ld e,(hl)
   inc hl
   ld d,(hl)           ; DE = nptr
   ex de,hl            ; HL = nptr
   pop de              ; DE = endptr; SP = entry_SP (ret_addr at [SP])
   push ix
   call asm_strtol     ; HL=nptr, DE=endptr, BC=base
   pop ix              ; SP = entry_SP
   ex de,hl            ; DE=low, HL=high (llvmz80 32-bit convention)
   ret                 ; SP = entry_SP+2; caller's pop af cleans nptr at [entry_SP+2]
ENDIF

