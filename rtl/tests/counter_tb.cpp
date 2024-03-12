#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vcounter.h"
#include "Vcounter___024root.h"

vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    Vcounter *dut = new Vcounter;

    Verilated::traceEverOn(true);
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 99);
    m_trace->open("waveform.vcd");

    dut->rst_ni = 0;
    while (!contextp->gotFinish()) {
        dut->clk_i ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;

        if(sim_time > 4 && dut->clk_i == 1)
            dut->rst_ni = 1;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}