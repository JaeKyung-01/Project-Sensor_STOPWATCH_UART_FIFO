`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    reg [7:0] q_reg;  // 8tab shift register SIPO
    wire debounce;  // output of 8 input AND gate
    reg edge_reg;

    reg [$clog2(50)-1:0] counter_reg;
    reg o_1mhz;

    // clock div : 100Mhz -> 1Mhz
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_1mhz <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (50-1)) begin
                counter_reg <= 0;
                o_1mhz <= ~o_1mhz;
            end
        end 
    end
    // assign o_btn = q_reg[7];

    // 8 bit shift register, SIPO
    always @(posedge o_1mhz, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h00;
        end else begin
            // q_reg <= {q_reg[6:0], i_btn}; //shift left
            q_reg <= {i_btn, q_reg[7:1]};  //shift right
        end
    end

    // 8bit input AND gate
    assign debounce = &q_reg;

    // 1 clock delay by debounce
    always @(posedge clk, posedge reset) begin
        if (reset) edge_reg <= 1'b0;
        else begin
            edge_reg <= debounce;
        end
    end
    // edge detection
    assign o_btn = debounce & (~edge_reg);

endmodule