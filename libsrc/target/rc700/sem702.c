/*
 * SEM702 RAM character generator -- raw platform routine.
 *
 * Declared in <video/sem702.h>.  Plain z80_outp() on the 3 documented ports;
 * no font-format assumptions.
 *
 * This file is always built with classic sccz80 (rc700.mak has no
 * -compiler=llvmz80 variant of the library), so it needs no clang-specific
 * code path itself -- the ABI boundary that matters is in the *header*
 * (<video/sem702.h>): sem702_loadglyph() must be declared __smallc there
 * so a clang caller (-compiler=llvmz80) marshals its call to match this
 * classically-compiled function's actual (all-stack, natural-order)
 * calling convention. See the header for the full explanation; omitting
 * that annotation made clang assume its default sdcccall(1) convention
 * (args in HL/DE) against a classic-ABI callee, corrupting the stack and
 * hanging almost immediately.
 */

#include <arch/z80.h>
#include <video/sem702.h>

void sem702_loadglyph(unsigned char ch, const unsigned char *lines, unsigned char nlines)
{
    unsigned char line;

    z80_outp(SEM702_CHAR_PORT, ch);
    for (line = 0; line < nlines; line++) {
        z80_outp(SEM702_LINE_PORT, line);
        z80_outp(SEM702_DATA_PORT, lines[line]);
    }
}
