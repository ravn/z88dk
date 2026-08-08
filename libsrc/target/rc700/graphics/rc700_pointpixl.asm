;
;   RC700 sextant point entry (overrides gencon pointxy via rc700.lst order).
;   See rc700_pixel6.inc for the shared body and the arithmetic reverse map.
;

    SECTION code_clib
    PUBLIC  pointxy

pointxy:
    defc    NEEDpoint = 1
    INCLUDE "rc700_pixel6.inc"
