`timescale 1ns / 1ps
module ROUNDER #(
    // Версия. OLD_VERSION = 0 - новая версия ROUNDER2ZEROS.
    //         OLD_VERSION = 1 - старая версия ROUNDER.
    parameter OLD_VERSION = 0,
    parameter integer DIN_WIDTH=12,
    parameter integer DOUT_WIDTH=10
)(
    input CLK,
    input [DIN_WIDTH-1:0]   DIN,
    input                   DIN_CE,
    output [DOUT_WIDTH-1:0] DOUT
);
/********************************************************************************/
//Signals declaration section
/********************************************************************************/
    wire [DIN_WIDTH-1:0]    DIN_ROUNDED;
    wire [DOUT_WIDTH-1:0]   DIN_ROUNDED_MUX;
    genvar I;
/********************************************************************************/
//Main section
/********************************************************************************/
    generate
        if (OLD_VERSION == 1) begin: old_version
            assign DIN_ROUNDED=$unsigned(DIN)+$unsigned({(DIN_WIDTH-DOUT_WIDTH-1){1'b1}})+$unsigned(DIN[DIN_WIDTH-1]);
            //Check for overflow
            assign DIN_ROUNDED_MUX=(DIN_ROUNDED[DIN_WIDTH-1]==DIN[DIN_WIDTH-1]) ? DIN_ROUNDED[DIN_WIDTH-1:DIN_WIDTH-DOUT_WIDTH] :
                                                                              {DIN[DIN_WIDTH-1:DIN_WIDTH-DOUT_WIDTH]};//,{DOUT_WIDTH-1{1'b1}}
        end else begin: new_version
            assign DIN_ROUNDED = $signed(DIN) - $signed({{(DIN_WIDTH-DOUT_WIDTH){DIN[DIN_WIDTH-1]}}, DIN[DIN_WIDTH-DOUT_WIDTH-1: 0]});
            //Check for overflow
            assign DIN_ROUNDED_MUX=DIN_ROUNDED[DIN_WIDTH-1:DIN_WIDTH-DOUT_WIDTH];
        end
    endgenerate

    generate
        for(I=0;I<DOUT_WIDTH;I=I+1)
        begin:DOUT_RG
            FDE INST(
                .Q(DOUT[I]),
                .D(DIN_ROUNDED_MUX[I]),
                .C(CLK),
                .CE(DIN_CE)
            );
        end
    endgenerate

endmodule