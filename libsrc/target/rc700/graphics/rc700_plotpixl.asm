;
;   RC700 sextant plot entry (overrides gencon plotpixel via rc700.lst order).
;   See rc700_pixel6.inc for the shared body and the arithmetic reverse map.
;

    SECTION code_clib
    PUBLIC  plotpixel

plotpixel:
    defc    NEEDplot = 1
    INCLUDE "rc700_pixel6.inc"
