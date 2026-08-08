;
;   RC700 sextant unplot entry (overrides gencon respixel via rc700.lst order).
;   See rc700_pixel6.inc for the shared body and the arithmetic reverse map.
;

    SECTION code_clib
    PUBLIC  respixel

respixel:
    defc    NEEDunplot = 1
    INCLUDE "rc700_pixel6.inc"
