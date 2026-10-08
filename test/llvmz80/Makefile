.PHONY: test tmpdir dhrystone

test:
	sh zcc_backend_smoke.sh
	sh run_minimal.sh

tmpdir:
	sh zcc_tmpdir.sh

DHRY_SRC = ../../support/benchmarks/dhrystone21

dhrystone:
	$(ZCC) +cpm -compiler=llvmz80 -O2 -DTIMER -create-app $(DHRY_SRC)/dhry_1.c $(DHRY_SRC)/dhry_2.c -o dhry -m
	z88dk-ticks -x dhry.map dhry.com -start TIMER_START -end TIMER_STOP -counter 4999999999
