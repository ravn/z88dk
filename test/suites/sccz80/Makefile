include ../make.config



CFLAGS +=  -DNO_LOG_RUNNING -DNO_LOG_PASSED

# --opt-code-speed is an sccz80-only knob; 80cc (and other compilers) reject it.
OPT_CODE_SPEED := $(if $(filter sccz80,$(COMPILER)),-Cc--opt-code-speed=all)

TARGET_Z80N = test_z80n_rshift.bin test_z80n_lshift.bin
TARGET_8080 = test_8080_bitfields.bin test_8080_rshift.bin test_8080_lshift.bin test_8080_compare.bin test_8080_compare0.bin test_8080_compare_const.bin test_8080_compare_mconst.bin test_8080_mult.bin test_8080_division.bin test_8080_bitwise.bin
TARGET_8085 = test_8085_bitfields.bin test_8085_rshift.bin test_8085_lshift.bin test_8085_compare.bin test_8085_compare0.bin test_8085_compare_const.bin test_8085_compare_mconst.bin test_8085_mult.bin test_8085_division.bin test_8085_bitwise.bin
TARGET_GBZ80 = test_gbz80_rshift.bin test_gbz80_lshift.bin test_gbz80_compare.bin test_gbz80_compare0.bin test_gbz80_compare_const.bin test_gbz80_compare_mconst.bin test_gbz80_mult.bin test_gbz80_division.bin test_gbz80_bitfields.bin test_gbz80_bitwise.bin test_gbz80_uminus.bin test_gbz80_loops.bin
TARGET_R2KA = test_r2ka_bitfields.bin test_r2ka_rshift.bin test_r2ka_lshift.bin test_r2ka_compare.bin test_r2ka_compare0.bin test_r2ka_compare_const.bin test_r2ka_compare_mconst.bin test_r2ka_mult.bin test_r2ka_division.bin test_r2ka_bitwise.bin
TARGET_R4K = test_r4k_bitfields.bin test_r4k_rshift.bin test_r4k_lshift.bin test_r4k_compare.bin test_r4k_compare0.bin test_r4k_compare_const.bin test_r4k_compare_mconst.bin test_r4k_mult.bin test_r4k_division.bin test_r4k_bitwise.bin
TARGET_RC2014 = test_rc2014_rshift_CODE.bin test_rc2014_lshift_CODE.bin test_rc2014_compare_CODE.bin test_rc2014_compare0_CODE.bin test_rc2014_compare_const_CODE.bin test_rc2014_compare_mconst_CODE.bin test_rc2014_mult_CODE.bin test_rc2014_division_CODE.bin test_rc2014_bitfields_CODE.bin test_rc2014_bitwise_CODE.bin test_rc2014_uminus_CODE.bin test_rc2014_loops_CODE.bin
TARGET_KC160 = test_kc160_bitfields.bin test_kc160_rshift.bin test_kc160_lshift.bin test_kc160_compare.bin test_kc160_compare0.bin test_kc160_compare_const.bin test_kc160_compare_mconst.bin test_kc160_mult.bin test_kc160_division.bin test_kc160_bitwise.bin


CFILES = $(wildcard *.c)
# ravn/llvm-z80: these four suites hard-code sccz80-specific ABI or rely on
# non-standard / UB semantics, so their assertions legitimately fail under the
# standards-correct llvmz80 backend -- there is no backend behaviour to match
# (same rationale as far; UB items tracked under ravn/z88dk#38 -- recordbench's
# own UB has since been fixed to unsigned int and it is re-included):
#   sizeof.c    sizeof(double)==6 (sccz80 48-bit double; llvmz80 +test = 4) and
#               3-byte `far` pointers (far is unsupported under llvmz80).
#   offsetof.c  bare `test_s` tag (non-standard; clang requires `struct test_s`)
#               plus struct offsets that assume the 6-byte double.
#   mult.c      3*715827883 overflows signed 32-bit long (UB); clang emits nsw.
#   rshift.c    `0x8000000000000000LL` is unsigned per C (exceeds LLONG_MAX) so
#               its `>>` is logical, while the signed `val >>` is arithmetic;
#               the test assumes the two are equal.
# autoinit.c is NOT excluded -- its two ABI-specific asserts were made
# compiler-aware (__LLVMZ80) with standards-correct alternatives.
ifeq ($(COMPILER),llvmz80)
CFILES := $(filter-out sizeof.c offsetof.c mult.c rshift.c,$(CFILES))
endif
TARGET_Z80 := $(foreach test,$(CFILES:.c=),test_$(test).bin)

ifeq ($(COMPILER),xcc)
all: $(TARGET_Z80)
else
all: $(TARGET_Z80) $(TARGET_8080) $(TARGET_8085) $(TARGET_GBZ80) $(TARGET_Z80N) $(TARGET_R2KA) $(TARGET_RC2014) $(TARGET_R4K) $(TARGET_KC160)
endif



test_autoinit.bin: $(SOURCES) autoinit.c
	$(call compile, -DGENMATH -DMATH_LIBRARY="\"\\\"Genmath\\\"\"", -lm )
	$(runtest)

test_callee.bin: $(SOURCES) callee.c
	$(call compile,-lm)
	$(runtest)

test_compare.bin: $(SOURCES) compare.c
	$(call compile, $(OPT_CODE_SPEED),)
	$(runtest)


test_%.bin: $(SOURCES) %.c
	$(compile)
	$(runtest)

test_8080_%.bin: $(SOURCES) %.c
	$(compile_8080)
	$(runtest_8080)

test_8085_%.bin: $(SOURCES) %.c
	$(compile_8085)
	$(runtest_8085)

test_gbz80_%.bin: $(SOURCES) %.c
	$(compile_gbz80)
	$(runtest_gbz80)

test_z80n_%.bin: $(SOURCES) %.c
	$(compile_z80n)
	$(runtest_z80n)
	
test_r2ka_%.bin: $(SOURCES) %.c
	$(compile_r2ka)
	$(runtest_r2ka)

test_r4k_%.bin: $(SOURCES) %.c
	$(compile_r4k)
	$(runtest_r4k)

test_kc160_%.bin: $(SOURCES) %.c
	$(compile_kc160)
	$(runtest_kc160)


test_rc2014_%_CODE.bin: $(SOURCES) %.c
	$(compile_rc2014)
	$(runtest_rc2014)

clean:
	rm -f *.bin *.map $(OBJECTS) zcc_opt.def *~ *.lis
