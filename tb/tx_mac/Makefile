SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(PWD)/../../src/tx_mac.v
VERILOG_SOURCES += $(PWD)/../../src/sync_fifo.v  
VERILOG_SOURCES += $(PWD)/../../src/crc32.v
TOPLEVEL = tx_mac
MODULE = test_tx_mac
WAVES=1 pytest examples/simple_dff/test_dff.py
include $(shell cocotb-config --makefiles)/Makefile.sim
