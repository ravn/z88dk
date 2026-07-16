#!/usr/bin/env perl
# Rewrite LLVM local/private labels into z80asm-legal identifiers.  z80asm's
# lexer forbids '.' inside identifiers (a '.' is its own token), so every
# dotted symbol clang emits must be flattened.  clang produces THREE dotted
# families (all verified against the Z80 backend):
#   1. .LBB0_4 / .Lfunc_end0  local labels     -> LBB0_4 / Lfunc_end0
#   2. L_.str  / L_.str.1      private globals   -> L__str / L__str_1
#   3. _counter.n              static locals     -> _counter_n
# Family 3 (`_func.var`, from `func.var` mangling under the target's Mach-O
# name mangling) is neither .L* nor L_*, so it is handled by the generic
# second rule below rather than a family-specific one.
#
# The generic rule matches any identifier that starts with a letter/'_' and
# contains at least one internal '.', translating every '.' in it to '_'.  The
# (?<!\.) lookbehind keeps it from biting into a dotted assembler directive
# that (defensively) survived copt, e.g. it will not touch `rodata` inside a
# stray `.rodata.str1.1`.
while (<>) {
    # Split each line into alternating unquoted / double-quoted segments so the
    # dot->underscore label rewrites never reach the CONTENTS of a string
    # literal.  copt has already lowered `.asciz "a.b.c"` to `DEFM "a.b.c"`, and
    # the generic Family 2/3 rule below would otherwise see the token `a.b.c`
    # inside the quotes and mangle it to `a_b_c` -- a silent runtime corruption
    # of every string literal whose text looks like a dotted identifier
    # (verified: `printf("x.y")` printed `x_y`).  The capture in split() keeps
    # the delimiters, and the (?:[^"\\]|\\.)* body skips over \" escapes so a
    # quote embedded in a string does not end the segment early.
    my @seg = split /("(?:[^"\\]|\\.)*")/, $_, -1;
    for my $s (@seg) {
        next if substr($s, 0, 1) eq '"';   # leave quoted string bodies intact
        # Family 1: strip the leading dot of .L labels, flatten any internal dots.
        $s =~ s/\.L([A-Za-z0-9_.]+)/ my $t=$1; $t=~tr:.:_:; "L$t" /ge;
        # Families 2 & 3: any identifier with internal dot(s) -> dots become '_'.
        $s =~ s/(?<![.\w])([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)/ my $t=$1; $t=~tr:.:_:; $t /ge;
    }
    print join('', @seg);
}
