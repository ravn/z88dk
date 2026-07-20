# Dhrystone 2.1 for zcc +test/+cpm -compiler=sdcc with the SDCC version-1
# calling convention (--sdcccall 1: 8-bit ret in A, 16-bit in DE, args in
# registers) instead of z88dk's default version-0 (stack frame, callee
# cleanup).
#
# Upstream SDCC defaults z80 to --sdcccall 1, but z88dk overrides it back to
# --sdcccall 0 because its entire precompiled clib + crt0 are built version 0.
# zcc deliberately does NOT forward --sdcccall (it is filtered), so we inject
# it with a one-line PATH shim on z88dk-zsdcc that keeps the rest of the zcc
# pipeline (dialect bridge, copt, libraries, crt0) intact.  This is SAFE for
# user code because z88dk's library headers pin each libc function to its own
# __smallc __z88dk_callee convention (immune to the compiler default) and crt0
# ignores main()'s return value -- so SDCC warning 296 is benign here.  The
# +cpm -DPRINTF verify build below confirms all self-validation checks pass.
#
#   make benchmark   -- +test -DTIMER build, z88dk-ticks -start/-end cycles.
#   make verify      -- +cpm -DPRINTF build run under ntvcm (needs ntvcm on
#                       PATH or NTVCM=/path/to/ntvcm).  The CLIB_OPT_PRINTF
#                       override drops the spurious %f converter (only used
#                       under TIMEFUNC) that dhry.h forces via #pragma output.

BIN:=dhry.bin
COM:=dhry.com
CPUFREQ:=4000000
RUNS:=20000
NTVCM?=ntvcm

# Resolve the REAL z88dk-zsdcc at parse time (before the shim shadows it),
# then generate a shim that injects --sdcccall 1.
SHIMDIR:=$(CURDIR)/.shim
REALZSDCC:=$(shell command -v z88dk-zsdcc)

Q=@
ifeq ($V,1)
Q=
endif

all:	benchmark

$(SHIMDIR)/z88dk-zsdcc:
	@mkdir -p $(SHIMDIR)
	@printf '#!/bin/bash\nexec "%s" --sdcccall 1 "$$@"\n' "$(REALZSDCC)" > $@
	@chmod +x $@

$(BIN):	dhry_1.c dhry_2.c dhry.h $(SHIMDIR)/z88dk-zsdcc
	@echo "[-] Compiling Dhrystone (sdcc --sdcccall 1, +test -DTIMER)..."
	$(Q)PATH="$(SHIMDIR):$$PATH" zcc +test -compiler=sdcc -SO3 \
		--max-allocs-per-node200000 -DTIMER -D__Z88DK \
		dhry_1.c dhry_2.c -o $(BIN) -m -lndos

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

$(COM):	dhry_1.c dhry_2.c dhry.h $(SHIMDIR)/z88dk-zsdcc
	@echo "[-] Compiling Dhrystone (sdcc --sdcccall 1, +cpm -DPRINTF)..."
	$(Q)PATH="$(SHIMDIR):$$PATH" zcc +cpm -compiler=sdcc -SO3 \
		--max-allocs-per-node200000 -DPRINTF \
		-pragma-define:CLIB_OPT_PRINTF=0x00000601 \
		dhry_1.c dhry_2.c -o $(COM) -create-app

verify:	$(COM)
	@echo "[-] Running self-validation under ntvcm ($(RUNS) runs)..."
	$(Q)echo "$(RUNS)" | $(NTVCM) $(COM) | grep -A1 "Int_Glob:" ; \
	echo "[-] (full 'should be:' report: echo $(RUNS) | $(NTVCM) $(COM))"

clean:
	rm -rf $(BIN) $(COM) dhrystone_ticks dhry.map zcc_opt.def *.o *.tmp $(SHIMDIR)

.PHONY: all benchmark verify clean
