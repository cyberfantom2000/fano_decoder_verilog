`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  STC
// Engineer: Evstigneev D.
// 
// Create Date: 21.04.2021 11:51:01
// Design Name: 
// Module Name: sync_system
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sync_system#(
    parameter SYNC_PERIOD_WIDTH = 24,
    parameter DEBUG             = 0
)(
    input                         clk, 
    input                         reset_n,
    input                         i_diff_en,
    input [1                  :0] i_code_rate,
    input [SYNC_PERIOD_WIDTH-1:0] i_sync_period,      // Период поиска синхронизации 
    input [SYNC_PERIOD_WIDTH-1:0] i_sync_threshold,
    input                         i_vld,
    input [1                  :0] i_source_word,
    input                         i_dec_sym,
    input                         i_last_phase_stb,
//    output                        o_llr_reset,        // Сброс Llr формера чтобы каждый круг при потере синхры начинать с 0 фазы
    output                        o_next_phase,       // поворнуть фазу в llr формере
    output                        o_deperf_next_st,   // Пинок для деперфоратора
   // output[SYNC_PERIOD_WIDTH  :0] o_bit_num,          // количество принятых бит
   // output[SYNC_PERIOD_WIDTH-1:0] o_err_num,          // количество ошибок в принятых битах
    output                        o_is_sync
);

localparam DELAY   = 7;  // тактовая задержка
localparam SYM_DLY = 2;  // символьная задержка

//reg [SYNC_PERIOD_WIDTH  :0] bit_cntr;
reg [SYNC_PERIOD_WIDTH-1:0] err_cntr;
reg [SYNC_PERIOD_WIDTH-1:0] period_cntr;
reg [DELAY*2-1          :0] dly_data;
reg [SYM_DLY*2-1        :0] sym_dly_data;
wire[1                  :0] metric;
wire[1                  :0] encoder_data;
wire[1                  :0] dly_rib;
reg                         sh_vld;
wire                        encoder_vld;
wire                        hamm_vld;
reg                         cntr_rst;
reg                         is_sync, last_phase, next_phase;
reg                         deperf_next_st, llr_next_phase;

always@(posedge clk) begin
    sh_vld <= (period_cntr==i_sync_period) && i_vld;
end
// Сивольная  задержка
always@(posedge clk) begin
    if(!reset_n  ) sym_dly_data <= 0;
    else if(i_vld) sym_dly_data[SYM_DLY*2-1:0] <= {sym_dly_data[SYM_DLY*2-3:0], i_source_word[1:0]};
end
// Задержка тактовая 
always@(posedge clk) begin
    if(!reset_n) dly_data <= 0;
    else         dly_data[DELAY*2-1:0] <= {dly_data[DELAY*2-3:0], sym_dly_data[SYM_DLY*2-1:SYM_DLY*2-2]};
end
// Счетчик периода синхронизации
always@(posedge clk) begin
    if(!reset_n) begin 
        period_cntr <= 0;
        //bit_cntr    <= 0;
    end else if(i_vld) begin
        period_cntr <= period_cntr >= i_sync_period ? 0 : period_cntr + 1;
        //bit_cntr    <= period_cntr * 2;
    end
end


seq_conv_encoder#(
    .DEBUG(DEBUG)
)encoder_inst(
    .clk        (clk         ),
    .reset_n    (reset_n     ),
    .i_diff_en  (i_diff_en   ),
    .i_code_rate(i_code_rate ),
    .i_vld      (i_vld       ),
    .i_data     (i_dec_sym   ),
    .o_vld      (encoder_vld ),
    .o_data     (encoder_data)
);

assign dly_rib[1:0] = dly_data[DELAY*2-1:DELAY*2-2];

hamming_distance#(
	.DEBUG(DEBUG)
) hamm_inst(
    .clk     (clk         ),
    .reset_n (reset_n     ),
    .i_mask  (2'b11       ),
    .i_vld   (encoder_vld ),
    .i_a     (dly_rib     ),
    .i_b     (encoder_data),
    .o_vld   (hamm_vld    ),
    .o_metric(metric      )
);

// Счетчик ошибок
always@(posedge clk) begin
    if(!reset_n || deperf_next_st || next_phase) // Обнуление при сбросе, пинке деперфоратора или пинке ллр формера.
        err_cntr <= 0;        
    else if(hamm_vld) 
        err_cntr <= err_cntr + metric;
end

// Проверка пересечения порога
always@(posedge clk) begin
    if(!reset_n) begin
        is_sync <= 0;
    end else if(period_cntr==i_sync_period && i_vld) begin                
        if(err_cntr >= i_sync_threshold) is_sync <= 1;
        else                             is_sync <= 0;
    end
end

always@(posedge clk) begin
    if(!reset_n) begin
        next_phase     <= 0;
        deperf_next_st <= 0;
    end else if((period_cntr==i_sync_period) && sh_vld && !is_sync) begin  // Если закончился период измерений и синхры нет.
        if(last_phase) deperf_next_st <= 1;                                // если фаза последняя            
        else           next_phase     <= 1;                                // если фаза не последняя            
    end else begin
        next_phase     <= 0;
        deperf_next_st <= 0;
    end
end

always@(posedge clk) begin
    if     (!reset_n        ) last_phase <= 0;
    else if(i_last_phase_stb) last_phase <= 1;
    else if(deperf_next_st  ) last_phase <= 0;    
end


assign o_next_phase     = next_phase;
assign o_deperf_next_st = deperf_next_st;
assign o_is_sync        = is_sync;

generate
    if (DEBUG) begin
        sync_system_ila sync_system_ila_inst(
        .clk   (clk),
        .probe0({reset_n,
				 last_phase,
				 next_phase,
				 deperf_next_st,
				 i_vld,
				 sh_vld,
				 encoder_vld,
				 hamm_vld
        }),
        .probe1({period_cntr     [23:0],
				 err_cntr	     [23:0],
				 i_sync_period   [23:0],
				 i_sync_threshold[23:0],
				 i_code_rate     [1 :0],
				 encoder_data    [1 :0],
				 dly_rib		 [1 :0],
				 dly_data		 [13:0],
				 metric		     [1 :0]				 
                })
        );
    end
endgenerate
endmodule