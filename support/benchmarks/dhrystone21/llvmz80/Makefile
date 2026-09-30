SRC_DIR := ../z88dk-classic
SRC     := $(SRC_DIR)/dhry_1.c $(SRC_DIR)/dhry_2.c
BIN     := dhry.bin

Q=@
ifeq ($V,1)
Q=
endif

all: benchmark

$(BIN): $(SRC)
	@echo "[-] Compiling Dhrystone (llvmz80)..."
	$(Q)zcc +test -vn -compiler=llvmz80 -SO3 -DTIMER -D__Z88DK \
	    $(SRC) -o dhry.bin -m

benchmark: $(BIN)
	@echo "[-] Measuring T-states (cycles):"
	$(Q)TIMER_START=$$(grep TIMER_START dhry.map | awk '{print $$3}' | sed 's,^.,,' | tr '[A-Z]' '[a-z]') ; \
	TIMER_STOP=$$(grep TIMER_STOP dhry.map | awk '{print $$3}' | sed 's,^.,,' | tr '[A-Z]' '[a-z]') ; \
	echo "[-] From $${TIMER_START} to $${TIMER_STOP}" ; \
	z88dk-ticks $< -start $${TIMER_START} -end $${TIMER_STOP} -counter 4999999999 > dhrystone_ticks
	@echo "[-] Computing Dhrystones..."
	@echo -n "[-] DMIPS = "
	@bash -c '{ echo -en "scale=5\n(20000.0 / (" ; cat dhrystone_ticks | tr -d "\012" ; echo  ".0 / 4000000)) / 1757." ; }' | bc -l

clean:
	rm -f dhry.bin dhry.map dhrystone_ticks zcc_opt.def *.o
