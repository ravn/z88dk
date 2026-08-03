include ../make.config

# ---------------------------------------------------------------------------
# run_check: run a built program under the emulator and decide pass/fail from
# the printed suite summary, NOT the emulator process exit code.
#
# Why: a +cpm .com program terminates via CP/M warm-boot (jp 0); z88dk-ticks
# then returns process exit code 1 regardless of the test result, so trusting
# that exit code makes every +cpm recipe RED even when the suite prints
# "8 run, 8 passed, 0 failed". Instead we parse the framework summary line
# "<run> run, <passed> passed, <failed> failed[, <xfail> xfail][, <n> XPASS]".
#
# A run is GREEN iff: run>0 AND failed==0 AND passed+xfail==run. The last term
# is essential: the framework increments exactly one counter per completed
# test, so passed+xfail==run only when the loop ran to the end. Without it a
# program that warm-boots MID-suite (sdcc does after test 4) can still emit a
# stale "8 run, 4 passed, 0 failed" line and false-green (4+0 != 8 -> caught).
# An XPASS bumps `failed`, so it also fails here (marker must be removed).
#
# $(1) = full emulator command incl. flags and target; $(2) = human label.
# ---------------------------------------------------------------------------
define run_check
	@echo "$(GREEN)" `date +%H:%M:%S` " Starting $(2) $(RESET)"
	@out=`printf '%s\n' '$(SCANF_INPUT)' | $(1) 2>&1`; \
	 printf '%s\n' "$$out"; \
	 printf '%s\n' "$$out" | grep -E '[0-9]+ run,' | tail -1 | awk '{ \
	   run=0; pass=0; fail=0; xf=0; \
	   for (i = 1; i <= NF; i++) { \
	     if ($$i ~ /^[0-9]+$$/) { n = $$i + 0; t = $$(i+1); \
	       if (t ~ /run/) run = n; \
	       else if (t ~ /passed/) pass = n; \
	       else if (t ~ /failed/) fail = n; \
	       else if (t ~ /xfail/) xf = n; } } \
	   exit !(run > 0 && fail == 0 && pass + xf == run) }' \
	   || { echo "$(RED)" `date +%H:%M:%S` " $(2) failure $(RESET)" ; exit 1; }
	@echo "$(GREEN)" `date +%H:%M:%S` " $(2) completed $(RESET)"
endef

# target_io — serial (printf/scanf) + disk (creat/write/lseek/read/close)
# under z88dk-ticks for multiple targets.
#
# Layout:
#   io_tests.c              shared tests
#   io_port.h               portable fcntl surface (tio_*)
#   fcntl_native.c          backend: native open/creat (CP/M, …)
#   fcntl_host.c            backend: ticks SYSCALL host files
#   ticks_host_fcntl.asm    SYSCALL wrappers for fcntl_host
#
# Adding a target: append a recipe below (compile line + runtest_* style
# ticks invocation). Prefer fcntl_native when the target's fcntl is
# emulated by ticks; use fcntl_host when only SYSCALL host files work.

SCANF_INPUT = 7 99

COMMON_NATIVE = io_tests.c fcntl_native.c $(SOURCES)
COMMON_HOST   = io_tests.c fcntl_host.c ticks_host_fcntl.asm $(SOURCES)

# -D string helpers for TIO_LABEL (sccz80/80cc)
LABEL = -DTIO_LABEL="\"\\\"$(1)\\\"\""

ALL_TARGETS = \
	test_cpm_z80.com \
	test_cpm_8085.com \
	test_cpm_new_z80.com \
	test_rc2014_z80_CODE.bin \
	test_rc2014_8085_CODE.bin \
	test_rc2014_cpm.com

# clang / -compiler=llvmz80 is a z80-only backend. The 8085 recipes
# (-clib=8085) target the 8085 ISA; the rc2014 host recipes use `#asm`
# SYSCALL wrappers (ticks_host_fcntl.asm) clang cannot preprocess; and the
# newlib recipes (-clib=new) pull far/newlib file I/O the clang backend does
# not support. All of them fail to build under llvmz80 (e.g. -clib=8085 +
# clang attribute headers -> "illegal identifier"). Restrict `all` to the
# native +cpm z80 recipe under llvmz80, mirroring the per-compiler suite
# opt-out used for far/zx in ../Makefile.
ifeq ($(COMPILER),llvmz80)
ALL_TARGETS = test_cpm_z80.com
endif

all: $(ALL_TARGETS)

# ---------------------------------------------------------------------------
# CP/M classic — native fcntl via BDOS; default subtype only (Z80 + 8085)
# ---------------------------------------------------------------------------

test_cpm_z80.com: $(COMMON_NATIVE)
	zcc +cpm -vn $(CFLAGS) $(call LABEL,CPM) $^ -o $@ -m -create-app
	$(call run_check,$(MACHINE) $@,cpm/z80 target_io)

test_cpm_8085.com: $(COMMON_NATIVE)
	zcc +cpm -vn -clib=8085 $(CFLAGS) $(call LABEL,CPM) $^ -o $@ -m -create-app
	$(call run_check,$(MACHINE) -m8085 $@,cpm/8085 target_io)

# ---------------------------------------------------------------------------
# CP/M newlib — BDOS FCB + character devices (+cpm -clib=new, Z80 only)
# ---------------------------------------------------------------------------

test_cpm_new_z80.com: $(COMMON_NATIVE)
	@# -startup=4 = DCIO console (BDOS 6); startup 0 uses BDOS 10 which ticks lacks
	@# -DTIO_CPM_DEVICES: CRT has stdrdr/stdpun/stdlst + cpm_device_file
	zcc +cpm -clib=new -startup=4 -vn $(CFLAGS) -DTIO_CPM_DEVICES $(call LABEL,CPM-NEW) \
		$^ -o $(@:.com=) -m -create-app
	@# -create-app may emit APP.COM; normalise for ticks
	@if [ -f APP.COM ]; then mv -f APP.COM $@; elif [ -f $(@:.com=_CODE.bin) ]; then cp $(@:.com=_CODE.bin) $@; fi
	@test -f $@ || { echo "missing $@ after link"; exit 1; }
	$(call run_check,$(MACHINE) $@,cpm/newlib z80 target_io)

# ---------------------------------------------------------------------------
# RC2014 basic — host SYSCALL fcntl; CODE.bin @ 0x9000; name has "rc2014"
# ---------------------------------------------------------------------------

test_rc2014_z80_CODE.bin: $(COMMON_HOST)
	zcc +rc2014 -vn $(CFLAGS) -DTIO_USE_HOST_FCNTL $(call LABEL,RC2014) \
		$^ -o $(@:_CODE.bin=.bin) -clib=new -subtype=basic -m
	$(call run_check,$(MACHINE) -pc 0x9000 $@,rc2014/z80 target_io)

test_rc2014_8085_CODE.bin: $(COMMON_HOST)
	zcc +rc2014 -vn $(CFLAGS) -DTIO_USE_HOST_FCNTL $(call LABEL,RC2014) \
		$^ -o $(@:_CODE.bin=.bin) -subtype=basic85 -m
	$(call run_check,$(MACHINE) -m8085 -pc 0x9000 $@,rc2014/8085 target_io)

# ---------------------------------------------------------------------------
# RC2014 CP/M subtype — native FCB fcntl via BDOS (newlib bridge)
# Output is CODE.bin @ 0x100; copy to .com for ticks CP/M mode.
# ---------------------------------------------------------------------------

test_rc2014_cpm.com: $(COMMON_NATIVE)
	@# -DTIO_CPM_DEVICES: subtype=cpm CRT instantiates stdrdr/stdpun/stdlst
	zcc +rc2014 -subtype=cpm -clib=new -vn $(CFLAGS) -DTIO_CPM_DEVICES $(call LABEL,RC2014-CPM) \
		$^ -o $(@:.com=) -m
	cp $(@:.com=_CODE.bin) $@
	$(call run_check,$(MACHINE) $@,rc2014/cpm target_io)

# ---------------------------------------------------------------------------
# Example: +test host fcntl (commented — enable when wanted)
# test_plus_test_z80.bin: $(COMMON_HOST)
#	zcc +test -vn $(CFLAGS) -DTIO_USE_HOST_FCNTL $(call LABEL,TEST) \
#		$^ -o $@ -m -lndos
#	@printf '%s\n' '$(SCANF_INPUT)' | $(MACHINE) $@ || exit 1
# ---------------------------------------------------------------------------

clean:
	rm -f *.com *.bin *.map *.o *.def zcc_opt.def *~ \
		suite.dat a.dat b.dat fopen.dat \
		test_cpm_* test_rc2014_* TEST_CPM_* TEST.DAT test.dat APP.COM app
