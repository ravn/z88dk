#!/usr/bin/env perl
# splitascii.pl -- z88dk "-compiler=llvmz80" bridge pre-pass.
#
# clang (--target=z80 -S) emits any `const unsigned char foo[N]` (N >= 2) as a
# SINGLE `.ascii "..."` line, however large N is (verified up to 2048 bytes,
# the SEM702 ROM font table).  Each non-printable byte is rendered as a 1-4
# char octal escape (`\NNN`), so the escaped line length is NOT bounded by N --
# a 2048-byte all-control-character table renders as an ~8000-char line.
#
# copt (z88dk/src/copt/copt.c) reads its input with a fixed `char lin[MAXLINE]`
# buffer, MAXLINE = 512 (copt.c:31).  Once a `.ascii` line's escaped text
# exceeds ~500 chars (leaving room for the `.ascii "..."` wrapper) copt's
# fgets() truncates/misreads the line, so its `.ascii %1 -> DEFM %1` rule never
# matches and the raw `.ascii` directive falls through to z80asm unmodified,
# which does not understand `.ascii` at all -> "syntax error" with no other
# symptom (root-caused via the sem702-flip-test font296[] build, 2026-08).
#
# This pre-pass runs BEFORE copt (mirroring the splitquad.pl precedent) and
# splits any `.ascii`/`.asciz "..."` line whose EMITTED text exceeds a safe
# threshold into several consecutive pieces, splitting only on real byte
# boundaries (never mid-escape), so copt sees several short lines instead of
# one long one and its ordinary `.ascii/.asciz %1 -> DEFM %1[ + DEFB 0]` rules
# apply to each piece unchanged.  For a split `.asciz` the implicit trailing
# NUL is preserved exactly once by emitting the leading pieces as `.ascii`
# (no NUL) and only the FINAL piece as `.asciz` (-> DEFM + DEFB 0x00).  A label
# on the original line is kept on the first piece only; splitting mid-array
# does not move where the label points (it is at the START of the data, which
# is still the first emitted byte).
#
# Chunk size chosen conservatively for the TIGHTER of the two downstream
# limits: copt's own 512-char line buffer (MAXLINE, copt.c:31), AND z80asm's
# 256-char string-token buffer (STR_SIZE, z80asm/src/c/str.h:63) that the
# translated `DEFM "..."` line lands in afterward.  z80asm's 256-char cap is
# the binding constraint.  Worst case is EVERY byte a 4-char octal escape
# (`\NNN`), so CHUNK=48 bytes -> at most 48*4 = 192 escaped chars, safely
# under both the 256-char z80asm token limit and copt's 512-char line buffer.
use strict; use warnings;

my $CHUNK = 48;   # max real bytes per emitted .ascii piece (see comment above)

while (my $line = <STDIN>) {
    # Match BOTH .ascii (no trailing NUL) and .asciz (implicit trailing NUL, the
    # form clang emits for every C string literal -- e.g. the ~430-char
    # peephole-rules string in stdcbench c90lib-peep.c).  A long .asciz used to
    # bypass this splitter entirely (the old /\.ascii\s/ regex does not match
    # the trailing 'z'), overflow z80asm's 256-char string token, and fail with
    # a bare "syntax error" -- same failure mode as the .ascii case below.
    if ($line =~ /^(\s*)\.(ascii|asciz)\s+"((?:[^"\\]|\\.)*)"\s*$/) {
        my ($indent, $dir, $body) = ($1, $2, $3);
        my @pieces;
        my $cur = '';
        my $n = 0;
        while (length($body)) {
            if ($body =~ s/^(\\[0-7]{1,3}|\\.|.)//s) {
                $cur .= $1;
            }
            $n++;
            if ($n >= $CHUNK) {
                push @pieces, $cur;
                $cur = '';
                $n = 0;
            }
        }
        push @pieces, $cur if length($cur) || !@pieces;
        if (@pieces > 1) {
            # For .asciz the implicit trailing NUL must be preserved exactly
            # once: emit every piece but the last as .ascii (no NUL) and the
            # final piece as .asciz, so copt lowers it to DEFM + DEFB 0x00.
            # (.ascii keeps all pieces as .ascii -- no NUL anywhere.)
            my $last = $#pieces;
            for my $i (0 .. $last) {
                my $d = ($dir eq 'asciz' && $i == $last) ? 'asciz' : 'ascii';
                print "$indent.$d\t\"$pieces[$i]\"\n";
            }
            next;
        }
        # single piece: short enough already, fall through unchanged below
    }
    print $line;
}
