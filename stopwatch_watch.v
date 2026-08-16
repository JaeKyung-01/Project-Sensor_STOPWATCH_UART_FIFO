`timescale 1ns / 1ps

module stopwatch_watch (
    input        clk,
    input        reset,
    input  [2:0] sw,
    input        sw_watch,
    input        sw_stop,
    input        btn_L,
    input        btn_R,
    input        btn_U,
    input        btn_D,
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output [3:0] led
);

    wire w_btn_L, w_btn_R, w_btn_U, w_btn_D;
    wire [3:0] watch_fnd_com, stop_fnd_com;
    wire [7:0] watch_fnd_data, stop_fnd_data;

    btn_debouncer U_BTN_L (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_L),
        .o_btn(w_btn_L)
    );

    btn_debouncer U_BTN_R (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_R),
        .o_btn(w_btn_R)
    );

    btn_debouncer U_BTN_U (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_U),
        .o_btn(w_btn_U)
    );

    btn_debouncer U_BTN_D (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_D),
        .o_btn(w_btn_D)
    );

    top_watch U_WATCH_TOP (
        .clk     (clk),
        .reset   (reset),
        .sw      (sw[1:0]),
        .sw_watch(sw_watch),
        .btn_L   (w_btn_L),
        .btn_R   (w_btn_R),
        .btn_U   (w_btn_U),
        .btn_D   (w_btn_D),
        .fnd_com (watch_fnd_com),
        .fnd_data(watch_fnd_data)
    );

    top_stopwatch U_STOPWATCH_TOP (
        .clk     (clk),
        .reset   (reset),
        .sw      (sw[2:0]),
        .sw_stop (sw_stop),
        .btn_L   (w_btn_L),
        .btn_R   (w_btn_R),
        .btn_U   (w_btn_U),
        .btn_D   (w_btn_D),
        .fnd_com (stop_fnd_com),
        .fnd_data(stop_fnd_data)
    );

    fnd_display_mux U_FND_DISPLAY (
        .sw_watch      (sw_watch),
        .sw_stop       (sw_stop),
        .watch_fnd_com (watch_fnd_com),
        .watch_fnd_data(watch_fnd_data),
        .stop_fnd_com  (stop_fnd_com),
        .stop_fnd_data (stop_fnd_data),
        .fnd_com       (fnd_com),
        .fnd_data      (fnd_data),
        .led           (led)
    );

endmodule


module fnd_display_mux (
    input        sw_watch,
    input        sw_stop,
    input  [3:0] watch_fnd_com,
    input  [7:0] watch_fnd_data,
    input  [3:0] stop_fnd_com,
    input  [7:0] stop_fnd_data,
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output [3:0] led
);

    assign fnd_com  = (sw_stop == 1'b1) ? stop_fnd_com : watch_fnd_com;
    assign fnd_data = (sw_stop == 1'b1) ? stop_fnd_data : watch_fnd_data;
    assign led      = 4'b1111;

endmodule


module top_watch (
    input        clk,
    input        reset,
    input  [1:0] sw,
    input        sw_watch,
    input        btn_L,
    input        btn_R,
    input        btn_U,
    input        btn_D,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire w_blink_sec, w_blink_min, w_blink_hour;
    wire [1:0] w_change_sec, w_change_min, w_change_hour;
    wire [6:0] w_msec;
    wire [5:0] w_sec, w_min;
    wire [4:0] w_hour;

    wire watch_btn_L = btn_L && sw_watch;
    wire watch_btn_U = btn_U && sw_watch;
    wire watch_btn_R = btn_R && sw_watch;
    wire watch_btn_D = btn_D && sw_watch;

    watch_fnd_controller U_FND_CNTL (
        .clk         (clk),
        .reset       (reset),
        .blink_sec   (w_blink_sec),
        .blink_min   (w_blink_min),
        .blink_hour  (w_blink_hour),
        .msec        (w_msec),
        .sec         (w_sec),
        .min         (w_min),
        .hour        (w_hour),
        .display_mode(sw[0]),
        .fnd_com     (fnd_com),
        .fnd_data    (fnd_data)
    );

    watch_datapath U_WATCH_DATAPATH (
        .clk        (clk),
        .reset      (reset),
        .change_sec (w_change_sec),
        .change_min (w_change_min),
        .change_hour(w_change_hour),
        .msec       (w_msec),
        .sec        (w_sec),
        .min        (w_min),
        .hour       (w_hour)
    );

    watch_control_unit U_CNTL_UNIT (
        .clk        (clk),
        .reset      (reset),
        .btn_L      (watch_btn_L),
        .btn_R      (watch_btn_R),
        .btn_U      (watch_btn_U),
        .btn_D      (watch_btn_D),
        .sw         (sw_watch),
        .change_sec (w_change_sec),
        .change_min (w_change_min),
        .change_hour(w_change_hour),
        .blink_sec  (w_blink_sec),
        .blink_min  (w_blink_min),
        .blink_hour (w_blink_hour)
    );

endmodule


module top_stopwatch (
    input        clk,
    input        reset,
    input  [2:0] sw,
    input        sw_stop,
    input        btn_L,
    input        btn_R,
    input        btn_U,
    input        btn_D,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire w_run_stop, w_clear, w_mode;
    wire [6:0] w_msec;
    wire [5:0] w_sec, w_min;
    wire [4:0] w_hour;
    wire [6:0] display_msec;
    wire [5:0] display_sec, display_min;
    wire [4:0] display_hour;

    wire stop_btn_L = btn_L && sw_stop;
    wire stop_btn_U = btn_U && sw_stop;
    wire stop_btn_R = btn_R && sw_stop;
    wire stop_btn_D = btn_D && sw_stop;

    wire real_clear;
    assign real_clear = w_clear && !sw[2];

    control_unit U_CONTROL_UNIT (
        .clk       (clk),
        .reset     (reset),
        .i_run_stop(stop_btn_L),
        .i_clear   (stop_btn_R),
        .i_mode    (stop_btn_U),
        .o_run_stop(w_run_stop),
        .o_clear   (w_clear),
        .o_mode    (w_mode)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .reset   (reset),
        .run_stop(w_run_stop),
        .clear   (real_clear),
        .mode    (w_mode),
        .msec    (w_msec),
        .sec     (w_sec),
        .min     (w_min),
        .hour    (w_hour)
    );

    time_storage_unit U_TIME_STORAGE (
        .clk         (clk),
        .reset       (reset),
        .w_clear     (w_clear),
        .w_btn_D     (stop_btn_D),
        .sw_2        (sw[2]),
        .w_msec      (w_msec),
        .w_sec       (w_sec),
        .w_min       (w_min),
        .w_hour      (w_hour),
        .display_msec(display_msec),
        .display_sec (display_sec),
        .display_min (display_min),
        .display_hour(display_hour)
    );

    fnd_controller U_FND_CNTL (
        .clk         (clk),
        .reset       (reset),
        .msec        (display_msec),
        .sec         (display_sec),
        .min         (display_min),
        .hour        (display_hour),
        .display_mode(sw[0]),
        .sw_2        (sw[2]),
        .fnd_com     (fnd_com),
        .fnd_data    (fnd_data)
    );

endmodule


module time_storage_unit (
    input        clk,
    input        reset,
    input        w_clear,
    input        w_btn_D,
    input        sw_2,
    input  [6:0] w_msec,
    input  [5:0] w_sec,
    input  [5:0] w_min,
    input  [4:0] w_hour,
    output [6:0] display_msec,
    output [5:0] display_sec,
    output [5:0] display_min,
    output [4:0] display_hour
);

    reg [6:0] record_msec;
    reg [5:0] record_sec, record_min;
    reg [4:0] record_hour;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            record_msec <= 7'd0;
            record_sec  <= 6'd0;
            record_min  <= 6'd0;
            record_hour <= 5'd0;
        end else begin
            if (sw_2 && w_clear) begin
                record_msec <= 7'd0;
                record_sec  <= 6'd0;
                record_min  <= 6'd0;
                record_hour <= 5'd0;
            end else if (!sw_2 && w_btn_D) begin
                record_msec <= w_msec;
                record_sec  <= w_sec;
                record_min  <= w_min;
                record_hour <= w_hour;
            end
        end
    end

    assign display_msec = sw_2 ? record_msec : w_msec;
    assign display_sec  = sw_2 ? record_sec : w_sec;
    assign display_min  = sw_2 ? record_min : w_min;
    assign display_hour = sw_2 ? record_hour : w_hour;

endmodule


module stopwatch_datapath (
    input clk,
    input reset,
    input run_stop,
    input clear,
    input mode,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_tick_sec, w_tick_min, w_tick_hour;

    time_counter #(
        .BIT_WIDTH(5),
        .TIMES(24)
    ) U_HOUR_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_hour),
        .mode(mode),
        .run_stop(run_stop),
        .clear(clear),
        .time_count(hour),
        .o_tick()
    );

    time_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) U_MIN_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_min),
        .mode(mode),
        .run_stop(run_stop),
        .clear(clear),
        .time_count(min),
        .o_tick(w_tick_hour)
    );

    time_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) U_SEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_sec),
        .mode(mode),
        .run_stop(run_stop),
        .clear(clear),
        .time_count(sec),
        .o_tick(w_tick_min)
    );

    time_counter #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) U_MSEC_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .mode(mode),
        .run_stop(run_stop),
        .clear(clear),
        .time_count(msec),
        .o_tick(w_tick_sec)
    );

    tick_gen_100hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .o_tick(w_tick_100hz)
    );

endmodule


module tick_gen_100hz (
    input clk,
    input reset,
    output reg o_tick
);

    parameter F_COUNT = 1_000_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;

            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                o_tick <= 1'b1;
            end else begin
                o_tick <= 1'b0;
            end
        end
    end

endmodule


module time_counter #(
    parameter BIT_WIDTH = 7,
    TIMES = 100
) (
    input clk,
    input reset,
    input i_tick,
    input mode,
    input run_stop,
    input clear,
    output [BIT_WIDTH-1:0] time_count,
    output reg o_tick
);

    reg [$clog2(TIMES)-1:0] counter_reg;

    assign time_count = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (i_tick & run_stop) begin
                if (!mode) begin
                    counter_reg <= counter_reg + 1;

                    if (counter_reg == (TIMES - 1)) begin
                        counter_reg <= 0;
                        o_tick <= 1'b1;
                    end
                end else begin
                    counter_reg <= counter_reg - 1;

                    if (counter_reg == 0) begin
                        counter_reg <= (TIMES - 1);
                        o_tick <= 1'b1;
                    end
                end
            end else begin
                o_tick <= 1'b0;
            end
        end
    end

endmodule


module control_unit (
    input  clk,
    input  reset,
    input  i_run_stop,
    input  i_clear,
    input  i_mode,
    output o_run_stop,
    output o_clear,
    output o_mode
);

    parameter STOP = 0, RUN = 1, CLEAR = 2, MODE = 3;

    reg [1:0] c_state, n_state;
    reg run_stop_reg, run_stop_next, clear_reg, clear_next, mode_reg, mode_next;

    assign o_run_stop = run_stop_reg;
    assign o_clear    = clear_reg;
    assign o_mode     = mode_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= STOP;
            run_stop_reg <= 0;
            clear_reg <= 0;
            mode_reg <= 0;
        end else begin
            c_state <= n_state;
            run_stop_reg <= run_stop_next;
            clear_reg <= clear_next;
            mode_reg <= mode_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        run_stop_next = run_stop_reg;
        clear_next = clear_reg;
        mode_next = mode_reg;

        case (c_state)
            STOP: begin
                run_stop_next = 0;
                clear_next = 0;

                if (i_run_stop) n_state = RUN;
                else if (i_clear) n_state = CLEAR;
                else if (i_mode) n_state = MODE;
            end

            RUN: begin
                run_stop_next = 1;

                if (i_run_stop) begin
                    run_stop_next = 0;
                    clear_next = 0;
                    n_state = STOP;
                end
            end

            CLEAR: begin
                clear_next = 1;
                n_state = STOP;
            end

            MODE: begin
                mode_next = ~mode_reg;
                n_state   = STOP;
            end
        endcase
    end

endmodule


module fnd_controller (
    input clk,
    input reset,
    input [6:0] msec,
    input [5:0] sec,
    input [5:0] min,
    input [4:0] hour,
    input display_mode,
    input sw_2,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire [3:0] w_min_1, w_min_10, w_hour_1, w_hour_10;
    wire [3:0] w_msec_1, w_msec_10, w_sec_1, w_sec_10;
    wire [3:0] w_msec_sec, w_min_hour, bcd;
    wire [2:0] w_digit_sel;
    wire w_1khz, w_dot_raw, w_dot_onoff;

    clk_div U_CLK_DIV (
        .clk   (clk),
        .reset (reset),
        .o_1khz(w_1khz)
    );

    counter_8 U_COUNTER_8 (
        .clk      (w_1khz),
        .reset    (reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2X4 (
        .digit_sel(w_digit_sel[1:0]),
        .fnd_com  (fnd_com)
    );

    comparator_dot U_COMP_DOT (
        .msec     (msec),
        .dot_onoff(w_dot_raw)
    );

    assign w_dot_onoff = sw_2 ? 1'b0 : ~w_dot_raw;

    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_DS_MSEC (
        .ds_in   (msec),
        .digit_1 (w_msec_1),
        .digit_10(w_msec_10)
    );

    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_DS_SEC (
        .ds_in   (sec),
        .digit_1 (w_sec_1),
        .digit_10(w_sec_10)
    );

    mux_8x1 U_MUX_MS (
        .sel    (w_digit_sel),
        .in0    (w_msec_1),
        .in1    (w_msec_10),
        .in2    (w_sec_1),
        .in3    (w_sec_10),
        .in4    (4'hf),
        .in5    (4'hf),
        .in6    ({3'b111, w_dot_onoff}),
        .in7    (4'hf),
        .mux_out(w_msec_sec)
    );

    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_DS_MIN (
        .ds_in   (min),
        .digit_1 (w_min_1),
        .digit_10(w_min_10)
    );

    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_DS_HOUR (
        .ds_in   (hour),
        .digit_1 (w_hour_1),
        .digit_10(w_hour_10)
    );

    mux_8x1 U_MUX_MH (
        .sel    (w_digit_sel),
        .in0    (w_min_1),
        .in1    (w_min_10),
        .in2    (w_hour_1),
        .in3    (w_hour_10),
        .in4    (4'hf),
        .in5    (4'hf),
        .in6    ({3'b111, w_dot_onoff}),
        .in7    (4'hf),
        .mux_out(w_min_hour)
    );

    mux_2x1 U_MUX_2X1 (
        .sel    (display_mode),
        .in0    (w_msec_sec),
        .in1    (w_min_hour),
        .mux_out(bcd)
    );

    bcd U_BCD (
        .bcd_in (bcd),
        .bcd_out(fnd_data)
    );

endmodule


module watch_datapath (
    input        clk,
    input        reset,
    input  [1:0] change_sec,
    input  [1:0] change_min,
    input  [1:0] change_hour,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_tick_sec, w_tick_min, w_tick_hour;

    tick_gen_100hz U_TICK_GEN (
        .clk   (clk),
        .reset (reset),
        .o_tick(w_tick_100hz)
    );

    watch_time_counter #(
        .BIT_WIDTH(5),
        .TIMES(24),
        .TIME(12)
    ) U_HOUR_CNTL (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_hour),
        .set_time  (change_hour),
        .time_count(hour),
        .o_tick    ()
    );

    watch_time_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .TIME(0)
    ) U_MIN_CNTL (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_min),
        .set_time  (change_min),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    watch_time_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .TIME(0)
    ) U_SEC_CNTL (
        .clk       (clk),
        .reset     (reset),
        .i_tick    (w_tick_sec),
        .set_time  (change_sec),
        .time_count(sec),
        .o_tick    (w_tick_min)
    );

    watch_time_counter #(
        .BIT_WIDTH(7),
        .TIMES    (100),
        .TIME     (0)
    ) U_MSEC_CNTL (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .set_time(2'b00),
        .time_count(msec),
        .o_tick(w_tick_sec)
    );

endmodule


module watch_fnd_controller (
    input clk,
    input reset,
    input blink_sec,
    input blink_min,
    input blink_hour,
    input [6:0] msec,
    input [5:0] sec,
    input [5:0] min,
    input [4:0] hour,
    input display_mode,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire [3:0] w_msec_1, w_msec_10, w_sec_1, w_sec_10;
    wire [3:0] w_min_1, w_min_10, w_hour_1, w_hour_10;
    wire [3:0] w_msec_sec, w_min_hour, bcd;
    wire [2:0] w_digit_sel;
    wire w_1khz, w_dot_onoff;
    wire [3:0] w_sec_1_b, w_sec_10_b;
    wire [3:0] w_min_1_b, w_min_10_b;
    wire [3:0] w_hour_1_b, w_hour_10_b;

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    blinker U_B_S1 (
        .clk  (w_1khz),
        .reset(reset),
        .onoff(blink_sec),
        .in0  (w_sec_1),
        .out  (w_sec_1_b)
    );

    blinker U_B_S10 (
        .clk  (w_1khz),
        .reset(reset),
        .onoff(blink_sec),
        .in0  (w_sec_10),
        .out  (w_sec_10_b)
    );

    blinker U_B_M1 (
        .clk  (w_1khz),
        .reset(reset),
        .onoff(blink_min),
        .in0  (w_min_1),
        .out  (w_min_1_b)
    );

    blinker U_B_M10 (
        .clk  (w_1khz),
        .reset(reset),
        .onoff(blink_min),
        .in0  (w_min_10),
        .out  (w_min_10_b)
    );

    blinker U_B_H1 (
        .clk  (w_1khz),
        .reset(reset),
        .onoff(blink_hour),
        .in0  (w_hour_1),
        .out  (w_hour_1_b)
    );

    blinker U_B_H10 (
        .clk  (w_1khz),
        .reset(reset),
        .onoff(blink_hour),
        .in0  (w_hour_10),
        .out  (w_hour_10_b)
    );

    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER (
        .digit_sel(w_digit_sel[1:0]),
        .fnd_com  (fnd_com)
    );

    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_DS1 (
        .ds_in(msec),
        .digit_1(w_msec_1),
        .digit_10(w_msec_10)
    );

    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_DS2 (
        .ds_in(sec),
        .digit_1(w_sec_1),
        .digit_10(w_sec_10)
    );

    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_DS3 (
        .ds_in(min),
        .digit_1(w_min_1),
        .digit_10(w_min_10)
    );

    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_DS4 (
        .ds_in(hour),
        .digit_1(w_hour_1),
        .digit_10(w_hour_10)
    );

    mux_8x1 U_MUX_HM (
        .sel(w_digit_sel),
        .in0(w_min_1_b),
        .in1(w_min_10_b),
        .in2(w_hour_1_b),
        .in3(w_hour_10_b),
        .in4(4'hf),
        .in5(4'hf),
        .in6({3'b111, w_dot_onoff}),
        .in7(4'hf),
        .mux_out(w_min_hour)
    );

    mux_8x1 U_MUX_SM (
        .sel(w_digit_sel),
        .in0(w_msec_1),
        .in1(w_msec_10),
        .in2(w_sec_1_b),
        .in3(w_sec_10_b),
        .in4(4'hf),
        .in5(4'hf),
        .in6({3'b111, w_dot_onoff}),
        .in7(4'hf),
        .mux_out(w_msec_sec)
    );

    comparator_dot U_COMP (
        .msec(msec),
        .dot_onoff(w_dot_onoff)
    );

    mux_2x1 U_MUX (
        .sel(display_mode),
        .in0(w_msec_sec),
        .in1(w_min_hour),
        .mux_out(bcd)
    );

    bcd U_BCD (
        .bcd_in (bcd),
        .bcd_out(fnd_data)
    );

endmodule


module comparator_dot #(
    parameter MSEC_WIDTH = 7
) (
    input [MSEC_WIDTH-1:0] msec,
    output dot_onoff
);

    assign dot_onoff = (msec < 50);

endmodule


module blinker (
    input clk,
    input reset,
    input onoff,
    input [3:0] in0,
    output [3:0] out
);

    reg [7:0] count_reg;
    reg blinking;

    assign out = (onoff && blinking) ? 4'hf : in0;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            count_reg <= 0;
            blinking  <= 0;
        end else begin
            if (onoff) begin
                count_reg <= count_reg + 1;

                if (count_reg == 255) begin
                    blinking  <= ~blinking;
                    count_reg <= 0;
                end
            end else begin
                count_reg <= 0;
                blinking  <= 0;
            end
        end
    end

endmodule


module clk_div (
    input  clk,
    input  reset,
    output o_1khz
);

    parameter DIVIDER = 50000;
    reg [$clog2(DIVIDER):0] counter_reg;
    reg clk_reg;

    assign o_1khz = clk_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_reg <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;

            if (counter_reg == (DIVIDER - 1)) begin
                counter_reg <= 0;
                clk_reg <= ~clk_reg;
            end
        end
    end

endmodule


module counter_8 (
    input clk,
    input reset,
    output [2:0] digit_sel
);

    reg [2:0] counter_reg;

    assign digit_sel = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) counter_reg <= 0;
        else counter_reg <= counter_reg + 1;
    end

endmodule


module decoder_2x4 (
    input [1:0] digit_sel,
    output reg [3:0] fnd_com
);

    always @(digit_sel) begin
        case (digit_sel)
            2'b00:   fnd_com = 4'b1110;
            2'b01:   fnd_com = 4'b1101;
            2'b10:   fnd_com = 4'b1011;
            2'b11:   fnd_com = 4'b0111;
            default: fnd_com = 4'b1110;
        endcase
    end

endmodule


module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] ds_in,
    output [3:0] digit_1,
    output [3:0] digit_10
);

    assign digit_1  = ds_in % 10;
    assign digit_10 = (ds_in / 10) % 10;

endmodule


module mux_8x1 (
    input [2:0] sel,
    input [3:0] in0,
    input [3:0] in1,
    input [3:0] in2,
    input [3:0] in3,
    input [3:0] in4,
    input [3:0] in5,
    input [3:0] in6,
    input [3:0] in7,
    output reg [3:0] mux_out
);

    always @(*) begin
        case (sel)
            3'b000: mux_out = in0;
            3'b001: mux_out = in1;
            3'b010: mux_out = in2;
            3'b011: mux_out = in3;
            3'b100: mux_out = in4;
            3'b101: mux_out = in5;
            3'b110: mux_out = in6;
            3'b111: mux_out = in7;
        endcase
    end

endmodule


module bcd (
    input [3:0] bcd_in,
    output reg [7:0] bcd_out
);

    always @(bcd_in) begin
        case (bcd_in)
            4'b0000: bcd_out = 8'hc0;
            4'b0001: bcd_out = 8'hf9;
            4'b0010: bcd_out = 8'ha4;
            4'b0011: bcd_out = 8'hb0;
            4'b0100: bcd_out = 8'h99;
            4'b0101: bcd_out = 8'h92;
            4'b0110: bcd_out = 8'h82;
            4'b0111: bcd_out = 8'hf8;
            4'b1000: bcd_out = 8'h80;
            4'b1001: bcd_out = 8'h90;
            4'b1010: bcd_out = 8'h88;
            4'b1011: bcd_out = 8'h83;
            4'b1100: bcd_out = 8'hc6;
            4'b1101: bcd_out = 8'ha1;
            4'b1110: bcd_out = 8'h7f;
            4'b1111: bcd_out = 8'hff;
        endcase
    end

endmodule


module mux_2x1 (
    input sel,
    input [3:0] in0,
    input [3:0] in1,
    output [3:0] mux_out
);

    assign mux_out = (sel) ? in0 : in1;

endmodule


module watch_control_unit (
    input clk,
    input reset,
    input btn_L,
    input btn_R,
    input btn_U,
    input btn_D,
    input sw,
    output [1:0] change_sec,
    output [1:0] change_min,
    output [1:0] change_hour,
    output blink_sec,
    output blink_min,
    output blink_hour
);

    parameter WATCH = 0, SET_SEC = 1, SET_MIN = 2, SET_HOUR = 3;
    reg [1:0] c_state, n_state;

    always @(posedge clk, posedge reset) begin
        if (reset) c_state <= WATCH;
        else c_state <= n_state;
    end

    assign change_sec  = (c_state == SET_SEC) ? {btn_U, btn_D} : 2'b00;
    assign change_min  = (c_state == SET_MIN) ? {btn_U, btn_D} : 2'b00;
    assign change_hour = (c_state == SET_HOUR) ? {btn_U, btn_D} : 2'b00;

    assign blink_sec   = (c_state == SET_SEC);
    assign blink_min   = (c_state == SET_MIN);
    assign blink_hour  = (c_state == SET_HOUR);

    always @(*) begin
        n_state = c_state;

        case (c_state)
            WATCH:
            if (sw == 1) n_state = SET_SEC;
            else n_state = WATCH;

            SET_SEC:
            if (sw == 1) begin
                if (btn_L) n_state = SET_MIN;
                else if (btn_R) n_state = SET_HOUR;
            end else n_state = WATCH;

            SET_MIN:
            if (sw == 1) begin
                if (btn_L) n_state = SET_HOUR;
                else if (btn_R) n_state = SET_SEC;
            end else n_state = WATCH;

            SET_HOUR:
            if (sw == 1) begin
                if (btn_L) n_state = SET_SEC;
                else if (btn_R) n_state = SET_MIN;
            end else n_state = WATCH;
        endcase
    end

endmodule


module watch_time_counter #(
    parameter BIT_WIDTH = 7,
    TIMES = 100,
    TIME = 0
) (
    input clk,
    input reset,
    input i_tick,
    input [1:0] set_time,
    output [BIT_WIDTH-1:0] time_count,
    output reg o_tick
);

    reg [$clog2(TIMES)-1:0] count_reg;

    assign time_count = count_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            count_reg <= TIME;
            o_tick <= 1'b0;
        end else begin
            if (set_time[1]) begin
                if (count_reg == TIMES - 1) count_reg <= 0;
                else count_reg <= count_reg + 1;
            end else if (set_time[0]) begin
                if (count_reg == 0) count_reg <= TIMES - 1;
                else count_reg <= count_reg - 1;
            end else if (i_tick) begin
                count_reg <= count_reg + 1;

                if (count_reg == TIMES - 1) begin
                    count_reg <= 0;
                    o_tick <= 1'b1;
                end
            end else begin
                o_tick <= 1'b0;
            end
        end
    end

endmodule


module btn_debouncer (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    reg [5:0] counter_reg;
    reg [7:0] q_reg;
    reg edge_reg, o_1mhz;
    wire debounce;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_1mhz <= 0;
        end else begin
            counter_reg <= counter_reg + 1;

            if (counter_reg == 49) begin
                counter_reg <= 0;
                o_1mhz <= ~o_1mhz;
            end
        end
    end

    always @(posedge o_1mhz, posedge reset) begin
        if (reset) q_reg <= 8'h00;
        else q_reg <= {i_btn, q_reg[7:1]};
    end

    assign debounce = &q_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) edge_reg <= 1'b0;
        else edge_reg <= debounce;
    end

    assign o_btn = debounce & (~edge_reg);

endmodule
