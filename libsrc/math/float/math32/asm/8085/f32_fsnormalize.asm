;
;  feilipu, 2026 August
;
;  This Source Code Form is subject to the terms of the Mozilla Public
;  License, v. 2.0. If a copy of the MPL was not distributed with this
;  file, You can obtain one at http://mozilla.org/MPL/2.0/.
;
;-------------------------------------------------------------------------
; m32_fsnormalize - 8085 normalisation
;-------------------------------------------------------------------------
;
;  unpacked: h==0; mantissa=lde, sign in b, exponent in c
;  result packed IEEE DEHL (no af')
;
;  ex de,hl → E:HL; byte scan; unrolled residual walk jumps into
;  reverse-label shift tree (add hl,hl / rl de); ex de,hl → pack.
;
;-------------------------------------------------------------------------

SECTION code_clib
SECTION code_fp_math32

PUBLIC m32_fsnormalize


.m32_fsnormalize
    ld a,b
    push af                     ; save sign

    ex de,hl                    ; E = high, HL = mid:low, D = 0

    ld a,e
    or a
    jp m,no_shift
    jr nz,bitwalk

    ld a,h
    or a
    jr nz,need8

    ld a,l
    or a
    jp z,normzero

    ld e,l
    ld hl,0
    ld a,c
    sub 16
    ld c,a
    jp c,normzero
    jp got_lead

.need8
    ld e,h
    ld h,l
    ld l,0
    ld a,c
    sub 8
    ld c,a
    jp c,normzero

.got_lead
    ld a,e
    or a
    jp m,no_shift
    jp z,normzero

.bitwalk
    ld b,1
    add a,a
    jp m,s1
    inc b
    add a,a
    jp m,s2
    inc b
    add a,a
    jp m,s3
    inc b
    add a,a
    jp m,s4
    inc b
    add a,a
    jp m,s5
    inc b
    add a,a
    jp m,s6
    inc b
    add a,a
    jp p,normzero               ; 7th trial still clear → zero
    ; fall through to s7

.s7
    add hl,hl
    rl de
.s6
    add hl,hl
    rl de
.s5
    add hl,hl
    rl de
.s4
    add hl,hl
    rl de
.s3
    add hl,hl
    rl de
.s2
    add hl,hl
    rl de
.s1
    add hl,hl
    rl de

    ld a,c
    sub b
    jp c,normzero
    ld c,a

.no_shift
    ex de,hl                    ; E:HL → LDE

    pop af
    ld b,a
    ld a,c

    ld h,a
    ld a,l
    rla
    ld l,a
    ld a,b
    rla
    ld a,h
    rra
    ld h,a
    ld a,l
    rra
    ld l,a
    ex de,hl
    ret

.normzero
    pop af
    ld hl,0
    ld de,hl
    ret
