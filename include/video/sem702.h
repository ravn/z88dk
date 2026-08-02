/*
 * SEM702 RAM character generator -- raw platform routine.
 *
 * The SEM702 board lets a program replace the ROA296 character ROM with a
 * per-glyph RAM font: select the character code on IO_RC700_SEM702_CHAR,
 * then for each of the up to 16 dot-lines the 8275 addresses within a
 * character cell, select the line on IO_RC700_SEM702_LINE and write its
 * 8 pixels to IO_RC700_SEM702_DATA.
 *
 * This is deliberately a thin, format-agnostic wrapper around the 3 ports
 * (declared in <sys/target/cpm/rc700.h>) -- it writes exactly the bytes it
 * is given, in the caller's own line order and bit order, with no padding
 * or mirroring.  Use it when you already have a font in the SEM702's native
 * bit order (MSB = leftmost pixel) and want direct control of which lines
 * are written and in what order.
 *
 * z88dk's own `rc700_loadfont()` (target/rc700/rc700_loadfont.asm, used by
 * <graphics.h>'s custom-font console mode) is NOT the same job: it assumes
 * an 8-line glyph, pads it to the 11-line semigraphics cell itself, and
 * mirrors each byte left-to-right in the process, because the font format
 * it was written for stores bits in the opposite order to the SEM702
 * hardware.  If your font is already in SEM702 bit order (as a raw ROM
 * dump such as ROA296 is), that mirror is wrong for you -- use
 * sem702_loadglyph() instead of rc700_loadfont() in that case.
 *
 * RC700 issue: https://github.com/z88dk/z88dk/issues/3011
 */

#ifndef __VIDEO_SEM702_H__
#define __VIDEO_SEM702_H__

#include <sys/compiler.h>

/* SEM702 I/O ports (target/cpm/def/rc700.h has the same values under
 * IO_RC700_SEM702_CHAR/LINE/DATA; repeated here so this header is
 * self-contained, matching <video/i8275.h>'s convention). */
#define SEM702_CHAR_PORT 0xd1
#define SEM702_LINE_PORT 0xd2
#define SEM702_DATA_PORT 0xd3

/* Write nlines bytes of lines[] into SEM702 glyph ch, one line per byte,
 * starting at dot-line 0.  nlines is normally FONT cell height (8..16);
 * lines beyond what the 8275 cell height needs are simply unused.
 *
 * This function is always compiled classically (sccz80) into rc700.lib,
 * even under -compiler=llvmz80 (there is no llvmz80-compiled variant of
 * the library) -- so a clang caller must be told it uses the classic
 * __smallc convention (all args on stack, caller-cleans), or clang's
 * default sdcccall(1) (first two args in HL/DE) desyncs the stack against
 * the classic callee and hangs almost immediately. The classic worker
 * reads ch/lines/nlines in natural declared order (ch on top, per the
 * sccz80 listing: "ch at sp+6, lines at sp+4, nlines at sp+2"), so no
 * argument reversal is needed here -- see CALLING_CONVENTION.md's
 * "__smallc == sdcccall(0)" section. __smallc expands to a no-op under
 * sccz80/SDCC (see <sys/compiler.h>), so this stays source-portable. */
void sem702_loadglyph(unsigned char ch, const unsigned char *lines, unsigned char nlines) __smallc;

#endif
