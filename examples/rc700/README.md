# RC700 graphics examples

Three semigraphics demos for the Regnecentralen RC700/RC702 (`+cpm -subtype=rc700`),
using the portable `<graphics.h>` layer on top of the gencon 2x3 sextant model
(160 x 75 "pixels" over the 80 x 25 text screen).

| File            | What it shows                          | Exercises                          |
|-----------------|----------------------------------------|------------------------------------|
| `sine.c`        | sin(x) + cos(x) with axes/ticks        | `draw`/`plot`, integer sine LUT    |
| `mandelbrot.c`  | filled Mandelbrot silhouette           | nested loops + Q6.10 fixed-point   |
| `ball.c`        | bouncing ball, gravity + wall bounces  | `circle`/`uncircle`, `clock()` timing |

All three are **pure integer** (no libm, no float runtime), so they build and
run under both the classic compiler and `-compiler=llvmz80`. For a float-based
(`-lm` / `--math32`) function plot see the portable `../graphics/coswave.c`.

## Building

From the z88dk root, with `ZCCCFG` and `PATH` set and `rc700.lib` built/installed:

```sh
# classic (sccz80) route
zcc +cpm -subtype=rc700 -O2 -create-app \
    -Cz+cpmdisk -Cz-f -Czrc700-8dd -Cz--container=imd \
    -o sine examples/rc700/sine.c

# llvmz80 route (needs LLVMZ80EXE pointing at the ravn/llvm-z80 clang)
zcc +cpm -subtype=rc700 -compiler=llvmz80 -O2 -create-app \
    -Cz+cpmdisk -Cz-f -Czrc700-8dd -Cz--container=imd \
    -o sine examples/rc700/sine.c
```

Each build produces `<name>.com` plus an `.imd` floppy image. Swap `sine` for
`mandelbrot` or `ball`.

## Running

Output goes to the RC700 video-RAM console (`0xF800`), **not** through BDOS, so
these must be run in **MAME rc702** — a BDOS-only emulator such as ntvcm will
run the code but show nothing. `sine` and `mandelbrot` hold the final image
until a key is pressed (snapshot before then); `ball` animates for a fixed
number of frames and exits.

Note: the emitted `.imd` is a data disk, not yet a bootable RC702 diskette
(see ravn/z88dk #36) — to run in MAME, place the `.com` on a bootable CP/M
system disk.
