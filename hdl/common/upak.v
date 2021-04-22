`timescale 1ns / 1ps
//
//�������� NOB(number of byte) ���������� ����������� �������� ������ 8,16,24,32 (=NOB*8)
module upak #(parameter NOB=1)(
	input i_clk,
	input i_rst,
	input [7:0] i_data,
	input i_data_valid,
	input [3:0] i_order,
	input i_isndata,
	input i_ismirrordata,
	input i_ismirrorbyte,
	input i_ismirrorword,
	output [(NOB*8)-1:0] o_byte,
	output o_byte_valid
	);

integer a,b,c,d,i,j,k;

//��������� ��������� ��� �������
    localparam FM2_1=4'd1;
    localparam FM4_2=4'd2;
    localparam FM8_3=4'd3;
    localparam QAM16_4=4'd4;
    localparam QAM32_5=4'd5;
    localparam QAM64_6=4'd6;
    localparam QAM128_7=4'd7;
    localparam QAM256_8=4'd8;
    
    localparam lat_valid=4;//����������� ������ ������ ������

wire clk=i_clk;//�������������� ������� ����

reg [7:0] byte_valid_tg=0;//����������� ������ ������ ����������

//��������� �������� ������� ������ �� ������� ��������
	reg [(NOB-1)*8+14:0] data_shift_reg_8=0;
    reg [(NOB-1)*8+14:0] data_shift_reg_7=0;
    reg [(NOB-1)*8+14:0] data_shift_reg_6=0;
    reg [(NOB-1)*8+14:0] data_shift_reg_5=0;
    reg [(NOB-1)*8+14:0] data_shift_reg_4=0;
    reg [(NOB-1)*8+14:0] data_shift_reg_3=0;
    reg [(NOB-1)*8+14:0] data_shift_reg_2=0;
    reg [(NOB-1)*8+14:0] data_shift_reg_1=0;
    reg [(NOB-1)*8+14:0] data_shift_reg=0;

reg [7:0] data_cnt=0;//������� ����������� �������� ���

//��������� ��� ������(�������� ���� ��� ����� ����� ������� �������� �����(���������� ������) ���)
//����������� �������� ��� ����� ����������� ����������� ���
//����������� ������� �������� ��� ��� ������� ��� ����
    reg [7:0] data_cnt_sub=0;//

reg [(NOB*8)-1:0] valid_byte=0;//�������� ������� ������
reg [(NOB*8)-1:0] valid_byte_shift_reg;//��������������� ������
reg [(NOB*8)-1:0] valid_byte_mirror_bit_reg;
reg [(NOB*8)-1:0] valid_byte_mirror_byte_reg;

reg [7:0] point_sub=0;//��������� ��� ����������� ���������

reg [3:0] i_order_tg;//�������� ��� ����������� ��������� ��� ��������� ���������� �����... ��� ���

//�������� ������
    assign o_byte=valid_byte;
    assign o_byte_valid=byte_valid_tg[lat_valid];

///////////////////////////
//��������� ��������������� ��������� �������� ��� ��������
always @(posedge clk) begin
    if(i_data_valid) begin//��� �� ������� ������������� ������� ������
        if(i_ismirrordata) begin
			data_shift_reg_8[(NOB-1)*8+14:0]<={data_shift_reg_8[(NOB-1)*8+6:0], i_data[0],i_data[1],i_data[2],i_data[3],i_data[4],i_data[5],i_data[6],i_data[7]};
            data_shift_reg_7[(NOB-1)*8+14:0]<={data_shift_reg_7[(NOB-1)*8+7:0], i_data[0],i_data[1],i_data[2],i_data[3],i_data[4],i_data[5],i_data[6]};
            data_shift_reg_6[(NOB-1)*8+14:0]<={data_shift_reg_6[(NOB-1)*8+8:0], i_data[0],i_data[1],i_data[2],i_data[3],i_data[4],i_data[5]};
            data_shift_reg_5[(NOB-1)*8+14:0]<={data_shift_reg_5[(NOB-1)*8+9:0], i_data[0],i_data[1],i_data[2],i_data[3],i_data[4]};
            data_shift_reg_4[(NOB-1)*8+14:0]<={data_shift_reg_4[(NOB-1)*8+10:0],i_data[0],i_data[1],i_data[2],i_data[3]};
            data_shift_reg_3[(NOB-1)*8+14:0]<={data_shift_reg_3[(NOB-1)*8+11:0],i_data[0],i_data[1],i_data[2]};
            data_shift_reg_2[(NOB-1)*8+14:0]<={data_shift_reg_2[(NOB-1)*8+12:0],i_data[0],i_data[1]};
            data_shift_reg_1[(NOB-1)*8+14:0]<={data_shift_reg_1[(NOB-1)*8+13:0],i_data[0]};
        end
        else begin
		    data_shift_reg_8[(NOB-1)*8+14:0]<={data_shift_reg_8[(NOB-1)*8+6:0], i_data[7:0]};
            data_shift_reg_7[(NOB-1)*8+14:0]<={data_shift_reg_7[(NOB-1)*8+7:0], i_data[6:0]};
            data_shift_reg_6[(NOB-1)*8+14:0]<={data_shift_reg_6[(NOB-1)*8+8:0], i_data[5:0]};
            data_shift_reg_5[(NOB-1)*8+14:0]<={data_shift_reg_5[(NOB-1)*8+9:0], i_data[4:0]};
            data_shift_reg_4[(NOB-1)*8+14:0]<={data_shift_reg_4[(NOB-1)*8+10:0],i_data[3:0]};
            data_shift_reg_3[(NOB-1)*8+14:0]<={data_shift_reg_3[(NOB-1)*8+11:0],i_data[2:0]};
            data_shift_reg_2[(NOB-1)*8+14:0]<={data_shift_reg_2[(NOB-1)*8+12:0],i_data[1:0]};
            data_shift_reg_1[(NOB-1)*8+14:0]<={data_shift_reg_1[(NOB-1)*8+13:0],i_data[0:0]};
        end
    end
end

///////////////////////////
//������
always @(posedge clk) begin
    i_order_tg[3:0]<=i_order[3:0];//���������� ����������� �������� ������� ��� ���������� ���������
    
    if((i_order_tg[3:0] != i_order[3:0]) || (i_rst)) begin//����� ��� ������������ �������
        data_cnt[7:0]<='d0;//���������,������� �������� ���
        byte_valid_tg[7:0]='d0;//������� ����������
    end
    else if(~i_data_valid) begin//����� ��������� ���� ���������� �������� ������ ��� ���������� ���������� ������� ������
        byte_valid_tg[lat_valid]<=0;
    end
    else if(i_data_valid) begin//��������� �������� ������
        //������������� ���� � ������
            if(i_ismirrorbyte) begin
                for(a=0;a<NOB;a=a+1) begin
                    for(b=0;b<8;b=b+1)
                        valid_byte_mirror_bit_reg[(a*8+b)]<=valid_byte_shift_reg[(a*8+7-b)];
                end
            end
            else//��� ���
                valid_byte_mirror_bit_reg[(NOB*8)-1:0]<=valid_byte_shift_reg[(NOB*8)-1:0];
        
        //������������� �������� ����� ��������  
            if(i_ismirrorword) begin
                for(c=0;c<NOB;c=c+1) begin
                    for(d=0;d<8;d=d+1)
                        valid_byte_mirror_byte_reg[((c*8)+d)]<=valid_byte_mirror_bit_reg[(((NOB-1)*8)-c*8+d)];
                end
            end 
            else//��� ���
                valid_byte_mirror_byte_reg[(NOB*8)-1:0]<=valid_byte_mirror_bit_reg[(NOB*8)-1:0];
            
        //�������� ��������� � �� �����           
            if(i_isndata)
                valid_byte[(NOB*8)-1:0]<=~valid_byte_mirror_byte_reg[(NOB*8)-1:0];//���� �� �����
            else//��� ���
                valid_byte[(NOB*8)-1:0]<=valid_byte_mirror_byte_reg[(NOB*8)-1:0];
            
            
        //��������� ����������
            byte_valid_tg[7:1]<=byte_valid_tg[6:0];//����������� �������� ���������� ������������ ������
            point_sub[7:0]<=(NOB*8)-i_order[3:0];//���������� ��� ���������� ������ ��������� ��� ������������� ���������� � ������
            data_cnt_sub[7:0]<=data_cnt[7:0]-(NOB*8); //���������� ��� ���������� ��������� ������ ������
            valid_byte_shift_reg<=(data_shift_reg>>(data_cnt_sub));//�������� �� ����� ����� �� ���������//��� ������������ ������� ����� �� �������
        
        //����������� ���������� �������� ������
            if(data_cnt[7:0]<(NOB*8)) begin//
                data_cnt[7:0]<=data_cnt[7:0]+i_order[3:0];//���������� ��������� +=�������
                byte_valid_tg[0]<=1'd0;//����� �������� ���������� ������������ ������ ��� ���������� ���
            end 
            else begin
                data_cnt[7:0]<=data_cnt[7:0]-point_sub[7:0];//���������� ��������� +=�������-�����������
                byte_valid_tg[0]<=1;//��������� �������� ���������� ������������ ������ ��� ������������� ���
            end
      
        //�������� ��������������� ����� � ������� ��� ���������� ���������
            case (i_order[3:0])//� �������� ������� �������� ����������� ������
                FM2_1:    data_shift_reg[(NOB-1)*8+14:0]<=data_shift_reg_1[(NOB-1)*8+14:0];
                FM4_2:    data_shift_reg[(NOB-1)*8+14:0]<=data_shift_reg_2[(NOB-1)*8+14:0];
                FM8_3:    data_shift_reg[(NOB-1)*8+14:0]<=data_shift_reg_3[(NOB-1)*8+14:0];
                QAM16_4:  data_shift_reg[(NOB-1)*8+14:0]<=data_shift_reg_4[(NOB-1)*8+14:0];
                QAM32_5:  data_shift_reg[(NOB-1)*8+14:0]<=data_shift_reg_5[(NOB-1)*8+14:0];
                QAM64_6:  data_shift_reg[(NOB-1)*8+14:0]<=data_shift_reg_6[(NOB-1)*8+14:0];
                QAM128_7: data_shift_reg[(NOB-1)*8+14:0]<=data_shift_reg_7[(NOB-1)*8+14:0];
				QAM256_8: data_shift_reg[(NOB-1)*8+14:0]<=data_shift_reg_8[(NOB-1)*8+14:0];
                default:  data_shift_reg[(NOB-1)*8+14:0]<=0;
            endcase
            
    end
end

endmodule