//
//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1 

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable, 

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,
 
///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus 

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,
    
output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
// 
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [15:0]  cont1_key,
input   wire    [15:0]  cont2_key,
input   wire    [15:0]  cont3_key,
input   wire    [15:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig
    
);

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// cart is unused, so set all level translators accordingly
// directions are 0:IN, 1:OUT
assign cart_tran_bank3 = 8'hzz;
assign cart_tran_bank3_dir = 1'b0;
assign cart_tran_bank2 = 8'hzz;
assign cart_tran_bank2_dir = 1'b0;
assign cart_tran_bank1 = 8'hzz;
assign cart_tran_bank1_dir = 1'b0;
assign cart_tran_bank0 = 4'hf;
assign cart_tran_bank0_dir = 1'b1;
assign cart_tran_pin30 = 1'b0;      // reset or cs2, we let the hw control it by itself
assign cart_tran_pin30_dir = 1'bz;
assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
assign cart_tran_pin31 = 1'bz;      // input
assign cart_tran_pin31_dir = 1'b0;  // input

// link port is input only
assign port_tran_so = 1'bz;
assign port_tran_so_dir = 1'b0;     // SO is output only
assign port_tran_si = 1'bz;
assign port_tran_si_dir = 1'b0;     // SI is input only
assign port_tran_sck = 1'bz;
assign port_tran_sck_dir = 1'b0;    // clock direction can change
assign port_tran_sd = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used

// tie off the rest of the pins we are not using
assign cram0_a = 'h0;
assign cram0_dq = {16{1'bZ}};
assign cram0_clk = 0;
assign cram0_adv_n = 1;
assign cram0_cre = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n = 1;
assign cram0_we_n = 1;
assign cram0_ub_n = 1;
assign cram0_lb_n = 1;

assign cram1_a = 'h0;
assign cram1_dq = {16{1'bZ}};
assign cram1_clk = 0;
assign cram1_adv_n = 1;
assign cram1_cre = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n = 1;
assign cram1_we_n = 1;
assign cram1_ub_n = 1;
assign cram1_lb_n = 1;

assign dram_a = 'h0;
assign dram_ba = 'h0;
assign dram_dq = {16{1'bZ}};
assign dram_dqm = 'h0;
assign dram_clk = 'h0;
assign dram_cke = 'h0;
assign dram_ras_n = 'h1;
assign dram_cas_n = 'h1;
assign dram_we_n = 'h1;

assign sram_a = 'h0;
assign sram_dq = {16{1'bZ}};
assign sram_oe_n  = 1;
assign sram_we_n  = 1;
assign sram_ub_n  = 1;
assign sram_lb_n  = 1;

assign dbg_tx = 1'bZ;
assign user1 = 1'bZ;
assign aux_scl = 1'bZ;
assign vpll_feed = 1'bZ;

// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always @(*) begin
    casex(bridge_addr)
    default: begin
        bridge_rd_data <= 0;
    end
    32'h10xxxxxx: begin
        // example
        // bridge_rd_data <= example_device_data;
        bridge_rd_data <= 0;
    end
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end


//
// host/target command handler
//
    wire            reset_n;                // driven by host commands, can be used as core-wide reset
    wire    [31:0]  cmd_bridge_rd_data;
    
// bridge host commands
// synchronous to clk_74a
    wire            status_boot_done = pll_core_locked; 
    wire            status_setup_done = pll_core_locked; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_allcomplete;

    wire            savestate_supported;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;
    
    wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a


// bridge data slot access

    wire    [9:0]   datatable_addr;
    wire            datatable_wren;
    wire    [31:0]  datatable_data;
    wire    [31:0]  datatable_q;

core_bridge_cmd icb (

    .clk                ( clk_74a ),
    .reset_n            ( reset_n ),

    .bridge_endian_little   ( bridge_endian_little ),
    .bridge_addr            ( bridge_addr ),
    .bridge_rd              ( bridge_rd ),
    .bridge_rd_data         ( cmd_bridge_rd_data ),
    .bridge_wr              ( bridge_wr ),
    .bridge_wr_data         ( bridge_wr_data ),
    
    .status_boot_done       ( status_boot_done ),
    .status_setup_done      ( status_setup_done ),
    .status_running         ( status_running ),

    .dataslot_requestread       ( dataslot_requestread ),
    .dataslot_requestread_id    ( dataslot_requestread_id ),
    .dataslot_requestread_ack   ( dataslot_requestread_ack ),
    .dataslot_requestread_ok    ( dataslot_requestread_ok ),

    .dataslot_requestwrite      ( dataslot_requestwrite ),
    .dataslot_requestwrite_id   ( dataslot_requestwrite_id ),
    .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack ),
    .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok ),

    .dataslot_allcomplete   ( dataslot_allcomplete ),

    .savestate_supported    ( savestate_supported ),
    .savestate_addr         ( savestate_addr ),
    .savestate_size         ( savestate_size ),
    .savestate_maxloadsize  ( savestate_maxloadsize ),

    .savestate_start        ( savestate_start ),
    .savestate_start_ack    ( savestate_start_ack ),
    .savestate_start_busy   ( savestate_start_busy ),
    .savestate_start_ok     ( savestate_start_ok ),
    .savestate_start_err    ( savestate_start_err ),

    .savestate_load         ( savestate_load ),
    .savestate_load_ack     ( savestate_load_ack ),
    .savestate_load_busy    ( savestate_load_busy ),
    .savestate_load_ok      ( savestate_load_ok ),
    .savestate_load_err     ( savestate_load_err ),

    .osnotify_inmenu        ( osnotify_inmenu ),
    
    .datatable_addr         ( datatable_addr ),
    .datatable_wren         ( datatable_wren ),
    .datatable_data         ( datatable_data ),
    .datatable_q            ( datatable_q ),

);

// Game type defines
parameter [2:0] GAME_ID_ROBOTRON=3'd0;
parameter [2:0] GAME_ID_JOUST=3'd1;
parameter [2:0] GAME_ID_STARGATE=3'd2;
parameter [2:0] GAME_ID_BUBBLES=3'd3;
parameter [2:0] GAME_ID_SPLAT=3'd4;
parameter [2:0] GAME_ID_SINISTAR=3'd5;
parameter [2:0] GAME_ID_PLAYBALL=3'd6;
parameter [2:0] GAME_ID_ALIENARENA=3'd7;

reg [2:0] game_id;
reg [31:0] game_settings;

wire original_controls;
assign original_controls = game_settings[0];

always @(posedge clk_74a) begin
  if(bridge_wr) begin
    casex(bridge_addr)
      32'h80000000: begin 
			game_id		 	<= bridge_wr_data[2:0];  
		end
	  32'h90000000: begin 
			game_settings 	<= bridge_wr_data[31:0];
		end
    endcase
  end
end

///////////////////////////////////////////////
// System
///////////////////////////////////////////////

wire osnotify_inmenu_s;

synch_3 OSD_S (osnotify_inmenu, osnotify_inmenu_s, clk_sys);

///////////////////////////////////////////////
// ROM
///////////////////////////////////////////////

reg         ioctl_download = 0;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
reg   [7:0] ioctl_index = 0;

always @(posedge clk_74a) begin
    if (dataslot_requestwrite)     ioctl_download <= 1;
    else if (dataslot_allcomplete) ioctl_download <= 0;
end

data_loader #(
    .ADDRESS_MASK_UPPER_4(0),
    .ADDRESS_SIZE(25)
) rom_loader (
    .clk_74a(clk_74a),
    .clk_memory(clk_sys),

    .bridge_wr(bridge_wr),
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr),
    .bridge_wr_data(bridge_wr_data),

    .write_en(ioctl_wr),
    .write_addr(ioctl_addr),
    .write_data(ioctl_dout)
);

wire rom_download = ioctl_download && (ioctl_addr[24] == 0);

///////////////////////////////////////////////
// High Score
///////////////////////////////////////////////

// HISCORE SYSTEM
// --------------
wire [9:0] hs_address;
wire [7:0] hs_data_out;
wire hs_pause;

nvram #(
	.DUMPWIDTH(10),
	.DUMPINDEX(4),
	.PAUSEPAD(2)
) hi (
	.reset(~reset_n),
	.clk(clk_sys),
	.paused(0),
	.autosave(0),
	.nvram_address(hs_address),
	.nvram_data_out(hs_data_out),
	.pause_cpu(hs_pause)
);


///////////////////////////////////////////////
// Video
///////////////////////////////////////////////

reg hblank_core, vblank_core;
wire hs_core, vs_core;
wire [2:0] r;
wire [2:0] g;
wire [1:0] b;

reg video_de_reg;
reg video_hs_reg;
reg video_vs_reg;
reg [23:0] video_rgb_reg;

reg hs_prev;
reg vs_prev;

assign video_rgb_clock = clk_core_6;
assign video_rgb_clock_90 = clk_core_6_90deg;

assign video_de = video_de_reg;
assign video_hs = video_hs_reg;
assign video_vs = video_vs_reg;
assign video_rgb = video_rgb_reg;
assign video_skip = 0;

always @(posedge clk_core_6) begin
    video_de_reg <= 0;
    
    video_rgb_reg <= 24'd0;
    if (~landscape) begin
        video_rgb_reg <= {8'h0, 3'b001, 13'h0};
    end 

    if (~(vblank_core || hblank_core)) begin
        video_de_reg <= 1;
        video_rgb_reg[23:18]  <= {2{r}};
        video_rgb_reg[17:16]  <= r[2:1];
        video_rgb_reg[15:10]  <= {2{g}};
        video_rgb_reg[9:8]    <= g[2:1];		  
        video_rgb_reg[7:0]    <= {4{b}};
	end    
	
    video_hs_reg <= ~hs_prev && hs_core;
    video_vs_reg <= ~vs_prev && vs_core;
    hs_prev <= hs_core;
    vs_prev <= vs_core;
end


///////////////////////////////////////////////
// Audio
///////////////////////////////////////////////

wire [7:0] audio;
wire [15:0] speech;
wire [16:0] audio_sum;

assign audio_sum = {audio, 8'd0} + speech;

sound_i2s #(
    .CHANNEL_WIDTH(15),
    .SIGNED_INPUT(0)
) sound_i2s (
    .clk_74a(clk_74a),
    .clk_audio(clk_sys),
    
    .audio_l(audio_sum[16:2]),
    .audio_r(audio_sum[16:2]),

    .audio_mclk(audio_mclk),
    .audio_lrck(audio_lrck),
    .audio_dac(audio_dac)
);

///////////////////////////////////////////////
// Control
///////////////////////////////////////////////

wire [15:0] joy;

synch_3 #(
    .WIDTH(16)
) cont1_key_s (
    cont1_key,
    joy,
    clk_sys
);

wire [15:0] joy2;

synch_3 #(
    .WIDTH(16)
) cont2_key_s (
    cont2_key,
    joy2,
    clk_sys
);

wire m_up1     = joy[0];
wire m_down1   = joy[1];
wire m_left1   = joy[2];
wire m_right1  = joy[3];
wire m_fire_a1   = joy[4];
wire m_fire_b1   = joy[5];
wire m_fire_x1   = joy[6];
wire m_fire_y1   = joy[7];

wire m_fire_l1   = joy[8];
wire m_fire_r1   = joy[9];

wire m_advance = m_coin1 && joy[8];
wire m_auto_up = joy[9];
wire m_reset_score = m_coin1 && joy[9];

wire m_start1 =  joy[15];
wire m_coin1   =  joy[14];

wire m_up2     = joy2[0];
wire m_down2   = joy2[1];
wire m_left2   = joy2[2];
wire m_right2  = joy2[3];
wire m_fire_a2   = joy2[4];
wire m_fire_b2   = joy2[5];
wire m_fire_x2   = joy2[6];
wire m_fire_y2   = joy2[7];

wire m_start2 =  joy2[15];
wire m_coin2   =  joy2[14];

reg [7:0] JA;
reg [7:0] JB;
reg [2:0] BTN;
reg [7:0] SW;

reg landscape;
reg sinistar;
reg blitter_sc2;
reg analog_stick_detected;

wire sg_state;

always @(*) begin
	analog_stick_detected <= cont1_joy[15:0] != 0;
	
	landscape <= 1;
	JA = 0;
	JB = 0;
	BTN = 0;
	blitter_sc2 = 0;
	sinistar = 0;
	SW = { 6'b0, m_advance, m_auto_up };

	case (game_id)
		GAME_ID_ROBOTRON:
			begin
				BTN = { m_start1, m_start2, m_coin1 | m_coin2 };
				JA  = ~{ 
						analog_stick_detected ? ((cont1_joy[23:16] > 224 ) | m_fire_a1) : m_fire_a1, 
						analog_stick_detected ? ((cont1_joy[23:16] < 32)   | m_fire_y1) : m_fire_y1, 
						analog_stick_detected ? ((cont1_joy[31:24] > 224 ) | m_fire_b1) : m_fire_b1, 
						analog_stick_detected ? ((cont1_joy[31:24] < 32 )  | m_fire_x1) : m_fire_x1, 
						analog_stick_detected ? ((cont1_joy[7:0]   > 224)  | m_right1)  : m_right1, 
						analog_stick_detected ? ((cont1_joy[7:0]   < 32)   | m_left1)   : m_left1, 
						analog_stick_detected ? ((cont1_joy[15:8]  > 224)  | m_down1)   : m_down1, 
						analog_stick_detected ? ((cont1_joy[15:8]  < 32)   | m_up1)     : m_up1};
				JB  = JA;
			end
		GAME_ID_JOUST:
			begin
				BTN = { m_start2, m_start1, m_coin1 | m_coin2 };
				JA  = ~{ 5'b00000, m_fire_a1, m_right1, m_left1 };
				JB  = ~{ 5'b00000, m_fire_a2, m_right2, m_left2 };
			end
		GAME_ID_SPLAT:
			begin
				blitter_sc2 = 1;
				BTN = { m_start1, m_start2, m_coin1 | m_coin2 };
				JA  = ~{ m_fire_a1, m_fire_y1, m_fire_b1, m_fire_x1, m_right1, m_left1, m_down1, m_up1 };
				JB  = ~{ m_fire_a2, m_fire_y2, m_fire_b2, m_fire_x2, m_right2, m_left2, m_down2, m_up2 };
			end
		GAME_ID_BUBBLES:
			begin
				BTN = { m_start2, m_start1, m_coin1 | m_coin2 };
				JA  = ~{ 4'b0000, m_right1, m_left1, m_down1, m_up1 };
				JB  = JA;
			end
		GAME_ID_STARGATE:
			begin
				BTN = { m_start2, m_start1, m_coin1 };
				JA  = ~{ 
					m_fire_b1, 
					m_up1, 
					m_down1,  
					original_controls ? m_fire_l1 : (sg_state ? m_right1 : m_left1), 
					m_fire_y1, 
					m_fire_x1, 
					original_controls ? m_fire_r1 : (sg_state ? m_left1 : m_right1), 
					m_fire_a1 };
				JB  = JA;
			end
		GAME_ID_ALIENARENA:
			begin
				BTN = { m_start1, m_start2, m_coin1 };
				JA  = ~{ 1'b0, 1'b0, m_fire_b1, m_fire_a1, m_right1, m_left1, m_down1, m_up1 };
				JB  = ~{ 1'b0, 1'b0, m_fire_b2, m_fire_a2, m_right2, m_left2, m_down2, m_up2 };
			end
		GAME_ID_SINISTAR:
			begin
				sinistar = 1;
				landscape <= 0;
				BTN = { m_start1, m_start2, m_coin1 };
				JA  = ~{ 
							analog_stick_detected ? ((amx == 7) ? dmx : amx) : dmx,
							analog_stick_detected ? ((amy == 7) ? dmy : amy) : dmy,
						};
				JB  = JA;
			end
		GAME_ID_PLAYBALL:
			begin
				landscape <= 0;
				BTN = { 2'b00, m_coin1 };
				JA  = ~{ 4'b0000, m_start2, m_right1, m_left1, m_start1 };
				JB  = JA;
			end
		default: ;
	endcase
end

wire [3:0] dmx = m_left1 ? 4'd0 : m_right1 ? 4'd8 : 4'd7;
wire [3:0] dmy = m_down1 ? 4'd0 : m_up1    ? 4'd8 : 4'd7;

wire [3:0] amx = (cont1_joy[7:0] < 32) ? 4'd0  :
                 (cont1_joy[7:0] < 64) ? 4'd4  :
                 (cont1_joy[7:0] < 96) ? 4'd6  :
                 (cont1_joy[7:0] >  224) ? 4'd8  :
                 (cont1_joy[7:0] >  192) ? 4'd9  :
                 (cont1_joy[7:0] >  160) ? 4'd11 : 4'd7;

wire [3:0] amy = (cont1_joy[15:8] < 32) ? 4'd8  :
                 (cont1_joy[15:8] < 64) ? 4'd9  :
                 (cont1_joy[15:8] < 96) ? 4'd11 :
                 (cont1_joy[15:8] >  224) ? 4'd0  :
                 (cont1_joy[15:8] >  192) ? 4'd4  :
                 (cont1_joy[15:8] >  160) ? 4'd6  : 4'd7; 


williams_soc soc
(
	.clock       ( clk_sys     ),
	.vgaRed      ( r           ),
	.vgaGreen    ( g           ),
	.vgaBlue     ( b           ),
	.Hsync       ( hs_core  ),
	.Vsync       ( vs_core  ),
	.audio_out   ( audio       ),
	.speech_out  ( speech      ),

	.blitter_sc2 ( blitter_sc2 ),
	.sinistar    ( sinistar    ),
	.sg_state    ( sg_state    ),

	.BTN         ( {BTN[2:0], ~reset_n} ),
	.SIN_FIRE    ( ~m_fire_a1   ),
	.SIN_BOMB    ( ~m_fire_b1   ),
	.SW          ( SW          ),
	.JA          ( JA          ),
	.JB          ( JB          ),

	.MemAdr      ( mem_addr    ),
	.MemDin      ( mem_di      ),
	.MemDout     ( mem_do      ),
	.MemWR       ( mem_we      ),
	.RamCS       ( ramcs       ),
	.RamLB       ( ramlb       ),
	.RamUB       ( ramub       ),

	.pause       ( 0  ),

    .dl_clock(clk_sys),       
	.dl_addr(ioctl_addr[16:0]),
	.dl_data(ioctl_dout),      
	.dl_wr(ioctl_wr & rom_download),
	.dl_upload    ( 0 )
);

wire [15:0] mem_addr;
wire  [7:0] mem_do = ~ramcs ? ram_do : rom_do;
wire  [7:0] mem_di;
wire        mem_we;
wire        ramcs;
wire        ramlb;
wire        ramub;

wire [7:0] rom_do;
dpram #(.dWidth(8),.aWidth(17)) cpu_prog_rom
(
	.clk_a(~clk_sys),
	.addr_a({1'b0,mem_addr[15], ~mem_addr[15] & mem_addr[14], mem_addr[13:0]}),
	.q_a(rom_do),

	.clk_b(clk_sys),
	.addr_b(ioctl_addr[16:0]),
	.d_b(ioctl_dout),
	.we_b(ioctl_wr & rom_download)
);

wire [7:0] ram_do;
williams_ram ram
(
	.CLK(~clk_sys),
	.ENL(~ramlb),
	.ENH(~ramub),
	.WE(~ramcs & ~mem_we),
	.ADDR(mem_addr),
	.DI(mem_di),
	.DO(ram_do),

	.dn_clock(clk_sys),
	.dn_addr(ioctl_download ? ioctl_addr[15:0] : hs_address),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & (rom_download || (ioctl_addr[24] == 1'b1))),
	.dn_din(hs_data_out),
	.dn_nvram(ioctl_addr[24] == 1'b1)
);

reg [10:0] lcnt;
reg [10:0] pcnt;

always @(posedge clk_sys) begin
	reg old_vs, old_hs;

	if(~&pcnt) pcnt <= pcnt + 1'd1;

	old_hs <= hs_core;
	if(~old_hs & hs_core) begin
		pcnt <= 0;
		if(~&lcnt) lcnt <= lcnt + 1'd1;

		old_vs <= vs_core;
		if(~old_vs & vs_core) lcnt <= 0;
	end

	if (pcnt[10:1] == 336) hblank_core <= 1;
	if (pcnt[10:1] == 040) hblank_core <= 0;

	if (lcnt == 254) vblank_core <= 1;
	if (lcnt == 14) vblank_core <= 0;
end


///////////////////////////////////////////////
// Clocks
///////////////////////////////////////////////

wire    clk_core_6;
wire    clk_core_6_90deg;
wire    clk_sys;  // 12MHz

wire    pll_core_locked;
    
mf_pllbase mp1 (
    .refclk         ( clk_74a ),
    .rst            ( 0 ),

    .outclk_2       ( clk_core_6_90deg ),
	.outclk_1       ( clk_core_6 ),
    .outclk_0       ( clk_sys ),

    .locked         ( pll_core_locked )
);

endmodule
