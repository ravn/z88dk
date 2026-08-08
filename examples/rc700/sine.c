/*
 *  RC700 graphics example 1: sine / cosine plotter with axes
 *
 *  Draws y = sin(x) and y = cos(x) across the full width of the RC700
 *  semigraphics screen (160 x 75 via 2x3 sextant cells), with x/y axes.
 *
 *  Pure integer: a 65-entry quarter-wave sine look-up table is mirrored by
 *  symmetry into a full period, so this builds and runs under BOTH the
 *  classic compiler and -compiler=llvmz80 with no libm / no float runtime.
 *  (For a float-based 3D function plot see the portable ../graphics/coswave.c.)
 *
 *  Build (from the z88dk root, ZCCCFG + PATH set):
 *    sccz80/classic:  zcc +cpm -subtype=rc700 -O2 -create-app \
 *                        -Cz+cpmdisk -Cz-f -Czrc700-8dd -Cz--container=imd \
 *                        -o sine examples/rc700/sine.c
 *    llvmz80:         zcc +cpm -subtype=rc700 -compiler=llvmz80 -O2 -create-app \
 *                        -Cz+cpmdisk -Cz-f -Czrc700-8dd -Cz--container=imd \
 *                        -o sine examples/rc700/sine.c
 *  Produces sine.com + sine.imd; run in MAME rc702 (output is on the video
 *  RAM console, not BDOS, so ntvcm cannot show it).
 */

#include <graphics.h>
#include <stdio.h>

/* Angle unit: 256 == full circle.  isin() returns -256..256 (amplitude 256). */
static const int quarter[65] = {
       0,   6,  13,  19,  25,  31,  38,  44,
      50,  56,  62,  68,  74,  80,  86,  92,
      98, 104, 109, 115, 121, 126, 132, 137,
     142, 147, 152, 157, 162, 167, 172, 177,
     181, 185, 190, 194, 198, 202, 206, 209,
     213, 216, 220, 223, 226, 229, 231, 234,
     237, 239, 241, 243, 245, 247, 248, 250,
     251, 252, 253, 254, 255, 255, 256, 256,
     256,
};

static int isin(int a)
{
    a &= 255;                       /* wrap to 0..255 */
    if (a < 64)   return  quarter[a];
    if (a < 128)  return  quarter[128 - a];
    if (a < 192)  return -quarter[a - 128];
    return               -quarter[256 - a];
}

static int icos(int a) { return isin(a + 64); }

void main(void)
{
    int w = getmaxx();              /* 160 on rc700 */
    int h = getmaxy();              /*  75 on rc700 */
    int midy = h / 2;
    int amp  = (h / 2) - 2;         /* vertical amplitude, leave a margin */
    int px, y;

    clg();

    /* Axes: horizontal (x) through the middle, vertical (y) at the left. */
    draw(0, midy, w - 1, midy);
    draw(0, 0, 0, h - 1);

    /* Tick marks every quarter period along the x axis. */
    for (px = 0; px < w; px += w / 8) {
        draw(px, midy - 1, px, midy + 1);
    }

    /* Plot sin(x) and cos(x).  x spans two full periods across the width:
       angle = px * 512 / w  (512 angle-units == two circles).            */
    for (px = 0; px < w; px++) {
        int angle = (int)(((long)px * 512) / w);

        y = midy - (isin(angle) * amp) / 256;   /* sine  */
        plot(px, y);

        y = midy - (icos(angle) * amp) / 256;   /* cosine */
        plot(px, y);
    }

    /* Hold the image until SPACE is pressed.  Use the non-blocking key poll
       getk() rather than getchar(): a blocking BDOS console read pages the
       graphics plane back out (RC700 _GFX_PAGE_VRAM), hiding the drawing. */
    while (getk() != ' ')
        ;
}
