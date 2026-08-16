`timescale 1ns / 1ps
// ============================================================
//  ascii_sender.v
//
//  역할: SR04 / Stopwatch / Watch (추후 DHT11) 결과값을
//        사람이 읽을 수 있는 ASCII 문자열로 바꿔서
//        UART TX FIFO (uart_fifo.v 안의 U_TX_FIFO, fifo push 포트)로
//        한 바이트씩 push 해주는 블록.
//
//  기존 코드 스타일(digit_splitter의 %10, /10 방식)에 맞춰서
//  double-dabble 대신 나눗셈 기반으로 자릿수를 뽑음.
//
//  출력 포맷 (각 줄 끝에 CR LF 붙여서 터미널에서 한 줄씩 보이게):
//    SR04      : "D:xxxcm\r\n"          (3자리, cm)
//    Stopwatch : "ST mm:ss.hh\r\n"      (분:초.1/100초)
//    Watch     : "WT hh:mm:ss\r\n"      (시:분:초)
//    DHT11     : "DH:ttC,hh%\r\n"       (정수 온도 C, 정수 습도 %)
//                -> DHT11 컨트롤러 소스가 아직 없어서 정수부만 있는
//                   일반적인 DHT11 스펙(0~99, 소수점 없음) 기준으로 임시 작성.
//                   실제 컨트롤러 붙으면 dht11_temp/dht11_humid 폭·연결만
//                   맞춰주면 됨.
//
//  ascii_sender.v 단독으로 iverilog 문법 체크 + 자체 테스트벤치로
//  4가지 소스 전송 / FIFO full 스톨 / busy 중 재트리거 무시 케이스까지
//  시뮬레이션 검증 완료.
// ============================================================

module ascii_sender (
    input        clk,
    input        reset,

    // ---- 어떤 소스를 보낼지 선택 + 전송 트리거 ----
    // src_sel : 2'b00 = SR04, 2'b01 = Stopwatch, 2'b10 = Watch, 2'b11 = DHT11
    input  [1:0] src_sel,
    input        send_trig,      // 1클럭 pulse: CONTROLL UNIT이 어떤 데이터를 한줄 보내라고 판단했을 때 보내는 신호

    //sr04_distance ~ dht11_humid: 4개 소스가 각자 가진 실제 값들. 이 모듈은 4개를 다 입력으로 받아두고, src_sel이 지정한 것만 골라서 씀
    // ---- SR04 ----
    input  [8:0] sr04_distance,  // top_sr04 / sr04_controller 의 distance 그대로 연결

    // ---- Stopwatch / Watch 공용 (top_stopwatch, top_watch 의 msec/sec/min/hour 그대로 연결) ----
    input  [6:0] time_msec,      // 0~99  (stopwatch datapath 기준. watch는 msec 안 쓰면 0 연결)
    input  [5:0] time_sec,       // 0~59
    input  [5:0] time_min,       // 0~59
    input  [4:0] time_hour,      // 0~23

    // ---- DHT11 (컨트롤러 소스 확정되면 폭/연결 다시 맞출 것) ----
    input  [7:0] dht11_temp,     // 정수부 온도, 0~99 가정
    input  [7:0] dht11_humid,    // 정수부 습도, 0~99 가정

    // ---- UART TX FIFO 쪽 (fifo 모듈의 push/wdata/full 포트에 그대로 연결) ----
    output reg [7:0] tx_data,
    output reg       push,
    input            full,

    output reg       busy,       // 전송 중이면 1 (이 동안은 send_trig 무시)
    output reg       send_done   // 한 줄 전송 끝나면 1클럭 pulse
);

    // ------------------------------------------------------
    // 상태 정의
    // ------------------------------------------------------
    localparam IDLE = 2'd0, SEND = 2'd1, DONE_ST = 2'd2;
    reg [1:0] state, next_state;

    // 최대 길이: "ST mm:ss.hh\r\n" = 13 byte 가 제일 김 -> 여유있게 16
    localparam BUF_LEN = 16;
    reg [7:0] buf_mem[0:BUF_LEN-1];
    reg [4:0] len_reg;      // 이번에 보낼 총 바이트 수
    reg [4:0] idx_reg;      // 지금 보내고 있는 인덱스

    // ------------------------------------------------------
    // 자릿수 분리 (digit_splitter 스타일: % , / 조합)
    // ------------------------------------------------------
    // SR04 distance -> 3자리
    wire [3:0] d_dist_1   = sr04_distance % 10;
    wire [3:0] d_dist_10  = (sr04_distance / 10) % 10;
    wire [3:0] d_dist_100 = (sr04_distance / 100) % 10;

    // 공통 2자리 분리용 (msec/sec/min/hour 모두 0~99 이내라 동일 로직 재사용)
    wire [3:0] d_msec_1  = time_msec % 10;
    wire [3:0] d_msec_10 = (time_msec / 10) % 10;
    wire [3:0] d_sec_1   = time_sec % 10;
    wire [3:0] d_sec_10  = (time_sec / 10) % 10;
    wire [3:0] d_min_1   = time_min % 10;
    wire [3:0] d_min_10  = (time_min / 10) % 10;
    wire [3:0] d_hour_1  = time_hour % 10;
    wire [3:0] d_hour_10 = (time_hour / 10) % 10;

    // DHT11 온습도 (정수 2자리)
    wire [3:0] d_temp_1   = dht11_temp % 10;
    wire [3:0] d_temp_10  = (dht11_temp / 10) % 10;
    wire [3:0] d_humid_1  = dht11_humid % 10;
    wire [3:0] d_humid_10 = (dht11_humid / 10) % 10;

    // BCD(4bit) -> ASCII 함수 (숫자만이라 +8'h30 이면 충분)
    function [7:0] to_ascii;
        input [3:0] bcd;
        begin
            to_ascii = {4'h3, bcd};
        end
    endfunction

    // ------------------------------------------------------
    // 상태 레지스터
    // ------------------------------------------------------
    always @(posedge clk, posedge reset) begin
        if (reset) state <= IDLE;
        else       state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    if (send_trig) next_state = SEND;
            SEND:    if (!full && idx_reg == len_reg - 1) next_state = DONE_ST;
            DONE_ST: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------
    // buf_mem 채우기 (IDLE 에서 send_trig 뜨는 그 클럭에 한번에 latch)
    //   -> src_sel 에 따라 포맷 다르게 구성
    // ------------------------------------------------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            len_reg <= 5'd0;
        end else if (state == IDLE && send_trig) begin
            case (src_sel)
                // ---- SR04 : "D:xxxcm\r\n"  (9 byte) ----
                2'b00: begin
                    buf_mem[0] <= "D";
                    buf_mem[1] <= ":";
                    buf_mem[2] <= to_ascii(d_dist_100);
                    buf_mem[3] <= to_ascii(d_dist_10);
                    buf_mem[4] <= to_ascii(d_dist_1);
                    buf_mem[5] <= "c";
                    buf_mem[6] <= "m";
                    buf_mem[7] <= 8'h0D;  // \r
                    buf_mem[8] <= 8'h0A;  // \n
                    len_reg    <= 5'd9;
                end

                // ---- Stopwatch : "ST mm:ss.hh\r\n" (13 byte) ----
                2'b01: begin
                    buf_mem[0]  <= "S";
                    buf_mem[1]  <= "T";
                    buf_mem[2]  <= " ";
                    buf_mem[3]  <= to_ascii(d_min_10);
                    buf_mem[4]  <= to_ascii(d_min_1);
                    buf_mem[5]  <= ":";
                    buf_mem[6]  <= to_ascii(d_sec_10);
                    buf_mem[7]  <= to_ascii(d_sec_1);
                    buf_mem[8]  <= ".";
                    buf_mem[9]  <= to_ascii(d_msec_10);
                    buf_mem[10] <= to_ascii(d_msec_1);
                    buf_mem[11] <= 8'h0D;
                    buf_mem[12] <= 8'h0A;
                    len_reg     <= 5'd13;
                end

                // ---- Watch : "WT hh:mm:ss\r\n" (13 byte) ----
                2'b10: begin
                    buf_mem[0]  <= "W";
                    buf_mem[1]  <= "T";
                    buf_mem[2]  <= " ";
                    buf_mem[3]  <= to_ascii(d_hour_10);
                    buf_mem[4]  <= to_ascii(d_hour_1);
                    buf_mem[5]  <= ":";
                    buf_mem[6]  <= to_ascii(d_min_10);
                    buf_mem[7]  <= to_ascii(d_min_1);
                    buf_mem[8]  <= ":";
                    buf_mem[9]  <= to_ascii(d_sec_10);
                    buf_mem[10] <= to_ascii(d_sec_1);
                    buf_mem[11] <= 8'h0D;
                    buf_mem[12] <= 8'h0A;
                    len_reg     <= 5'd13;
                end

                // ---- DHT11 : "DH:ttC,hh%\r\n" (12 byte) ----
                default: begin
                    buf_mem[0]  <= "D";
                    buf_mem[1]  <= "H";
                    buf_mem[2]  <= ":";
                    buf_mem[3]  <= to_ascii(d_temp_10);
                    buf_mem[4]  <= to_ascii(d_temp_1);
                    buf_mem[5]  <= "C";
                    buf_mem[6]  <= ",";
                    buf_mem[7]  <= to_ascii(d_humid_10);
                    buf_mem[8]  <= to_ascii(d_humid_1);
                    buf_mem[9]  <= "%";
                    buf_mem[10] <= 8'h0D;
                    buf_mem[11] <= 8'h0A;
                    len_reg     <= 5'd12;
                end
            endcase
        end
    end

    // ------------------------------------------------------
    // 전송 로직 (idx_reg, tx_data, push, busy, send_done)
    // ------------------------------------------------------
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            idx_reg   <= 5'd0;
            tx_data   <= 8'd0;
            push      <= 1'b0;
            busy      <= 1'b0;
            send_done <= 1'b0;
        end else begin
            push      <= 1'b0;   // 기본 1클럭 pulse
            send_done <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (send_trig) begin
                        idx_reg <= 5'd0;
                        busy    <= 1'b1;
                    end
                end

                SEND: begin
                    if (!full) begin
                        tx_data <= buf_mem[idx_reg];
                        push    <= 1'b1;
                        if (idx_reg != len_reg - 1)
                            idx_reg <= idx_reg + 5'd1;
                    end
                    // full 이면 그냥 대기(스톨) -> FIFO 여유 생기면 이어서 push
                end

                DONE_ST: begin
                    busy      <= 1'b0;
                    send_done <= 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule