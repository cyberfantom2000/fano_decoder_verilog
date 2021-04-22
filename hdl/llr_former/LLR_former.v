`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.03.2019 10:36:43
// Design Name: 
// Module Name: LLR_former
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/** ѕо€снени€
    angle[2:0]
      0 - 0 градусов
      1 - 45 градусов
      2 - 90 градусов
      3 - 135 градусов
      4 - 180 градусов
      5 - 225 градусов
      6 - 270 градусов
      7 - 315 градусов.
*/

module llr_former #(
    // Автоматическое управление сдвигом фазы
    //   по i_rotate_period и i_sync
    parameter AUTO_PHASE_CTRL = 0,
    
    parameter IQ_WIDTH = 10,
    parameter IQ_RAM_WIDTH = 7,
    parameter LLR_WIDTH = 6,
    parameter LLR_MAX_ORDER = 4,
    parameter FIFO_LENGTH_LOG2 = 5,
    parameter ROTATE_PERIOD_WIDTH = 24,
    parameter LLR_DELAY = 12,
    parameter DEBUG = 0 )
(
    // Ctrl stream
    input i_ctrl_clk,
    input i_ctrl_reset,
    input [LLR_WIDTH*LLR_MAX_ORDER-1:0] i_ctrl_data,
    input i_ctrl_valid,
    
    input i_clk,
    input i_reset,
    
    // “ип модул€ции.
    //   0 - обычна€
    //   1 - офсетна€.
    input [1:0] i_mod_type,

    input [2:0] i_llr_order,
    input [2:0] i_angle_step,
    input [ROTATE_PERIOD_WIDTH-1:0] i_rotate_period,
    
    input i_shift_phase_stb,
    output o_last_phase_stb,
    input i_sync,  
    
    // Input    
    input [IQ_WIDTH-1:0] i_data_i,
    input [IQ_WIDTH-1:0] i_data_q,
    input i_valid,
    
    // Output
    output [LLR_WIDTH-1:0] o_llr,	
    output o_harddec,
    output o_llr_valid,
    output o_ready
);

    localparam RAM_DATA_WIDTH = LLR_WIDTH*LLR_MAX_ORDER;
    
    localparam integer COS0 = 1.0 * (2**(IQ_WIDTH-1)-1);
    localparam integer SIN0 = 0.0 * (2**(IQ_WIDTH-1)-1);
    localparam integer COS45 = 0.707 * (2**(IQ_WIDTH-1)-1);
    localparam integer SIN45 = 0.707 * (2**(IQ_WIDTH-1)-1);
    localparam integer COS90 = 0.0 * (2**(IQ_WIDTH-1)-1);
    localparam integer SIN90 = 1.0 * (2**(IQ_WIDTH-1)-1);
    localparam integer COS135 = -0.707 * (2**(IQ_WIDTH-1)-1);
    localparam integer SIN135 = 0.707 * (2**(IQ_WIDTH-1)-1);
    localparam integer COS180 = -1.0 * (2**(IQ_WIDTH-1)-1);
    localparam integer SIN180 = 0.0   * (2**(IQ_WIDTH-1)-1);
    localparam integer COS225 = -0.707 * (2**(IQ_WIDTH-1)-1);
    localparam integer SIN225 = -0.707 * (2**(IQ_WIDTH-1)-1);
    localparam integer COS270 = 0.0 * (2**(IQ_WIDTH-1)-1);
    localparam integer SIN270 = -1.0 * (2**(IQ_WIDTH-1)-1);
    localparam integer COS315 = 0.707 * (2**(IQ_WIDTH-1)-1);
    localparam integer SIN315 = -0.707 * (2**(IQ_WIDTH-1)-1);

//------------------------------------declaration-------------------------------------------//

reg [2:0] llr_order_reg = 0;
reg [2:0] llr_number_cnt = 0;

reg [IQ_WIDTH-1:0] data_i_reg = 0;
reg [IQ_WIDTH-1:0] data_q_reg = 0;
reg valid_reg = 0;

wire [2*IQ_WIDTH:0] rotated_i;
wire [2*IQ_WIDTH:0] rotated_q;
 
wire [IQ_RAM_WIDTH-1:0] rounded_i;
wire [IQ_RAM_WIDTH-1:0] rounded_q;

wire [IQ_RAM_WIDTH-1:0] delayed_i;
wire [IQ_RAM_WIDTH-1:0] delayed_q;
wire delayed_valid;

reg [IQ_WIDTH-1:0] cos_angle_reg = 0;
reg [IQ_WIDTH-1:0] sin_angle_reg = 0;

reg [2:0] angle_reg = 0;
reg [2:0] angle_step_reg = 0;

wire next_phase;
reg next_phase_reg = 0;

reg llr_valid_tg = 0;
wire llr_tg_reset;
wire llr_tg_set;

//-------------------------------------reg input data----------------------------------------//		
always @(posedge i_clk) begin
    data_i_reg[IQ_WIDTH-1:0] <= i_data_i[IQ_WIDTH-1:0];
    data_q_reg[IQ_WIDTH-1:0] <= i_data_q[IQ_WIDTH-1:0];
    valid_reg <= i_valid;
end

//-------------------------------------save settings----------------------------------------//		
always @(posedge i_clk) begin
    if (i_reset) begin
        llr_order_reg[2:0] <= i_llr_order[2:0];
        angle_step_reg[2:0] <= i_angle_step[2:0];
    end
end
		
//-------------------------------------------rotator----------------------------------------//		
cmult #(
    .AWIDTH(IQ_WIDTH),
    .BWIDTH(IQ_WIDTH)
) cmult_inst (
    .i_clk(i_clk),
    .i_ce(valid_reg),
    
    .i_are(data_i_reg[IQ_WIDTH-1:0]),
    .i_aim(data_q_reg[IQ_WIDTH-1:0]),
    
    .i_bre(cos_angle_reg[IQ_WIDTH-1:0]),
    .i_bim(sin_angle_reg[IQ_WIDTH-1:0]),		
    
    .o_pre(rotated_i[2*IQ_WIDTH:0]),
    .o_pim(rotated_q[2*IQ_WIDTH:0])
);

//---------------------------------------rotation counter-----------------------------------------//

generate
    if (AUTO_PHASE_CTRL) begin
        reg [ROTATE_PERIOD_WIDTH-1:0] norotate_cnt = 0;
        wire norotate_cnt_rst;
        wire norotate_cnt_ce;
        wire norotate_cnt_last_count;
        wire norotate_cnt_last_count_ce;
        
        always @(posedge i_clk) begin
            if (norotate_cnt_rst) begin
                norotate_cnt[ROTATE_PERIOD_WIDTH-1:0] <= 0;
            end else if (norotate_cnt_ce) begin
                norotate_cnt[ROTATE_PERIOD_WIDTH-1:0] <=
                        norotate_cnt[ROTATE_PERIOD_WIDTH-1:0] + 1;
            end
        end
        
        assign norotate_cnt_rst = i_reset | i_sync | norotate_cnt_last_count_ce;
        assign norotate_cnt_ce = i_valid & ~i_sync;
        assign norotate_cnt_last_count =
                (norotate_cnt[ROTATE_PERIOD_WIDTH-1:0] == i_rotate_period[ROTATE_PERIOD_WIDTH-1:0]);
        assign norotate_cnt_last_count_ce = norotate_cnt_last_count & i_valid;
        assign next_phase = norotate_cnt_last_count_ce;
    end else begin
        assign next_phase = i_shift_phase_stb;
    end
endgenerate

wire [2:0] next_angle;
wire last_angle_ce;
reg last_angle_ce_reg = 0;

always @(posedge i_clk) begin
    if (i_reset) begin
        angle_reg[2:0] <= 0;
    end else if (next_phase) begin
        angle_reg[2:0] <= angle_reg[2:0] + angle_step_reg[2:0];
    end
end

assign next_angle[2:0] = angle_reg[2:0] + angle_step_reg[2:0];
assign last_angle_ce = (next_angle[2:0] == 0) & next_phase;

always @(posedge i_clk) begin
    last_angle_ce_reg <= last_angle_ce;
end

assign o_last_phase_stb = last_angle_ce_reg;

always @(posedge i_clk) begin	
    next_phase_reg <= next_phase;
end

always @(posedge i_clk) begin
    if (next_phase_reg | i_reset ) begin
        case (angle_reg[2:0])
            3'd0: begin
                cos_angle_reg[IQ_WIDTH-1:0] <= COS0;
                sin_angle_reg[IQ_WIDTH-1:0] <= SIN0;
            end
            3'd1: begin
                cos_angle_reg[IQ_WIDTH-1:0] <= COS45;
                sin_angle_reg[IQ_WIDTH-1:0] <= SIN45;
            end
            3'd2: begin
                cos_angle_reg[IQ_WIDTH-1:0] <= COS90;
                sin_angle_reg[IQ_WIDTH-1:0] <= SIN90;
            end
            3'd3: begin
                cos_angle_reg[IQ_WIDTH-1:0] <= COS135;
                sin_angle_reg[IQ_WIDTH-1:0] <= SIN135;
            end
            3'd4: begin
                cos_angle_reg[IQ_WIDTH-1:0] <= COS180;
                sin_angle_reg[IQ_WIDTH-1:0] <= SIN180;
            end
            3'd5: begin
                cos_angle_reg[IQ_WIDTH-1:0] <= COS225;
                sin_angle_reg[IQ_WIDTH-1:0] <= SIN225;
            end
            3'd6: begin
                cos_angle_reg[IQ_WIDTH-1:0] <= COS270;
                sin_angle_reg[IQ_WIDTH-1:0] <= SIN270;
            end
            3'd7: begin
                cos_angle_reg[IQ_WIDTH-1:0] <= COS315;
                sin_angle_reg[IQ_WIDTH-1:0] <= SIN315;
            end
        endcase
    end
end

//---------------------------------------------------rounder--------------------------------//
// I
ROUNDER # (
    .DIN_WIDTH(2*IQ_WIDTH-1),
    .DOUT_WIDTH(IQ_RAM_WIDTH)
) mul_round_i_inst (
    .CLK(i_clk),
    .DIN(rotated_i[2*IQ_WIDTH-2:0]),
    .DIN_CE(valid_reg),
    .DOUT(rounded_i[IQ_RAM_WIDTH-1:0]) 
);

// Q
ROUNDER #(
    .DIN_WIDTH(2*IQ_WIDTH-1),
    .DOUT_WIDTH(IQ_RAM_WIDTH)
) mul_round_q_inst (
    .CLK(i_clk),
    .DIN(rotated_q[2*IQ_WIDTH-2:0]),
    .DIN_CE(valid_reg),
    .DOUT(rounded_q[IQ_RAM_WIDTH-1:0]) 
); 

//---------------------------------------------------iq_delay--------------------------------//
reg i_dly_enable_reg = 0;
reg q_dly_enable_reg = 0;
wire dly_enable_i;
wire dly_enable_q;

always @(posedge i_clk) begin
    if (dly_enable_i) begin
        i_dly_enable_reg <= 1;
        q_dly_enable_reg <= 0;
    end else if (dly_enable_q) begin
        i_dly_enable_reg <= 0;
        q_dly_enable_reg <= 1;
    end else begin
        i_dly_enable_reg <= 0;
        q_dly_enable_reg <= 0;
    end
end

// ќфсетна€ модул€ци€ и (90 градусов или 270 градусов).
assign dly_enable_i = (i_mod_type[1:0] == 1) && ((angle_reg[2:0] == 2) || (angle_reg[2:0] == 6));
assign dly_enable_q = (i_mod_type[1:0] == 2) && ((angle_reg[2:0] == 2) || (angle_reg[2:0] == 6));

iq_dly #(
    .DATA_WIDTH(IQ_RAM_WIDTH)
) iq_dly_inst (
    .i_clk(i_clk),
    .i_reset(i_reset),

    .i_i(rounded_i[IQ_RAM_WIDTH-1:0]),
    .i_q(rounded_q[IQ_RAM_WIDTH-1:0]),
    .i_valid(valid_reg),
    
    .i_i_dly_enable(i_dly_enable_reg),
    .i_q_dly_enable(q_dly_enable_reg),
    
    .o_i(delayed_i[IQ_RAM_WIDTH-1:0]),
    .o_q(delayed_q[IQ_RAM_WIDTH-1:0]),
    .o_valid(delayed_valid)
);

//----------------------------------------LLR RAM-------------------------------------------------//
reg [RAM_DATA_WIDTH-1:0] llr_ram_reg = 0;
reg llr_ram_valid_reg = 0;
wire [2*IQ_RAM_WIDTH-1:0] llr_ram_rd_addr;	
	
(*RAM_STYLE = "BLOCK"*) reg [RAM_DATA_WIDTH-1:0] llr_ram [2**(2*IQ_RAM_WIDTH)-1:0];
	
assign llr_ram_rd_addr[2*IQ_RAM_WIDTH-1:0] = {
    delayed_i[IQ_RAM_WIDTH-1:0],
    delayed_q[IQ_RAM_WIDTH-1:0]
};
	
initial begin
    // $readmemb("llr_bpsk.mif", llr_ram, 0, 16383);
    $readmemb("llr_qpsk.mif", llr_ram, 0, 16383);
    // $readmemb("llr_8psk.mif", llr_ram, 0, 16383);
end

reg [2*IQ_RAM_WIDTH-1:0] llr_ram_wr_addr_cnt = 0;
	
always @(posedge i_ctrl_clk) begin
    if (i_ctrl_reset) begin
        llr_ram_wr_addr_cnt[2*IQ_RAM_WIDTH-1:0] <= 0;
    end else if (i_ctrl_valid) begin
          llr_ram_wr_addr_cnt[2*IQ_RAM_WIDTH-1:0] <=
                  llr_ram_wr_addr_cnt[2*IQ_RAM_WIDTH-1:0] + 1;
    end
end
			  
// write to memory
always @ (posedge i_ctrl_clk) begin
    if (i_ctrl_valid) begin
        llr_ram[llr_ram_wr_addr_cnt] <= i_ctrl_data;
    end
end

// read from memory	   
always @(posedge i_clk) begin
	if (delayed_valid) begin
        llr_ram_reg[RAM_DATA_WIDTH-1:0] <= llr_ram[llr_ram_rd_addr];
    end
end	
			
always @(posedge i_clk) begin	
    llr_ram_valid_reg <= delayed_valid;
end
	
//-----------------------------------------FIFO---------------------------------------------------//	
wire fifo_wr;
wire fifo_rd;
wire fifo_full;
wire fifo_empty;
//wire fifo_err;
	
wire [RAM_DATA_WIDTH-1:0] fifo_dout;
//wire fifo_dout_valid;

simpleFIFO #(
    .DATA_W(RAM_DATA_WIDTH),
	.ADDR_W(FIFO_LENGTH_LOG2),
	.FWFT(0)
) simpleFIFO_inst (
    .Clk(i_clk),
    .Rst(i_reset),
    
    .wrData(llr_ram_reg[RAM_DATA_WIDTH-1:0]),
    .wrWe(fifo_wr),
    .wrFull(fifo_full),
	
    .rdData(fifo_dout[RAM_DATA_WIDTH-1:0]),
    .rdRe(fifo_rd),
    .rdEmpty(fifo_empty),
    
    .Entries()
);

assign fifo_rd = (llr_number_cnt[2:0] == llr_order_reg[2:0]-1) & ~fifo_empty;
assign fifo_wr = llr_ram_valid_reg & ~fifo_full;
	
//------------------------------------- LLR number counter---------------------------------------//
always @(posedge i_clk) begin
    if (i_reset) begin
        llr_number_cnt[2:0] <= llr_order_reg[2:0] - 1;
    end else begin
        if (fifo_rd) begin 
            llr_number_cnt[2:0] <= 0;
        end else if (llr_valid_tg && (llr_number_cnt[2:0] < llr_order_reg[2:0]-1)) begin 
            llr_number_cnt[2:0] <= llr_number_cnt[2:0] + 1;
        end
    end
end
	
//------------------------------------------LLR valid signal TG--------------------------------//
always @ (posedge i_clk) begin
    if (llr_tg_set)	begin
        llr_valid_tg <= 1;
    end else if (llr_tg_reset) begin
        llr_valid_tg <= 0;
    end
end
        
assign llr_tg_reset = (llr_number_cnt[2:0] == llr_order_reg[2:0]-1) | i_reset;
assign llr_tg_set = fifo_rd;
	
//----------------------------------LLR number mux----------------------------------------------//
reg [LLR_WIDTH-1:0] llr_reg = 0;
wire [LLR_WIDTH-1:0] llr_bus [LLR_MAX_ORDER-1:0];

genvar k;   
generate    
    for (k = 0; k < LLR_MAX_ORDER; k = k + 1) begin   		    	
        assign llr_bus[k] = fifo_dout[(k+1)*LLR_WIDTH-1:k*LLR_WIDTH];
    end
endgenerate
	
always @(posedge i_clk) begin
    if (llr_valid_tg) begin
        llr_reg[LLR_WIDTH-1:0] <= llr_bus[llr_number_cnt];
	end
end

reg llr_valid_dly_tg = 0;	   
always @ (posedge i_clk) begin
    llr_valid_dly_tg <= llr_valid_tg;
end

//------------------------------------delay	LLR -------------------------------------------------//

wire [LLR_WIDTH-1:0] llr_mux;
	
genvar i;   
generate
    if (LLR_DELAY == 0) begin : zero_delay_mode		
        assign llr_mux[LLR_WIDTH-1:0] = llr_reg[LLR_WIDTH-1:0];
    end else begin : non_zero_delay_mode 	
        reg [LLR_WIDTH-1:0] llr_dly_mem_reg [LLR_DELAY-1:0];   
        for (i = 0; i < LLR_DELAY; i = i + 1) begin
            always @(posedge i_clk) begin
                if (i_reset) begin
                    llr_dly_mem_reg[i] <= 0;			
                end else if (llr_valid_dly_tg) begin 	
                    if (i == 0) begin	
                        llr_dly_mem_reg[i] <= llr_reg[LLR_WIDTH-1:0];				
                    end else begin
                        llr_dly_mem_reg[i] <= llr_dly_mem_reg[i-1];
                    end 
                end
            end
        end
        
        assign llr_mux[LLR_WIDTH-1:0] = llr_dly_mem_reg[LLR_DELAY-1];
    end	
endgenerate

//-------------------------------------output data------------------------------------------------//
assign o_ready = ~fifo_full;

assign o_harddec = llr_reg[LLR_WIDTH-1];
assign o_llr[LLR_WIDTH-1:0] = llr_mux[LLR_WIDTH-1:0];
assign o_llr_valid = llr_valid_dly_tg;
	
generate
   if (DEBUG) begin
        decoder_llr_ila decoder_llr_ila_inst (
            .clk(i_clk),
            .probe0({o_ready, 
                     o_llr[2:0], 
                     o_harddec, 
                     o_llr_valid,
                     i_llr_order[2:0], 
                     i_angle_step[2:0], 
                     fifo_wr, 
                     fifo_rd,
                     fifo_empty, 
                     fifo_full, 
                     i_data_i[6:0], 
                     i_data_q[6:0], 
                     i_valid,
                     angle_reg[2:0]})
        );
        
        decoder_ctrl_llr_ila decoder_ctrl_llr_ila_inst (
            .clk(i_ctrl_clk),
            .probe0({i_ctrl_reset, 
                     i_ctrl_valid, 
                     i_ctrl_data[11:0],
                     llr_ram_wr_addr_cnt[13:0]})
        );
    end
endgenerate

endmodule