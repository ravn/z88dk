
SECTION code_l_clang

PUBLIC __llmulu

EXTERN l_mulu_64_64x64

; 64-bit unsigned multiply, ez80-clang calling convention.
;
; enter :  hl = b0 (bits  0-15 of the second operand "b")
;          de = b1 (bits 16-31 of "b")
;          bc = b2 (bits 32-47 of "b")
;          stack (relative to SP at entry, i.e. right after the `call`
;                 instruction pushed the return address):
;                 +2  b3   (bits 48-63 of "b")
;                 +4  a0   (bits  0-15 of the first operand "a")
;                 +6  a1   (bits 16-31 of "a")
;                 +8  a2   (bits 32-47 of "a")
;                 +10 a3   (bits 48-63 of "a")
;
; exit  :  hl = product bits  0-15
;          de = product bits 16-31
;          bc = product bits 32-47
;          iy = product bits 48-63
;          caller pops the 10 bytes of stack arguments (b3,a0,a1,a2,a3)
;          itself after the call returns (e.g. via
;          `ld ix,10 / add ix,sp / ld sp,ix`) -- this routine does not
;          clean the stack.
;
; This ABI was reverse-engineered from ez80-clang (CE-Programming/
; llvm-project)'s own -S output for `a*b` on `unsigned long long`
; (ravn/rc700-gensmedet#122). No other z88dk 64-bit entry point uses a
; mixed register/stack convention like this one, so this file is a
; thin ABI-adapter wrapper around the shared l_mulu_64_64x64 core (see
; libsrc/math/integer/l_mulu_64_64x64.asm): it reconstructs the
; 16-byte contiguous {b,a} operand block that routine expects at
; ix+0..+15, relocating the return address out of the way first (its
; stack slot is exactly where operand word b2 must be written), then
; restoring it before RET.
;
; uses  : af, bc, de, hl, iy, af', bc', de', hl'

__llmulu:
   pop iy                  ; iy = return address (stashed here because
                           ; its stack slot is where b2 must go, below)

   push bc                 ; b2
   push de                 ; b1
   push hl                 ; b0
                           ; stack now reads, low->high address:
                           ; b0,b1,b2,b3,a0,a1,a2,a3 -- a contiguous
                           ; 16-byte block, exactly what
                           ; l_mulu_64_64x64 wants at ix+0..+15.

   push ix                 ; save caller's ix (l_mulu_64_64x64 leaves ix
                           ; unchanged on exit, but we need it as a
                           ; scratch pointer into the block above)
   ld ix,2
   add ix,sp               ; ix -> start of the 16-byte {b,a} block (b0)

   call l_mulu_64_64x64    ; dehl'dehl = product (hl=bits0-15,
                           ; de=bits16-31, hl'=bits32-47, de'=bits48-63);
                           ; ix left unchanged by the callee

   pop ix                  ; restore caller's ix

   pop af                  ; discard b0 (no longer needed)
   pop af                  ; discard b1
   pop af                  ; discard b2 -- SP now sits exactly on b3's
                           ; original address, i.e. one push away from
                           ; the slot the return address needs

   push iy                 ; write the saved return address back onto
                           ; the stack, into the slot the 3 discards
                           ; above just freed up

   exx                     ; bring the product's high half (hl'=bits
                           ; 32-47, de'=bits48-63) into view as hl/de;
                           ; the low half (still correct in the real
                           ; hl/de) is safely parked in the shadow bank
                           ; for the duration of this round-trip
   push de                 ; stash bits 48-63
   push hl                 ; stash bits 32-47
   exx                     ; hl/de = product bits 0-15/16-31 again,
                           ; unaffected by the exx round-trip above

   pop bc                  ; bc = product bits 32-47
   pop iy                  ; iy = product bits 48-63; SP now points
                           ; exactly at the restored return address

   ret
