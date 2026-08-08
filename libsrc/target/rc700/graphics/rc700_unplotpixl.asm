;
;   RC700 sextant unplot entry (overrides gencon respixel via rc700.lst order).
;   See rc700_pixel6.inc for the shared body and the arithmetic reverse map.
;

    SECTION code_clib
    PUBLIC  respixel
    PUBLIC  unplot_fc                   ; z80_fastcall alias: HL = (x<<8)|y
    PUBLIC  _unplot_fc

respixel:
unplot_fc:
_unplot_fc:
    defc    NEEDunplot = 1
    INCLUDE "rc700_pixel6.inc"
