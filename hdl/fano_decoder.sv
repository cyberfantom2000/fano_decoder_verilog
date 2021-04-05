`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 10.03.2021 11:35:28
// Design Name: 
// Module Name: fano_decoder
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


module fano_decoder#(
    parameter ROTATE_PERIOD_WIDTH = 24,
    parameter SYNC_PERIOD_WIDTH   = 15,
    parameter MAX_SH_W = 256,   // Максимальное число шагов назад
    parameter DEBUG    = 0
)(
    input                           clk,
    input                           reset_n,
    input                           i_diff_en,          // включение выключение diff кодера
    input [1                    :0] i_code_rate,        // 2'd0 - 1/2, 2'd1 - 3/4, 2'd2 - 7/8
    input [ROTATE_PERIOD_WIDTH-1:0] i_norotate_period,  // Период смены фазы llr формера
    input [SYNC_PERIOD_WIDTH-1  :0] i_sync_period,      // Период поиска синхронизации 
    input [SYNC_PERIOD_WIDTH-1  :0] i_sync_threshold,   // Порог (symbols - errors) для захвата
    input                           i_last_phase_stb,
    output                          o_shift_phs,
    output                          o_llr_reset,
    input                           i_vld,
    input [1                    :0] i_data,
    input [7                    :0] i_delta_T,
    input [7                    :0] i_forward_step,     // Кол-во шагов вперед после которого нормируются метрики
    output                          o_is_sync
);


//**********  Constants and parameters  **********//  
localparam SH_W = MAX_SH_W - 1;
localparam code_len1_2 = 36;
localparam code_len3_4 = 63;
localparam code_len7_8 = 89;
localparam mask_1_2 = 89'hFFFFFFFFF;
localparam mask_3_4 = 89'h7FFFFFFFFFFFFFFF;
localparam mask_7_8 = 89'h1FFFFFFFFFFFFFFFFFFFFFF;
// FSM state
localparam INIT          = 0;   // Инициализация после сброса
localparam IDLE          = 1;   // Висим здесь если все символы декодированы
localparam RIBS_CALC     = 2;   // Вычисление ребер для следующего символа
localparam METRIC_CALC   = 3;   // Вычисление метрик принятого ребра и полученных из RIB_CALC
localparam FORWARD_MOVE  = 4;
localparam BACKWARD_MOVE = 5;
localparam CHECK_POINTER = 6;
localparam MP_RECALC     = 7;

genvar i;

// FSM signals
reg[3:0] state, nextstate;
reg[MAX_SH_W-1:0] A;            // Признак того что надо выбрать худшую метрику
reg start_rib_calc;
reg start_metric_calc;
reg forward_move;
reg back_move;
reg start_init;
reg start_norm;
reg T_up, T_down;
reg Mp_recalc;
reg inverse_A;
reg mp_check;                   // Флаг для проверки Mp >= T ? mp_check = 0 : mp_check = 1;
reg norm_en;                    // Флаг разрешения нормировки
reg metric_norm;                // Нормировка метрик и порога чтобы избежать переполнения.
// Main signals
reg [MAX_SH_W-1:0] pointer;
reg [MAX_SH_W-1:0] sh_d;           // Параллельные ргеистры сдвига для бита sh_d - для информационного бита, sh_p - для провероченого бита
reg [MAX_SH_W-1:0] sh_p;                  
reg [MAX_SH_W-1:0] decode_sh;      // Регистр в катором хранятся потенциальные декодированные символы
reg                encode_in_vld;
reg                out_dec_sym;
reg                metric_vld_sh, forward_move_sh, back_move_sh;
reg [1         :0] rib_0_r, rib_1_r;
wire[1         :0] rib_0, rib_1;
wire[1         :0] cur_rib;
wire[88        :0] data_to_enc;
wire               rib_d, rib_p;
wire               A_w;
wire               to_enc_vld;
wire               encode_vld;
wire               metric_vld;
wire               dec_sym;
wire[1         :0] path;
wire signed[5  :0] metric;

// deperforator signals
wire      deperf_vld;
wire[1:0] deperf_data;
wire      deperf_next_st;
// Fano decoder signals
reg signed [15:0] T;                           // Текущее значение порога.
reg signed [15:0] Mp, Mc, Ms;                  // FIXME: Размерность от балды.
reg        [11:0] forward_cnt;                 // Счетчик шагов вперед
reg        [7 :0] norm_cnt;                    // Счетчик для нормировки метрик
 // FIXME: Стоит еще подумать над размерностью.
reg [MAX_SH_W-1:0] V_d, V_p;                    // Регистр для хранения пройденного пути
reg                nlocal_rst;                  // Внутренний ресет, либо от внешнего, либо при пинке от синхронизатора


always@(posedge clk) begin
    nlocal_rst <= reset_n & ~deperf_next_st;
end

// Восстановление до кода 1/2 + сдвиг при отсутствии синхронизации
deperforator#(
    .D_WIDTH(2    ),
    .DEBUG  (DEBUG)
)deperforator_inst(
    .clk         (clk           ),
    .reset_n     (reset_n       ),
    // .i_code_rate(),
    .i_sh_pointer(deperf_next_st),
    .i_vld       (i_vld         ),
    .i_data      (i_data        ),
    .o_vld       (deperf_vld    ),
    .o_data      (deperf_data   )
);

// Сохранение принятых ребер
always@(posedge clk) begin
    if(!nlocal_rst) begin
        sh_d        <= 0;
        sh_p        <= 0;
        out_dec_sym <= 0;
    end else if(deperf_vld) begin           // Сдвиг если пришло новое кодовое слово то сдвигаем регистры
        out_dec_sym <= decode_sh[MAX_SH_W-1];
        sh_d        <= {sh_d[MAX_SH_W-2:0], deperf_data[1]};
        sh_p        <= {sh_p[MAX_SH_W-2:0], deperf_data[0]};
    end
end

// Немного запутанно с ходом назад и указателем.
// assign data_to_enc[88:0] = (state == MP_RECALC) ? {{53{1'b0}}, decode_sh[pointer+code_len1_2:pointer+1]}:
                                                  // {{53{1'b0}}, decode_sh[pointer+code_len1_2-1:pointer]};
assign data_to_enc[88:0] = (state == MP_RECALC) ? (decode_sh >> (pointer)) & mask_1_2 : (decode_sh >> (pointer-1)) & mask_1_2;
assign to_enc_vld = start_rib_calc || back_move_sh; // back_move - задержан чтобы указатель успел передвинуться на предидущий символ.
// Формирование предполагаемых ребер
recover_encoder#(
    .DEBUG(DEBUG)
)recover_encoder_inst(
    .clk        (clk        ),
    .reset_n    (nlocal_rst ),
    .i_diff_en  (i_diff_en  ),
    .i_code_rate(i_code_rate),
    .i_vld      (to_enc_vld ),
    .i_data     (data_to_enc),
    .o_vld      (encode_vld ),
    .o_rib_0    (rib_0      ),
    .o_rib_1    (rib_1      )
);

// FIXME здесь было : ? (sh_d >> (pointer+1)) : (sh_d >> pointer)
assign rib_d = (state == BACKWARD_MOVE) ? (sh_d >> pointer) : (sh_d >> (pointer-1));  // FIXME ??? state==BACKWARD_MOVE or state==MP_RECALC
assign rib_p = (state == BACKWARD_MOVE) ? (sh_p >> pointer) : (sh_p >> (pointer-1));  // FIXME ??? state==BACKWARD_MOVE or state==MP_RECALC
assign cur_rib = {rib_d, rib_p};
assign A_w = (state == BACKWARD_MOVE) ? (A >> (pointer)) : (A >> pointer-1); // FIXME old: (A >> (pointer+1)) : (A >> pointer);
assign to_metric_vld = start_metric_calc || Mp_recalc;
// Вычисление метрик между текущим ребром и ребрами предложеными кодером.
metric_calc metric_calc_inst0(
    .clk         (clk        ),
    .reset_n     (nlocal_rst ),
    .i_vld       (encode_vld ), // to_metric_vld
    .i_code_rate (i_code_rate),
    .i_rib_0     (rib_0      ), // rib_0_r
    .i_rib_1     (rib_1      ), // rib_1_r
    .i_cur_rib   (cur_rib    ),
    .A           (A_w        ),
    .o_vld       (metric_vld ),
    .o_path      (path       ),
    .o_metric    (metric     ),
    .o_decode_sym(dec_sym    )
);


// Вычисление метрики будущего пути.
always@(posedge clk) begin
    if(!nlocal_rst) begin
        Ms              <= 0;
        metric_vld_sh   <= 0;
        forward_move_sh <= 0;
        back_move_sh    <= 0;
    end else begin
        if(metric_vld) Ms <= Mc + metric;
        metric_vld_sh   <= metric_vld;
        forward_move_sh <= forward_move;
        back_move_sh    <= back_move;
    end
end

// generate
    // for(i=0; i<MAX_SH_W; i++)begin
        // always@(posedge clk) begin
            // if(!nlocal_rst)                        decode_sh[i] <= 1'b0;
            // else if(deperf_vld)                 decode_sh[i] <= (i==0) ? 1'b0 : decode_sh[i-1];
            // else if(forward_move && pointer[i]) decode_sh[i] <= dec_sym;
        // end
        
        // always@(posedge clk) begin
            // if(!nlocal_rst) begin
                // V_d[i] <= 1'b0;
                // V_p[i] <= 1'b0; 
            // end else if(deperf_vld) begin
                // V_d[i] <= (i==0) ? 1'b0 : V_d[i-1];
                // V_p[i] <= (i==0) ? 1'b0 : V_p[i-1];
            // end else if(forward_move && pointer[i]) begin
                // V_d[i] <= path[1];
                // V_p[i] <= path[0];
            // end
        // end
    // end
// endgenerate

always@(posedge clk) begin
    if(!nlocal_rst) begin
        V_d <= 0;
        V_p <= 0;
    end else if(deperf_vld) begin
        V_d <= V_d << 1;
        V_p <= V_p << 1;
    end else if(forward_move) begin
        V_d <= path[1] ? V_d | (256'b1 << (pointer-1)) : V_d & ~(256'b1 << (pointer-1));
        V_p <= path[0] ? V_p | (256'b1 << (pointer-1)) : V_p & ~(256'b1 << (pointer-1));
    end
end

always@(posedge clk) begin
    if(!nlocal_rst) 
        decode_sh <= 0;
    else if(deperf_vld)
        decode_sh <= decode_sh << 1;
    else if(forward_move) 
        decode_sh <= dec_sym ?  decode_sh |  (256'b1 << (pointer-1)): 
                                decode_sh & ~(256'b1 << (pointer-1));
end


// always@(posedge clk) begin
    // if(!nlocal_rst) begin
        // decode_sh <= 0;
        // V_d       <= 0;
        // V_p       <= 0;
    // end else if(deperf_vld) begin
        // decode_sh <= {decode_sh[MAX_SH_W-2:0], 1'b0};
        // V_d       <= {V_d[MAX_SH_W-1:0], 1'b0};
        // V_p       <= {V_p[MAX_SH_W-1:0], 1'b0};
    // end else if(forward_move) begin
        // decode_sh[pointer-1] <= dec_sym;
        // V_d[pointer-1]       <= path[1];
        // V_p[pointer-1]       <= path[0];
    // end
// end



always@(posedge clk) begin
    if(!nlocal_rst) begin
        Mc <= 0;
        Mp <= 0;
    end else if (forward_move) begin
        Mp <= Mc;
        Mc <= Ms;
    end else if (back_move) begin
        Mc <= Mp;
    end else if(metric_norm) begin
        Mp <= Mp - i_forward_step;
        Mc <= Mc - i_forward_step;
    end else if(metric_vld && state == MP_RECALC) begin  // FIXME: check state
        if     (forward_cnt == 0) Mp <= -16'd32768;
        else if(forward_cnt == 1) Mp <= 16'd0;
        else                      Mp <= Mp - metric;
    end
end


// Поиск синхронизации
sync_finder#(
    .SYNC_PERIOD_WIDTH  (SYNC_PERIOD_WIDTH  ),
    .ROTATE_PERIOD_WIDTH(ROTATE_PERIOD_WIDTH),
    .DEBUG              (DEBUG              )
)sync_finder_inst( 
    .clk              (clk                  ),
    .reset_n          (reset_n              ),
    .i_diff_en        (i_diff_en            ),
    .i_norotate_period(i_norotate_period    ),
    .o_next_phase     (o_shift_phs          ),
    .i_code_rate      (i_code_rate          ),
    .i_sync_period    (i_sync_period        ),
    .i_sync_threshold (i_sync_threshold     ),
    .i_last_phase_stb (i_last_phase_stb     ),
    .i_vld            (deperf_vld           ),
    .i_encode_data    (deperf_data          ),
    .i_decode_data    (decode_sh[MAX_SH_W-1]),
    .o_llr_reset      (o_llr_reset          ),
    .o_deperf_next_st (deperf_next_st       ),
    .o_is_sync        (o_is_sync            )    
);


// Передвижение указателя на текущее исследуемое ребро
always@(posedge clk) begin
    if   (!nlocal_rst || start_init) pointer <= 0;        
    else if(deperf_vld || back_move) pointer <= pointer < MAX_SH_W - code_len1_2 ? pointer + 1 : pointer;   // FIXME: check
    else if(forward_move           ) pointer <= pointer > 0                      ? pointer - 1 : 0;         // FIXME: check
end
// always@(posedge clk) begin
    // if     (!nlocal_rst || start_init ) pointer[MAX_SH_W-1:0] <= 'd1;
    // else if(deperf_vld || back_move) pointer[MAX_SH_W-1:0] <= {pointer[MAX_SH_W-2:0], 1'b0};
    // else if(forward_move           ) pointer[MAX_SH_W-1:0] <= {1'b0, pointer[MAX_SH_W:1]};
// end

// Изменение текущего порога
always@(posedge clk) begin
    if  (!nlocal_rst || start_init) T <= 0;
    else if(T_down                ) T <= T - i_delta_T;
    else if(T_up                  ) T <= T + i_delta_T;
    else if(metric_norm           ) T <= T - i_forward_step;
end

// Счетчик нормировки
always@(posedge clk) begin
    if  (!nlocal_rst || start_init) norm_cnt <= 0;
    else if(forward_move          ) norm_cnt <= norm_cnt < i_forward_step ? norm_cnt + 1 : 0; // FIXME (forward_move && T > delta_T)
    else if(back_move             ) norm_cnt <= norm_cnt > 0              ? norm_cnt - 1 : 0;
end

// Счетчик шагов вперед
always@(posedge clk) begin
    if  (!nlocal_rst || start_init) forward_cnt <= 0;
    else if(forward_move          ) forward_cnt <= forward_cnt < MAX_SH_W ? forward_cnt + 1 : forward_cnt; 
    else if(back_move             ) forward_cnt <= forward_cnt > 0        ? forward_cnt - 1 : 0;
end

// Регистр признаков, что было выбрано худшее ребро
// generate
    // for(i=0; i<MAX_SH_W; i++)begin
        // always@(posedge clk) begin
            // if(!nlocal_rst)                           A[i] <= 1'b0;
            // else if(deperf_vld)                    A[i] <= (i==0) ? 1'b0 : A[i-1];
            // else if(inverse_A && pointer[i])       A[i] <= 1'b1;
            // else if(forward_move_sh && pointer[i]) A[i] <= 1'b0;
        // end
    // end
// endgenerate

always@(posedge clk) begin
    if(!nlocal_rst || start_init) A <= 0;
    else if(deperf_vld          ) A <= A << 1;
    else if(inverse_A           ) A <= A |  (256'b1 << pointer);
    else if(forward_move        ) A <= A & ~(256'b1 << (pointer-1));
end
// always@(posedge clk) begin
    // if     (!nlocal_rst    ) A            <= 0;
    // else if(deperf_vld  ) A            <= {A[MAX_SH_W-2:1], 1'b0};
    // else if(inverse_A   ) A[pointer]   <= 1'b1;
    // else if(forward_move) A[pointer-1] <= 1'b0; // После движения вперед следующий путь А = 0
// end


//---------   FSM    -----------//
always@(posedge clk) begin
    if(!nlocal_rst) state <= INIT;
    else            state <= nextstate;
end

always@(*) begin
    nextstate         = 'hX;
    start_rib_calc    = 0;
    start_metric_calc = 0;
    forward_move      = 0;
    back_move         = 0;
    start_init        = 0;
    start_norm        = 0;
    T_up              = 0;
    T_down            = 0;
    Mp_recalc         = 0;
    inverse_A         = 0;
    metric_norm       = 0;
    
    case(state)
        // Инициализация стартового состояния
        INIT: begin
            start_init = 1;
            mp_check   = 0;
            nextstate  = IDLE;
        end
        
        // Ожидание новых слов
        IDLE: begin
            nextstate = IDLE;
            // При нормировке уменьшаем значения чтобы небыло переполнения
            if(norm_cnt >= i_forward_step && norm_en) begin
                metric_norm = 1;
                norm_en     = 0;
            end
            // Если появились новые слова для декодирования
            if(pointer > 0) begin
                start_rib_calc = 1;
                nextstate      = RIBS_CALC;            
            end    
        end
        
        // Расчет ребер
        RIBS_CALC: begin
            nextstate = RIBS_CALC;
            norm_en = 1;
            if (encode_vld) begin
                rib_0_r           = rib_0;
                rib_1_r           = rib_1;
                start_metric_calc = 1;
                nextstate         = METRIC_CALC;
            end
        end
        
        // Расчет метрик между текущим ребром и предполагаемыми из кодера.
        METRIC_CALC: begin
            nextstate = METRIC_CALC;
            if(metric_vld_sh || mp_check) begin
                if(Ms >= T) begin
                    forward_move = 1;
                    mp_check = 0;
                    nextstate    = FORWARD_MOVE;
                end else if(Mp >= T) begin
                    back_move = 1;
                    mp_check = 0;
                    nextstate = BACKWARD_MOVE;
                end else begin
                    T_down    = 1;
                    mp_check      = 1;
                    nextstate = METRIC_CALC;
                end
            end
        end
        
        // Движение вперед по кодовому древу, если не пересекли порог
        FORWARD_MOVE: begin
            nextstate = FORWARD_MOVE;
            if(forward_move_sh) begin   // FIXME ??????
                if(Mp < (T + i_delta_T)) T_up = 1;
                nextstate = IDLE;
            end
        end
        
        // Движение назад по кодовому древу, если пересекли порог
        BACKWARD_MOVE: begin
            nextstate = BACKWARD_MOVE;
            if(encode_vld) begin
                Mp_recalc = 1;
                rib_0_r   = rib_0;
                rib_1_r   = rib_1;
                nextstate = MP_RECALC;
            end
        end
        
        MP_RECALC: begin            
            nextstate = MP_RECALC;
            if(metric_vld_sh) begin
                if (A[pointer]) begin // В прошлый раз в этом узле ходили по худшему пути? Да - отступаем еще на один узел назад. Нет - пробуем пойти по худшему.
                    if(Mp >= T) begin
                        back_move = 1;
                        nextstate = BACKWARD_MOVE;
                    end else begin
                        T_down    = 1;
                        nextstate = IDLE;
                    end
                end else begin
                    inverse_A  = 1;
                    nextstate  = METRIC_CALC;
                end
            end  
        end
    endcase
end

endmodule