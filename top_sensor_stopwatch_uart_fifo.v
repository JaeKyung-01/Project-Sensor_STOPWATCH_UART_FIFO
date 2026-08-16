`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2026/08/16 17:16:53
// Design Name:
// Module Name: top_sensor_stopwatch_uart_fifo
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//   실제 값(distance, msec/sec/min/hour, temp/humid)을 AsciiSender까지
//   내보내야 해서, top_sr04/top_stopwatch/top_watch/top_dht11 같은
//   래퍼 대신 그 안의 하위 모듈(sr04_controller, stopwatch_datapath,
//   watch_datapath, dht11)을 직접 갖다 씀. -> 다이어그램에서
//   Control Unit이 "Stopwatch Datapath / Watch-Datapath / SR04
//   Controller / DHT11 Controller"에 직접 붙어있던 것과 같은 구조.
//
//   *** 아래 두 가지는 "있는 것만" 으로는 실제 의미를 알 수 없어서
//       임시로 자리만 잡아둔 부분입니다 (TODO 표시) ***
//     1) main_control_unit 이 아직 없어서, UART 커맨드(ascii_decoder
//        출력) -> 각 센서 start/run 신호로 연결하는 부분이 없음.
//        지금은 버튼이 각 top_* 모듈 설계대로 직접 그 센서를 제어함.
//     2) AsciiSender의 src_sel/send_trig 를 뭘로 트리거할지 아직
//        안 정해져서 0.5초 주기 라운드로빈으로 임시 연결.
//
//   *** 중요: 이 파일이 컴파일되려면 아래 모듈 이름 충돌을 먼저
//       해결해야 합니다 (자세한 설명은 채팅 답변 참고) ***
//     - stopwatch_watch.v 안의 control_unit/fnd_controller/clk_div/
//       decoder_2x4/digit_splitter/bcd  ->  fifo.v의 control_unit,
//       fnd_controller.v의 fnd_controller/clk_div/decoder_2x4/
//       digit_splitter/bcd 와 이름이 완전히 겹침.
//       stopwatch_ 접두사 붙이는 걸 추천 (아래 코드는 이미 그렇게
//       가정하고 짜여 있음: stopwatch_control_unit,
//       stopwatch_fnd_controller, stopwatch_clk_div,
//       stopwatch_decoder_2x4, stopwatch_digit_splitter, stopwatch_bcd)
//     - uart_controller.v 는 uart.v 의 uart_controller 와 이름이
//       겹치면서 포트도 완전히 다름 -> 이 top에서는 uart_controller.v
//       를 아예 프로젝트에서 빼고 uart.v 것만 씁니다.
//////////////////////////////////////////////////////////////////////////////////


module top_sensor_stopwatch_uart_fifo (
    input        clk,
    input        reset,

    // ---- UART ----
    input        rx,
    output       tx,

    // ---- 모드 선택 스위치 (TODO: 실제 배치에 맞게 조정) ----
    input  [2:0] sw,
    input        sw_watch,
    input        sw_stop,
    input        sw_sr04,   // TODO
    input        sw_dht11,  // TODO

    // ---- 버튼 (스톱워치/워치는 기존처럼 공용, SR04/DHT11은 자체 버튼) ----
    input        btn_L,
    input        btn_R,
    input        btn_U,
    input        btn_D,
    input        sr04_btnR,
    input        dht11_btnR,
    input        dht11_btnL,
    input        dht11_btnU,
    input        dht11_btnD,

    // ---- SR04 ----
    input        echo,
    output       trigger,

    // ---- DHT11 ----
    inout        dht11_io,

    // ---- 출력 ----
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output [3:0] led
);

    // ========================================================
    // UART 코어 (uart.v)
    // ========================================================
    wire [7:0] w_rx_data;
    wire       w_rx_done;
    wire [7:0] w_tx_data_to_uart;
    wire       w_uart_tx_busy, w_uart_tx_start;

    uart_controller U_UART_CTRL (
        .clk     (clk),
        .reset   (reset),
        .tx_start(w_uart_tx_start),
        .tx_data (w_tx_data_to_uart),
        .rx      (rx),
        .rx_data (w_rx_data),
        .rx_done (w_rx_done),
        .tx_busy (w_uart_tx_busy),
        .tx_done (),
        .tx      (tx)
    );

    // ========================================================
    // AsciiDecoder (RX FIFO 없이 rx_done 순간 바로 반응)
    // ========================================================
    wire [11:0] w_cmd;

    ascii_decoder U_ASCII_DECODER (
        .data   (w_rx_data),
        .rx_done(w_rx_done),
        .o_ascii(w_cmd)
    );

    // ========================================================
    // AsciiSender + TX FIFO (fifo.v)
    // TODO: 실제 커맨드 -> src_sel/send_trig 매핑 아직 없음.
    //       지금은 0.5초 주기 라운드로빈으로 4개 소스를 돌아가며 전송.
    // ========================================================
    wire [8:0] w_sr04_distance;
    wire [6:0] w_time_msec;
    wire [5:0] w_time_sec, w_time_min;
    wire [4:0] w_time_hour;
    wire [7:0] w_dht11_temp, w_dht11_humid;

    wire [7:0] w_sender_tx_data;
    wire       w_sender_push, w_sender_busy, w_sender_done;
    wire       w_tx_fifo_full, w_tx_fifo_empty;

    reg  [1:0] r_send_src_sel;
    reg        r_send_trig;

    ascii_sender U_ASCII_SENDER (
        .clk          (clk),
        .reset        (reset),
        .src_sel      (r_send_src_sel),
        .send_trig    (r_send_trig),
        .sr04_distance(w_sr04_distance),
        .time_msec    (w_time_msec),
        .time_sec     (w_time_sec),
        .time_min     (w_time_min),
        .time_hour    (w_time_hour),
        .dht11_temp   (w_dht11_temp),
        .dht11_humid  (w_dht11_humid),
        .tx_data      (w_sender_tx_data),
        .push         (w_sender_push),
        .full         (w_tx_fifo_full),
        .busy         (w_sender_busy),
        .send_done    (w_sender_done)
    );

    fifo #(
        .WIDTH(4)  // TODO: fifo.v 내부에서 WIDTH가 실제로 전달 안 되고
                   //       항상 depth=4로 고정되는 버그 있음 (채팅 답변 참고)
    ) U_TX_FIFO (
        .clk  (clk),
        .reset(reset),
        .push (w_sender_push),
        .pop  (w_uart_tx_start),
        .wdata(w_sender_tx_data),
        .rdata(w_tx_data_to_uart),
        .full (w_tx_fifo_full),
        .empty(w_tx_fifo_empty)
    );

    assign w_uart_tx_start = ~w_tx_fifo_empty & ~w_uart_tx_busy;

    // 0.5초 주기로 SR04 -> Stopwatch -> Watch -> DHT11 순서로 전송 (임시)
    localparam PERIOD = 50_000_000;
    reg [25:0] r_tick_cnt;
    reg        r_tick_pulse;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_tick_cnt   <= 0;
            r_tick_pulse <= 1'b0;
        end else if (r_tick_cnt == PERIOD - 1) begin
            r_tick_cnt   <= 0;
            r_tick_pulse <= 1'b1;
        end else begin
            r_tick_cnt   <= r_tick_cnt + 1;
            r_tick_pulse <= 1'b0;
        end
    end

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_send_src_sel <= 2'b00;
            r_send_trig    <= 1'b0;
        end else begin
            r_send_trig <= 1'b0;
            if (r_tick_pulse && !w_sender_busy) begin
                r_send_trig    <= 1'b1;
                r_send_src_sel <= r_send_src_sel + 2'b01;
            end
        end
    end

    // ========================================================
    // SR04  (sr04.v 의 하위 모듈 직접 사용 -> distance 값 확보)
    // ========================================================
    wire w_sr04_btn_start;
    wire [3:0] w_sr04_fnd_com;
    wire [7:0] w_sr04_fnd_data;

    btn_debounce U_BD_SR04_START (
        .clk  (clk),
        .reset(reset),
        .i_btn(sr04_btnR),
        .o_btn(w_sr04_btn_start)
    );

    sr04_controller U_SR04_CNTL (
        .clk     (clk),
        .reset   (reset),
        .start   (w_sr04_btn_start),
        .echo    (echo),
        .trigger (trigger),
        .done    (),
        .distance(w_sr04_distance)
    );

    fnd_controller U_SR04_FND_CNTL (
        .clk     (clk),
        .reset   (reset),
        .fnd_in  ({5'd0, w_sr04_distance}),
        .fnd_com (w_sr04_fnd_com),
        .fnd_data(w_sr04_fnd_data)
    );

    // ========================================================
    // DHT11  (dht11.v 의 dht11(core) 직접 사용 -> temp/humid 값 확보)
    //   top_dht11 안에 있던 latch/버튼 로직을 그대로 여기로 옮김
    // ========================================================
    wire w_dht11_btn_start, w_dht11_btn_temp, w_dht11_btn_humi, w_dht11_btn_fahr;
    wire w_dht11_start;
    wire [15:0] w_dht11_humidity, w_dht11_temperature;
    wire w_dht11_done, w_dht11_valid;
    wire [3:0] w_dht11_fnd_com;
    wire [7:0] w_dht11_fnd_data;
    wire [7:0] w_dht11_fahrenheit;
    wire [13:0] w_dht11_fnd_in;

    reg [15:0] r_humidity_latched, r_temperature_latched;
    reg [1:0]  r_dht11_display_mode;
    localparam DHT11_MODE_TEMP = 2'd0, DHT11_MODE_HUMI = 2'd1, DHT11_MODE_FAHR = 2'd2;

    btn_debounce U_BD_DHT11_START (
        .clk  (clk),
        .reset(reset),
        .i_btn(dht11_btnR),
        .o_btn(w_dht11_btn_start)
    );
    btn_debounce U_BD_DHT11_TEMP (
        .clk  (clk),
        .reset(reset),
        .i_btn(dht11_btnL),
        .o_btn(w_dht11_btn_temp)
    );
    btn_debounce U_BD_DHT11_HUMI (
        .clk  (clk),
        .reset(reset),
        .i_btn(dht11_btnU),
        .o_btn(w_dht11_btn_humi)
    );
    btn_debounce U_BD_DHT11_FAHR (
        .clk  (clk),
        .reset(reset),
        .i_btn(dht11_btnD),
        .o_btn(w_dht11_btn_fahr)
    );

    // TODO(원본 dht11.v와 동일한 버그 그대로 있음): temp/humi/fahr
    // 모드버튼이 sw_dht11로 안 걸려있어서, 다른 모드에 있어도
    // 이 버튼 누르면 DHT11 내부 display_mode가 바뀜 (화면엔 안 보이지만
    // 내부 상태는 바뀜). 필요하면 & sw_dht11 붙이는 걸 추천.
    assign w_dht11_start = w_dht11_btn_start && sw_dht11;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_humidity_latched    <= 16'd0;
            r_temperature_latched <= 16'd0;
        end else if (w_dht11_done && w_dht11_valid) begin
            r_humidity_latched    <= w_dht11_humidity;
            r_temperature_latched <= w_dht11_temperature;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_dht11_display_mode <= DHT11_MODE_TEMP;
        end else begin
            if (w_dht11_btn_temp) r_dht11_display_mode <= DHT11_MODE_TEMP;
            else if (w_dht11_btn_humi) r_dht11_display_mode <= DHT11_MODE_HUMI;
            else if (w_dht11_btn_fahr) r_dht11_display_mode <= DHT11_MODE_FAHR;
        end
    end

    dht11 U_DHT11 (
        .clk        (clk),
        .reset      (reset),
        .start      (w_dht11_start),
        .humidity   (w_dht11_humidity),
        .temperature(w_dht11_temperature),
        .done       (w_dht11_done),
        .valid      (w_dht11_valid),
        .dht11_io   (dht11_io)
    );

    assign w_dht11_fahrenheit = (r_temperature_latched[15:8] * 8'd9) / 8'd5 + 8'd32;

    assign w_dht11_fnd_in =
        (r_dht11_display_mode == DHT11_MODE_TEMP) ? r_temperature_latched[15:8] :
        (r_dht11_display_mode == DHT11_MODE_HUMI) ? r_humidity_latched[15:8] :
        w_dht11_fahrenheit;

    fnd_controller U_DHT11_FND_CNTL (
        .clk     (clk),
        .reset   (reset),
        .fnd_in  (w_dht11_fnd_in),
        .fnd_com (w_dht11_fnd_com),
        .fnd_data(w_dht11_fnd_data)
    );

    // AsciiSender로는 항상 온도/습도 정수부(섭씨 기준)를 보냄
    assign w_dht11_temp   = r_temperature_latched[15:8];
    assign w_dht11_humid  = r_humidity_latched[15:8];

    // ========================================================
    // Stopwatch  (stopwatch_watch.v 하위 모듈 직접 사용 -> 값 확보)
    //   *** stopwatch_control_unit / stopwatch_fnd_controller 이름은
    //       stopwatch_watch.v 안에서 미리 접두사 붙여 rename 했다고
    //       가정하고 짠 코드입니다 (파일 상단 설명 참고) ***
    // ========================================================
    wire w_btn_L, w_btn_R, w_btn_U, w_btn_D;  // stopwatch/watch 공용 디바운스

    btn_debouncer U_BTN_L (.clk(clk), .reset(reset), .i_btn(btn_L), .o_btn(w_btn_L));
    btn_debouncer U_BTN_R (.clk(clk), .reset(reset), .i_btn(btn_R), .o_btn(w_btn_R));
    btn_debouncer U_BTN_U (.clk(clk), .reset(reset), .i_btn(btn_U), .o_btn(w_btn_U));
    btn_debouncer U_BTN_D (.clk(clk), .reset(reset), .i_btn(btn_D), .o_btn(w_btn_D));

    wire stop_btn_L = w_btn_L && sw_stop;
    wire stop_btn_R = w_btn_R && sw_stop;
    wire stop_btn_U = w_btn_U && sw_stop;
    wire stop_btn_D = w_btn_D && sw_stop;

    wire w_stop_run_stop, w_stop_clear, w_stop_mode;
    wire real_clear = w_stop_clear && !sw[2];
    wire [6:0] w_stop_msec;
    wire [5:0] w_stop_sec, w_stop_min;
    wire [4:0] w_stop_hour;
    wire [6:0] w_stop_display_msec;
    wire [5:0] w_stop_display_sec, w_stop_display_min;
    wire [4:0] w_stop_display_hour;
    wire [3:0] w_stop_fnd_com;
    wire [7:0] w_stop_fnd_data;

    stopwatch_control_unit U_STOP_CTRL (
        .clk       (clk),
        .reset     (reset),
        .i_run_stop(stop_btn_L),
        .i_clear   (stop_btn_R),
        .i_mode    (stop_btn_U),
        .o_run_stop(w_stop_run_stop),
        .o_clear   (w_stop_clear),
        .o_mode    (w_stop_mode)
    );

    stopwatch_datapath U_STOP_DATAPATH (
        .clk     (clk),
        .reset   (reset),
        .run_stop(w_stop_run_stop),
        .clear   (real_clear),
        .mode    (w_stop_mode),
        .msec    (w_stop_msec),
        .sec     (w_stop_sec),
        .min     (w_stop_min),
        .hour    (w_stop_hour)
    );

    time_storage_unit U_STOP_TIME_STORAGE (
        .clk         (clk),
        .reset       (reset),
        .w_clear     (w_stop_clear),
        .w_btn_D     (stop_btn_D),
        .sw_2        (sw[2]),
        .w_msec      (w_stop_msec),
        .w_sec       (w_stop_sec),
        .w_min       (w_stop_min),
        .w_hour      (w_stop_hour),
        .display_msec(w_stop_display_msec),
        .display_sec (w_stop_display_sec),
        .display_min (w_stop_display_min),
        .display_hour(w_stop_display_hour)
    );

    stopwatch_fnd_controller U_STOP_FND_CNTL (
        .clk         (clk),
        .reset       (reset),
        .msec        (w_stop_display_msec),
        .sec         (w_stop_display_sec),
        .min         (w_stop_display_min),
        .hour        (w_stop_display_hour),
        .display_mode(sw[0]),
        .sw_2        (sw[2]),
        .fnd_com     (w_stop_fnd_com),
        .fnd_data    (w_stop_fnd_data)
    );

    // ========================================================
    // Watch  (stopwatch_watch.v 하위 모듈 직접 사용 -> 값 확보)
    // ========================================================
    wire watch_btn_L = w_btn_L && sw_watch;
    wire watch_btn_R = w_btn_R && sw_watch;
    wire watch_btn_U = w_btn_U && sw_watch;
    wire watch_btn_D = w_btn_D && sw_watch;

    wire w_blink_sec, w_blink_min, w_blink_hour;
    wire [1:0] w_change_sec, w_change_min, w_change_hour;
    wire [6:0] w_watch_msec;
    wire [5:0] w_watch_sec, w_watch_min;
    wire [4:0] w_watch_hour;
    wire [3:0] w_watch_fnd_com;
    wire [7:0] w_watch_fnd_data;

    watch_control_unit U_WATCH_CTRL (
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

    watch_datapath U_WATCH_DATAPATH (
        .clk        (clk),
        .reset      (reset),
        .change_sec (w_change_sec),
        .change_min (w_change_min),
        .change_hour(w_change_hour),
        .msec       (w_watch_msec),
        .sec        (w_watch_sec),
        .min        (w_watch_min),
        .hour       (w_watch_hour)
    );

    watch_fnd_controller U_WATCH_FND_CNTL (
        .clk         (clk),
        .reset       (reset),
        .blink_sec   (w_blink_sec),
        .blink_min   (w_blink_min),
        .blink_hour  (w_blink_hour),
        .msec        (w_watch_msec),
        .sec         (w_watch_sec),
        .min         (w_watch_min),
        .hour        (w_watch_hour),
        .display_mode(sw[1]),
        .fnd_com     (w_watch_fnd_com),
        .fnd_data    (w_watch_fnd_data)
    );

    // AsciiSender에 넣을 time_* 는 지금 어떤 소스를 보내는 중인지에
    // 맞춰서 stopwatch/watch 값 중 하나를 고름
    assign w_time_msec = (r_send_src_sel == 2'b10) ? w_watch_msec : w_stop_display_msec;
    assign w_time_sec  = (r_send_src_sel == 2'b10) ? w_watch_sec  : w_stop_display_sec;
    assign w_time_min  = (r_send_src_sel == 2'b10) ? w_watch_min  : w_stop_display_min;
    assign w_time_hour = (r_send_src_sel == 2'b10) ? w_watch_hour : w_stop_display_hour;

    // ========================================================
    // 최종 FND 표시 선택 (End Controller 자리 -> 모듈 못 받아서
    // 여기 인라인으로 4-way mux 로 대체)
    // ========================================================
    assign fnd_com  = sw_dht11 ? w_dht11_fnd_com :
                       sw_sr04  ? w_sr04_fnd_com  :
                       sw_stop  ? w_stop_fnd_com  :
                                  w_watch_fnd_com;

    assign fnd_data = sw_dht11 ? w_dht11_fnd_data :
                       sw_sr04  ? w_sr04_fnd_data  :
                       sw_stop  ? w_stop_fnd_data  :
                                  w_watch_fnd_data;

    assign led = 4'b1111;

endmodule