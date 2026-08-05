


SUBDIRS = string ctype stdio stdlib target_io math md5 regex sccz80 zx far
# benchmark suites (also self-checking via host-verified assertEqual)
SUBDIRS += charbench crcbench intbench ptrbench sieve rle \
           sortbench queenbench searchbench switchbench \
           structbench vecbench recordbench maskbench \
           strbench listbench interpbench matrixbench \
           hashbench fixedbench histbench lexbench

ifeq ($(COMPILER),80cc)
SUBDIRS += long_ir debuginfo
endif

# ravn/llvm-z80 (compiler=llvmz80) does not support far pointers, so the far
# suite (sbrk_far/*_far) has no way to build under it -- exclude it here,
# following the existing per-compiler SUBDIRS convention above (80cc opts
# INTO extra suites; llvmz80 opts OUT of one it cannot support).
#
# recordbench was previously excluded as an XFAIL: recordbench.c had
# signed-integer-overflow UB in churn() (two masked int fields summed to
# <=0xfffe, exceeding INT_MAX on 16-bit int, THEN masked with & 0x7fff). clang
# legitimately emitted `add nsw` and InstCombine dropped the now-redundant mask,
# so the checksum differed (37157 vs the host-verified 4389). This was a bug in
# the TEST, not the compiler. FIXED in ravn/z88dk#38 by making the struct fields
# `unsigned int` (well-defined modular wrap on both 16-bit and 32-bit int), so
# recordbench is no longer excluded here.
#
# zx is excluded because every one of its 13 .c files is a thin C wrapper around
# a classic-clib `#asm ... #endasm` inline-assembly block (INCLUDE of the z80
# .asm display routines under test). clang / -compiler=llvmz80 has no `#asm`
# preprocessor directive, so each file fails at preprocessing with
# "invalid preprocessing directive". These tests exercise z80 asm library
# routines, not C codegen, so there is nothing for the clang backend to compile;
# exclude the whole suite (same rationale as far -- unsupportable, not a bug).
ifeq ($(COMPILER),llvmz80)
SUBDIRS := $(filter-out far zx,$(SUBDIRS))
endif


all: subdirs-all


subdirs-all: $(SUBDIRS)


clean: subdirs-clean

subdirs-clean:
	@for s in $(SUBDIRS); \
	do \
		$(MAKE) -C $$s clean ; \
	done


.PHONY:	subdirs-all $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@ all
