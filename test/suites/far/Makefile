include ../make.config



SOURCES += $(wildcard *.c) 
OBJECTS := $(SOURCES:.c=.o)
CFLAGS +=  -DNO_LOG_RUNNING -DNO_LOG_PASSED


all:	test.bin 


# ravn/llvm-z80 (compiler=llvmz80) has no far-pointer support (no sbrk_far /
# *_far entry points), so this suite cannot build under it. Skip cleanly
# instead of failing with "call to undeclared function 'sbrk_far'" -- this
# is a known, permanent compiler capability gap, not a regression to chase.
# The parent suites/Makefile also excludes `far` from SUBDIRS when
# COMPILER=llvmz80; this guard covers direct `make -C suites/far
# COMPILER=llvmz80 test.bin` invocations too.
ifeq ($(COMPILER),llvmz80)
test.bin:
	@echo "SKIP: far suite unsupported under COMPILER=llvmz80 (no far-pointer support in ravn/llvm-z80)"
else
test.bin: $(SOURCES)
	$(call compile,-lm)
	$(runtest)
endif

clean:
	rm -f test*.bin *.map $(OBJECTS) zcc_opt.def *~
