`timescale 1ns / 1ps

module fnd_controller (
    input         clk,
    input         reset,
    input  [13:0] fnd_in,
    output [ 3:0] fnd_com,
    output [ 7:0] fnd_data
);

    //assign fnd_com = 4'b1110;
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    wire [3:0] bcd;
    wire [1:0] w_digit_sel;
    wire w_1khz;

    clk_div U_CLK_DIV (
        .clk   (clk),
        .reset (reset),
        .o_1khz(w_1khz)
    );

    counter_4 U_COUNTER_4 (
        .clk      (w_1khz),
        .reset    (reset),
        .digit_sel(w_digit_sel)

    );

    decoder_2x4 U_DECODER_2X4 (
        .digit_sel(w_digit_sel),
        .fnd_com  (fnd_com)
    );

    digit_splitter U_DS (
        .seg_data  (fnd_in),
        .digit_1   (w_digit_1),
        .digit_10  (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000(w_digit_1000)
    );

    mux_4x1 U_MUX_4X1 (
        .sel       (w_digit_sel),   // mux selection
        .digit_1   (w_digit_1),
        .digit_10  (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000(w_digit_1000),
        .mux_out   (bcd)
    );

    bcd U_BCD (
        .bcd_in (bcd),
        .bcd_out(fnd_data)
    );

endmodule

module clk_div (
    input  clk,
    input  reset,
    output o_1khz
);

    reg [15:0] counter_reg;
    reg clk_reg;

    assign o_1khz = clk_reg;

    // sequential logic
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_reg     <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (50000 - 1)) begin
                counter_reg <= 0;
                clk_reg     <= ~clk_reg;
            end
        end
    end

endmodule

module counter_4 (
    input clk,
    input reset,
    output [1:0] digit_sel
);
    reg [1:0] counter_reg;

    assign digit_sel = counter_reg;

    // sequential logic : SL
    always @(posedge clk, posedge reset) begin  // clock 비동기 reset
        if (reset) begin
            counter_reg <= 0;
        end else begin
            // operation
            counter_reg <= counter_reg + 1;
        end
    end


endmodule

module decoder_2x4 (
    input      [1:0] digit_sel,
    output reg [3:0] fnd_com
);

    always @(digit_sel) begin
        case (digit_sel)
            2'b00:   fnd_com = 4'b1110;  //digit 1
            2'b01:   fnd_com = 4'b1101;  //digit 10
            2'b10:   fnd_com = 4'b1011;  //digit 100
            2'b11:   fnd_com = 4'b0111;  //digit 1000
            default: fnd_com = 4'b1110;  //default value
        endcase
    end

endmodule

module digit_splitter (
    input  [13:0] seg_data,
    output [ 3:0] digit_1,
    output [ 3:0] digit_10,
    output [ 3:0] digit_100,
    output [ 3:0] digit_1000
);

    assign digit_1    = seg_data % 10;
    assign digit_10   = (seg_data / 10) % 10;
    assign digit_100  = (seg_data / 100) % 10;
    assign digit_1000 = (seg_data / 1000) % 10;

endmodule

module mux_4x1 (
    input  [1:0] sel,         // mux selection
    input  [3:0] digit_1,
    input  [3:0] digit_10,
    input  [3:0] digit_100,
    input  [3:0] digit_1000,
    output [3:0] mux_out
);

    //assign
    assign mux_out = (sel == 2'b00) ? digit_1 :  //true
        (sel == 2'b01) ? digit_10 : 
        (sel == 2'b10) ? digit_100 : 
        (sel == 2'b11) ? digit_1000 : 4'b1111;

endmodule


module bcd (
    input      [3:0] bcd_in,
    output reg [7:0] bcd_out
);

    always @(bcd_in) begin
        case (bcd_in)
            4'b0000: bcd_out = 8'hc0;  // 0
            4'b0001: bcd_out = 8'hf9;  // 1
            4'b0010: bcd_out = 8'ha4;  // 2
            4'b0011: bcd_out = 8'hb0;  // 3
            4'b0100: bcd_out = 8'h99;  // 4
            4'b0101: bcd_out = 8'h92;  // 5
            4'b0110: bcd_out = 8'h82;  // 6
            4'b0111: bcd_out = 8'hf8;  // 7
            4'b1000: bcd_out = 8'h80;  // 8
            4'b1001: bcd_out = 8'h90;  // 9
            4'b1010: bcd_out = 8'h88;  // a
            4'b1011: bcd_out = 8'h83;  // b
            4'b1100: bcd_out = 8'hc6;  // c
            4'b1101: bcd_out = 8'ha1;  // d
            4'b1110: bcd_out = 8'h86;  // e
            4'b1111: bcd_out = 8'h8e;  // f
        endcase
    end

endmodule