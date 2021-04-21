`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  STC
// Engineer: Evstigneev D.
// 
// Create Date: 14.04.2021 11:59:01
// Design Name: 
// Module Name: simple_sync_system
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Принцип прост: если синхронизация декодера есть, то порог увеличиватся
//              значительно чаще чем уменьшается. Если синхронизация нет это условие 
//              не выполняется.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module simple_sync_system#(
    parameter SYNC_PERIOD_WIDTH   = 24,
    parameter DEBUG               = 0
)(
    input                         clk, 
    input                         reset_n,
    input                         i_vld,
    input                         i_T_up,
    input                         i_T_down,
    input [SYNC_PERIOD_WIDTH-1:0] i_sync_period,      // Период поиска синхронизации 
    input [SYNC_PERIOD_WIDTH-1:0] i_sync_threshold,
    input                         i_last_phase_stb,
    output                        o_llr_reset,        // Сброс Llr формера чтобы каждый круг при потере синхры начинать с 0 фазы
    output                        o_next_phase,       // поворнуть фазу в llr формере
    output                        o_deperf_next_st,   // Пинок для деперфоратора
    output                        o_is_sync
);

reg[SYNC_PERIOD_WIDTH-1:0] period_cntr;
reg[SYNC_PERIOD_WIDTH-1:0] T_cntr;
reg is_sync;
reg rst_cnt;
reg last_phase;


always@(posedge clk) begin
    if     (!reset_n || next_st_deperf) last_phase <= 0;
    else if(i_last_phase_stb          ) last_phase <= 1;
end

always@(posedge clk) begin
    if(!reset_n || rst_cnt) period_cntr <= 0;
    else if(i_vld         ) period_cntr <= period_cntr + 1;
end

always@(posedge clk) begin
    if(!reset_n || rst_cnt) T_cntr <= 0;
    else if(i_T_up        ) T_cntr <= T_cntr + 1;
    else if(i_T_down      ) T_cntr <= T_cntr - 1;
end

always@(posedge clk) begin
    if(!reset_n) begin
        is_sync <= 0;
        rst_cnt <= 0;
    end else if(period_cntr >= i_sync_period) begin
        rst_cnt <= 1;
        is_sync <= T_cntr > i_sync_threshold ? 1'b1: 1'b0;
    end else begin
        rst_cnt <= 0;
    end
end

//---------   FSM    -----------//
reg[1:0] state, nextstate;
reg      phase_stb_reset;
reg      next_st_deperf;
reg      next_phase;

localparam IDLE        = 0;
localparam SEARCH_SYNC = 1;


always@(posedge clk) begin
    if(!reset_n) state <= IDLE;
    else         state <= nextstate;
end

always@(*) begin
    next_phase      = 0;
    next_st_deperf  = 0;
    phase_stb_reset = 0;
    
    case(state)
        IDLE: begin
            if(is_sync) begin
                nextstate = IDLE;
            end else begin
                phase_stb_reset = 1;            // FIXME: скорее всего можно без этого
                nextstate       = SEARCH_SYNC;
            end
        end
        
        SEARCH_SYNC: begin
            nextstate = SEARCH_SYNC;
            if(is_sync) begin
                nextstate = IDLE;
            end else if(rst_cnt) begin
                next_st_deperf = last_phase ? 1 : 0;
                next_phase     = 1;
                nextstate      = SEARCH_SYNC;
            end
        end
    endcase
end

assign o_deperf_next_st = next_st_deperf;
assign o_llr_reset      = phase_stb_reset;
assign o_next_phase     = next_phase;
assign o_is_sync        = is_sync;


generate
    if (DEBUG) begin
        sync_system_ila sync_system_ila_inst(
        .clk   (clk),
        .probe0({reset_n,
                 i_vld,
                 i_T_up,
                 i_T_down,
                 i_last_phase_stb,
                 is_sync,
                 rst_cnt,
                 o_deperf_next_st,
                 o_llr_reset,
                 o_next_phase,
                 o_is_sync
        }),
        .probe1({i_sync_period   [23:0],
                 i_sync_threshold[23:0],
                 period_cntr     [23:0],
                 T_cntr          [23:0],
                 state           [1 :0]
                })
        );
    end
endgenerate


endmodule
