SRC_DIR := ../z88dk-classic
SRC     := $(SRC_DIR)/whetstone.c
BIN     := whet.bin

Q=@
ifeq ($V,1)
Q=
endif

all: benchmark

$(BIN): $(SRC)
	@echo "[-] Compiling Whetstone (llvmz80)..."
	$(Q)zcc +test -vn -compiler=llvmz80 -SO3 -DTIMER -D__Z88DK \
	    --math32 $(SRC) -o $(BIN) -m

benchmark: $(BIN)
	@echo "[-] Measuring T-states (cycles):"
	$(Q)TIMER_START=$$(grep '^TIMER_START ' $(BIN:.bin=.map) | awk '{print $$3}' | sed 's,^.,,' | tr 'A-Z' 'a-z') ; \
	TIMER_STOP=$$(grep '^TIMER_STOP ' $(BIN:.bin=.map) | awk '{print $$3}' | sed 's,^.,,' | tr 'A-Z' 'a-z') ; \
	echo "[-] From $${TIMER_START} to $${TIMER_STOP}" ; \
	z88dk-ticks $(BIN) -start $${TIMER_START} -end $${TIMER_STOP} -counter 4999999999 > whetstone_ticks
	@echo "[-] Computing KWIPS/MWIPS..."
	@bash -c '{ echo -en "scale=7\n100*10*1 / (" ; cat whetstone_ticks | tr -d "\012" ; echo ".0 / 4000000)" ; }' | bc -l | \
	    awk '{printf "KWIPS = %.4f\nMWIPS = %.7f\n", $$1, $$1/1000}'

clean:
	rm -f $(BIN) whet.map whetstone_ticks zcc_opt.def *.o
