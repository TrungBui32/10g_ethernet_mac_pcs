SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(PWD)/../../src/rx_mac.v
VERILOG_SOURCES += $(PWD)/../../src/crc32.v
TOPLEVEL = rx_mac
MODULE = test_rx_mac
include $(shell cocotb-config --makefiles)/Makefile.sim
