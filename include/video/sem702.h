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
 * the classic callee and hangs almost immediately.
 *
 * The __smallc annotation alone is necessary but NOT sufficient under
 * -compiler=llvmz80.  __smallc maps to the z80_smallc calling convention
 * (ravn/llvm-z80#279): arguments pushed LEFT-TO-RIGHT, caller-clean -- the
 * same push ORDER the classic sccz80 worker reads (ch at the deepest slot
 * sp+6, lines sp+4, nlines topmost at sp+2).  So a NATURAL-order
 * sem702_loadglyph(ch,lines,nlines) declaration already lands the args
 * correctly and NO parameter reversal is needed.  (The reversal that used to
 * live here was required only before #279, when __smallc still meant
 * sdcccall(0) = right-to-left, first param topmost.)
 *
 * One mismatch remains, so this branch is not yet a plain natural prototype:
 * clang still narrows an `unsigned char` argument to a single-byte push
 * (`ld a,x; push af; inc sp`) under z80_smallc, whereas the sccz80 worker
 * reads a fixed 2-byte slot per argument.  The two char params must therefore
 * still be WIDENED to `unsigned int` so clang emits full 2-byte pushes.
 * Verified with `clang --target=z80 -S`: widened args emit `ld hl,x; push hl`
 * -- three 2-byte slots (ch deepest, lines, nlines topmost) the caller then
 * cleans with three `pop`, matching the worker's frame exactly.  The widened
 * prototype keeps the public symbol name, so no macro or __asm__ rename is
 * needed; __smallc is a no-op under sccz80/SDCC (see <sys/compiler.h>), so the
 * #else branch stays source-portable. */
#if defined(__LLVMZ80)
extern void __LIB__ sem702_loadglyph(unsigned int ch, const unsigned char *lines, unsigned int nlines) __smallc;
#else
void sem702_loadglyph(unsigned char ch, const unsigned char *lines, unsigned char nlines) __smallc;
#endif

#endif
