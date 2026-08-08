;
;   RC700 sextant xor entry (overrides gencon xorpixel via rc700.lst order).
;   See rc700_pixel6.inc for the shared body and the arithmetic reverse map.
;

    SECTION code_clib
    PUBLIC  xorpixel

xorpixel:
    defc    NEEDxor = 1
    INCLUDE "rc700_pixel6.inc"
