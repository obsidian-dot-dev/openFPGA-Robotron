// Copyright (c) 2026, Obsidian.dev
// Licensed under the MIT License.
// SPDX-License-Identifier: MIT

`ifndef M6800_PKG_SV
`define M6800_PKG_SV

package m6800_pkg;

  // Condition Code Bits
  localparam int CC_C = 0; // Carry
  localparam int CC_V = 1; // Overflow
  localparam int CC_Z = 2; // Zero
  localparam int CC_N = 3; // Negative
  localparam int CC_I = 4; // Interrupt Mask
  localparam int CC_H = 5; // Half Carry

  // CPU Registers Structure
  typedef struct packed {
    logic [15:0] pc;
    logic [15:0] sp;
    logic [15:0] ix;
    logic [7:0]  acc_a;
    logic [7:0]  acc_b;
    logic [7:0]  cc; // H I N Z V C
  } regs_t;

  // Bus Cycle Types
  typedef enum logic [1:0] {
    BusIdle,
    BusRead,
    BusWrite,
    BusFetch
  } bus_cycle_e;

  // State Machine
  typedef enum logic [3:0] {
    StReset,
    StFetch,
    StDecode,
    StExecute,
    StWriteback,
    StInterrupt,
    StWai
  } state_e;

  // Opcodes
  localparam logic [7:0] OP_NOP   = 8'h01;
  localparam logic [7:0] OP_TAP   = 8'h06;
  localparam logic [7:0] OP_TPA   = 8'h07;
  localparam logic [7:0] OP_INX   = 8'h08;
  localparam logic [7:0] OP_DEX   = 8'h09;
  localparam logic [7:0] OP_CLV   = 8'h0A;
  localparam logic [7:0] OP_SEV   = 8'h0B;
  localparam logic [7:0] OP_CLC   = 8'h0C;
  localparam logic [7:0] OP_SEC   = 8'h0D;
  localparam logic [7:0] OP_CLI   = 8'h0E;
  localparam logic [7:0] OP_SEI   = 8'h0F;
  localparam logic [7:0] OP_SBA   = 8'h10;
  localparam logic [7:0] OP_CBA   = 8'h11;
  localparam logic [7:0] OP_TAB   = 8'h16;
  localparam logic [7:0] OP_TBA   = 8'h17;
  localparam logic [7:0] OP_DAA   = 8'h19;
  localparam logic [7:0] OP_ABA   = 8'h1B;
  localparam logic [7:0] OP_BRA   = 8'h20;

endpackage : m6800_pkg

`endif // M6800_PKG_SV
