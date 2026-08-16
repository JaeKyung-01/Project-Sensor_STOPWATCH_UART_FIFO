`timescale 1ns / 1ps

module top_dht11 (
    input clk,
    input reset,
    input btnR,
    input btnL,
    input btnU,
    input btnD,
    input sw_dht11,
    inout dht11_io,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire w_btn_start;
    wire w_btn_temp;
    wire w_btn_humi;
    wire w_btn_fahr;
    wire w_dht11_start;
    wire [15:0] w_humidity;
    wire [15:0] w_temperature;
    wire w_done;
    wire w_valid;
    wire [7:0] w_fahrenheit;
    wire [13:0] w_fnd_in;

    reg [15:0] humidity_latched;
    reg [15:0] temperature_latched;
    reg [1:0] display_mode;

    localparam MODE_TEMP = 2'd0;
    localparam MODE_HUMI = 2'd1;
    localparam MODE_FAHR = 2'd2;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            humidity_latched <= 16'd0;
            temperature_latched <= 16'd0;
        end else if (w_done && w_valid) begin
            humidity_latched <= w_humidity;
            temperature_latched <= w_temperature;
        end
    end

    btn_debounce U_BD_START (
        .clk  (clk),
        .reset(reset),
        .i_btn(btnR),
        .o_btn(w_btn_start)
    );

    btn_debounce U_BD_TEMP (
        .clk  (clk),
        .reset(reset),
        .i_btn(btnL),
        .o_btn(w_btn_temp)
    );

    btn_debounce U_BD_HUMI (
        .clk  (clk),
        .reset(reset),
        .i_btn(btnU),
        .o_btn(w_btn_humi)
    );

    btn_debounce U_BD_FAHR (
        .clk  (clk),
        .reset(reset),
        .i_btn(btnD),
        .o_btn(w_btn_fahr)
    );

    assign w_dht11_start = w_btn_start && sw_dht11;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            display_mode <= MODE_TEMP;
        end else begin
            if (w_btn_temp) display_mode <= MODE_TEMP;
            else if (w_btn_humi) display_mode <= MODE_HUMI;
            else if (w_btn_fahr) display_mode <= MODE_FAHR;
        end
    end

    dht11 U_DHT11 (
        .clk(clk),
        .reset(reset),
        .start(w_dht11_start),
        .humidity(w_humidity),
        .temperature(w_temperature),
        .done(w_done),
        .valid(w_valid),
        .dht11_io(dht11_io)
    );

    assign w_fahrenheit = (temperature_latched[15:8] * 8'd9) / 8'd5 + 8'd32;

    assign w_fnd_in =
    (display_mode == MODE_TEMP) ? temperature_latched[15:8] :
    (display_mode == MODE_HUMI) ? humidity_latched[15:8] :
    w_fahrenheit;

    fnd_controller U_FND_CNTL (
        .clk(clk),
        .reset(reset),
        .fnd_in(w_fnd_in),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

endmodule

module dht11 (
    input clk,
    input reset,
    input start,
    output [15:0] humidity,
    output [15:0] temperature,
    output done,
    output valid,
    inout dht11_io
);

    dht11_controller U_DHT11_CONTROLLER (
        .clk(clk),
        .reset(reset),
        .start(start),
        .humidity(humidity),
        .temperature(temperature),
        .done(done),
        .valid(valid),
        .dht11_io(dht11_io)
    );

endmodule

module dht11_controller (
    input clk,
    input reset,
    input start,
    output [15:0] humidity,
    output [15:0] temperature,
    output reg done,
    output reg valid,
    inout dht11_io
);

    localparam [2:0]
IDLE = 3'd0,
START = 3'd1,
WAIT = 3'd2,
SYNC = 3'd3,
DATA = 3'd4,
STOP = 3'd5;

    localparam [1:0]
SYNC_WAIT_LOW = 2'd0,
SYNC_MEAS_LOW = 2'd1,
SYNC_MEAS_HIGH = 2'd2;

    localparam [14:0] TIMEOUT_US = 15'd100;

    reg [2:0] c_state;
    reg [2:0] n_state;
    reg [14:0] tick_count_reg;
    reg [14:0] tick_count_next;
    reg [5:0] bit_count_reg;
    reg [5:0] bit_count_next;
    reg [39:0] data_reg;
    reg [39:0] data_next;
    reg io_control;
    reg dht11_io_reg;
    reg dht11_io_next;
    reg [1:0] sync_phase_reg;
    reg [1:0] sync_phase_next;
    reg wait_released_reg;
    reg wait_released_next;
    reg data_phase_reg;
    reg data_phase_next;
    reg dht_sync1;
    reg dht_sync2;

    wire dht11_in;
    wire tick_us;
    wire [7:0] checksum;
    wire [7:0] calc_checksum;

    assign dht11_io = io_control ? dht11_io_reg : 1'bz;
    assign dht11_in = dht_sync2;
    assign humidity = data_reg[39:24];
    assign temperature = data_reg[23:8];
    assign checksum = data_reg[7:0];
    assign calc_checksum = data_reg[39:32] + data_reg[31:24] + data_reg[23:16] + data_reg[15:8];

    dht_11_tick_us U_TICK_US (
        .clk(clk),
        .reset(reset),
        .run_stop(1'b1),
        .clear(1'b0),
        .o_tick_us(tick_us)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dht_sync1 <= 1'b1;
            dht_sync2 <= 1'b1;
        end else begin
            dht_sync1 <= dht11_io;
            dht_sync2 <= dht_sync1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            tick_count_reg <= 15'd0;
            bit_count_reg <= 6'd0;
            data_reg <= 40'd0;
            dht11_io_reg <= 1'b1;
            sync_phase_reg <= SYNC_WAIT_LOW;
            data_phase_reg <= 1'b0;
            wait_released_reg <= 1'b0;
        end else begin
            c_state <= n_state;
            tick_count_reg <= tick_count_next;
            bit_count_reg <= bit_count_next;
            data_reg <= data_next;
            dht11_io_reg <= dht11_io_next;
            sync_phase_reg <= sync_phase_next;
            data_phase_reg <= data_phase_next;
            wait_released_reg <= wait_released_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        tick_count_next = tick_count_reg;
        bit_count_next = bit_count_reg;
        data_next = data_reg;
        dht11_io_next = dht11_io_reg;
        sync_phase_next = sync_phase_reg;
        data_phase_next = data_phase_reg;
        wait_released_next = wait_released_reg;
        io_control = 1'b0;
        done = 1'b0;
        valid = 1'b0;

        case (c_state)
            IDLE: begin
                tick_count_next = 15'd0;
                bit_count_next = 6'd0;
                sync_phase_next = SYNC_WAIT_LOW;
                data_phase_next = 1'b0;
                wait_released_next = 1'b0;
                if (start) begin
                    n_state = START;
                    tick_count_next = 15'd0;
                end
            end

            START: begin
                io_control = 1'b1;
                dht11_io_next = 1'b0;
                if (tick_us) begin
                    if (tick_count_reg == 15'd18999) begin
                        tick_count_next = 15'd0;
                        wait_released_next = 1'b0;
                        n_state = WAIT;
                    end else begin
                        tick_count_next = tick_count_reg + 1'b1;
                    end
                end
            end

            WAIT: begin
                if (!wait_released_reg) begin
                    if (dht11_in) begin
                        wait_released_next = 1'b1;
                        tick_count_next = 15'd0;
                    end else if (tick_us) begin
                        if (tick_count_reg >= TIMEOUT_US) begin
                            tick_count_next = 15'd0;
                            n_state = IDLE;
                        end else begin
                            tick_count_next = tick_count_reg + 1'b1;
                        end
                    end
                end else begin
                    if (!dht11_in) begin
                        tick_count_next = 15'd0;
                        sync_phase_next = SYNC_WAIT_LOW;
                        n_state = SYNC;
                    end else if (tick_us) begin
                        if (tick_count_reg >= TIMEOUT_US) begin
                            tick_count_next = 15'd0;
                            n_state = IDLE;
                        end else begin
                            tick_count_next = tick_count_reg + 1'b1;
                        end
                    end
                end
            end

            SYNC: begin
                case (sync_phase_reg)
                    SYNC_WAIT_LOW: begin
                        tick_count_next = 15'd0;
                        sync_phase_next = SYNC_MEAS_LOW;
                    end

                    SYNC_MEAS_LOW: begin
                        if (dht11_in) begin
                            tick_count_next = 15'd0;
                            sync_phase_next = SYNC_MEAS_HIGH;
                        end else if (tick_us) begin
                            if (tick_count_reg >= TIMEOUT_US) begin
                                tick_count_next = 15'd0;
                                n_state = IDLE;
                            end else begin
                                tick_count_next = tick_count_reg + 1'b1;
                            end
                        end
                    end

                    SYNC_MEAS_HIGH: begin
                        if (!dht11_in) begin
                            tick_count_next = 15'd0;
                            bit_count_next = 6'd0;
                            data_phase_next = 1'b0;
                            n_state = DATA;
                        end else if (tick_us) begin
                            if (tick_count_reg >= TIMEOUT_US) begin
                                tick_count_next = 15'd0;
                                n_state = IDLE;
                            end else begin
                                tick_count_next = tick_count_reg + 1'b1;
                            end
                        end
                    end

                    default: begin
                        sync_phase_next = SYNC_WAIT_LOW;
                    end
                endcase
            end

            DATA: begin
                if (!data_phase_reg) begin
                    if (dht11_in) begin
                        tick_count_next = 15'd0;
                        data_phase_next = 1'b1;
                    end else if (tick_us) begin
                        if (tick_count_reg >= TIMEOUT_US) begin
                            tick_count_next = 15'd0;
                            n_state = IDLE;
                        end else begin
                            tick_count_next = tick_count_reg + 1'b1;
                        end
                    end
                end else begin
                    if (dht11_in) begin
                        if (tick_us) begin
                            if (tick_count_reg >= TIMEOUT_US) begin
                                tick_count_next = 15'd0;
                                n_state = IDLE;
                            end else begin
                                tick_count_next = tick_count_reg + 1'b1;
                            end
                        end
                    end else begin
                        if (tick_count_reg >= 15'd50)
                            data_next = {data_reg[38:0], 1'b1};
                        else data_next = {data_reg[38:0], 1'b0};

                        tick_count_next = 15'd0;
                        data_phase_next = 1'b0;

                        if (bit_count_reg == 6'd39) n_state = STOP;
                        else bit_count_next = bit_count_reg + 1'b1;
                    end
                end
            end

            STOP: begin
                done = 1'b1;

                if (checksum == calc_checksum) valid = 1'b1;
                else valid = 1'b0;

                n_state = IDLE;
                tick_count_next = 15'd0;
            end

            default: begin
                n_state = IDLE;
                tick_count_next = 15'd0;
                bit_count_next = 6'd0;
                data_next = 40'd0;
                sync_phase_next = SYNC_WAIT_LOW;
                data_phase_next = 1'b0;
                wait_released_next = 1'b0;
            end
        endcase
    end

endmodule

module dht_11_tick_us (
    input  clk,
    input  reset,
    input  run_stop,
    input  clear,
    output o_tick_us
);

    parameter F_COUNT = 100;

    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg tick_us_reg;

    assign o_tick_us = tick_us_reg;

    always @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            counter_reg <= 0;
            tick_us_reg <= 1'b0;
        end else if (run_stop) begin
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_us_reg <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1'b1;
                tick_us_reg <= 1'b0;
            end
        end else begin
            tick_us_reg <= 1'b0;
        end
    end

endmodule
