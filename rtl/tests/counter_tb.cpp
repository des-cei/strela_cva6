#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsim_top.h"
#include "Vsim_top___024root.h"

// To access memory
#include "Vsim_top_sim_top.h"
#include "Vsim_top_test_ram_64.h"

// To access registers
#include "Vsim_top_axi_cgra_top__pi1.h"
#include "Vsim_top_test_csr__Tz17_TBz18.h"

// Register addresses
#include "register_addresses.h"

vluint64_t sim_time = 0;


// To be called before rising edge of the clock
void write_reg(Vsim_top *dut, uint32_t reg_addr, uint32_t reg_data)
{
    dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_addr = reg_addr;
    dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_write_data = reg_data;
    dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_we = 1;
}


void write_reg_eval(Vsim_top *dut, VerilatedVcdC *m_trace, uint32_t reg_addr, uint32_t reg_data)
{
    dut->clk_i = 0;  dut->eval();  m_trace->dump(sim_time++);
    dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_addr = reg_addr;
    dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_write_data = reg_data;
    dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_we = 1;
    dut->clk_i = 1;  dut->eval();  m_trace->dump(sim_time++);
}


uint32_t read_reg(Vsim_top *dut, uint32_t reg_addr)
{
    dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_addr = reg_addr;
    dut->eval();
    return dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_read_data;
}

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
        dut->clk_i = 0;  dut->eval();  m_trace->dump(sim_time++);
        dut->clk_i = 1;  dut->eval();  m_trace->dump(sim_time++);

        if(sim_time > 2)
            dut->rst_ni = 1;

        if(sim_time == 10)
        {
            // write_reg_eval(dut, m_trace, CG_CONTROL_STATUS_A, CG_CONTROL_STATUS_BIT_START_EXEC);
            write_reg_eval(dut, m_trace, CG_CONTROL_STATUS_A, CG_CONTROL_STATUS_BIT_LOAD_CONFIG);
        }

        if(sim_time == 100)
        {
            write_reg_eval(dut, m_trace, CG_IN_ADDR0_A, 0xa0001111);
            write_reg_eval(dut, m_trace, CG_IN_ADDR1_A, 0xb0002222);
        }
            

    }


    dut->clk_i = 0;
    dut->eval();

    // write_reg(dut, 0x14, 0xdead1234);

    dut->clk_i = 1;
    dut->eval();


    // dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_addr = 0x14; // reg_we, reg_write_data, reg_read_data
    // dut->eval();
    // printf("DATA: %x \n", dut->sim_top->i_axi_cgra_top->i_test_reg_interface->reg_read_data);


    printf("DATA: %x \n", read_reg(dut, 0x10));



    printf("MEMORY CONTENTS\n");




    for(int i=0; i<2; i++)
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


    // dut->rst_ni = 0;
    // while (!contextp->gotFinish()) {
    //     dut->clk_i ^= 1;
    //     dut->eval();
    //     m_trace->dump(sim_time);
    //     sim_time++;

    //     if(sim_time > 4 && dut->clk_i == 1)
    //         dut->rst_ni = 1;

    // }