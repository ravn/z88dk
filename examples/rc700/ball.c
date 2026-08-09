/*
 *  RC700 graphics example 3: animated bouncing ball
 *
 *  A ball falls under gravity and bounces off the floor and side walls,
 *  losing a little energy each floor bounce.  Each frame the old ball is
 *  erased (uncircle) and the new one drawn (circle) -- this exercises the
 *  read-modify-write nature of the sextant semigraphics model, where every
 *  pixel op reads the current cell, edits one of its 6 subpixels, and writes
 *  it back.  Frame pacing uses clock() (CLOCKS_PER_SEC == 50 on the RC700).
 *
 *  Pure integer (Q4 sub-pixel fixed-point); builds under BOTH the classic
 *  compiler and -compiler=llvmz80.
 *
 *  Build (from the z88dk root):
 *    zcc +cpm -subtype=rc700 [-compiler=llvmz80] -O2 -create-app \
 *        -Cz+cpmdisk -Cz-f -Czrc700-8dd -Cz--container=imd \
 *        -o ball examples/rc700/ball.c
 *  Produces ball.com + ball.imd; run in MAME rc702.
 */

#include <graphics.h>
#include <time.h>

#define SUB     4                       /* fixed-point sub-pixel shift (1/16) */
#define GRAVITY 2                        /* added to vy each frame (sub-px) */
#define RADIUS  3
#define FRAMES  600                      /* run for ~12 s at ~50 fps */
#define TICKS   1                        /* clock ticks to wait per frame */

void main(void)
{
    int w = getmaxx();                  /* 160 */
    int h = getmaxy();                  /*  75 */

    int x  = (RADIUS + 1) << SUB;       /* position, Q4 */
    int y  = (RADIUS + 1) << SUB;
    int vx = 3 << (SUB - 2);            /* velocity, Q4 */
    int vy = 0;

    int minx = RADIUS,       maxx = w - 1 - RADIUS;
    int miny = RADIUS,       maxy = h - 1 - RADIUS;
    int px, py, oldx = -1, oldy = -1;
    int frame;

    clg();

    for (frame = 0; frame < FRAMES; frame++) {
        clock_t t0 = clock();

        /* integrate */
        vy += GRAVITY;
        x  += vx;
        y  += vy;

        px = x >> SUB;
        py = y >> SUB;

        /* wall bounces (reflect in fixed-point, clamp to the visible band) */
        if (px < minx) { px = minx; x = minx << SUB; vx = -vx; }
        if (px > maxx) { px = maxx; x = maxx << SUB; vx = -vx; }
        if (py < miny) { py = miny; y = miny << SUB; vy = -vy; }
        if (py > maxy) {
            py = maxy; y = maxy << SUB;
            vy = -vy + (vy >> 3);       /* lose ~1/8 of the speed */
        }

        /* redraw only if the ball moved to a new cell */
        if (px != oldx || py != oldy) {
            if (oldx >= 0)
                uncircle(oldx, oldy, RADIUS, 0);
            circle(px, py, RADIUS, 0);
            oldx = px;
            oldy = py;
        }

        /* pace the frame */
        while (clock() - t0 < TICKS)
            ;
    }
}
