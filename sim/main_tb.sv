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
localparam MODULATION_TYPE = 2;  // 1 - qpsk, else - 8-psk

wire shift_phase;
wire llr_reset;
wire sync_ok;
wire llr_hd;
wire llr_vld;
wire llr_ready;
wire[2:0] llr_order;

reg       vld_sh;
reg [1 :0]in_data;
reg       err_vld_sh;
// prs signal
wire      prs_sym;
wire      prs_vld;
wire      encoder_vld;
wire[1:0] encoder_word;
wire[1:0] err_word;
wire      err_vld;
wire      dec_vld;
wire      dec_sym;
reg       wr_vld;
reg [5:0] cntr;
reg [7:0] wr_data;
reg [9:0] I, Q;
wire      vld;

integer fout;

initial begin
    fout = $fopen("dec_sym.bin", "wb");
    if(fout == 0) begin
		$display("Error: output TB File  could not be opened.\nExiting Simulation.");
		$finish;
	end
    #500000
    $fclose(fout);
end

always@(posedge CLK) begin
	if(wr_vld)
        $fwrite(fout,"%c",  wr_data[7:0]);
end

always@(posedge CLK) begin
    if(!nRESET) begin
        cntr    <= 0;
        wr_data <= 0;
    end else if(dec_vld) begin
        cntr         <= cntr + 1;
        wr_data[7:0] <= {wr_data[6:0], dec_sym};
    end else begin
        cntr <= (cntr == 6'd8) ? 0 : cntr;
    end
end

always@(posedge CLK) begin
    if(!nRESET) wr_vld <= 0;
    else        wr_vld <= (cntr == 6'd8) ? 1 : 0;
end


prs_gen prs_gen_inst(
    .clk    (CLK    ),
    .reset_n(nRESET ),
    .i_vld  (VAL_REG),
    .o_vld  (prs_vld),
    .o_sym  (prs_sym)
);

conv_encoder encoder_inst(
    .clk    (CLK         ),
    .reset_n(nRESET      ),
    .i_vld  (prs_vld     ),
    .i_sym  (prs_sym     ),
    .o_vld  (encoder_vld ),
    .o_word (encoder_word)
);

err_generator err_gen_inst(
    .clk        (CLK         ),
    .reset_n    (nRESET      ),
    .i_enable   (1'b0        ),
    .i_first_err(11'd4       ),
    .i_err_rate (11'd30      ),
    .i_vld      (encoder_vld ),
    .i_word     (encoder_word),
    .o_vld      (err_vld     ),
    .o_word     (err_word    )
);

always@(posedge CLK) begin
        if(!nRESET) err_vld_sh <= 0;
        else        err_vld_sh <= err_vld;
end

generate
    if(MODULATION_TYPE) begin
        assign llr_order = 2;
    //========= qpsk ===========//
        always@(posedge CLK) begin
            if(!nRESET) begin
                I          <= 0;
                Q          <= 0;
            end else begin            
                if(err_word == 2'b11) begin
                    I <= -10'd180;
                    Q <= -10'd180;
                end else if(err_word == 2'b10) begin
                    I <=  10'd180;
                    Q <= -10'd180;
                end else if(err_word == 2'b01) begin
                    I <= -10'd180;
                    Q <=  10'd180;
                end else begin
                    I <= 10'd180;
                    Q <= 10'd180;
                end
            end
        end
        
        assign vld = err_vld_sh;
    end else begin
    //========= 8-psk ===========//
        assign llr_order = 3;
        reg[3:0]  sh_reg;
        reg       take_flag = 0;
        reg       en_flag = 0;
        wire[2:0] encode_word;
        reg [1:0] vld_cntr = 0;
        reg       word_vld;
        always@(posedge CLK) begin
            if(!nRESET) begin     
                sh_reg[3:0] <= 0;
                take_flag   <= 0;
            end else if(err_vld) begin
                sh_reg[3:0] <= {sh_reg[1:0], err_word};
                take_flag   <= vld_cntr == 0 ? take_flag : ~take_flag;
            end
        end
        
        always@(posedge CLK) begin
            if(!nRESET)         vld_cntr <= 0;
            else if(err_vld_sh) vld_cntr <= vld_cntr == 2 ? 0 : vld_cntr + 1;
        end
        
        assign encode_word[2:0] = take_flag ? sh_reg[3:1] : sh_reg[2:0];
        
        always@(posedge CLK) begin
            if(err_vld_sh && vld_cntr!=0) begin
                case(encode_word[2:0])

                    3'b000: begin          // 000
                        I = 10'd236;
                        Q = 10'd98 ;
                    end                    
                    3'b001: begin          // 001
                        I = 10'd98 ;
                        Q = 10'd236;
                    end                    

                    3'b011: begin           // 011
                        I = -10'd98 ;
                        Q =  10'd236;
                    end                    
                    3'b010: begin           // 010
                        I = -10'd236;
                        Q =  10'd98 ;
                    end                    

                    3'b110: begin           // 110
                        I = -10'd236;
                        Q = -10'd98 ;
                    end                    
                    3'b111: begin           // 111
                        I = -10'd98 ;
                        Q = -10'd236;
                    end                    

                    3'b101: begin           // 101
                        I =  10'd98 ;
                        Q = -10'd236;
                    end                    
                    3'b100: begin           // 100
                        I =  10'd236;
                        Q = -10'd98 ;
                    end                    
                    default: begin
                        I = 10'd0;
                        Q = 10'd0;
                    end                    
                endcase
                word_vld <= 1;
            end else 
                word_vld <= 0;
        end
        assign vld = word_vld;
    end
endgenerate


fano_decoder#(
    .SYNC_PERIOD_WIDTH  (24),
    .MAX_SH_W           (60)
)fano_decoder_inst(
    .clk              (CLK      ),
    .reset_n          (nRESET   ),
    .i_diff_en        (1'b0     ),
    .i_llr_order      (llr_order),
    .i_code_rate      (2'b0     ),
    .i_sync_period    (24'd40000),
    .i_sync_threshold (15'd100  ),
    .i_vld            (vld      ),  // VAL_REG
    .i_data_I         (I        ),
    .i_data_Q         (Q        ),
    .i_delta_T        (8'd5     ),
    .i_forward_step   (16'd100  ),
    .o_vld            (dec_vld  ),
    .o_dec_sym        (dec_sym  ),
    .o_is_sync        (sync_ok  )
);

endmodule
