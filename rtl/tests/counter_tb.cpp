#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsim_top.h"
#include "Vsim_top___024root.h"


#include "Vsim_top_sim_top.h"
#include "Vsim_top_test_ram_64.h"

vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    Vsim_top *dut = new Vsim_top;

    Verilated::traceEverOn(true);
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 99);
    m_trace->open("waveform.vcd");

    //
    for(int i=0; i<10; i++)
    {
        dut->sim_top->i_test_ram->ram_memory_contents[i] = 0xa0000000b0000000 + 0x0000000100000001*i;
    }

    //

    dut->rst_ni = 0;
    while (!contextp->gotFinish()) {
        dut->clk_i ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;

        if(sim_time > 4 && dut->clk_i == 1)
            dut->rst_ni = 1;
    }

    printf("MEMORY CONTENTS\n");

    for(int i=0; i<100; i++)
    {
        uint32_t high = (dut->sim_top->i_test_ram->ram_memory_contents[i]) >> 32;
        uint32_t low = dut->sim_top->i_test_ram->ram_memory_contents[i] & 0x00000000ffffffff;

        printf("%08x: %08x %08x\n", 8*i, high, low);
        if((i+1)%4 == 0)
            printf("\n");
    }


    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}