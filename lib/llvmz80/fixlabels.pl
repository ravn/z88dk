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
    # Family 1: strip the leading dot of .L labels, flatten any internal dots.
    s/\.L([A-Za-z0-9_.]+)/ my $s=$1; $s=~tr:.:_:; "L$s" /ge;
    # Families 2 & 3: any identifier with internal dot(s) -> dots become '_'.
    s/(?<![.\w])([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)/ my $s=$1; $s=~tr:.:_:; $s /ge;
    print;
}
