


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
# recordbench is excluded as an XFAIL: recordbench.c has signed-integer-overflow
# UB in churn() (two masked int fields summed to <=0xfffe, exceeding INT_MAX on
# 16-bit int, THEN masked with & 0x7fff). clang legitimately emits `add nsw` and
# InstCombine drops the now-redundant mask, so the checksum differs (37157 vs the
# host-verified 4389). This is a bug in the TEST, not the compiler; sccz80 passes
# only by not exploiting the nsw. Tracked in ravn/z88dk#38 -- re-include this suite
# once recordbench.c is made UB-free (unsigned int fields).
ifeq ($(COMPILER),llvmz80)
SUBDIRS := $(filter-out far recordbench,$(SUBDIRS))
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
