# Dhrystone 2.1 for zcc +cpm/+test -compiler=llvmz80 (ravn/llvm-z80 backend).
#
# Mirrors ../z88dk-classic/Makefile but drives the llvmz80 (z80, 16-bit
# register ABI) clang instead of sdcc/sccz80.  Two z88dk-native paths:
#
#   make benchmark   -- +test -DTIMER build; the z88dk intrinsic_label(TIMER_*)
#                       markers become bare labels (see include/intrinsic.h
#                       __CLANG branch + lib/llvmz80/llvmz80_rules.1), and
#                       z88dk-ticks -start/-end counts cycles between them.
#                       No printf, no float -> a clean cycle/DMIPS number.
#
#   make verify      -- +cpm -DPRINTF build run under ntvcm to prove the
#                       self-validating "should be:" checks all pass.  dhry.h
#                       forces the %f printf converter (CLIB_OPT_PRINTF bit
#                       0x04000000) under PRINTF even though %f is only used
#                       under TIMEFUNC; the llvmz80 path has no float-math lib
#                       wired, so we drop that bit at build time with
#                       -pragma-define:CLIB_OPT_PRINTF=0x00000601 (%d %c %s).
#                       Requires ntvcm on PATH (or NTVCM=/path/to/ntvcm).

BIN:=dhry.bin
COM:=dhry.com
CPUFREQ:=4000000
RUNS:=20000
NTVCM?=ntvcm

Q=@
ifeq ($V,1)
Q=
endif

all:	benchmark

$(BIN):	dhry_1.c dhry_2.c dhry.h
	@echo "[-] Compiling Dhrystone (llvmz80, +test -DTIMER)..."
	$(Q)zcc +test -compiler=llvmz80 -O2 -DTIMER -D__Z88DK dhry_1.c dhry_2.c -o $(BIN) -m

benchmark:	$(BIN)
	@echo "[-] Measuring T-states (cycles) between the TIMER labels:"
	$(Q)TIMER_START=$$(grep '^TIMER_START ' dhry.map | awk '{print $$3}' | sed 's,^.,,' | tr 'A-Z' 'a-z') ; \
	TIMER_STOP=$$(grep '^TIMER_STOP ' dhry.map | awk '{print $$3}' | sed 's,^.,,' | tr 'A-Z' 'a-z') ; \
	echo "[-] From $${TIMER_START} to $${TIMER_STOP}" ; \
	z88dk-ticks $(BIN) -start $${TIMER_START} -end $${TIMER_STOP} -counter 4999999999 > dhrystone_ticks
	@echo "[-] Computing Dhrystones..."
	@CYC=$$(cat dhrystone_ticks | tr -d '\012') ; \
	echo "[-] cycles=$${CYC} for $(RUNS) runs @ $(CPUFREQ) Hz" ; \
	echo -n "[-] DMIPS = " ; \
	bash -c '{ echo -en "scale=5\n($(RUNS).0 / ('"$${CYC}"'.0 / $(CPUFREQ))) / 1757." ; }' | bc -l

$(COM):	dhry_1.c dhry_2.c dhry.h
	@echo "[-] Compiling Dhrystone (llvmz80, +cpm -DPRINTF, self-validating)..."
	$(Q)zcc +cpm -compiler=llvmz80 -O2 -DPRINTF -pragma-define:CLIB_OPT_PRINTF=0x00000601 \
		dhry_1.c dhry_2.c -o $(COM) -create-app

verify:	$(COM)
	@echo "[-] Running self-validation under ntvcm ($(RUNS) runs)..."
	$(Q)echo "$(RUNS)" | $(NTVCM) $(COM) | grep -A1 "Int_Glob:" ; \
	echo "[-] (full 'should be:' report: echo $(RUNS) | $(NTVCM) $(COM))"

clean:
	rm -f $(BIN) $(COM) dhrystone_ticks dhry.map zcc_opt.def *.o *.tmp

.PHONY: all benchmark verify clean
