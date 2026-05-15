// Copyright (c) 2026, Obsidian.dev
// Licensed under the MIT License.
// SPDX-License-Identifier: MIT

`ifndef M6800_ALU_SV
`define M6800_ALU_SV

`include "m6800_pkg.sv"

module m6800_alu (
  input  logic [7:0] a_i,
  input  logic [7:0] b_i,
  input  logic [7:0] cc_i,
  input  logic [4:0] op_i,
  output logic [7:0] out_o,
  output logic [7:0] cc_o
);

  import m6800_pkg::*;

  logic [8:0] res9;
  logic       h, i, n, z, v, c;
  logic [7:0] correction;
  logic [3:0] lsn, msn;

  always_comb begin
    h          = cc_i[CC_H];
    i          = cc_i[CC_I];
    n          = cc_i[CC_N];
    z          = cc_i[CC_Z];
    v          = cc_i[CC_V];
    c          = cc_i[CC_C];
    out_o      = 8'h00;
    res9       = 9'h000;
    correction = 8'h00;
    lsn        = a_i[3:0];
    msn        = a_i[7:4];

    unique case (op_i)
      5'h00: begin // ADD
        res9  = {1'b0, a_i} + {1'b0, b_i};
        out_o = res9[7:0];
        c     = res9[8];
        h     = (a_i[3] & b_i[3]) | (b_i[3] & !out_o[3]) | (a_i[3] & !out_o[3]);
        v     = (a_i[7] & b_i[7] & !out_o[7]) | (!a_i[7] & !b_i[7] & out_o[7]);
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h01: begin // SUB / CMP
        res9  = {1'b0, a_i} - {1'b0, b_i};
        out_o = res9[7:0];
        c     = res9[8];
        v     = (a_i[7] & !b_i[7] & !out_o[7]) | (!a_i[7] & b_i[7] & out_o[7]);
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h02: begin // AND / BIT / LDA / STA
        out_o = a_i & b_i;
        v     = 1'b0;
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h03: begin // OR
        out_o = a_i | b_i;
        v     = 1'b0;
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h04: begin // EOR
        out_o = a_i ^ b_i;
        v     = 1'b0;
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h05: begin // ADC
        res9  = {1'b0, a_i} + {1'b0, b_i} + {8'h00, cc_i[CC_C]};
        out_o = res9[7:0];
        c     = res9[8];
        h     = (a_i[3] & b_i[3]) | (b_i[3] & !out_o[3]) | (a_i[3] & !out_o[3]);
        v     = (a_i[7] & b_i[7] & !out_o[7]) | (!a_i[7] & !b_i[7] & out_o[7]);
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h06: begin // SBC
        res9  = {1'b0, a_i} - {1'b0, b_i} - {8'h00, cc_i[CC_C]};
        out_o = res9[7:0];
        c     = res9[8];
        v     = (a_i[7] & !b_i[7] & !out_o[7]) | (!a_i[7] & b_i[7] & out_o[7]);
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h07: begin // DAA
        if (lsn > 4'd9 || h) begin
          correction[3:0] = 4'h6;
        end
        if (msn > 4'd9 || c || (msn > 4'd8 && lsn > 4'd9)) begin
          correction[7:4] = 4'h6;
        end
        res9  = {1'b0, a_i} + {1'b0, correction};
        out_o = res9[7:0];
        n     = out_o[7];
        z     = (out_o == 8'h00);
        v     = 1'b0;
        c     = c | res9[8];
      end

      5'h08: begin // INC
        out_o = a_i + 8'h01;
        v     = (a_i == 8'h7f);
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h09: begin // DEC
        out_o = a_i - 8'h01;
        v     = (a_i == 8'h81);
        n     = out_o[7] ^ v;
        z     = (out_o == 8'h00);
      end

      5'h0A: begin // NEG
        res9  = 9'h000 - {1'b0, a_i};
        out_o = res9[7:0];
        c     = (a_i != 8'h00);
        v     = (a_i == 8'h80);
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h0B: begin // COM
        out_o = ~a_i;
        v     = 1'b0;
        c     = 1'b1;
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h0C: begin // LSR
        c     = a_i[0];
        out_o = {1'b0, a_i[7:1]};
        n     = 1'b0;
        v     = n ^ c;
        z     = (out_o == 8'h00);
      end

      5'h0D: begin // ROR
        logic old_c;
        old_c = cc_i[CC_C];
        c     = a_i[0];
        out_o = {old_c, a_i[7:1]};
        n     = out_o[7];
        v     = n ^ c;
        z     = (out_o == 8'h00);
      end

      5'h0E: begin // ASR
        c     = a_i[0];
        out_o = {a_i[7], a_i[7:1]};
        n     = out_o[7];
        v     = n ^ c;
        z     = (out_o == 8'h00);
      end

      5'h0F: begin // ASL
        c     = a_i[7];
        out_o = {a_i[6:0], 1'b0};
        n     = out_o[7];
        v     = n ^ c;
        z     = (out_o == 8'h00);
      end

      5'h10: begin // ROL
        logic old_c;
        old_c = cc_i[CC_C];
        c     = a_i[7];
        out_o = {a_i[6:0], old_c};
        n     = out_o[7];
        v     = n ^ c;
        z     = (out_o == 8'h00);
      end

      5'h11: begin // TST
        out_o = a_i;
        v     = 1'b0;
        c     = 1'b0;
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      5'h12: begin // CLR
        out_o = 8'h00;
        v     = 1'b0;
        c     = 1'b0;
        n     = 1'b0;
        z     = 1'b1;
      end

      5'h13: begin // PASS_B (for LDA/STA)
        out_o = b_i;
        v     = 1'b0;
        n     = out_o[7];
        z     = (out_o == 8'h00);
      end

      default: begin
        out_o = a_i;
      end
    endcase

    cc_o       = cc_i;
    cc_o[CC_H] = h;
    cc_o[CC_I] = i;
    cc_o[CC_N] = n;
    cc_o[CC_Z] = z;
    cc_o[CC_V] = v;
    cc_o[CC_C] = c;
  end

endmodule : m6800_alu

`endif // M6800_ALU_SV
