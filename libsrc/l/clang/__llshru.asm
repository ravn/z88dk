
SECTION code_l_clang

PUBLIC __llshru

EXTERN l_lsr_dehldehl

; 64-bit logical shift-right, ez80-clang calling convention.
;
; enter :  hl = a0 (bits  0-15 of the value to shift)
;          de = a1 (bits 16-31)
;          bc = a2 (bits 32-47)
;          stack (relative to SP at entry, i.e. right after the `call`
;                 instruction pushed the return address):
;                 +2  a3   (bits 48-63)
;                 +4  n    (shift amount; only the low byte is used --
;                           shift counts are always 0-63 for a 64-bit
;                           value, so the high byte, if any, is ignored)
;
; exit  :  hl = result bits  0-15
;          de = result bits 16-31
;          bc = result bits 32-47
;          iy = result bits 48-63
;          caller pops the 4 bytes of stack arguments (a3,n) itself
;          after the call returns (two bare `pop hl`s in the observed
;          ez80-clang output) -- this routine does not clean the
;          stack.
;
; ABI reverse-engineered the same way as __llmulu.asm (see that file
; and ravn/rc700-gensmedet#122). Unlike __llmulu, a3/n only need to be
; *read*, never relocated into a contiguous memory block -- l_lsr_
; dehldehl (libsrc/l/util/5-z80/longlong/l_lsr_dehldehl.asm) takes its
; whole 64-bit operand in registers, no memory operand at all. So this
; wrapper never has to move the return address out of the way: it
; reads a3/n non-destructively through an ix frame pointer and
; reassembles the value into the dehl'dehl format l_lsr_dehldehl
; expects (low 32 bits in de:hl, high 32 bits in the shadow de':hl').
;
; uses  : af, bc, de, hl, ix, iy, bc', de', hl'

__llshru:
   push ix                 ; save caller's ix
   ld ix,4
   add ix,sp               ; ix -> a3 (ix+0,+1 = a3; ix+2,+3 = n)

   push bc                 ; a2, parked on the stack purely so the
                           ; upcoming exx can pick it up into the
                           ; shadow bank (there's no direct bc->bc'
                           ; move on z80)
   exx
   pop hl                  ; hl' = a2
   ld e,(ix+0)
   ld d,(ix+1)             ; de' = a3, read directly off the caller's
                           ; stack -- never popped, so the return
                           ; address and a3/n stay exactly where the
                           ; caller left them
   exx                     ; hl/de restored = a0/a1 (untouched all
                           ; along; only bc was ever disturbed)

   ld a,(ix+2)             ; a = shift amount (n's low byte)

   call l_lsr_dehldehl     ; dehl'dehl >>= a

   exx                     ; bring result bits 32-63 into view as hl/de
   push de                 ; stash bits 48-63
   push hl                 ; stash bits 32-47
   exx                     ; hl/de = result bits 0-15/16-31 again

   pop bc                  ; bc = result bits 32-47
   pop iy                  ; iy = result bits 48-63

   pop ix                  ; restore caller's ix; SP now points exactly
                           ; at the (never-touched) return address

   ret
