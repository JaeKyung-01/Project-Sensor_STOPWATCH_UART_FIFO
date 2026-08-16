`timescale 1ns / 1ps

module top_sr04 (
    input        clk,
    input        reset,
    input        btnR,
    input        echo,
    output       trigger,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire w_btn_start;
    wire [8:0] w_dist;

    sr04_controller U_SR04_CNTL (
        .clk     (clk),
        .reset   (reset),
        .start   (w_btn_start),
        .echo    (echo),
        .trigger (trigger),
        .done    (),
        .distance(w_dist)
    );

    fnd_controller U_FND_CNTL (
        .clk     (clk),
        .reset   (reset),
        .fnd_in  (w_dist),
        .fnd_com (fnd_com),
        .fnd_data(fnd_data)
    );

    btn_debounce U_BD_START (
        .clk  (clk),
        .reset(reset),
        .i_btn(btnR),
        .o_btn(w_btn_start)
    );

endmodule

module sr04_controller (
    input            clk,
    input            reset,
    input            start,
    input            echo,
    output           done,
    output reg       trigger,
    output     [8:0] distance
);

    wire w_tick_us;

    localparam [2:0] IDLE = 0, START = 1, WAIT = 2, COUNT = 3, DISTANCE = 4;

    reg [2:0] c_state, n_state;
    reg run_stop;
    reg clear;
    reg [$clog2(58*400)-1:0] counter_reg, counter_next;
    reg [8:0] distance_reg;

    tick_us U_TICK_US (
        .clk      (clk),
        .reset    (reset),
        .run_stop (run_stop),
        .clear    (clear),
        .o_tick_us(w_tick_us)
    );

    assign distance = distance_reg;
    // assign done = (c_state == DISTANCE); test use

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state      <= IDLE;
            counter_reg  <= 0;
            distance_reg <= 0;
        end else begin
            c_state     <= n_state;
            counter_reg <= counter_next;

            if (c_state == DISTANCE) begin
                distance_reg <= counter_reg / 58;
            end
        end
    end

    always @(*) begin
        n_state      = c_state;
        counter_next = counter_reg;
        run_stop     = 1'b0;
        clear        = 1'b0;
        trigger      = 1'b0;

        case (c_state)
            IDLE: begin
                run_stop = 1'b0;
                clear    = 1'b1;
                trigger  = 1'b0;
                if (start) begin
                    n_state      = START;
                    counter_next = 0;
                end
            end

            START: begin
                run_stop = 1'b1;
                clear    = 1'b0;
                trigger  = 1'b1;
                if (w_tick_us) begin
                    counter_next = counter_reg + 1;
                end
                if (counter_reg == 11) begin
                    n_state = WAIT;
                    counter_next = 0;
                end
            end

            WAIT: begin
                run_stop = 1'b0;
                clear    = 1'b0;
                trigger  = 1'b0;

                if (echo) begin
                    clear = 1'b1;
                    counter_next = 0;
                    n_state = COUNT;
                end
            end

            COUNT: begin
                run_stop = 1'b1;
                clear    = 1'b0;
                trigger  = 1'b0;
                if (echo) begin
                    if (w_tick_us) begin
                        counter_next = counter_reg + 1;
                    end
                end else begin
                    n_state = DISTANCE;
                end
            end

            DISTANCE: begin
                run_stop = 1'b0;
                clear    = 1'b1;
                trigger  = 1'b0;
                n_state = IDLE;
            end

            default: begin
                n_state      = IDLE;
                counter_next = 0;
                run_stop     = 1'b0;
                clear        = 1'b1;
                trigger      = 1'b0;
            end
        endcase
    end

endmodule

module tick_us (
    input  clk,
    input  reset,
    input  run_stop,
    input  clear,
    output o_tick_us
);

    parameter F_COUNT = 100;

    reg [$clog2(F_COUNT-1):0] counter_reg;
    reg tick_us_reg;

    assign o_tick_us = tick_us_reg;

    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
            tick_us_reg <= 0;
        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == (F_COUNT - 1)) begin
                    counter_reg <= 0;
                    tick_us_reg <= 1'b1;
                end else begin
                    tick_us_reg <= 1'b0;
                end
            end
        end
    end

endmodule