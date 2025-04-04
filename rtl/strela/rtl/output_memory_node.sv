// Copyright 2024 CEI-UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Daniel Vazquez (daniel.vazquez@upm.es)

module output_memory_node
  import cgra_pkg::*;
  import obi_pkg::*;
(
  // Clock and reset
  input  logic        clk_i,
  input  logic        rst_ni,

  // Control
  input  logic        execute_i,
  output logic        done_o,

  // Configuration
  input  logic [31:0] output_addr_i,
  input  logic [15:0] output_size_i,
  
  // OBI memory master port
  output obi_req_t    masters_req_o,
  input  obi_resp_t   masters_resp_i,

  // Input data to the IDM
  input  logic [31:0] din_i,
  input  logic        din_v_i,
  output logic        din_r_o
);

  enum logic [1:0] {
    S_IDLE = 2'b00,
    S_MREQ = 2'b01,
    S_DONE = 2'b10
  } state, n_state;

  logic [15:0] addr_offset, n_addr_offset;

  logic [FIFO_PTR_WIDTH-1:0] data_count;
  logic full, empty, we, re;

  assign n_addr_offset = addr_offset + 16'h4;

  assign masters_req_o.we     = 1;
  assign masters_req_o.be     = 4'b1111;
  assign masters_req_o.addr   = output_addr_i + {16'h0, addr_offset};

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(~rst_ni) begin
      addr_offset <= '0;
      state <= S_IDLE;
    end else begin
      if(re) begin
        addr_offset <= n_addr_offset;
      end      
      state <= n_state;
    end
  end

  always_comb
  begin
    n_state = S_IDLE;
    masters_req_o.req = 0;
    done_o = 0;

    unique case (state)
      S_IDLE:
      begin
        if(execute_i) begin
          if(output_size_i == 0) begin
            n_state = S_DONE;
          end else begin
            n_state = S_MREQ;
          end
        end else begin
          n_state = S_IDLE;
        end        
      end
      S_MREQ:
      begin
        if(n_addr_offset >= output_size_i & re) begin
          n_state = S_DONE;
        end else begin
          n_state = S_MREQ;
        end
        masters_req_o.req = !empty;
      end
      S_DONE: 
      begin
        n_state = S_DONE;
        done_o = 1;
      end
      default : n_state = S_IDLE;
    endcase
  end

  assign din_r_o = !full;
  assign we = din_r_o & din_v_i;
  assign re = masters_req_o.req & masters_resp_i.gnt;

  fifo_v3 fifo_i
  (
    .clk_i        ( clk_i                 ),
    .rst_ni       ( rst_ni                ),
    .flush_i      ( 1'b0                  ),
    .testmode_i   ( 1'b0                  ),
    .usage_o      ( data_count            ),
    .data_i       ( din_i                 ),
    .push_i       ( we                    ),
    .full_o       ( full                  ),
    .data_o       ( masters_req_o.wdata   ),
    .pop_i        ( re                    ),
    .empty_o      ( empty                 )
  );

endmodule
