#!/usr/bin/env sh
# bridge_postproc.sh -- z88dk "-compiler=llvmz80" post-compile bridge.
#
# Turns the raw GNU-as-dialect assembly emitted by ravn/llvm-z80 clang
# (`clang --target=z80 -S`) into z80asm the z88dk assembler accepts.  Reads
# clang asm on stdin, writes z80asm on stdout.  Three stages that copt alone
# cannot do on its own (see below):
#
#   1. z88dk-copt <rules>   -- maps the bulk of the asm dialect: .text/.bss/
#      .rodata -> SECTION *; .globl -> GLOBAL; .asciz/.short/.byte/.zero ->
#      DEFM/DEFW/DEFB/DEFS; strips .file/.ident/.type/.size/.addrsig.
#      NB: 64-bit `.quad` is NOT handled by copt -- z88dk's DEFQ is only 4 bytes,
#      so a text-substitution rule cannot split the value (ravn/z88dk#27).  The
#      splitquad.pl pre-pass (stage 0) rewrites `.quad` into two `.long` halves
#      first, which copt's correct `.long -> DEFQ` (4-byte) rule then lowers.
#      Similarly, a large `.ascii "..."` (any const byte array >= ~100 bytes,
#      escaped) overflows copt's own 512-char line buffer (copt.c MAXLINE) so
#      its `.ascii -> DEFM` rule silently fails to match; splitascii.pl
#      (stage 0, alongside splitquad.pl) breaks any long `.ascii` line into
#      several short ones on real byte boundaries before copt ever sees it.
#   2. fixlabels.pl         -- copt tokenises on whitespace, so it cannot
#      rewrite labels containing dots (`.LBB0_4`, `L_.str.1`); perl does the
#      dot->underscore / leading-dot-strip rewrite copt cannot express.
#   3. awk header pass      -- emits the `EXTERN <sym>` import header for every
#      referenced extern (a self-inserting copt rule for this recurses and
#      explodes); drops GNU `.local`; hoists `.comm NAME,SIZE,ALIGN` into a
#      trailing `SECTION bss_compiler` block (z88dk crt0 zeroes bss_compiler).
#      NOTE: must be EXTERN (import), not GLOBAL (export) -- z88dk-z80asm's
#      demand-loader only searches libraries for EXTERN references, not GLOBAL.
#
# Args: $1 = copt binary (abs path)   $2 = copt cpu arg (e.g. -mz80)
#       $3 = copt rules file (llvmz80_rules.1)
# fixlabels.pl is a sibling of this script.
set -eu
COPT=$1; CPUARG=$2; RULES=$3
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

perl "$HERE/splitquad.pl" | perl "$HERE/splitascii.pl" | "$COPT" "$CPUARG" "$RULES" | perl "$HERE/fixlabels.pl" | awk '
  /^[ \t]*\.local[ \t]/ { next }
  /^[ \t]*\.comm[ \t]/ {
    split($2,c,","); cn[++nc]=c[1]; cs[nc]=c[2]; def[c[1]]=1; next
  }
  /^[A-Za-z_.][A-Za-z0-9_.$]*:/ { d=$0; sub(/:.*/,"",d); def[d]=1 }
  {
    L[NR]=$0
    n=split($0,t,/[ \t,()+\-]+/)
    for(i=1;i<=n;i++)
      if(t[i]~/^_[A-Za-z0-9_]+$/ || t[i]~/^L__[A-Za-z0-9_]+$/ || t[i]~/^l_[A-Za-z0-9_]+$/) r[t[i]]=1
  }
  END{
    for(s in r) if(!(s in def)) print "\tEXTERN\t" s
    for(i=1;i<=NR;i++) print L[i]
    if(nc>0){
      print "\tSECTION bss_compiler"
      for(i=1;i<=nc;i++){ print cn[i] ":"; print "\tDEFS " cs[i] }
    }
  }' | grep -v '__do_zero_bss' | grep -v 'Declaring this symbol'
# NOTE (ravn/llvm-z80#267, removed 2026-07-21): there used to be a final
#   perl -pe 's/\bjr\s+(c|nc|z|nz|pe|po|p|m)\s*,/jp $1,/gi;'
# stage here that rewrote every conditional `jr cc` -> `jp cc`.  It was a
# workaround from when clang's BranchRelaxation undercounted expanded pseudos
# (sized 0 in getInstSizeInBytes) and left out-of-range conditional jr in the
# textual .s.  That workaround was BOTH redundant and harmful:
#   * redundant: clang's Z80 backend already relaxes conditional jr itself
#     (isBranchOffsetInRange covers JR_Z/NZ/C/NC; insertBranch emits jr in-range
#     / jp out-of-range), so it never emits an out-of-range conditional jr.
#   * harmful: rewriting jr cc (2 B) -> jp cc (3 B) inflates the code by 1 B per
#     site AFTER clang has already run BranchRelaxation, growing the span of an
#     enclosing UNCONDITIONAL `jr` that clang correctly left in place at <=127 B
#     in its own model.  A single intervening jr->jp tipped fmt64.c @ -O2 from
#     127 to 128 ($80) -> z80asm "integer range".
# The proper fix is the #267 systemic getInstSizeInBytes sizing in the backend;
# with that in place clang's jr/jp choice is authoritative and the assembled
# bytes match its model exactly.  Do NOT reintroduce a jr<->jp rewrite here.
