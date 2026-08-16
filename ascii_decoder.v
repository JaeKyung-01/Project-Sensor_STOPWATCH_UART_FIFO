`timescale 1ns / 1ps


module ascii_decoder (
    input      [7:0] data,
    input            rx_done,
    output reg [11:0] o_ascii

);

    always @(*) begin
        o_ascii = 12'h000;
        if (rx_done) begin
            case (data)
                8'h72: begin  //r
                    o_ascii[0] = 1;
                end
                8'h73: begin  //s
                    o_ascii[1] = 1;
                end
                8'h63: begin  //c
                    o_ascii[2] = 1;
                end
                8'h6d: begin  //m
                    o_ascii[3] = 1;
                end
                8'h53: begin  //S
                    o_ascii[4] = 1;
                end
                8'h4d: begin  //M
                    o_ascii[5] = 1;
                end
                8'h48: begin  //H
                    o_ascii[6] = 1;
                end
                8'h41: begin  //A
                    o_ascii[7] = 1;
                end
                8'h43: begin  //C
                    o_ascii[8] = 1;
                end
                8'h46: begin  //F
                    o_ascii[9] = 1;
                end
                8'h42: begin  //B
                    o_ascii[10] = 1;
                end

            endcase
        end
    end
endmodule




