`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.03.2021 13:52:12
// Design Name: 
// Module Name: main_tb
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


module main_tb();

localparam IQ_DATA_WIDTH = 10;
localparam VAL_CNT_WIDTH = 6;

reg CLK 	= 0;
reg nRESET  = 0;
reg I_DATA_VAL = 0;
reg VAL_REG = 1;

reg [31:0]  word_ascii;
reg [31:0]  memory [5000000:0];

reg signed [IQ_DATA_WIDTH-1:0] I_DATA_I=100;
reg signed [IQ_DATA_WIDTH-1:0] I_DATA_Q=100;

reg [VAL_CNT_WIDTH-1:0] VAL_REG_CNT=0;

integer	fid;
integer fout, fout1, fout2;
integer N,i=0;
	
initial forever #8  CLK <= !CLK;	//125 MHz
initial 		#32 nRESET <= 1;

//блок генерации прореженного велида(чтобы данные не шли сплошным потоком.)	
initial  begin		
    while (1) begin	
		@ (posedge CLK);			
			VAL_REG_CNT <= VAL_REG_CNT+1;
			VAL_REG     <= ( VAL_REG_CNT==0 );			
    end
end


//============================================================================================================//
//												Test block's											      //
//============================================================================================================//
wire shift_phase;
wire llr_reset;
wire sync_ok;


reg [59:0]demode_data = 60'b101001000100111011001100010011100111010101111111011110110111;   // Добавлена ошибка в 6 бите справа, начиная счет с 0
reg       vld_sh;
reg [1 :0]in_data;
reg [7 :0]cnt = 0;
wire[1 :0] a;


assign a = (demode_data >> cnt);

always@(posedge CLK) begin
    if(!nRESET) begin
        demode_data <= 60'b101001000100111011001100010011100111010101111111011110110111;    // Добавлена ошибка в 6 бите справа, начиная счет с 0
        cnt <= 0;
        in_data <= 0;
    end else if (VAL_REG && cnt < 60) begin
        cnt <= cnt + 2;
        in_data[1:0] <= {a[0], a[1]}; 
    end
    vld_sh <= VAL_REG;
end

fano_decoder#(
    .ROTATE_PERIOD_WIDTH(24),
    .SYNC_PERIOD_WIDTH  (15),
    .MAX_SH_W           (60)
)fano_decoder_inst(
    .clk              (CLK        ),
    .reset_n          (nRESET     ),
    .i_diff_en        (1'b0       ),
    .i_code_rate      (2'b0       ),
    .i_norotate_period(24'd40000  ),
    .i_sync_period    (15'd10000  ),
    .i_sync_threshold (15'd20000  ),
    .i_last_phase_stb (1'b0       ),
    .o_shift_phs      (shift_phase),
    .o_llr_reset      (llr_reset  ),
    .i_vld            (vld_sh     ),
    .i_data           (in_data    ),
    .i_delta_T        (8'd5       ),
    .i_forward_step   (8'd10      ),
    .o_is_sync        (sync_ok    )
);


endmodule
