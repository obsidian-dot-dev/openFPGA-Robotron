// Copyright (c) 2026, Obsidian.dev
// Licensed under the MIT License.
// SPDX-License-Identifier: MIT

`ifndef M6800_CORE_SV
`define M6800_CORE_SV

`include "m6800_pkg.sv"
`include "m6800_alu.sv"

module m6800_core (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        clk_en_i,

  // Interrupts & Control
  input  logic        irq_ni,
  input  logic        nmi_ni,
  input  logic        halt_ni,

  // Bus Interface
  output logic [15:0] addr_o,
  input  logic [7:0]  data_i,
  output logic [7:0]  data_o,
  output logic        we_o,
  output logic        re_o,
  output logic        vma_o,
  output logic        rw_no,

  output logic [15:0] pc_o
);

  import m6800_pkg::*;

  // Internal Registers
  logic [15:0] pc /*verilator public*/;
  logic [15:0] sp /*verilator public*/;
  logic [15:0] ix /*verilator public*/;
  logic [7:0]  acc_a /*verilator public*/;
  logic [7:0]  acc_b /*verilator public*/;
  logic [7:0]  cc /*verilator public*/;
  logic [3:0]  state /*verilator public*/;
  logic [3:0]  cycle_cnt /*verilator public*/;
  logic [7:0]  opcode /*verilator public*/;
  logic [15:0] ea /*verilator public*/;
  logic [15:0] res16 /*verilator public*/;

  // Interrupt synchronization
  logic        int_nmi_latch;
  logic        nmi_sync_0, nmi_sync_1, nmi_pending;
  wire         irq_pending = !irq_ni && !cc[CC_I];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      nmi_sync_0  <= 1'b1;
      nmi_sync_1  <= 1'b1;
      nmi_pending <= 1'b0;
    end else if (clk_en_i) begin
      nmi_sync_0 <= nmi_ni;
      nmi_sync_1 <= nmi_sync_0;
      if (!nmi_sync_0 && nmi_sync_1) begin
        nmi_pending <= 1'b1;
      end else if (state == 4'd5 && cycle_cnt == 4'd0) begin
        nmi_pending <= 1'b0;
      end
    end
  end

  // Combinatorial signals
  logic [15:0] mul_res;
  assign mul_res = acc_a * acc_b;

  logic [15:0] reg_val;

  // ALU Signals
  logic [7:0]  alu_a, alu_b, alu_out, alu_cc_out;
  logic [4:0]  alu_op;

  m6800_alu alu_inst (
    .a_i   (alu_a),
    .b_i   (alu_b),
    .cc_i  (cc),
    .op_i  (alu_op),
    .out_o (alu_out),
    .cc_o  (alu_cc_out)
  );

  // Control Signals
  logic branch_taken;

  assign pc_o  = pc;
  assign rw_no = !we_o;

  // --- COMBINATORIAL ADDRESS LOGIC ---
  always_comb begin
    addr_o = pc;
    we_o   = 1'b0;
    re_o   = 1'b0;
    data_o = 8'h00;
    vma_o  = (state != 4'd0); // VMA inactive during Reset state 0

    case (state)
      4'd0: begin // StReset
        vma_o = 1'b0;
        if (cycle_cnt == 4'd0) begin
          addr_o = 16'hFFFE;
          re_o   = 1'b1;
        end else if (cycle_cnt == 4'd1) begin
          addr_o = 16'hFFFF;
          re_o   = 1'b1;
        end
      end

      4'd1: begin // StFetch
        addr_o = pc;
        re_o   = 1'b1;
      end

      4'd5: begin // StInterrupt
        if (cycle_cnt <= 4'd6) begin
          addr_o = sp - {12'h000, cycle_cnt};
          we_o   = 1'b1;
          unique case (cycle_cnt)
            4'd0: data_o = pc[7:0];
            4'd1: data_o = pc[15:8];
            4'd2: data_o = ix[7:0];
            4'd3: data_o = ix[15:8];
            4'd4: data_o = acc_a;
            4'd5: data_o = acc_b;
            4'd6: data_o = cc;
            default: data_o = 8'h00;
          endcase
        end else if (cycle_cnt == 4'd7) begin
          addr_o = int_nmi_latch ? 16'hFFFC : 16'hFFF8;
          re_o   = 1'b1;
        end else if (cycle_cnt == 4'd8) begin
          addr_o = int_nmi_latch ? 16'hFFFD : 16'hFFF9;
          re_o   = 1'b1;
        end
      end

      4'd3: begin // StExecute
        case (opcode)
          // 1. IMM (8-bit)
          8'h80, 8'h81, 8'h82, 8'h84, 8'h85, 8'h86, 8'h88, 8'h89, 8'h8A, 8'h8B,
          8'hC0, 8'hC1, 8'hC2, 8'hC4, 8'hC5, 8'hC6, 8'hC8, 8'hC9, 8'hCA, 8'hCB: begin
            addr_o = pc;
            re_o   = 1'b1;
          end

          // 2. DIR (8-bit)
          8'h90, 8'h91, 8'h92, 8'h94, 8'h95, 8'h96, 8'h97, 8'h98, 8'h99, 8'h9A, 8'h9B,
          8'hD0, 8'hD1, 8'hD2, 8'hD4, 8'hD5, 8'hD6, 8'hD7, 8'hD8, 8'hD9, 8'hDA, 8'hDB: begin
            if (cycle_cnt == 4'd1) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              addr_o = {8'h00, ea[7:0]};
              if (opcode[3:0] == 4'h7) we_o = 1'b1;
              else                     re_o = 1'b1;
              data_o = opcode[6] ? acc_b : acc_a;
            end
          end

          // 3. EXT (8-bit)
          8'hB0, 8'hB1, 8'hB2, 8'hB4, 8'hB5, 8'hB6, 8'hB7, 8'hB8, 8'hB9, 8'hBA, 8'hBB,
          8'hF0, 8'hF1, 8'hF2, 8'hF4, 8'hF5, 8'hF6, 8'hF7, 8'hF8, 8'hF9, 8'hFA, 8'hFB: begin
            if (cycle_cnt == 4'd1 || cycle_cnt == 4'd2) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd3) begin
              addr_o = ea;
              if (opcode[3:0] == 4'h7) we_o = 1'b1;
              else                     re_o = 1'b1;
              data_o = opcode[6] ? acc_b : acc_a;
            end
          end

          // 4. IDX (8-bit)
          8'hA0, 8'hA1, 8'hA2, 8'hA4, 8'hA5, 8'hA6, 8'hA7, 8'hA8, 8'hA9, 8'hAA, 8'hAB,
          8'hE0, 8'hE1, 8'hE2, 8'hE4, 8'hE5, 8'hE6, 8'hE7, 8'hE8, 8'hE9, 8'hEA, 8'hEB: begin
            if (cycle_cnt == 4'd1) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              addr_o = ix + {8'h00, ea[7:0]};
              if (opcode[3:0] == 4'h7) we_o = 1'b1;
              else                     re_o = 1'b1;
              data_o = opcode[6] ? acc_b : acc_a;
            end
          end

          // 5. IMM (16-bit)
          8'h8C, 8'hCE, 8'h8E: begin
            if (cycle_cnt == 4'd1 || cycle_cnt == 4'd2) begin
              addr_o = pc;
              re_o   = 1'b1;
            end
          end

          // 6. DIR (16-bit)
          8'h9E, 8'hDE, 8'h9C: begin // LDX, LDS, CPX
            if (cycle_cnt == 4'd1) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              addr_o = {8'h00, ea[7:0]};
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd3) begin
              addr_o = {8'h00, ea[7:0]} + 16'h1;
              re_o   = 1'b1;
            end
          end
          8'h9F, 8'hDF: begin // STX, STS
            if (cycle_cnt == 4'd1) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              addr_o = {8'h00, ea[7:0]};
              we_o   = 1'b1;
              data_o = opcode[6] ? ix[15:8] : sp[15:8];
            end else if (cycle_cnt == 4'd3) begin
              addr_o = {8'h00, ea[7:0]} + 16'h1;
              we_o   = 1'b1;
              data_o = opcode[6] ? ix[7:0] : sp[7:0];
            end
          end

          // 7. EXT (16-bit)
          8'hBE, 8'hFE, 8'hBC: begin // LDX, LDS, CPX
            if (cycle_cnt == 4'd1 || cycle_cnt == 4'd2) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd3) begin
              addr_o = ea;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd4) begin
              addr_o = ea + 16'h1;
              re_o   = 1'b1;
            end
          end
          8'hBF, 8'hFF: begin // STX, STS
            if (cycle_cnt == 4'd1 || cycle_cnt == 4'd2) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd3) begin
              addr_o = ea;
              we_o   = 1'b1;
              data_o = opcode[6] ? ix[15:8] : sp[15:8];
            end else if (cycle_cnt == 4'd4) begin
              addr_o = ea + 16'h1;
              we_o   = 1'b1;
              data_o = opcode[6] ? ix[7:0] : sp[7:0];
            end
          end

          // 8. IDX (16-bit)
          8'hAE, 8'hEE, 8'hAC: begin // LDX, LDS, CPX
            if (cycle_cnt == 4'd1) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              addr_o = ix + {8'h00, ea[7:0]};
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd3) begin
              addr_o = ix + {8'h00, ea[7:0]} + 16'h1;
              re_o   = 1'b1;
            end
          end
          8'hAF, 8'hEF: begin // STX, STS
            if (cycle_cnt == 4'd1) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              addr_o = ix + {8'h00, ea[7:0]};
              we_o   = 1'b1;
              data_o = opcode[6] ? ix[15:8] : sp[15:8];
            end else if (cycle_cnt == 4'd3) begin
              addr_o = ix + {8'h00, ea[7:0]} + 16'h1;
              we_o   = 1'b1;
              data_o = opcode[6] ? ix[7:0] : sp[7:0];
            end
          end

          // 9. Stack Ops
          8'h36, 8'h37: begin // PSH
            if (cycle_cnt == 4'd1) begin
              addr_o = sp;
              we_o   = 1'b1;
              data_o = (opcode == 8'h36) ? acc_a : acc_b;
            end
          end
          8'h32, 8'h33: begin // PUL
            if (cycle_cnt == 4'd1) begin
              addr_o = sp + 16'h1;
              re_o   = 1'b1;
            end
          end
          8'h38: begin // PULX
            if (cycle_cnt == 4'd1) begin
              addr_o = sp + 16'h1;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              addr_o = sp + 16'h2;
              re_o   = 1'b1;
            end
          end
          8'h3A: begin // ABX
            if (cycle_cnt >= 4'd1 && cycle_cnt <= 4'd3) begin
              addr_o = pc;
              re_o   = 1'b0;
            end
          end
          8'h3D: begin // MUL
            if (cycle_cnt >= 4'd1 && cycle_cnt <= 4'd8) begin
              addr_o = pc;
              re_o   = 1'b0;
            end
          end
          8'h39: begin // RTS
            if (cycle_cnt == 4'd1) begin
              addr_o = sp + 16'h1;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              addr_o = sp + 16'h2;
              re_o   = 1'b1;
            end
          end
          8'h3B: begin // RTI
            if (cycle_cnt >= 4'd1 && cycle_cnt <= 4'd7) begin
              addr_o = sp + {12'h000, cycle_cnt};
              re_o   = 1'b1;
            end
          end
          8'h3E: begin // WAI
            if (cycle_cnt >= 4'd1 && cycle_cnt <= 4'd7) begin 
              addr_o = sp - {12'h000, cycle_cnt - 4'd1};
              we_o   = 1'b1; 
              unique case (cycle_cnt)
                4'd1: data_o = pc[7:0];
                4'd2: data_o = pc[15:8];
                4'd3: data_o = ix[7:0];
                4'd4: data_o = ix[15:8];
                4'd5: data_o = acc_a;
                4'd6: data_o = acc_b;
                4'd7: data_o = cc;
                default: data_o = 8'h00;
              endcase
            end
          end
          8'h3F: begin // SWI
            if (cycle_cnt >= 4'd1 && cycle_cnt <= 4'd7) begin 
              addr_o = sp - {12'h000, cycle_cnt - 4'd1};
              we_o   = 1'b1; 
              unique case (cycle_cnt)
                4'd1: data_o = pc[7:0];
                4'd2: data_o = pc[15:8];
                4'd3: data_o = ix[7:0];
                4'd4: data_o = ix[15:8];
                4'd5: data_o = acc_a;
                4'd6: data_o = acc_b;
                4'd7: data_o = cc;
                default: data_o = 8'h00;
              endcase
            end else if (cycle_cnt == 4'd8) begin
              addr_o = 16'hFFFA;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd9) begin
              addr_o = 16'hFFFB;
              re_o   = 1'b1;
            end
          end
          8'h3C: begin // PSHX
            if (cycle_cnt == 4'd1) begin
              addr_o = sp;
              we_o   = 1'b1;
              data_o = ix[7:0];
            end else if (cycle_cnt == 4'd2) begin
              addr_o = sp - 16'h1;
              we_o   = 1'b1;
              data_o = ix[15:8];
            end
          end

          // 10. Branches
          8'h20, 8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28, 8'h29, 8'h2A, 8'h2B, 8'h2C, 8'h2D, 8'h2E, 8'h2F: begin
            if (cycle_cnt == 4'd1) begin
              addr_o = pc;
              re_o   = 1'b1;
            end
          end

          // 11. Illegal/Redundant Fetch
          8'h00, 8'h02, 8'h03, 8'h04, 8'h05, 8'h14, 8'h15, 8'h18, 8'h1C, 8'h1D, 8'h1E, 8'h1F,
          8'h41, 8'h42, 8'h45, 8'h4B, 8'h4E, 8'h51, 8'h52, 8'h55, 8'h5B, 8'h5E,
          8'h61, 8'h62, 8'h65, 8'h6B, 8'h71, 8'h72, 8'h75, 8'h7B,
          8'h83, 8'h87, 8'h8F, 8'h93, 8'hA3, 8'hB3, 8'hC3, 8'hC7, 8'hCC, 8'hCD, 8'hCF, 8'hD3, 8'hDC, 8'hDD, 8'hE3, 8'hEC, 8'hED, 8'hF3, 8'hFC, 8'hFD: begin
            if (cycle_cnt == 4'd1) begin
              addr_o = pc - 16'h1;
              re_o   = 1'b1;
            end else begin
              addr_o = pc;
              re_o   = 1'b0;
            end
          end

          8'h12, 8'h13: begin
            if (cycle_cnt == 4'd1) begin
              addr_o = sp + 16'h1;
              re_o   = 1'b1;
            end
          end

          // 12. Indexed Unary (6x)
          8'h60, 8'h63, 8'h64, 8'h66, 8'h67, 8'h68, 8'h69, 8'h6A, 8'h6C, 8'h6D, 8'h6E, 8'h6F: begin
            if (cycle_cnt == 4'd1) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd2) begin
              if (opcode == 8'h6E) begin
                addr_o = ix + {8'h00, ea[7:0]}; // JMP IDX
                re_o   = 1'b1;
              end else begin
                addr_o = ix + {8'h00, ea[7:0]};
                re_o   = 1'b1;
              end
            end else if (cycle_cnt == 4'd3) begin
              if (opcode[3:0] != 4'hD && opcode != 8'h6E) begin
                addr_o = ix + {8'h00, ea[7:0]};
                we_o   = 1'b1;
                data_o = alu_out;
              end
            end
          end

          // 13. Extended Unary (7x)
          8'h70, 8'h73, 8'h74, 8'h76, 8'h77, 8'h78, 8'h79, 8'h7A, 8'h7C, 8'h7D, 8'h7E, 8'h7F: begin
            if (cycle_cnt == 4'd1 || cycle_cnt == 4'd2) begin
              addr_o = pc;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd3) begin
              addr_o = ea;
              re_o   = 1'b1;
            end else if (cycle_cnt == 4'd4) begin
              if (opcode[3:0] != 4'hD && opcode != 8'h7E) begin
                addr_o = ea;
                we_o   = 1'b1;
                data_o = alu_out;
              end
            end
          end

          // 14. BSR / JSR
          8'h8D, 8'h9D, 8'hAD, 8'hBD: begin
            if (opcode == 8'h8D || opcode == 8'h9D || opcode == 8'hAD) begin // BSR, JSR DIR, JSR IDX
              if (cycle_cnt == 4'd1) begin addr_o = pc; re_o = 1'b1; end
              else if (cycle_cnt == 4'd2) begin addr_o = sp; we_o = 1'b1; data_o = pc[7:0]; end
              else if (cycle_cnt == 4'd3) begin addr_o = sp - 16'h1; we_o = 1'b1; data_o = pc[15:8]; end
            end else if (opcode == 8'hBD) begin // JSR EXT
              if (cycle_cnt == 4'd1 || cycle_cnt == 4'd2) begin addr_o = pc; re_o = 1'b1; end
              else if (cycle_cnt == 4'd3) begin addr_o = sp; we_o = 1'b1; data_o = pc[7:0]; end
              else if (cycle_cnt == 4'd4) begin addr_o = sp - 16'h1; we_o = 1'b1; data_o = pc[15:8]; end
            end
          end

          8'h01: ; // NOP
          default: ;
        endcase
      end
      default: ;
    endcase
  end

  // Branch Condition Logic
  always_comb begin
    case (opcode)
      8'h20: branch_taken = 1'b1;
      8'h21: branch_taken = 1'b0;
      8'h22: branch_taken = !(cc[CC_C] | cc[CC_Z]);
      8'h23: branch_taken = (cc[CC_C] | cc[CC_Z]);
      8'h24: branch_taken = !cc[CC_C];
      8'h25: branch_taken = cc[CC_C];
      8'h26: branch_taken = !cc[CC_Z];
      8'h27: branch_taken = cc[CC_Z];
      8'h28: branch_taken = !cc[CC_V];
      8'h29: branch_taken = cc[CC_V];
      8'h2A: branch_taken = !cc[CC_N];
      8'h2B: branch_taken = cc[CC_N];
      8'h2C: branch_taken = !(cc[CC_N] ^ cc[CC_V]);
      8'h2D: branch_taken = (cc[CC_N] ^ cc[CC_V]);
      8'h2E: branch_taken = !(cc[CC_Z] | (cc[CC_N] ^ cc[CC_V]));
      8'h2F: branch_taken = (cc[CC_Z] | (cc[CC_N] ^ cc[CC_V]));
      default: branch_taken = 1'b0;
    endcase
  end

  // Sequential State Machine
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state         <= 4'd0; // StReset
      pc            <= 16'h0000;
      sp            <= 16'hFFFF;
      ix            <= 16'h0000;
      acc_a         <= 8'h00;
      acc_b         <= 8'h00;
      cc            <= 8'hC0;
      cycle_cnt     <= 4'd0;
      opcode        <= 8'h01; // NOP
      int_nmi_latch <= 1'b0;
    end else if (clk_en_i && halt_ni) begin
      // Local variables for sequential block must be at top (using blocking here)
      /* verilator lint_off BLKSEQ */
      logic [15:0] local_val16;
      logic [15:0] local_diff16;
      /* verilator lint_off UNUSED */
      logic [7:0]  h_diff;
      /* verilator lint_on UNUSED */
      /* verilator lint_on BLKSEQ */

      // Cycle Logging (Optional for release, but kept for now)
      // $display("CYCLE: PC=%h SP=%h IX=%h A=%h B=%h CC=%h State=%d Cnt=%d Op=%h ADDR=%h DATA_I=%h DATA_O=%h WE=%b",
      //          pc, sp, ix, acc_a, acc_b, cc, state, cycle_cnt, opcode, addr_o, data_i, data_o, we_o);

      case (state)
        4'd0: begin // StReset
          if (cycle_cnt == 4'd0) begin
            pc[15:8]  <= data_i;
            cycle_cnt <= 4'd1;
          end else begin
            pc[7:0]   <= data_i;
            cycle_cnt <= 4'd0;
            state     <= 4'd1; // StFetch
          end
        end

        4'd1: begin // StFetch
          if (nmi_pending || irq_pending) begin
            int_nmi_latch <= nmi_pending;
            state         <= 4'd5; // StInterrupt
            cycle_cnt     <= 4'd0;
          end else begin
            opcode    <= data_i;
            pc        <= pc + 16'h1;
            cycle_cnt <= 4'd1;
            state     <= 4'd3;
          end
        end

        4'd5: begin // StInterrupt
          if (cycle_cnt <= 4'd5) begin
            cycle_cnt <= cycle_cnt + 4'd1;
          end else if (cycle_cnt == 4'd6) begin
            sp        <= sp - 16'h7;
            cc[CC_I]  <= 1'b1;
            cycle_cnt <= 4'd7;
          end else if (cycle_cnt == 4'd7) begin
            pc[15:8]  <= data_i;
            cycle_cnt <= 4'd8;
          end else if (cycle_cnt == 4'd8) begin
            pc[7:0]   <= data_i;
            cycle_cnt <= 4'd0;
            state     <= 4'd1;
          end
        end

        4'd3: begin // StExecute
          unique case (opcode)
            // IMM 8-bit
            8'h80, 8'h81, 8'h82, 8'h84, 8'h85, 8'h86, 8'h88, 8'h89, 8'h8A, 8'h8B,
            8'hC0, 8'hC1, 8'hC2, 8'hC4, 8'hC5, 8'hC6, 8'hC8, 8'hC9, 8'hCA, 8'hCB: begin
              if (opcode[3:0] != 4'h1 && opcode[3:0] != 4'h5) begin
                if(opcode[6]) acc_b <= alu_out;
                else          acc_a <= alu_out;
              end
              cc        <= alu_cc_out;
              pc        <= pc + 16'h1;
              cycle_cnt <= 4'd0;
              state     <= 4'd1;
            end

            // DIR 8-bit
            8'h90, 8'h91, 8'h92, 8'h94, 8'h95, 8'h96, 8'h97, 8'h98, 8'h99, 8'h9A, 8'h9B,
            8'hD0, 8'hD1, 8'hD2, 8'hD4, 8'hD5, 8'hD6, 8'hD7, 8'hD8, 8'hD9, 8'hDA, 8'hDB: begin
              if (cycle_cnt == 4'd1) begin
                ea[7:0]   <= data_i;
                pc        <= pc + 16'h1;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                if (opcode[3:0] != 4'h1 && opcode[3:0] != 4'h5 && opcode[3:0] != 4'h7) begin
                  if(opcode[6]) acc_b <= alu_out;
                  else          acc_a <= alu_out;
                end
                cc        <= alu_cc_out;
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // EXT 8-bit
            8'hB0, 8'hB1, 8'hB2, 8'hB4, 8'hB5, 8'hB6, 8'hB7, 8'hB8, 8'hB9, 8'hBA, 8'hBB,
            8'hF0, 8'hF1, 8'hF2, 8'hF4, 8'hF5, 8'hF6, 8'hF7, 8'hF8, 8'hF9, 8'hFA, 8'hFB: begin
              if (cycle_cnt == 4'd1) begin
                ea[15:8]  <= data_i;
                pc        <= pc + 16'h1;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                ea[7:0]   <= data_i;
                pc        <= pc + 16'h1;
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                if (opcode[3:0] != 4'h1 && opcode[3:0] != 4'h5 && opcode[3:0] != 4'h7) begin
                  if(opcode[6]) acc_b <= alu_out;
                  else          acc_a <= alu_out;
                end
                cc        <= alu_cc_out;
                cycle_cnt <= 4'd4;
              end else if (cycle_cnt == 4'd4) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // IDX 8-bit
            8'hA0, 8'hA1, 8'hA2, 8'hA4, 8'hA5, 8'hA6, 8'hA7, 8'hA8, 8'hA9, 8'hAA, 8'hAB,
            8'hE0, 8'hE1, 8'hE2, 8'hE4, 8'hE5, 8'hE6, 8'hE7, 8'hE8, 8'hE9, 8'hEA, 8'hEB: begin
              if (cycle_cnt == 4'd1) begin
                ea[7:0]   <= data_i;
                pc        <= pc + 16'h1;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                if (opcode[3:0] != 4'h1 && opcode[3:0] != 4'h5 && opcode[3:0] != 4'h7) begin
                  if(opcode[6]) acc_b <= alu_out;
                  else          acc_a <= alu_out;
                end
                cc        <= alu_cc_out;
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd4;
              end else if (cycle_cnt == 4'd4) begin
                if (opcode[3:0] == 4'h7) begin
                  cycle_cnt <= 4'd5;
                end else begin
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end
              end else if (cycle_cnt == 4'd5) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // 16-bit LD/ST/CPX
            8'h8C, 8'hCE, 8'h8E, 8'h9E, 8'hAE, 8'hBE, 8'hDE, 8'hEE, 8'hFE, 8'h9F, 8'hAF, 8'hBF, 8'hDF, 8'hEF, 8'hFF,
            8'h9C, 8'hAC, 8'hBC: begin
              if (opcode == 8'h8C || opcode == 8'hCE || opcode == 8'h8E) begin // IMM
                if (cycle_cnt == 4'd1) begin
                  ea[15:8]  <= data_i;
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd2;
                end else if (cycle_cnt == 4'd2) begin
                  /* verilator lint_off BLKSEQ */
                  local_val16 = {ea[15:8], data_i};
                  if (opcode == 8'h8C) begin
                    local_diff16 = ix - local_val16;
                    h_diff = ix[15:8] - local_val16[15:8];
                    cc[CC_Z] <= (local_diff16 == 16'h0);
                    // CPX flags N and V are based on the high byte subtraction result (no borrow from low byte)
                    cc[CC_N] <= h_diff[7];
                    cc[CC_V] <= (ix[15] ^ local_val16[15]) & (ix[15] ^ h_diff[7]);
                  end else if (opcode == 8'hCE) begin
                    ix       <= local_val16;
                    cc[CC_V] <= 1'b0;
                    cc[CC_Z] <= (local_val16 == 16'h0);
                    cc[CC_N] <= local_val16[15];
                  end else if (opcode == 8'h8E) begin
                    sp       <= local_val16;
                    cc[CC_V] <= 1'b0;
                    cc[CC_Z] <= (local_val16 == 16'h0);
                    cc[CC_N] <= local_val16[15];
                  end
                  /* verilator lint_on BLKSEQ */
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end
              end else if (opcode == 8'h9E || opcode == 8'hDE || opcode == 8'h9C || opcode == 8'h9F || opcode == 8'hDF) begin // DIR
                if (cycle_cnt == 4'd1) begin
                  ea[7:0]   <= data_i;
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd2;
                end else if (cycle_cnt == 4'd2) begin
                  res16[15:8] <= data_i;
                  cycle_cnt   <= 4'd3;
                end else if (cycle_cnt == 4'd3) begin
                  /* verilator lint_off BLKSEQ */
                  local_val16 = (opcode == 8'h9E || opcode == 8'hDE || opcode == 8'h9C) ? {res16[15:8], data_i} : (opcode[6] ? ix : sp);
                  if (opcode == 8'h9C) begin
                    local_diff16 = ix - local_val16;
                    h_diff = ix[15:8] - local_val16[15:8];
                    cc[CC_Z] <= (local_diff16 == 16'h0);
                    // CPX flags N and V are based on the high byte subtraction result (no borrow from low byte)
                    cc[CC_N] <= h_diff[7];
                    cc[CC_V] <= (ix[15] ^ local_val16[15]) & (ix[15] ^ h_diff[7]);
                  end else if (opcode == 8'h9E || opcode == 8'hDE) begin
                    if(opcode[6]) ix <= local_val16;
                    else          sp <= local_val16;
                    cc[CC_V]  <= 1'b0;
                    cc[CC_Z]  <= (local_val16 == 16'h0);
                    cc[CC_N]  <= local_val16[15];
                  end else begin // STX, STS DIR
                    cc[CC_V]  <= 1'b0;
                    cc[CC_Z]  <= (local_val16 == 16'h0);
                    cc[CC_N]  <= local_val16[15];
                  end
                  /* verilator lint_on BLKSEQ */
                  cycle_cnt <= 4'd4;
                end else if (cycle_cnt == 4'd4) begin
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end
              end else if (opcode == 8'hBE || opcode == 8'hFE || opcode == 8'hBC || opcode == 8'hBF || opcode == 8'hFF) begin // EXT
                if (cycle_cnt == 4'd1) begin
                  ea[15:8]  <= data_i;
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd2;
                end else if (cycle_cnt == 4'd2) begin
                  ea[7:0]   <= data_i;
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd3;
                end else if (cycle_cnt == 4'd3) begin
                  res16[15:8] <= data_i;
                  cycle_cnt   <= 4'd4;
                end else if (cycle_cnt == 4'd4) begin
                  /* verilator lint_off BLKSEQ */
                  local_val16 = (opcode == 8'hBE || opcode == 8'hFE || opcode == 8'hBC) ? {res16[15:8], data_i} : (opcode[6] ? ix : sp);
                  if (opcode == 8'hBC) begin
                    local_diff16 = ix - local_val16;
                    h_diff = ix[15:8] - local_val16[15:8];
                    cc[CC_Z] <= (local_diff16 == 16'h0);
                    // CPX flags N and V are based on the high byte subtraction result (no borrow from low byte)
                    cc[CC_N] <= h_diff[7];
                    cc[CC_V] <= (ix[15] ^ local_val16[15]) & (ix[15] ^ h_diff[7]);
                  end else if (opcode == 8'hBE || opcode == 8'hFE) begin
                    if(opcode[6]) ix <= local_val16;
                    else          sp <= local_val16;
                    cc[CC_V]  <= 1'b0;
                    cc[CC_Z]  <= (local_val16 == 16'h0);
                    cc[CC_N]  <= local_val16[15];
                  end else begin // STX, STS EXT
                    cc[CC_V]  <= 1'b0;
                    cc[CC_Z]  <= (local_val16 == 16'h0);
                    cc[CC_N]  <= local_val16[15];
                  end
                  /* verilator lint_on BLKSEQ */
                  cycle_cnt <= 4'd5;
                end else if (cycle_cnt == 4'd5) begin
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end
              end else if (opcode == 8'hAE || opcode == 8'hEE || opcode == 8'hAC || opcode == 8'hAF || opcode == 8'hEF) begin // IDX
                if (cycle_cnt == 4'd1) begin
                  ea[7:0]   <= data_i;
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd2;
                end else if (cycle_cnt == 4'd2) begin
                  res16[15:8] <= data_i;
                  cycle_cnt   <= 4'd3;
                end else if (cycle_cnt == 4'd3) begin
                  /* verilator lint_off BLKSEQ */
                  local_val16 = (opcode == 8'hAE || opcode == 8'hEE || opcode == 8'hAC) ? {res16[15:8], data_i} : (opcode[6] ? ix : sp);
                  if (opcode == 8'hAC) begin
                    local_diff16 = ix - local_val16;
                    h_diff = ix[15:8] - local_val16[15:8];
                    cc[CC_Z] <= (local_diff16 == 16'h0);
                    // CPX flags N and V are based on the high byte subtraction result (no borrow from low byte)
                    cc[CC_N] <= h_diff[7];
                    cc[CC_V] <= (ix[15] ^ local_val16[15]) & (ix[15] ^ h_diff[7]);
                  end else if (opcode == 8'hAE || opcode == 8'hEE) begin
                    if(opcode[6]) ix <= local_val16;
                    else          sp <= local_val16;
                    cc[CC_V] <= 1'b0;
                    cc[CC_Z] <= (local_val16 == 16'h0);
                    cc[CC_N] <= local_val16[15];
                  end else begin // STX, STS IDX
                    cc[CC_V] <= 1'b0;
                    cc[CC_Z] <= (local_val16 == 16'h0);
                    cc[CC_N] <= local_val16[15];
                  end
                  /* verilator lint_on BLKSEQ */
                  cycle_cnt <= 4'd4;
                end else if (cycle_cnt == 4'd4) begin
                  cycle_cnt <= 4'd5;
                end else if (cycle_cnt == 4'd5) begin
                  if (opcode == 8'hAF || opcode == 8'hEF) begin
                    cycle_cnt <= 4'd6;
                  end else begin
                    cycle_cnt <= 4'd0;
                    state     <= 4'd1;
                  end
                end else if (cycle_cnt == 4'd6) begin
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end
              end
            end

            // Branches
            8'h20, 8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27, 8'h28, 8'h29, 8'h2A, 8'h2B, 8'h2C, 8'h2D, 8'h2E, 8'h2F: begin
              if (cycle_cnt == 4'd1) begin
                if (branch_taken) begin
                  pc <= pc + 16'h1 + {{8{data_i[7]}}, data_i};
                end else begin
                  pc <= pc + 16'h1;
                end
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // 4-cycle 1-byte Illegals
            8'h00, 8'h02, 8'h03, 8'h04, 8'h05, 8'h14, 8'h15, 8'h18, 8'h1A, 8'h1C, 8'h1D, 8'h1E, 8'h1F,
            8'h41, 8'h42, 8'h45, 8'h4B, 8'h4E, 8'h51, 8'h52, 8'h55, 8'h5B, 8'h5E: begin
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // 4-cycle 2-byte Illegals
            8'h61, 8'h62, 8'h65, 8'h6B, 8'h83, 8'h87, 8'h8F, 8'h93, 8'hA3, 8'hC3, 8'hC7, 8'hCF, 8'hD3, 8'hDC, 8'hDD, 8'hE3, 8'hEC, 8'hED: begin
              if (cycle_cnt == 4'd1) begin
                pc        <= pc + 16'h1;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // 4-cycle 3-byte Illegals
            8'h71, 8'h72, 8'h75, 8'h7B, 8'hB3, 8'hCC, 8'hCD, 8'hF3, 8'hFC, 8'hFD: begin
              if (cycle_cnt == 4'd1) begin
                pc        <= pc + 16'h2;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            8'h12, 8'h13: begin // Undocumented X += RM(S + 1)
              if (cycle_cnt == 4'd1) begin
                ix        <= ix + {8'h00, data_i};
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // TSX (30)
            8'h30: begin
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                ix        <= sp + 16'h1;
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // INS (31)
            8'h31: begin
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                sp        <= sp + 16'h1;
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // DES (34)
            8'h34: begin
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                sp        <= sp - 16'h1;
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // TXS (35)
            8'h35: begin
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                sp        <= ix - 16'h1;
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // Stack Ops
            8'h36, 8'h37: begin
              if (cycle_cnt == 4'd1) begin
                sp        <= sp - 16'h1;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end else begin
                cycle_cnt <= cycle_cnt + 4'd1;
              end
            end

            8'h32, 8'h33: begin
              if (cycle_cnt == 4'd1) begin
                if(opcode == 8'h32) acc_a <= data_i;
                else                acc_b <= data_i;
                sp        <= sp + 16'h1;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end else begin
                cycle_cnt <= cycle_cnt + 4'd1;
              end
            end

            8'h38: begin // PULX (4 cycles)
              if (cycle_cnt == 4'd1) begin
                ix[15:8]  <= data_i;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                ix[7:0]   <= data_i;
                sp        <= sp + 16'h2;
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            8'h39: begin // RTS (5 cycles)
              if (cycle_cnt == 4'd1) begin
                pc[15:8]  <= data_i;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                pc[7:0]   <= data_i;
                sp        <= sp + 16'h2;
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd4) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end else begin
                cycle_cnt <= cycle_cnt + 4'd1;
              end
            end

            8'h3B: begin // RTI (10 cycles)
              if (cycle_cnt == 4'd1) begin
                cc        <= data_i;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                acc_b     <= data_i;
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                acc_a     <= data_i;
                cycle_cnt <= 4'd4;
              end else if (cycle_cnt == 4'd4) begin
                ix[15:8]  <= data_i;
                cycle_cnt <= 4'd5;
              end else if (cycle_cnt == 4'd5) begin
                ix[7:0]   <= data_i;
                cycle_cnt <= 4'd6;
              end else if (cycle_cnt == 4'd6) begin
                pc[15:8]  <= data_i;
                cycle_cnt <= 4'd7;
              end else if (cycle_cnt == 4'd7) begin
                pc[7:0]   <= data_i;
                sp        <= sp + 16'h7;
                cycle_cnt <= 4'd8;
              end else if (cycle_cnt == 4'd9) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end else begin
                cycle_cnt <= cycle_cnt + 4'd1;
              end
            end

            8'h3E: begin // WAI (9 cycles)
              if (cycle_cnt >= 4'd1 && cycle_cnt <= 4'd6) begin
                cycle_cnt <= cycle_cnt + 4'd1;
              end else if (cycle_cnt == 4'd7) begin
                sp        <= sp - 16'h7;
                cycle_cnt <= 4'd8;
              end else if (cycle_cnt == 4'd8) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            8'h3F: begin // SWI (12 cycles)
              if (cycle_cnt >= 4'd1 && cycle_cnt <= 4'd6) begin
                cycle_cnt <= cycle_cnt + 4'd1;
              end else if (cycle_cnt == 4'd7) begin
                sp        <= sp - 16'h7;
                cc[CC_I]  <= 1'b1;
                cycle_cnt <= 4'd8;
              end else if (cycle_cnt == 4'd8) begin
                pc[15:8]  <= data_i;
                cycle_cnt <= 4'd9;
              end else if (cycle_cnt == 4'd9) begin
                pc[7:0]   <= data_i;
                cycle_cnt <= 4'd10;
              end else if (cycle_cnt == 4'd11) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end else begin
                cycle_cnt <= cycle_cnt + 4'd1;
              end
            end

            8'h3C: begin // PSHX (4 cycles)
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                sp        <= sp - 16'h2;
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            8'h3A: begin // ABX (4 cycles)
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                ix        <= ix + {8'h00, acc_b};
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            8'h3D: begin // MUL (9 cycles)
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt < 4'd8) begin
                cycle_cnt <= cycle_cnt + 4'd1;
              end else if (cycle_cnt == 4'd8) begin
                acc_a     <= mul_res[15:8];
                acc_b     <= mul_res[7:0];
                cc[CC_C]  <= mul_res[7];
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // INX/DEX (4 cycles)
            8'h08: begin
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                ix        <= ix + 16'h1;
                cc[CC_Z]  <= (ix + 16'h1 == 16'h0);
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end
            8'h09: begin
              if (cycle_cnt == 4'd1) begin
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                cycle_cnt <= 4'd3;
              end else if (cycle_cnt == 4'd3) begin
                ix        <= ix - 16'h1;
                cc[CC_Z]  <= (ix - 16'h1 == 16'h0);
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // Flags
            8'h0A: if (cycle_cnt == 4'd1) begin cc[CC_V] <= 1'b0; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h0B: if (cycle_cnt == 4'd1) begin cc[CC_V] <= 1'b1; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h0C: if (cycle_cnt == 4'd1) begin cc[CC_C] <= 1'b0; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h0D: if (cycle_cnt == 4'd1) begin cc[CC_C] <= 1'b1; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h0E: if (cycle_cnt == 4'd1) begin cc[CC_I] <= 1'b0; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h0F: if (cycle_cnt == 4'd1) begin cc[CC_I] <= 1'b1; cycle_cnt <= 4'd0; state <= 4'd1; end

            // ALU Ops (SBA, CBA, TAB, TBA, ABA)
            8'h10: if (cycle_cnt == 4'd1) begin acc_a <= alu_out; cc <= alu_cc_out; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h11: if (cycle_cnt == 4'd1) begin cc <= alu_cc_out; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h16: if (cycle_cnt == 4'd1) begin acc_b <= alu_out; cc <= alu_cc_out; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h17: if (cycle_cnt == 4'd1) begin acc_a <= alu_out; cc <= alu_cc_out; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h19: if (cycle_cnt == 4'd1) begin acc_a <= alu_out; cc <= alu_cc_out; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h1B: if (cycle_cnt == 4'd1) begin acc_a <= alu_out; cc <= alu_cc_out; cycle_cnt <= 4'd0; state <= 4'd1; end

            // Inherent Unary 4x/5x
            8'h40, 8'h43, 8'h44, 8'h46, 8'h47, 8'h48, 8'h49, 8'h4A, 8'h4C, 8'h4D, 8'h4F,
            8'h50, 8'h53, 8'h54, 8'h56, 8'h57, 8'h58, 8'h59, 8'h5A, 8'h5C, 8'h5D, 8'h5F: begin
              if (cycle_cnt == 4'd1) begin
                if(opcode[4]) acc_b <= alu_out;
                else          acc_a <= alu_out;
                cc        <= alu_cc_out;
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // Indexed Unary (6x)
            8'h60, 8'h63, 8'h64, 8'h66, 8'h67, 8'h68, 8'h69, 8'h6A, 8'h6C, 8'h6D, 8'h6E, 8'h6F: begin
              if (cycle_cnt == 4'd1) begin
                ea[7:0]   <= data_i;
                if (opcode == 8'h6E) begin
                  pc        <= ix + {8'h00, data_i};
                end else begin
                  pc        <= pc + 16'h1;
                end
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                if (opcode == 8'h6E) begin
                  cycle_cnt <= 4'd3;
                end else begin
                  res16[7:0] <= data_i;
                  cycle_cnt  <= 4'd3;
                end
              end else if (cycle_cnt == 4'd3) begin
                if (opcode == 8'h6E) begin
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end else begin
                  cc        <= alu_cc_out;
                  cycle_cnt <= 4'd4;
                end
              end else if (cycle_cnt == 4'd4) begin
                cycle_cnt <= 4'd5;
              end else if (cycle_cnt == 4'd5) begin
                cycle_cnt <= 4'd6;
              end else if (cycle_cnt == 4'd6) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // Extended Unary (7x)
            8'h70, 8'h73, 8'h74, 8'h76, 8'h77, 8'h78, 8'h79, 8'h7A, 8'h7C, 8'h7D, 8'h7E, 8'h7F: begin
              if (cycle_cnt == 4'd1) begin
                ea[15:8]  <= data_i;
                pc        <= pc + 16'h1;
                cycle_cnt <= 4'd2;
              end else if (cycle_cnt == 4'd2) begin
                ea[7:0]   <= data_i;
                if (opcode == 8'h7E) begin
                  pc        <= {ea[15:8], data_i};
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end else begin
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd3;
                end
              end else if (cycle_cnt == 4'd3) begin
                res16[7:0] <= data_i;
                cycle_cnt  <= 4'd4;
              end else if (cycle_cnt == 4'd4) begin
                cc        <= alu_cc_out;
                cycle_cnt <= 4'd5;
              end else if (cycle_cnt == 4'd5) begin
                cycle_cnt <= 4'd0;
                state     <= 4'd1;
              end
            end

            // 14. BSR / JSR
            8'h8D, 8'h9D, 8'hAD, 8'hBD: begin
              if (opcode == 8'h8D || opcode == 8'h9D || opcode == 8'hAD) begin // BSR (8), JSR DIR (8), JSR IDX (8)
                if (cycle_cnt == 4'd1) begin
                  if (opcode == 8'h8D)      reg_val <= pc + 16'h1 + {{8{data_i[7]}}, data_i};
                  else if (opcode == 8'h9D) reg_val <= {8'h00, data_i};
                  else                      reg_val <= ix + {8'h00, data_i};
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd2;
                end else if (cycle_cnt == 4'd2) begin
                  cycle_cnt <= 4'd3;
                end else if (cycle_cnt == 4'd3) begin
                  sp        <= sp - 16'h2;
                  pc        <= reg_val;
                  cycle_cnt <= 4'd4;
                end else if (cycle_cnt < 4'd7) begin
                  cycle_cnt <= cycle_cnt + 4'd1;
                end else begin
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end
              end else if (opcode == 8'hBD) begin // JSR EXT (9 cycles)
                if (cycle_cnt == 4'd1) begin
                  ea[15:8]  <= data_i;
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd2;
                end else if (cycle_cnt == 4'd2) begin
                  reg_val   <= {ea[15:8], data_i};
                  pc        <= pc + 16'h1;
                  cycle_cnt <= 4'd3;
                end else if (cycle_cnt == 4'd3) begin
                  cycle_cnt <= 4'd4;
                end else if (cycle_cnt == 4'd4) begin
                  sp        <= sp - 16'h2;
                  pc        <= reg_val;
                  cycle_cnt <= 4'd5;
                end else if (cycle_cnt < 4'd8) begin
                  cycle_cnt <= cycle_cnt + 4'd1;
                end else begin
                  cycle_cnt <= 4'd0;
                  state     <= 4'd1;
                end
              end
            end

            // TAP/TPA
            8'h06: if (cycle_cnt == 4'd1) begin cc <= acc_a; cycle_cnt <= 4'd0; state <= 4'd1; end
            8'h07: if (cycle_cnt == 4'd1) begin acc_a <= cc; cycle_cnt <= 4'd0; state <= 4'd1; end

            // NOP
            8'h01: if (cycle_cnt == 4'd1) begin cycle_cnt <= 4'd0; state <= 4'd1; end
            default: begin 
              $display("ERROR: Unknown opcode %h in State 3", opcode);
              cycle_cnt <= 4'd0; state <= 4'd1; 
            end
          endcase
        end
        default: state <= 4'd1;
      endcase
    end
  end

  // ALU Input Mux
  always_comb begin
    alu_a  = opcode[6] ? acc_b : acc_a;
    alu_b  = (opcode[3:0] == 4'h7) ? (opcode[6] ? acc_b : acc_a) : data_i;
    alu_op = {1'b0, opcode[3:0]};
    case (opcode[3:0])
      4'h0:    alu_op = 5'h01; // SUB
      4'h1:    alu_op = 5'h01; // CMP
      4'h2:    alu_op = 5'h06; // SBC
      4'h4:    alu_op = 5'h02; // AND
      4'h5:    alu_op = 5'h02; // BIT
      4'h6:    alu_op = 5'h13; // LDA
      4'h7:    alu_op = 5'h13; // STA
      4'h8:    alu_op = 5'h04; // EOR
      4'h9:    alu_op = 5'h05; // ADC
      4'hA:    alu_op = 5'h03; // ORA
      4'hB:    alu_op = 5'h00; // ADD
      default: alu_op = 5'h1F;
    endcase

    if (opcode == 8'h10 || opcode == 8'h11) begin
      alu_a  = acc_a;
      alu_b  = acc_b;
      alu_op = 5'h01;
    end
    if (opcode == 8'h19) begin
      alu_a  = acc_a;
      alu_op = 5'h07;
    end
    if (opcode == 8'h1B) begin
      alu_a  = acc_a;
      alu_b  = acc_b;
      alu_op = 5'h00;
    end
    if (opcode == 8'h16) begin
      alu_a  = acc_a;
      alu_b  = 8'hFF;
      alu_op = 5'h02;
    end
    if (opcode == 8'h17) begin
      alu_a  = acc_b;
      alu_b  = 8'hFF;
      alu_op = 5'h02;
    end

    // Unary Ops 4x/5x
    case (opcode)
      8'h40, 8'h50: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h0A; end // NEG
      8'h43, 8'h53: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h0B; end // COM
      8'h44, 8'h54: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h0C; end // LSR
      8'h46, 8'h56: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h0D; end // ROR
      8'h47, 8'h57: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h0E; end // ASR
      8'h48, 8'h58: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h0F; end // ASL
      8'h49, 8'h59: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h10; end // ROL
      8'h4A, 8'h5A: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h09; end // DEC
      8'h4C, 8'h5C: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h08; end // INC
      8'h4D, 8'h5D: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h11; end // TST
      8'h4F, 8'h5F: begin alu_a = opcode[4] ? acc_b : acc_a; alu_op = 5'h12; end // CLR
      default: ;
    endcase

    // Memory-based Unary Ops 6x/7x
    if (opcode[7:4] == 4'h6 || opcode[7:4] == 4'h7) begin
      // Use data_i during the read cycle, and latched res16[7:0] during the write cycle.
      if ((opcode[7:4] == 4'h6 && cycle_cnt == 4'd2) ||
          (opcode[7:4] == 4'h7 && cycle_cnt == 4'd3)) begin
        alu_a = data_i;
      end else begin
        alu_a = res16[7:0];
      end
      case (opcode[3:0])
        4'h0: alu_op = 5'h0A; // NEG
        4'h3: alu_op = 5'h0B; // COM
        4'h4: alu_op = 5'h0C; // LSR
        4'h6: alu_op = 5'h0D; // ROR
        4'h7: alu_op = 5'h0E; // ASR
        4'h8: alu_op = 5'h0F; // ASL
        4'h9: alu_op = 5'h10; // ROL
        4'hA: alu_op = 5'h09; // DEC
        4'hC: alu_op = 5'h08; // INC
        4'hD: alu_op = 5'h11; // TST
        4'hF: alu_op = 5'h12; // CLR
        default: ;
      endcase
    end
  end

endmodule : m6800_core

`endif // M6800_CORE_SV
