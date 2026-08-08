/*
 *  RC700 graphics example 4: pixel-drawing benchmark ("measuring stick")
 *
 *  A deterministic, exhaustive stress test of the <graphics.h> pixel path
 *  (plot / unplot) on the RC700/RC702 160 x 75 semigraphics screen.  Unlike
 *  mandelbrot.c -- whose per-pixel cost is dominated by 32-bit fixed-point
 *  MULTIPLY, not by drawing -- this demo does *no* arithmetic worth measuring
 *  in its inner loops: every T-state between _main and _getk is spent in
 *  plot() / unplot().  That makes the _main -> _getk cycle count a stable
 *  yardstick for improvements to the pixel-drawing primitives themselves.
 *
 *  Pure integer, no libm / no float runtime, so it builds and runs under both
 *  the classic compiler and -compiler=llvmz80.  See README.md for build/run.
 *
 *  Screen model: 160 x 75 "pixels" laid over an 80 x 25 text grid via the
 *  gencon 2x3 sextant cells -- each text cell is 2 px wide x 3 px tall = 6
 *  sub-pixels, so a cell has 2^6 = 64 distinct on/off glyph states.
 *
 *  Two fixed-workload phases (both fully deterministic -> repeatable timing):
 *
 *    Phase 1 -- sextant glyph sweep: cycle EVERY cell through ALL 64 on/off
 *               combinations of its 6 sub-pixels.  This exercises the whole
 *               sextant glyph set and hammers plot()/unplot() at every cell.
 *               Work = 64 patterns * 2000 cells * 6 sub-pixels = 768,000 ops.
 *
 *    Phase 2 -- prime-stride fill + erase: visit every one of the 12,000
 *               pixels exactly once in a scattered order (see below), plot
 *               them all, then visit again and unplot them all.  Work =
 *               2 * 12,000 = 24,000 ops.
 *
 *  Why a PRIME stride (Phase 2)?  To sweep the whole screen in a scattered
 *  order without a random-number generator and without ever repeating or
 *  skipping a pixel, we step through each row's columns by a stride that is
 *  COPRIME to the row width, and step the row-start / row-index by strides
 *  coprime to the height.  Stepping by S (mod N) visits all N slots exactly
 *  once iff gcd(S, N) == 1.  Width 160 = 2^5 * 5, height 75 = 3 * 5^2, so any
 *  prime other than 2, 3, 5 is automatically coprime to both -- hence the
 *  prime strides below.  Worked example, width sweep with PX_SKIP = 71:
 *  x = 0, 71, 142, 53, 124, 35, ... (each +71, minus 160 on wrap) -- after
 *  160 steps every column 0..159 has been hit once, in a scattered order.
 *
 *  The inner loops use only add + compare + one conditional subtract to do
 *  the "mod" -- NO multiply and NO divide anywhere in the program (cell counts
 *  are walked by px += 2 / py += 3, not by dividing) -- so the measured cost
 *  is the drawing primitive, not the address arithmetic.
 */

#include <graphics.h>
#include <stdio.h>              /* getk() */

/* Prime strides, each coprime to the relevant screen dimension (see header).
   PX_SKIP  : column stride within a row      (coprime to width 160)
   COL_SKIP : per-row starting-column stride   (coprime to width 160)
   ROW_SKIP : row-visit stride                 (coprime to height 75) */
#define PX_SKIP   71
#define COL_SKIP  53
#define ROW_SKIP  29

/*
 *  Set (or clear) the 6 sub-pixels of one 2x3 sextant cell to match the low 6
 *  bits of `pat`.  Bit layout, bit b = row*2 + col within the cell:
 *
 *      bit0 = (col0,row0) top-left     bit1 = (col1,row0) top-right
 *      bit2 = (col0,row1) mid-left     bit3 = (col1,row1) mid-right
 *      bit4 = (col0,row2) bot-left     bit5 = (col1,row2) bot-right
 *
 *  Worked example, pat = 0b100001 (0x21): bit0 set -> plot(px,py) top-left,
 *  bit5 set -> plot(px+1,py+2) bottom-right, the other four -> unplot.  So the
 *  cell shows the two diagonal corners lit.  Cycling pat 0..63 over one cell
 *  walks it through every possible sextant glyph.
 */
static void cell_pattern(int px, int py, int pat)
{
    /* Running one-bit mask instead of `1 << b`: a variable shift is a loop on
       the Z80, whereas doubling (mask += mask) is a single add per step. */
    int mask = 1;
    int row, col;

    for (row = 0; row < 3; row++) {
        for (col = 0; col < 2; col++) {
            if (pat & mask)
                plot(px + col, py + row);
            else
                unplot(px + col, py + row);
            mask += mask;               /* mask <<= 1, add-only */
        }
    }
}

void main(void)
{
    int w = getmaxx();                  /* 160 on rc700 */
    int h = getmaxy();                  /*  75 on rc700 */

    int pat;
    int r, c, x, y, px, py;
    int col_start;

    clg();

    /* ---- Phase 1: cycle every cell through all 64 on/off combinations ---- */
    /* pat is the shared glyph state applied to every cell in turn, so the
       whole screen flips through all 64 sextant glyphs.  This both draws and
       erases sub-pixels (unplot for cleared bits), exercising both paths.
       Cells are walked by px += 2 / py += 3 (NO division to derive counts):
       a cell fits while px+1 < w (2 wide) and py+2 < h (3 tall). */
    for (pat = 0; pat < 64; pat++) {
        py = 0;
        while (py + 2 < h) {            /* 3-tall cell fully on-screen */
            px = 0;
            while (px + 1 < w) {        /* 2-wide cell fully on-screen */
                cell_pattern(px, py, pat);
                px += 2;                /* next cell is 2 px to the right */
            }
            py += 3;                    /* next cell row is 3 px down     */
        }
    }

    clg();                             /* blank slate before Phase 2 */

    /* ---- Phase 2a: prime-stride scatter FILL (every pixel once) ---- */
    /* row_start walks by COL_SKIP so consecutive rows begin at different
       columns (diagonal scatter); the row index r walks the actual row y by
       ROW_SKIP so rows are visited top-to-bottom in scattered order too.
       Because gcd(ROW_SKIP,h)=1 and gcd(PX_SKIP,w)=1, every (x,y) is hit once. */
    y = 0;
    col_start = 0;
    for (r = 0; r < h; r++) {
        x = col_start;
        for (c = 0; c < w; c++) {
            plot(x, y);
            x += PX_SKIP;
            if (x >= w) x -= w;         /* cheap mod-w: stride < w guarantees one sub */
        }
        col_start += COL_SKIP;
        if (col_start >= w) col_start -= w;
        y += ROW_SKIP;
        if (y >= h) y -= h;             /* scattered next row, still each row once */
    }

    /* ---- Phase 2b: prime-stride scatter ERASE (same order, unplot) ---- */
    y = 0;
    col_start = 0;
    for (r = 0; r < h; r++) {
        x = col_start;
        for (c = 0; c < w; c++) {
            unplot(x, y);
            x += PX_SKIP;
            if (x >= w) x -= w;
        }
        col_start += COL_SKIP;
        if (col_start >= w) col_start -= w;
        y += ROW_SKIP;
        if (y >= h) y -= h;
    }

    /* Hold until SPACE.  Non-blocking getk() (not getchar()): a blocking BDOS
       read pages the graphics plane back out on the RC700 (see sine.c). */
    while (getk() != ' ')
        ;
}
