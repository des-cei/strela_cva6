export VERILATOR_ROOT= /home/juangranja/Documents/verilator-5.020

VERILATOR= $(VERILATOR_ROOT)/bin/verilator

.PHONY: verilate sim
verilate: .stamp.verilate
sim: waveform.vcd


# For sv testbench
#TOP_MODULE = test_tb
TOP_MODULE = counter

axi_src_dir = rtl/vendor/pulp-platform/axi/src

verilator_inc_dirs = $(axi_src_dir)/../include/

# rtl/tests/test_tb.sv

verilator_srcs =  rtl/tests/counter.sv rtl/tests/test_ram_64.sv
#verilator_srcs += rtl/tests/axi_master.sv
verilator_srcs += rtl/tests/axi_master_test.sv
				 
verilator_srcs += $(axi_src_dir)/axi_pkg.sv $(axi_src_dir)/axi_intf.sv
verilator_srcs += rtl/vendor/pulp-platform/axi_mem_if/src/axi2mem.sv \
					rtl/vendor/pulp-platform/common_cells/src/fifo_v3.sv

verilator_cpp_testbench = rtl/tests/counter_tb.cpp

verilate_command = 	$(VERILATOR) --timing
verilate_command +=	-Wall --trace -cc
verilate_command +=	$(verilator_srcs)
verilate_command +=	--top-module $(TOP_MODULE)
verilate_command += $(foreach dir, ${verilator_inc_dirs}, +incdir+$(dir))

verilate_command +=	--exe $(verilator_cpp_testbench)

verilate_command +=	-Werror-PINMISSING      \
                    -Werror-IMPLICIT        \
                    -Wno-fatal              \
                    -Wno-PINCONNECTEMPTY    \
                    -Wno-ASSIGNDLY          \
                    -Wno-DECLFILENAME       \
                    -Wno-UNUSED             \
                    -Wno-UNOPTFLAT          \
                    -Wno-BLKANDNBLK			\
					-Wno-GENUNNAMED			\
											\
					-Wno-WIDTHEXPAND		\
					-Wno-WIDTHTRUNC			\
					-Wno-CASEINCOMPLETE		\
					-Wno-SYNCASYNCNET

.stamp.verilate: $(verilator_srcs) $(verilator_cpp_testbench)
	@echo "### VERILATING ###"
# $(verilate_command) --binary -j $(shell nproc)
	$(verilate_command) --build -j $(shell nproc)
	@touch .stamp.verilate

waveform.vcd: .stamp.verilate # Because we verilate and build at once.
	@echo "### RUNNING ###"
	./obj_dir/V$(TOP_MODULE)

.PHONY:waves
waves: waveform.vcd
	gtkwave waveform.vcd gtkwave_config/gtkwave_waveform_setup.gtkw --rcvar 'fontname_signals Monospace 10' --rcvar 'fontname_waves Monospace 10' 

.PHONY:lint
lint: $(verilator_srcs)
	$(verilate_command) --lint-only

.PHONY: test
test:
	echo $(wildcard $(axi_src_dir)/../include/axi/*.svh)

.PHONY:clean
clean:
	rm -rf ./obj_dir
	rm -rf waveform.vcd
	rm -rf .stamp.*
