export VERILATOR_ROOT= /home/juangranja/Documents/verilator-5.018

VERILATOR= $(VERILATOR_ROOT)/bin/verilator

.PHONY: verilate sim
verilate: .stamp.verilate
sim: waveform.vcd


# For sv testbench
TOP_MODULE = test_tb
verilator_srcs = rtl/tests2/counter.sv rtl/tests2/test_tb.sv rtl/tests2/test_ram_64.sv

verilate_command = 	$(VERILATOR) --timing
verilate_command +=	-Wall --trace -cc
verilate_command +=	$(verilator_srcs)
verilate_command +=	--top-module $(TOP_MODULE) 


verilate_command +=	-Werror-PINMISSING      \
                    -Werror-IMPLICIT        \
                    -Wno-fatal              \
                    -Wno-PINCONNECTEMPTY    \
                    -Wno-ASSIGNDLY          \
                    -Wno-DECLFILENAME       \
                    -Wno-UNUSED             \
                    -Wno-UNOPTFLAT          \
                    -Wno-BLKANDNBLK			\
					-Wno-GENUNNAMED

.stamp.verilate: $(verilator_srcs)
	@echo "### VERILATING ###"
	$(verilate_command) --binary -j $(shell nproc)
	@touch .stamp.verilate

waveform.vcd: .stamp.verilate # Because we verilate and build at once.
	@echo "### RUNNING ###"
	./obj_dir/V$(TOP_MODULE)

.PHONY:waves
waves: waveform.vcd
	gtkwave waveform.vcd gtkwave_waveform_setup.gtkw --rcvar 'fontname_signals Monospace 12' --rcvar 'fontname_waves Monospace 10' 

.PHONY:lint
lint: $(verilator_srcs)
	$(verilate_command) --lint-only

.PHONY:clean
clean:
	rm -rf ./obj_dir
	rm -rf waveform.vcd
	rm -rf .stamp.*
