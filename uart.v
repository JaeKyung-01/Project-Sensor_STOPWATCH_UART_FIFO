`timescale 1ns / 1ps


module uart_controller (
    input        clk,
    input        reset,
    input        tx_start,
    input  [7:0] tx_data,
    input        rx,
    output [7:0] rx_data,
    output       rx_done,
    output       tx_busy,
    output       tx_done,
    output       tx

    //output rx,

);

    wire w_baud_tick_x16;

    baud_tick_x16 U_BAUD_TICK_X16 (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(w_baud_tick_x16)
    );

    uart_tx U_UART_TX (
        .clk        (clk),
        .reset      (reset),
        .tx_start   (tx_start),
        .tx_data    (tx_data),
        .i_baud_tick(w_baud_tick_x16),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done),
        .tx         (tx)
    );

    uart_rx U_UART_RX (
        .clk        (clk),
        .reset      (reset),
        .i_baud_tick(w_baud_tick_x16),
        .rx         (rx),
        .rx_data    (rx_data),
        .rx_done    (rx_done)
    );

endmodule

module uart_tx (
    input clk,
    input reset,
    input tx_start,
    input [7:0] tx_data,
    input i_baud_tick,
    output tx_busy,
    output tx_done,
    output tx                                                         /////////////////////tx 사용의 용도가 뭐지? // 용도는 병렬로 들어온 신호를 직렬로 보내는 동작을 위해(PISO)
);

    localparam [1:0] IDLE = 2'd0, START = 2'd1;
    localparam [1:0] DATA = 2'd2, STOP = 2'd3;

    reg [1:0] c_state, n_state;
    reg [3:0] tick_count_reg, tick_count_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg tx_reg, tx_next;
    reg [7:0] data_reg, data_next;
    reg tx_busy_reg, tx_busy_next;
    reg tx_done_reg, tx_done_next;

    assign tx      = tx_reg;
    assign tx_busy = tx_busy_reg;
    assign tx_done = tx_done_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            tick_count_reg <= 4'b0000;
            bit_count_reg <= 3'b000;
            tx_reg          <= 1'b1;                    /////////////////////uart 통신 규경에서 대기 상태의 기본값이 1로 약속
            data_reg <= 8'h00;
            tx_busy_reg <= 1'b0;
            tx_done_reg <= 1'b0;
        end else begin
            c_state        <= n_state;
            tick_count_reg <= tick_count_next;
            bit_count_reg  <= bit_count_next;
            tx_reg         <= tx_next;
            data_reg       <= data_next;
            tx_busy_reg    <= tx_busy_next;
            tx_done_reg    <= tx_done_next;
        end
    end

    always @(*) begin
        n_state         = c_state;
        tx_next         = tx_reg;
        tick_count_next = tick_count_reg;  /////////////수정(추가함)
        bit_count_next  = bit_count_reg;
        data_next       = data_reg;
        tx_busy_next    = tx_busy_reg;
        tx_done_next    = tx_done_reg;
        case (c_state)
            IDLE: begin
                tick_count_next = 0;  /////////////수정(추가함)
                tx_next         = 1'b1;
                tx_busy_next    = 1'b0;
                tx_done_next    = 1'b0;
                if (tx_start) begin
                    tx_busy_next = 1'b1;
                    data_next    = tx_data;
                    n_state      = START;
                end
            end
            START: begin
                tx_next        = 1'b0;
                bit_count_next = 3'b000;
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        n_state         = DATA;
                    end else tick_count_next = tick_count_reg + 1;
                end
            end
            DATA: begin
                tx_next = data_reg[0];                                    /////////////////////여기 자리가 bit_count_reg인가? // 그리고 시프트 된 data를 tx로 넘겨서 어디에 사용하는거야?
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        data_next = {1'b0, data_reg[7:1]};
                        tick_count_next = 0;                               ///////////////////이거 여기 위치면 
                        if (bit_count_reg == 7) n_state = STOP;
                        else begin
                            n_state        = DATA;
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin                     ///////////////////tx에서 굳이 STOP에서 tick_count_reg가 7일때 하는 이유는? 15에서 안하고//수정함(7->15)
                        //tick_count_next = 0;                                       ///////////////////수정내용(추가함) -> 다시 주석처리. 이유는 idle에서 초기화함
                        tx_busy_next = 1'b0;
                        tx_done_next = 1'b1;
                        n_state = IDLE;
                    end else tick_count_next = tick_count_reg + 1;
                end
            end
        endcase
    end
endmodule


module uart_rx (                             ///////////////////rx에는 bit_count가 없네. 그러면 rx가 1일 때는 기본적으로 
    input        clk,
    input        reset,
    input        i_baud_tick,
    input        rx,
    output [7:0] rx_data,
    output       rx_done

);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA = 2'd2;
    localparam [1:0] STOP = 2'd3;

    reg [1:0] n_state;
    reg [1:0] c_state;
    reg [3:0] tick_count_reg, tick_count_next;
    reg [2:0]
        bit_count_reg, bit_count_next;  //////////////비트수 수정 4 -> 3
    reg [7:0] data_reg, data_next;
    //reg rx_done_reg; // for CL
    reg rx_done_reg, rx_done_next;  // for SL

    assign rx_done = rx_done_reg;
    assign rx_data = data_reg;

    //for SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state        <= 0;
            tick_count_reg <= 0;
            bit_count_reg  <= 0;
            data_reg       <= 0;
            rx_done_reg    <= 0;

        end else begin
            c_state        <= n_state;
            tick_count_reg <= tick_count_next;
            bit_count_reg  <= bit_count_next;
            data_reg       <= data_next;
            rx_done_reg    <= rx_done_next;

        end
    end

    always @(*) begin
        n_state         = c_state;
        tick_count_next = tick_count_reg;
        bit_count_next  = bit_count_reg;
        data_next       = data_reg;
        rx_done_next    = rx_done_reg;  //for SL

        case (c_state)
            IDLE: begin
                rx_done_next = 0;
                //bit_count_next = 0;       /////////////위치를 아래쪽로 변경
                if (i_baud_tick) begin
                    if (!rx) begin
                        if (tick_count_reg == 7) begin
                            n_state         = START;
                            tick_count_next = 0;
                        end else begin
                            tick_count_next = tick_count_reg + 1;
                        end
                    end else begin
                        //data_next       = 0;            ////////////////////이거 주석 풀어야 하는거 아닌가?
                        tick_count_next = 0;
                        bit_count_next  = 0;
                    end
                end
            end
            START: begin
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        n_state = DATA;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                if (i_baud_tick) begin
                    if (tick_count_reg == 0) begin
                        // data_next = data_reg[bit_count_reg]; // PIPO ,bit indexing
                        //SIPO
                        data_next = {
                            rx, data_reg[7:1]
                        };  ////여기 다음에 n_state = DATA;나와야할것 같은데?  //그리고 여기에 rx가 있으면 data_reg 0으로 초기화 되는거 아닌가? 
                    end
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1; /////////////////이게 위치가 여기가 맞나?
                    end
                end  /////////////////////여기에 tick_count_next = tick_count_reg + 1;이게 있어야 하는거 아닌가?
            end
            STOP: begin
                if (i_baud_tick) begin
                    if (tick_count_reg == 7) begin
                        rx_done_next = 1;
                        n_state = IDLE;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule


module baud_tick_x16 (
    input  clk,
    input  reset,
    output o_baud_tick
);

    parameter F_COUNT = 100_000_000 / (9600 * 16);
    reg  [$clog2(F_COUNT)-1:0] count_reg;
    wire [$clog2(F_COUNT)-1:0] count_next;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            count_reg <= 0;
        end else begin
            count_reg <= count_next;
        end
    end

    //next CL
    assign count_next  = (count_reg == (F_COUNT - 1)) ? 0 : count_reg + 1;
    assign o_baud_tick = (count_reg == (F_COUNT - 1)) ? 1 : 0;
    //always @(*) begin 
    //    count_next = count_reg;
    //    if(count_reg == F_COUNT - 1) count_next = 0;
    //    else count_reg = count_reg;
    //end

    //9600bps baud tick gen
endmodule


//module baud_tick (
//    input  clk,
//    input  reset,
//    output o_baud_tick
//);
//
//    parameter F_COUNT = 100_000_000 / 9600;
//    reg  [$clog2(F_COUNT)-1:0] count_reg;
//    wire [$clog2(F_COUNT)-1:0] count_next;
//
//    always @(posedge clk, posedge reset) begin
//
//        if (reset) begin
//            count_reg <= 0;
//        end else begin
//            count_reg <= count_next;
//        end
//    end
//
//    //next CL
//    assign count_next  = (count_reg == (F_COUNT - 1)) ? 0 : count_reg + 1;
//    assign o_baud_tick = (count_reg == (F_COUNT - 1)) ? 1 : 0;
//    //always @(*) begin 
//    //    count_next = count_reg;
//    //    if(count_reg == F_COUNT - 1) count_next = 0;
//    //    else count_reg = count_reg;
//    //end
//
//    //9600bps baud tick gen
//
//endmodule




//module badu_tick_2(
//    input clk,
//    input reset,
//    output reg o_baud_tick
//);
//
//    parameter F_COUNT = 100_000_000/9600;
//    reg [$clog2(F_COUNT)-1:0] count_reg;
//
//
//    always @(posedge clk, posedge reset) begin 
//        if(reset) begin
//            count_reg <= 0;
//        end else begin 
//            count_reg <= count_reg + 1;
//            if (count_reg == (F_COUNT - 1)) begin
//                count_reg <= 0;
//                o_baud_tick <= 1;
//            end
//            o_baud_tick <= 0;
//        end
//    end
//endmodule