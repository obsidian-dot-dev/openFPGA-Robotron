// Copyright (c) 2026, Obsidian.dev
// Licensed under the MIT License.
// SPDX-License-Identifier: MIT

`ifndef M6800_REGFILE_SV
`define M6800_REGFILE_SV

`include "m6800_pkg.sv"

module m6800_regfile (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        clk_en_i,

  // Write Interface
  input  logic        pc_load_i,
  input  logic [15:0] pc_next_i,
  input  logic        sp_load_i,
  input  logic [15:0] sp_next_i,
  input  logic        ix_load_i,
  input  logic [15:0] ix_next_i,
  input  logic        acc_a_load_i,
  input  logic [7:0]  acc_a_next_i,
  input  logic        acc_b_load_i,
  input  logic [7:0]  acc_b_next_i,
  input  logic        cc_load_i,
  input  logic [7:0]  cc_next_i,

  // Read Interface
  output logic [15:0] pc_o,
  output logic [15:0] sp_o,
  output logic [15:0] ix_o,
  output logic [7:0]  acc_a_o,
  output logic [7:0]  acc_b_o,
  output logic [7:0]  cc_o
);

  import m6800_pkg::*;

  logic [15:0] pc /*verilator public*/;
  logic [15:0] sp /*verilator public*/;
  logic [15:0] ix /*verilator public*/;
  logic [7:0]  acc_a /*verilator public*/;
  logic [7:0]  acc_b /*verilator public*/;
  logic [7:0]  cc /*verilator public*/;

  assign pc_o = pc;
  assign sp_o = sp;
  assign ix_o = ix;
  assign acc_a_o = acc_a;
  assign acc_b_o = acc_b;
  assign cc_o = cc;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc    <= 16'h0000;
      sp    <= 16'hFFFF;
      ix    <= 16'h0000;
      acc_a <= 8'h00;
      acc_b <= 8'h00;
      cc    <= 8'hC0;
    end else if (clk_en_i) begin
      if (pc_load_i)    pc    <= pc_next_i;
      if (sp_load_i)    sp    <= sp_next_i;
      if (ix_load_i)    ix    <= ix_next_i;
      if (acc_a_load_i) acc_a <= acc_a_next_i;
      if (acc_b_load_i) acc_b <= acc_b_next_i;
      if (cc_load_i)    cc    <= cc_next_i;
    end
  end

endmodule : m6800_regfile

`endif // M6800_REGFILE_SV
