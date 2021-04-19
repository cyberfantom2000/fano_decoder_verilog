`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 16.03.2021 10:51:22
// Design Name: 
// Module Name: sync_system
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


// Сделано в лоб для 1/2. Для нормальной реализации я вижу 2 путя:
// 1 - данные берутся после деперфоратора. Но тогда нужно придумать как не учитывать выколотые биты.
// 2 - данные берутся до деперфоратора, но тогда надо накапливать статистику либо как то по другому
// придумать как формировать сравниваемые слова.


// Входной валид должен быть прорежен как минимум 2мя не валидами
module sync_system#(
    parameter SYNC_PERIOD_WIDTH = 15,
    parameter DEBUG = 0
)(
    input                       clk,
    input                       reset_n,
    input                       i_diff_en,
    input [1                :0] i_code_rate,
    input [SYNC_PERIOD_WIDTH:0] i_sync_period,
    input [SYNC_PERIOD_WIDTH:0] i_sync_threshold,
    input                       i_vld,
    input [1                :0] i_encode_data,
    input                       i_decode_data,
    output                      o_is_sync
);

localparam DELAY     = 8;
localparam MAX_CNT   = 2 ** SYNC_PERIOD_WIDTH - 1;
localparam DELAY_CNT = 200; // Задержка выходного сигнала, пока не на


reg unsigned [SYNC_PERIOD_WIDTH:0] sym_cntr;
reg unsigned [SYNC_PERIOD_WIDTH:0] err_cntr;
reg                        sync;
reg  [SYNC_PERIOD_WIDTH:0] diff_rate;
reg  [DELAY*2-1        :0] delayed_data;
wire [1                :0] encoder_data;
wire [1                :0] metric;
wire                       encoder_vld;
wire                       hamm_vld;


// Задержка на время работы кодера
always@(posedge clk) begin
    delayed_data[DELAY*2-1:0] <= {delayed_data[DELAY*2-3:0], i_encode_data[1:0]};
end


seq_conv_encoder#(
    .DEBUG(DEBUG)
)encoder_inst(
    .clk        (clk          ),
    .reset_n    (reset_n      ),
    .i_diff_en  (i_diff_en    ),
    .i_code_rate(i_code_rate  ),
    .i_vld      (i_vld        ),
    .i_data     (i_decode_data),
    .o_vld      (encoder_data ),
    .o_data     (encoder_vld  )
);


hamming_distance hamm_inst(
    .clk     (clk              ),
    .reset_n (reset_n          ),
    .i_vld   (encoder_vld      ),
    .i_mask  (2'b11            ),
    .i_a     (delayed_data[DELAY*2-1:DELAY*2-2]),
    .i_b     (encoder_data[1:0]),
    .o_vld   (hamm_vld         ),
    .o_metric(metric           )
);

always@(posedge clk) begin
    if(!reset_n  ) sym_cntr <= 0;
    else if(i_vld) sym_cntr <= sym_cntr < i_sync_period ?  sym_cntr + 2 : 0;
end

always@(posedge clk) begin
    if(!reset_n || sym_cntr >= i_sync_period) err_cntr <= 0;
    else if(hamm_vld                        ) err_cntr <= err_cntr + metric;
end

always@(posedge clk) begin
    if     (!reset_n) diff_rate <= 0;        
    else if(hamm_vld) diff_rate <= sym_cntr - err_cntr;

    if(!reset_n) 
        sync <= 0;
    // Задержка на DELAY_CNT чтобы при сбросе счетчик не сбивалась синхра.
    else if(sym_cntr > DELAY_CNT && hamm_vld)   
        sync <= diff_rate < i_sync_threshold ? 1'b1 : 1'b0;
end

assign o_is_sync = sync;

endmodule
