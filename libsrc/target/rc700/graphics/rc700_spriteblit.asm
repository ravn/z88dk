;
;   RC700 cell-batched sprite blit -- PROOF OF CONCEPT (spr_or only).
;
;   Lever D: the generic __generic_putsprite calls plotpixel once per set pixel,
;   paying the whole ~763 T sextant primitive (address + VRAM read + reverse-map
;   + forward-map + write + setgfx) for EACH pixel. But up to 6 sprite pixels
;   share one 2x3 sextant character cell, so this routine builds the 6-bit cell
;   mask ONCE per cell and does a single read-modify-write -- amortising the
;   fixed per-cell cost over up to 6 pixels.
;
;   SCOPE (PoC restrictions, deliberately narrow so the batched win can be
;   measured without the full edge/alignment machinery):
;     * spr_or mode only (no AND/XOR yet)
;     * cell-aligned: x0 EVEN, y0 a MULTIPLE OF 3
;     * width <= 8 (one bitmap byte per row), height a multiple of 3
;   A production override of putsprite would additionally handle odd-x /
;   misaligned-y partial edge cells, multi-byte rows, and AND/XOR.
;
;   Entry: __z88dk_fastcall, HL -> parameter block:
;       +0  x0   (even, pixel col of sprite's left edge)
;       +1  y0   (multiple of 3, pixel row of sprite's top edge)
;       +2  spr  (word: pointer to sprite = {w, h, row bytes...})
;
;   Worked example: sprite {8,3, 0xFF,0x81,0x00} at x0=4, y0=6.
;     Band 0 covers cell-row crow = y0/3 = 2, cells ccol = x0/2 = 2..5 (w/2=4).
;     r0=0xFF (all 8 px set), r1=0x81 (ends set), r2=0x00.
;     Cell ccol=2 takes cols 4,5: from r0 both set (bit0,bit1), r1 col4=bit(7-4=3)
;     of 0x81=0 -> no bit2, col5=bit2 of 0x81=0 -> no bit3, r2 none.  mask=0b000011.
;     -> RMW cell (crow=2,ccol=2): OR 0b000011 into whatever glyph is there.
;
        SECTION code_clib

        PUBLIC  sprite_or
        PUBLIC  _sprite_or

        EXTERN  rc700_rowaddr
        EXTERN  textpixl
        EXTERN  setgfx

sprite_or:
_sprite_or:
        ; ---- unpack the parameter block (HL -> params) ----
        ld      a, (hl)                 ; x0
        srl     a                       ; x0/2 = starting cell column (x0 even)
        ld      (sb_ccol0), a
        inc     hl
        ld      a, (hl)                 ; y0
        inc     hl
        ld      e, (hl)
        inc     hl
        ld      d, (hl)                 ; DE = sprite pointer
        ; crow = y0/3  (y0 is a multiple of 3; divide by repeated subtraction)
        ld      b, 0                    ; crow accumulator
        ld      c, a                    ; c = y0
crowdiv:
        ld      a, c
        sub     3
        jr      c, crowdone
        ld      c, a
        inc     b
        jr      crowdiv
crowdone:
        ld      a, b
        ld      (sb_crow), a

        ex      de, hl                  ; HL = sprite pointer
        ld      a, (hl)                 ; width
        srl     a                       ; w/2 = cells per band
        ld      (sb_wcells), a
        inc     hl
        ld      a, (hl)                 ; height
        ld      (sb_hrem), a            ; remaining sprite rows
        inc     hl                      ; HL -> first bitmap row byte
        ld      (sb_bmptr), hl

    ; =====================================================================
    ; band loop: each band is 3 sprite rows == one sextant cell-row
    ; =====================================================================
band_loop:
        ld      a, (sb_hrem)
        or      a
        jp      z, blit_done            ; no rows left

        ; load the 3 row bytes of this band (w<=8 -> 1 byte/row)
        ld      hl, (sb_bmptr)
        ld      a, (hl)
        ld      (sb_r0), a
        inc     hl
        ld      a, (hl)
        ld      (sb_r1), a
        inc     hl
        ld      a, (hl)
        ld      (sb_r2), a
        inc     hl
        ld      (sb_bmptr), hl          ; advance past the 3 consumed rows

        ; band cell base address = rc700_rowaddr[crow]
        ld      a, (sb_crow)
        ld      l, a
        ld      h, 0
        add     hl, hl                  ; word index
        ld      de, rc700_rowaddr
        add     hl, de
        ld      a, (hl)
        inc     hl
        ld      h, (hl)
        ld      l, a                    ; HL = RC700_DISPLAY + crow*80
        ld      (sb_base), hl

        ; per-cell loop across the band
        ld      a, (sb_ccol0)
        ld      (sb_ccol), a
        ld      a, (sb_wcells)
        ld      (sb_ccnt), a

cell_loop:
        ; ---- build the 6-bit cell mask from the 3 stored row bytes ----
        ; consume 2 MSBs from each row (col0 then col1), left-to-right cells.
        ld      e, 0                    ; e = accumulating mask
        ; row0 -> bit0 (col0), bit1 (col1)
        ld      a, (sb_r0)
        sla     a
        ld      (sb_r0), a
        jr      nc, m_n0
        set     0, e
m_n0:
        ld      a, (sb_r0)
        sla     a
        ld      (sb_r0), a
        jr      nc, m_n1
        set     1, e
m_n1:
        ; row1 -> bit2 (col0), bit3 (col1)
        ld      a, (sb_r1)
        sla     a
        ld      (sb_r1), a
        jr      nc, m_n2
        set     2, e
m_n2:
        ld      a, (sb_r1)
        sla     a
        ld      (sb_r1), a
        jr      nc, m_n3
        set     3, e
m_n3:
        ; row2 -> bit4 (col0), bit5 (col1)
        ld      a, (sb_r2)
        sla     a
        ld      (sb_r2), a
        jr      nc, m_n4
        set     4, e
m_n4:
        ld      a, (sb_r2)
        sla     a
        ld      (sb_r2), a
        jr      nc, m_n5
        set     5, e
m_n5:
        ld      a, e
        or      a
        jp      z, cell_next            ; no set sub-pixels -> nothing to write

        ; ---- RMW this cell: addr = base + ccol ----
        ld      hl, (sb_base)
        ld      a, (sb_ccol)
        add     a, l
        ld      l, a
        jr      nc, addr_nc
        inc     h
addr_nc:
        ; save the write address; read current glyph
        ld      (sb_addr), hl
        ld      a, (hl)                 ; current glyph char

        ; reverse-map char -> current 6-bit mask (same arithmetic as pixel6.inc)
        ; $20..$3F -> 0..31 ; $60..$7F -> 32..63 ; else -> 0
        ld      d, a
        sub     $20
        cp      $20
        jr      c, rev_ok
        ld      a, d
        sub     $60
        cp      $20
        jr      nc, rev_zero
        add     a, 32
        jr      rev_ok
rev_zero:
        xor     a
rev_ok:
        ; a = existing mask ; OR in the sprite cell mask e
        or      e

        ; forward-map mask -> glyph char, write back
        ld      hl, textpixl
        ld      d, 0
        ld      e, a
        add     hl, de
        ld      a, (hl)
        ld      hl, (sb_addr)
        ld      (hl), a
        call    setgfx                  ; re-assert gfx page, as printc did

cell_next:
        ld      a, (sb_ccol)
        inc     a
        ld      (sb_ccol), a
        ld      a, (sb_ccnt)
        dec     a
        ld      (sb_ccnt), a
        jp      nz, cell_loop

        ; next band: crow++, hrem -= 3
        ld      a, (sb_crow)
        inc     a
        ld      (sb_crow), a
        ld      a, (sb_hrem)
        sub     3
        ld      (sb_hrem), a
        jp      band_loop

blit_done:
        ret

        SECTION bss_clib
sb_ccol0:   defb 0
sb_crow:    defb 0
sb_wcells:  defb 0
sb_hrem:    defb 0
sb_bmptr:   defw 0
sb_base:    defw 0
sb_addr:    defw 0
sb_ccol:    defb 0
sb_ccnt:    defb 0
sb_r0:      defb 0
sb_r1:      defb 0
sb_r2:      defb 0
