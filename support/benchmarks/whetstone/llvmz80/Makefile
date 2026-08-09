# Whetstone (double-precision, IEEE-754 binary32) for zcc +cpm -compiler=llvmz80
# (ravn/llvm-z80 backend).  Mirrors ../../dhrystone21/llvmz80/Makefile.
#
# Under llvmz80, `double` == float32 (math32).  Beyond the integer benchmarks a
# FLOATING-POINT whole program needs the #277 soft-float ARITHMETIC bridges
# (__addsf3/__cmpsf2/__floatsisf), passed as explicit sources (not in the default
# clib link set).  --math32 selects the f32 libm.
#
# The transcendentals (exp/log/sin/cos/atan) need NO bridge: the fix is in the
# header.  math32 already ships `#define exp(x) exp_fastcall(x)` routing (the
# _fastcall entries alias the register-ABI _m32_*f cores), but it was gated
# `#ifndef __STDC_ABI_ONLY`, which clang defines -- so clang fell through to the
# plain stack-wrapper entries and, passing the f32 arg in registers, got garbage
# (0).  math_math32.h now also fires that routing for llvmz80 on the z80 target
# (`|| (defined(__LLVMZ80) && defined(__Z80__))`, sm83 excluded), so clang's
# z80_fastcall hits _m32_*f directly -- header-only, no bridge, no lib rebuild.
# See ../WHETSTONE_LLVMZ80_FINDING.md.
#
#   make benchmark   -- +cpm -DTIMER build; z88dk-ticks counts T-states between
#                       the intrinsic_label(TIMER_*) markers -> a cycle count and
#                       KWIPS @ CPUFREQ.  Writes whetstone_ticks.
#   make verify      -- +cpm -DSELFCHECK build run under ntvcm; module 11 must
#                       converge to X~=0.83467 (readme.txt reference).  Prints
#                       WHET-SELFCHECK: PASS/FAIL using only %d/%s (float printf
#                       is unreliable on the classic/llvmz80 path).  MUST pass
#                       before any timing is trusted.

SRC     := ../whetstone.c
BIN     := whet.bin
COM     := whet.com
CPUFREQ := 4000000
NTVCM   ?= ntvcm

# bridges (relative to this lane dir: whetstone/llvmz80 -> z88dk/libsrc/l/llvmz80)
BR       := ../../../../libsrc/l/llvmz80
MATH32   := ../../../../libsrc
BRIDGES  := $(BR)/__addsf3.asm $(BR)/__cmpsf2.asm $(BR)/__floatsisf.asm
FLOAT    := -mllvm -z80-float-sdcccall0 --math32 -L$(MATH32)

Q=@
ifeq ($V,1)
Q=
endif

all: benchmark

$(BIN): $(SRC)
	@echo "[-] Compiling Whetstone (llvmz80 -O3, +cpm -DTIMER)..."
	$(Q)zcc +cpm -compiler=llvmz80 -O3 -DTIMER $(FLOAT) $(BRIDGES) $(SRC) -o whet -create-app -m
	$(Q)cp -f whet $(BIN); cp -f whet.map whet_bin.map 2>/dev/null || true

benchmark: $(BIN)
	@echo "[-] Measuring T-states between the TIMER labels:"
	$(Q)TS=$$(grep '^TIMER_START ' whet.map | awk '{print $$3}' | sed 's,^.,,' | tr 'A-Z' 'a-z') ; \
	TE=$$(grep '^TIMER_STOP ' whet.map | awk '{print $$3}' | sed 's,^.,,' | tr 'A-Z' 'a-z') ; \
	echo "[-] From $${TS} to $${TE}" ; \
	z88dk-ticks $(COM) -start $${TS} -end $${TE} -counter 9999999999 > whetstone_ticks ; \
	CYC=$$(tr -d '\n' < whetstone_ticks) ; \
	echo "[-] cycles=$${CYC} for 1,000,000 Whetstone instructions (LOOP=10, II=1)" ; \
	KWIPS=$$(echo "scale=2; 1000000/($${CYC}/$(CPUFREQ))/1000" | bc -l) ; \
	printf '[-] KWIPS @ %d Hz = %s\n' "$(CPUFREQ)" "$${KWIPS}"

verify:
	@echo "[-] Building self-validating Whetstone (llvmz80 -O3, +cpm -DSELFCHECK)..."
	$(Q)zcc +cpm -compiler=llvmz80 -O3 -DSELFCHECK $(FLOAT) $(BRIDGES) $(SRC) -o whetsc -create-app
	@echo "[-] Running module-11 convergence check under ntvcm:"
	$(Q)$(NTVCM) whetsc.com | tr -d '\r' | grep "WHET-SELFCHECK"

clean:
	rm -f whet $(BIN) $(COM) whetsc whetsc.com whetstone_ticks whet.map whet_bin.map \
	      zcc_opt.def *.o *.tmp *_BSS.bin

.PHONY: all benchmark verify clean
