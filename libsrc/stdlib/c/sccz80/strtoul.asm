
; unsigned long strtoul( const char * restrict nptr, char ** restrict endptr, int base)

IF !__CPU_INTEL__ && !__CPU_GBZ80__


SECTION code_clib
SECTION code_stdlib

PUBLIC strtoul

EXTERN asm_strtoul

strtoul:
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
   jp  asm_strtoul
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
   call asm_strtoul
   pop ix
   ret
ENDIF

; SDCC bridge for Classic
IF __CLASSIC
PUBLIC _strtoul
defc _strtoul = strtoul
ENDIF

; Clang (llvmz80) bridge for Classic
; ZPROTO3 call: ___strtoul(base, endptr, nptr) -- all args reversed
;   HL = base, DE = endptr, [SP+0]=ret_addr, [SP+2]=nptr (caller does pop af after ret)
; asm_strtoul expects: HL=nptr, DE=endptr, BC=base
; Returns (llvmz80 32-bit): DE=low word, HL=high word
;   asm_strtoul returns sccz80 dehl: DE=high, HL=low -- bridge swaps with ex de,hl
IF __CLASSIC
PUBLIC ___strtoul
___strtoul:
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
   call asm_strtoul    ; HL=nptr, DE=endptr, BC=base
   pop ix              ; SP = entry_SP
   ex de,hl            ; DE=low, HL=high (llvmz80 32-bit convention)
   ret                 ; SP = entry_SP+2; caller's pop af cleans nptr at [entry_SP+2]
ENDIF

ENDIF

