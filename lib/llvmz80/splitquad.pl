#!/usr/bin/env perl
# splitquad.pl -- z88dk "-compiler=llvmz80" bridge pre-pass.
#
# clang (--target=z80 -S) emits 64-bit data as a GNU `.quad <value>` (8 bytes).
# z88dk's assembler has NO 8-byte data directive: `DEFQ` is only 4 bytes.  The
# copt rule set therefore cannot faithfully lower `.quad` by text substitution
# (it used to map `.quad %1` -> `DEFQ %1 / DEFQ 0`, truncating the 64-bit value
# to its low 32 bits and zeroing the real high 32 -- see ravn/z88dk#27).
#
# This pre-pass runs BEFORE copt and splits every `.quad <v>` into two little-
# endian 32-bit halves, which copt's correct `.long %1 -> DEFQ %1` rule (DEFQ =
# 4 bytes) then lowers faithfully:
#
#     .quad 0x4008000000000000   ->   .long 0            ; low  32
#                                     .long 1074266112   ; high 32 (0x40080000)
#
# Value forms handled (all emitted by clang): positive decimal, negative decimal
# (two's-complement), and 0xHEX.  A symbolic operand (address / `sym+off`) is
# zero-extended: `.long <operand>` then `.long 0` (Z80 addresses are 16-bit, so
# the high 32 bits are always 0).  64-bit arithmetic is done with Math::BigInt
# so it is exact regardless of the host perl's integer width.
use strict; use warnings;
use Math::BigInt;

my $MASK64 = Math::BigInt->new(1)->blsft(64)->bsub(1);   # 0xFFFFFFFFFFFFFFFF
my $MASK32 = Math::BigInt->new("0xFFFFFFFF");

while (my $line = <STDIN>) {
    if ($line =~ /^\s*\.quad\s+(\S+)/) {
        my $op = $1;
        if ($op =~ /^-?(0[xX][0-9a-fA-F]+|\d+)$/) {
            # numeric: split into exact little-endian 32-bit halves.
            # Emit with the same TAB layout clang uses (\t.long\t<v>) so copt's
            # `.long %1 -> DEFQ %1` rule matches (copt keys on the tab separator).
            my $v  = Math::BigInt->new($op)->band($MASK64);   # to unsigned 64
            my $lo = $v->copy->band($MASK32)->bstr;
            my $hi = $v->copy->brsft(32)->band($MASK32)->bstr;
            print "\t.long\t$lo\n\t.long\t$hi\n";
        } else {
            # symbolic address: low = the 16-bit address, high = 0
            print "\t.long\t$op\n\t.long\t0\n";
        }
        next;
    }
    print $line;
}
