`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.03.2021 15:48:25
// Design Name: 
// Module Name: sync_finder
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


module sync_finder#(
    parameter SYNC_PERIOD_WIDTH   = 15,
    parameter ROTATE_PERIOD_WIDTH = 24,
    parameter DEBUG               = 0
)(
    input                           clk,
    input                           reset_n,
    input                           i_diff_en,
    input [ROTATE_PERIOD_WIDTH-1:0] i_norotate_period,  // Период смены фазы llr формера
    input                           o_next_phase,     
    input [1                    :0] i_code_rate,
    input [SYNC_PERIOD_WIDTH    :0] i_sync_period,      // Период поиска синхронизации 
    input [SYNC_PERIOD_WIDTH    :0] i_sync_threshold,
    input                           i_last_phase_stb,
    input                           i_vld,
    input [1                    :0] i_encode_data,
    input                           i_decode_data,
    output                          o_llr_reset,        // Сброс Llr формера чтобы каждый круг при потере синхры начинать с 0 фазы
    output                          o_deperf_next_st,   // Пинок для деперфоратора
    output                          o_is_sync
);

reg[ROTATE_PERIOD_WIDTH:0] norotate_cntr;
wire is_sync;
wire sync_nreset;

sync_system#(
    .SYNC_PERIOD_WIDTH(SYNC_PERIOD_WIDTH),
    .DEBUG            (DEBUG            )
)sync_system_inst(
    .clk             (clk             ),
    .reset_n         (sync_nreset     ),
    .i_diff_en       (i_diff_en       ),
    .i_code_rate     (i_code_rate     ),
    .i_sync_period   (i_sync_period   ),
    .i_sync_threshold(i_sync_threshold),
    .i_vld           (i_vld           ),
    .i_encode_data   (i_encode_data   ),
    .i_decode_data   (i_decode_data   ),
    .o_is_sync       (is_sync         )
);

assign sync_nreset = reset_n || !phase_stb_reset;

always@(posedge clk) begin
    if(!reset_n || cntr_reset) norotate_cntr <= 0;
    else if(i_vld && !is_sync) norotate_cntr <= norotate_cntr + 1;
end

//---------   FSM    -----------//
reg[3:0] state, nextstate;
reg      phase_stb_reset;
reg      cntr_reset;
reg      next_phase;
reg      next_st_deperf;
localparam IDLE        = 0;
localparam SEARCH_SYNC = 1;
localparam NEXT_PHASE  = 2;
localparam LAST_PH_STB = 3;


always@(posedge clk) begin
    if(!reset_n) state <= IDLE;
    else         state <= nextstate;
end

always@(*) begin
    cntr_reset      = 1;
    next_phase      = 0;
    next_st_deperf  = 0;
    phase_stb_reset = 0;
    
    case(state)        
        IDLE: begin
            if(is_sync) begin
                phase_stb_reset = 0;
                nextstate       = IDLE;
            end else begin
                phase_stb_reset = 1;
                nextstate       = SEARCH_SYNC;
            end
        end
        
        SEARCH_SYNC: begin
            nextstate  = SEARCH_SYNC;
            cntr_reset = 0;
            if(is_sync) begin
                nextstate = IDLE;
            end else if(norotate_cntr == i_norotate_period) begin
                next_phase = 1;
                nextstate  = NEXT_PHASE;
            end
        end
        
        NEXT_PHASE: begin
            nextstate = i_last_phase_stb ? LAST_PH_STB : SEARCH_SYNC;
        end
        
        LAST_PH_STB: begin
            nextstate  = LAST_PH_STB; 
            cntr_reset = 0;
            if(is_sync) begin
                nextstate = IDLE;
            end else if(norotate_cntr == i_norotate_period) begin
                next_phase     = 1;
                next_st_deperf = 1;
                nextstate      = SEARCH_SYNC;
            end
        end
    endcase
end

assign o_llr_reset      = phase_stb_reset;
assign o_deperf_next_st = next_st_deperf;
assign o_next_phase     = next_phase;
assign o_is_sync        = is_sync;

endmodule
