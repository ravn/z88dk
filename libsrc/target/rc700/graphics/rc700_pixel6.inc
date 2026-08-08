;
;   RC700 2x3 sextant pixel core (plot / unplot / xor / point).
;
;   Derived from classic/gfx/gencon/pixel6.inc, specialised for the RC700's
;   fixed configuration (2x3 cells, raw vpeek/printc, no USE_INDEX). It exists
;   in the rc700 target so its objects are pulled from rc700.lib *before* the
;   generic gencon plotpixl6/respixl6/pointxy6 (rc700.lst lists
;   target/rc700/obj/... ahead of the gencon manifest), overriding them.
;
;   The one optimisation vs. gencon: the reverse map "on-screen char -> 6-bit
;   sextant mask" is done by ARITHMETIC, not by the up-to-64-iteration linear
;   `ckmap` scan of the textpixl table that gencon runs on every plot.
;
;   WHY arithmetic works: textpixl (target/rc700/graphics/textpixl6.asm) lays
;   the 64 sextant patterns out as two *contiguous* runs of char codes:
;       mask 0..31  -> char $20..$3F        (so mask = char - $20)
;       mask 32..63 -> char $60..$7F        (so mask = char - $40)
;   Any other char (e.g. a plain space that isn't a sextant glyph) maps to 0,
;   exactly like gencon's "not found -> e=0" fallback.
;
;   Worked example: pixel (x=3, y=4). col = x/2 = 1, row = y/3 = 1. vpeek reads
;   the char already in that cell; say the cell currently shows char $63
;   ($60-run) -> mask = $63 - $40 = 0x23 = 0b100011 (three sub-pixels lit).
;   plot then ORs in the bit for (x%2=1, y%3=1) and writes textpixl[newmask].
;
;   Entry (from plot/unplot/point/xor wrappers): H = x, L = y.
;   One of NEEDplot / NEEDunplot / NEEDxor / NEEDpoint must be defc'd by the
;   including wrapper before this file.

        EXTERN  textpixl
        EXTERN  div3
        EXTERN  setgfx
        EXTERN  RC700_DISPLAY
        EXTERN  __console_w
        EXTERN  __console_h
        EXTERN  __gfx_coords

    ; ---- bounds check: x < 2*__console_w, y < 3*__console_h ----
        ld      a, (__console_w)
        add     a                       ; 2 pixels per cell horizontally
        dec     a
        cp      h
        ret     c                       ; x out of range -> ignore

        ld      a, (__console_h)
        ld      e, a
        add     a
        add     e                       ; 3 pixels per cell vertically
        dec     a
        cp      l
        ret     c                       ; y out of range -> ignore

        ld      (__gfx_coords), hl      ; stash original (x,y) for the modulus
        push    bc                      ; save caller's bc

    ; ---- reduce to cell coords: row = y/3 (div3 table), col = x/2 ----
        ld      c, h                    ; c = x
        ld      de, div3
        ld      h, 0                    ; hl = y
        add     hl, de
        ld      b, (hl)                 ; b = y/3  (cell row)
        sub     a                       ; clear carry for a clean x>>1
        ld      a, c
        rra
        ld      c, a                    ; c = x/2  (cell col)
        push    bc                      ; save reduced (b=row, c=col)

    ; ---- compute the VRAM cell address ONCE: RC700_DISPLAY + row*80 + col ----
    ; VRAM is a contiguous 80x25 grid, so cell (row,col) lives at a fixed
    ; offset row*80+col from the base -- no O(row) `xypos` djnz loop needed,
    ; and we compute it once for both the read and the write (same cell).
    ; row*80 = (row<<4)*5 = 16*row + 64*row, all constant-time shifts.
        ld      l, b
        ld      h, 0                    ; hl = row
        add     hl, hl                  ; 2*row
        add     hl, hl                  ; 4*row
        add     hl, hl                  ; 8*row
        add     hl, hl                  ; hl = 16*row
        ld      d, h
        ld      e, l                    ; de = 16*row
        add     hl, hl                  ; 32*row
        add     hl, hl                  ; 64*row
        add     hl, de                  ; hl = 80*row
        ld      d, 0
        ld      e, c
        add     hl, de                  ; + col  -> row*80 + col
        ld      de, RC700_DISPLAY
        add     hl, de                  ; hl = &VRAM[cell]
        ld      (rc700_pix_addr), hl    ; stash for the write-back

    ; ---- read the char currently in the cell (raw mode, hl already = addr) ----
        ld      a, (hl)                 ; a = char at (col,row)

    ; ---- reverse map char -> mask (arithmetic; replaces gencon ckmap scan) --
    ; $20..$3F -> 0..31 ; $60..$7F -> 32..63 ; anything else -> 0
        ld      d, a                    ; keep the raw char
        sub     $20
        cp      $20
        jr      c, revfound             ; was $20..$3F -> a = 0..31
        ld      a, d
        sub     $60
        cp      $20
        jr      nc, revzero             ; not $60..$7F -> treat as blank
        add     a, 32                   ; $60..$7F -> 32..63
        jr      revfound
revzero:
        xor     a
revfound:
        ld      e, a                    ; e = current 6-bit mask in the cell

    ; ---- compute the single-bit mask for this pixel within the cell ----
        pop     hl                      ; h = row, l = col
        push    hl

        ld      a, (__gfx_coords)       ; original y
        sub     h                       ; y - row
        sub     h
        sub     h                       ; a = y - 3*row = y%3  (0..2)
        ld      h, a                    ; remember remainder
        rrca                            ; carry set if remainder odd
        ld      a, 1                    ; base pixel bit
        jr      z, iszero               ; remainder 0
        jr      c, is1                  ; remainder 1
        add     a                       ; remainder 2: shift up a row-pair
        add     a
is1:
        add     a
        add     a
iszero:
        ld      h, a                    ; save pixel bit
        ld      a, (__gfx_coords+1)     ; original x
        rrca                            ; carry set if x odd (right column)
        ld      a, h
        jr      nc, evencol
        add     a                       ; odd x -> shift into right sub-column
evencol:

    ; ---- combine with the existing mask e per operation ----
    IF NEEDplot
        or      e
    ENDIF
    IF NEEDunplot
        cpl
        and     e
    ENDIF
    IF NEEDxor
        xor     e
    ENDIF
    IF NEEDpoint
        and     e                       ; test only
        pop     bc                      ; drop reduced coords
    ELSE
    ; forward map mask -> char and write it back (raw mode)
        ld      hl, textpixl
        ld      d, 0
        ld      e, a
        add     hl, de
        ld      a, (hl)                 ; a = char to display
        pop     bc                      ; drop reduced coords (addr already known)
        ld      hl, (rc700_pix_addr)
        ld      (hl), a                 ; raw VRAM write (same cell we peeked)
        call    setgfx                  ; re-assert gfx page, exactly as printc did
    ENDIF

        pop     bc                      ; restore caller's bc
        ret

        SECTION bss_clib
rc700_pix_addr:
        defw    0
