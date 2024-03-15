export VERILATOR_ROOT= /home/juangranja/Documents/verilator-5.020

VERILATOR= $(VERILATOR_ROOT)/bin/verilator

.PHONY: verilate sim
verilate: .stamp.verilate
sim: waveform.vcd

# For sv testbench
#TOP_MODULE = test_tb
TOP_MODULE = sim_top

axi_src_dir = rtl/vendor/pulp-platform/axi/src

verilator_inc_dirs = $(axi_src_dir)/../include/ 	\
					rtl/vendor/pulp-platform/common_cells/include

verilator_src_pkgs = $(axi_src_dir)/axi_pkg.sv


# Note: riscv_pkg.sv is included with Flist.cva6 in original makefile.

# rtl/cva6_files/config_pkg.sv 
# rtl/cva6_files/cv64a6_imafdc_sv39_config_pkg.sv 
# rtl/cva6_files/riscv_pkg.sv	
# rtl/cva6_files/ariane_pkg.sv

verilator_src_pkgs += 	rtl/cva6_files/ariane_soc_pkg.sv \
						rtl/vendor/pulp-platform/common_cells/src/cf_math_pkg.sv

#$(filter %_pkg.sv, $(wildcard rtl/vendor/pulp-platform/common_cells/src/*.sv))
					

# rtl/tests/test_tb.sv

############# My sources ##############
verilator_srcs =  rtl/tests/sim_top.sv rtl/tests/test_ram_64.sv
#verilator_srcs += rtl/tests/axi_master.sv
verilator_srcs += rtl/tests/axi_master_test.sv


verilator_srcs += 	rtl/vendor/pulp-platform/axi_mem_if/src/axi2mem.sv



############# AXI etc sources ###########
verilator_srcs  +=	rtl/vendor/pulp-platform/common_cells/src/rstgen_bypass.sv                       \
					rtl/vendor/pulp-platform/common_cells/src/rstgen.sv                              \
					rtl/vendor/pulp-platform/common_cells/src/addr_decode.sv                         \
					rtl/vendor/pulp-platform/common_cells/src/stream_register.sv                     \
																								 	 \
					rtl/vendor/pulp-platform/common_cells/src/cdc_2phase.sv                          \
					rtl/vendor/pulp-platform/common_cells/src/spill_register_flushable.sv            \
					rtl/vendor/pulp-platform/common_cells/src/spill_register.sv                      \
					rtl/vendor/pulp-platform/common_cells/src/deprecated/fifo_v1.sv                  \
					rtl/vendor/pulp-platform/common_cells/src/deprecated/fifo_v2.sv                  \
					rtl/vendor/pulp-platform/common_cells/src/stream_delay.sv                        \
					rtl/vendor/pulp-platform/common_cells/src/lfsr_16bit.sv                          \
					\
					rtl/vendor/pulp-platform/common_cells/src/delta_counter.sv \
					rtl/vendor/pulp-platform/common_cells/src/rr_arb_tree.sv \
					rtl/vendor/pulp-platform/common_cells/src/lzc.sv \
					rtl/vendor/pulp-platform/common_cells/src/fifo_v3.sv \
					rtl/vendor/pulp-platform/common_cells/src/addr_decode_dync.sv  \
					rtl/vendor/pulp-platform/common_cells/src/counter.sv


# $(filter-out %_pkg.sv, $(wildcard rtl/vendor/pulp-platform/common_cells/src/*.sv)) \
# 					rtl/vendor/pulp-platform/common_cells/src/deprecated/fifo_v1.sv                  \
# 					rtl/vendor/pulp-platform/common_cells/src/deprecated/fifo_v2.sv
				 
verilator_srcs += 	$(axi_src_dir)/axi_intf.sv									\
					$(axi_src_dir)/axi_cut.sv                                 	\
					$(axi_src_dir)/axi_join.sv                                	\
					$(axi_src_dir)/axi_delayer.sv                             	\
					$(axi_src_dir)/axi_to_axi_lite.sv                         	\
					$(axi_src_dir)/axi_id_prepend.sv                          	\
					$(axi_src_dir)/axi_atop_filter.sv                         	\
					$(axi_src_dir)/axi_err_slv.sv                             	\
					$(axi_src_dir)/axi_mux.sv                                 	\
					$(axi_src_dir)/axi_demux.sv                               	\
					$(axi_src_dir)/axi_xbar.sv	




verilator_cpp_testbench = rtl/tests/counter_tb.cpp

verilate_command = 	$(VERILATOR) --no-timing
verilate_command +=	-Wall --trace -cc
verilate_command +=	$(verilator_src_pkgs)
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
# $(verilate_command) --build -j $(shell nproc)
	$(verilate_command) -j $(shell nproc)
# -CFLAGS '-DVL_DEBUG -ggdb'

# -CFLAGS '-DVL_DEBUG -ggdb' --debug --gdbbt

	@echo "### BUILDING ###"
	$(MAKE) -C obj_dir -f V$(TOP_MODULE).mk V$(TOP_MODULE) -j $(shell nproc)
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









