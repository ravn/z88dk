


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
ifeq ($(COMPILER),llvmz80)
SUBDIRS := $(filter-out far,$(SUBDIRS))
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
