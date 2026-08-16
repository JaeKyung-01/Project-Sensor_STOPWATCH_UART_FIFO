`timescale 1ns / 1ps
// ============================================================
//  control_unit.v  (초안 / 얼추 버전)
//
//  다이어그램의 중앙 Control Unit. AsciiDecoder가 만든 11bit
//  one-hot 커맨드(r,s,c,m,S,M,H,A,C,F,B) + 물리 버튼/스위치를
//  받아서, Stopwatch Datapath / Watch Datapath 로 나가는 제어
//  신호를 만들어줌. (SR04/DHT11/AsciiSender 쪽은 아직 확정된 게
//  없어서 일단 자리만 잡아둔 버전 - 아래 "확정 아님" 표시 참고)
//
//  포트 이름은 팀원이 분리 중인 datapath 모듈과 그대로 맞춰 씀:
//    - stopwatch_datapath 의 run_stop / clear / mode
//    - watch_datapath 의 change_sec / change_min / change_hour
//  (기존 stopwatch_watch.v 안의 control_unit / watch_control_unit
//   로직을 그대로 가져와서 버튼 + UART 커맨드를 같이 받아들이게
//   확장한 것뿐이라, datapath 쪽 포트가 이미 저 이름 그대로라면
//   바로 연결될 것)
//
//  --------------------------------------------------------
//  cmd 비트별 매핑 (r/s/c/m 은 기존 uart_command_controller.v에서
//  이미 확인된 것. S/M/H/A/C/F/B는 제가 "그럴듯하게" 붙여본 제안일
//  뿐 팀에서 확정한 게 아님. 다르면 아래 wire cmd_* 선언부만
//  고치면 됨):
//    cmd[0] r : 스톱워치 run
//    cmd[1] s : 스톱워치 stop
//    cmd[2] c : 스톱워치 clear
//    cmd[3] m : 스톱워치 mode
//    cmd[4] S : 워치 초 설정모드로 진입          (제안, 확정 아님)
//    cmd[5] M : 워치 분 설정모드로 진입          (제안, 확정 아님)
//    cmd[6] H : 워치 시 설정모드로 진입          (제안, 확정 아님)
//    cmd[7] A : DHT11(온습도) 측정 시작          (확정)  // 수정: SR04->DHT11로 정정
//    cmd[8] C : DHT11 섭씨 표시 전환             (확정, run/stop처럼 토글) // 수정
//    cmd[9] F : DHT11 화씨 표시 전환             (확정, run/stop처럼 토글) // 수정
//    cmd[10] B: SR04(거리) 측정 시작             (확정)  // 수정: DHT11->SR04로 정정
//
//  SR04 / DHT11 버튼 매핑 (사용자 확인, 확정):
//    - SR04  : btn_L(sw_sr04 on)  = 측정 시작, UART 'B'와 동일 동작
//    - DHT11 : btn_L(sw_dht11 on) = 측정 시작, UART 'A'와 동일 동작
//              btn_R(sw_dht11 on) = 섭씨/화씨 전환, UART 'C'/'F'와 동일
//              동작 (스톱워치 run/stop과 같은 "토글" 방식)
//  --------------------------------------------------------
// ============================================================

module control_unit (
    input        clk,
    input        reset,

    // ---- AsciiDecoder 출력 ----
    input [11:0] cmd,

    // ---- 모드 선택 스위치 ----
    input        sw_watch,
    input        sw_stop,
    input        sw_sr04,     // 추가: SR04 모드 선택 스위치
    input        sw_dht11,    // 추가: DHT11 모드 선택 스위치

    // ---- 디바운스 통과한 물리 버튼 (btn_debouncer 이후 값) ----
    // SR04/DHT11도 다른 서브시스템과 동일하게 btn_L/btn_R을
    // 공용으로 쓰고 sw_sr04 / sw_dht11로 게이팅함 (전용 버튼 없앰)
    input        btn_L,       // 수정: sr04_btn/dht11_btn 대신 공용 btn_L 재사용
    input        btn_R,       // 수정: DHT11 섭씨/화씨 전환용으로 공용 btn_R 재사용
    input        btn_U,
    input        btn_D,

    // ---- Stopwatch Datapath 로 (stopwatch_datapath 포트명과 동일) ----
    output       run_stop,
    output       clear,
    output       mode,

    // ---- Watch Datapath 로 (watch_datapath 포트명과 동일) ----
    output [1:0] change_sec,
    output [1:0] change_min,
    output [1:0] change_hour,

    // ---- Watch FND 깜빡임용 (기존 watch_control_unit에 있던 출력) ----
    output       blink_sec,
    output       blink_min,
    output       blink_hour,

    // ---- SR04 / DHT11 트리거 (버튼/커맨드 매핑 확정) ----
    output       sr04_start,
    output       dht11_start,
    output       dht11_mode_celsius_req,    // 수정: 토글 레지스터 기반 레벨 신호 (현재 섭씨면 1)
    output       dht11_mode_fahrenheit_req, // 수정: 토글 레지스터 기반 레벨 신호 (현재 화씨면 1)

    // ---- AsciiSender ---- (확정 아님 - 임시로 커맨드 들어오면 그대로 전송 트리거)
    output [1:0] send_src_sel,
    output       send_trig
);

    // ------------------------------------------------------
    // cmd 비트 이름 붙이기 (여기만 고치면 매핑 전체 바뀜)
    // ------------------------------------------------------
    wire cmd_r = cmd[0];
    wire cmd_s = cmd[1];
    wire cmd_c = cmd[2];
    wire cmd_m = cmd[3];
    wire cmd_S = cmd[4];
    wire cmd_M = cmd[5];
    wire cmd_H = cmd[6];
    wire cmd_A = cmd[7];
    wire cmd_C = cmd[8];
    wire cmd_F = cmd[9];
    wire cmd_B = cmd[10];

    // ========================================================
    // Stopwatch 부분
    //   원래 stopwatch_watch.v 의 control_unit(STOP/RUN/CLEAR/MODE
    //   FSM) 그대로 가져오고, 트리거만 버튼 OR UART커맨드로 확장.
    //   r은 정지상태일 때만, s는 동작중일 때만 먹히게 해서
    //   (기존 uart_command_controller.v 방식과 동일) 버튼 토글이랑
    //   안 꼬이게 함.
    // ========================================================
    wire stop_btn_L = btn_L && sw_stop;
    wire stop_btn_R = btn_R && sw_stop;
    wire stop_btn_U = btn_U && sw_stop;

    wire i_run_stop_trig = stop_btn_L || (cmd_r && !run_stop) || (cmd_s && run_stop);
    wire i_clear_trig    = stop_btn_R || cmd_c;
    wire i_mode_trig      = stop_btn_U || cmd_m;

    localparam STOP = 0, RUN = 1, CLEAR = 2, MODE = 3;
    reg [1:0] stop_c_state, stop_n_state;
    reg run_stop_reg, run_stop_next, clear_reg, clear_next, mode_reg, mode_next;

    assign run_stop = run_stop_reg;
    assign clear    = clear_reg;
    assign mode     = mode_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            stop_c_state <= STOP;
            run_stop_reg <= 0;
            clear_reg    <= 0;
            mode_reg     <= 0;
        end else begin
            stop_c_state <= stop_n_state;
            run_stop_reg <= run_stop_next;
            clear_reg    <= clear_next;
            mode_reg     <= mode_next;
        end
    end

    always @(*) begin
        stop_n_state  = stop_c_state;
        run_stop_next = run_stop_reg;
        clear_next    = clear_reg;
        mode_next     = mode_reg;

        case (stop_c_state)
            STOP: begin
                run_stop_next = 0;
                clear_next    = 0;

                if (i_run_stop_trig) stop_n_state = RUN;
                else if (i_clear_trig) stop_n_state = CLEAR;
                else if (i_mode_trig) stop_n_state = MODE;
            end

            RUN: begin
                run_stop_next = 1;

                if (i_run_stop_trig) begin
                    run_stop_next = 0;
                    clear_next    = 0;
                    stop_n_state  = STOP;
                end
            end

            CLEAR: begin
                clear_next   = 1;
                stop_n_state = STOP;
            end

            MODE: begin
                mode_next    = ~mode_reg;
                stop_n_state = STOP;
            end
        endcase
    end

    // ========================================================
    // Watch 부분
    //   원래 watch_control_unit(WATCH/SET_SEC/SET_MIN/SET_HOUR FSM)
    //   그대로 가져오고, S/M/H 커맨드가 오면 그 설정모드로 바로
    //   점프하는 것만 추가 (제안, 확정 아님).
    // ========================================================
    wire watch_btn_L = btn_L && sw_watch;
    wire watch_btn_R = btn_R && sw_watch;
    wire watch_btn_U = btn_U && sw_watch;
    wire watch_btn_D = btn_D && sw_watch;

    localparam WATCH = 0, SET_SEC = 1, SET_MIN = 2, SET_HOUR = 3;
    reg [1:0] watch_c_state, watch_n_state;

    always @(posedge clk, posedge reset) begin
        if (reset) watch_c_state <= WATCH;
        else watch_c_state <= watch_n_state;
    end

    assign change_sec  = (watch_c_state == SET_SEC) ? {watch_btn_U, watch_btn_D} : 2'b00;
    assign change_min  = (watch_c_state == SET_MIN) ? {watch_btn_U, watch_btn_D} : 2'b00;
    assign change_hour = (watch_c_state == SET_HOUR) ? {watch_btn_U, watch_btn_D} : 2'b00;

    assign blink_sec  = (watch_c_state == SET_SEC);
    assign blink_min  = (watch_c_state == SET_MIN);
    assign blink_hour = (watch_c_state == SET_HOUR);

    always @(*) begin
        watch_n_state = watch_c_state;

        // UART S/M/H 로 바로 점프 (제안, 확정 아님)
        if (sw_watch && cmd_S) begin
            watch_n_state = SET_SEC;
        end else if (sw_watch && cmd_M) begin
            watch_n_state = SET_MIN;
        end else if (sw_watch && cmd_H) begin
            watch_n_state = SET_HOUR;
        end else begin
            case (watch_c_state)
                WATCH:
                if (sw_watch == 1) watch_n_state = SET_SEC;
                else watch_n_state = WATCH;

                SET_SEC:
                if (sw_watch == 1) begin
                    if (watch_btn_L) watch_n_state = SET_MIN;
                    else if (watch_btn_R) watch_n_state = SET_HOUR;
                end else watch_n_state = WATCH;

                SET_MIN:
                if (sw_watch == 1) begin
                    if (watch_btn_L) watch_n_state = SET_HOUR;
                    else if (watch_btn_R) watch_n_state = SET_SEC;
                end else watch_n_state = WATCH;

                SET_HOUR:
                if (sw_watch == 1) begin
                    if (watch_btn_L) watch_n_state = SET_SEC;
                    else if (watch_btn_R) watch_n_state = SET_MIN;
                end else watch_n_state = WATCH;
            endcase
        end
    end

    // ========================================================
    // SR04 / DHT11 버튼 게이팅 (다른 서브시스템과 동일한 패턴)
    // ========================================================
    wire sr04_btn_L  = btn_L && sw_sr04;   // 추가: 거리센서 시작 버튼
    wire dht11_btn_L = btn_L && sw_dht11;  // 추가: 온습도센서 시작 버튼
    wire dht11_btn_R = btn_R && sw_dht11;  // 추가: 온습도센서 섭씨/화씨 전환 버튼

    // ========================================================
    // SR04(거리센서): btn_L 또는 UART 'B' 로 측정 시작 (확정)
    // ========================================================
    assign sr04_start = sr04_btn_L || cmd_B;   // 수정: cmd_A -> cmd_B로 정정 (B가 SR04)

    // ========================================================
    // DHT11(온습도센서)
    //  - 시작: btn_L 또는 UART 'A' (확정)                 // 수정: cmd_B -> cmd_A로 정정 (A가 DHT11)
    //  - 섭씨/화씨 전환: btn_R 또는 UART 'C'/'F', 스톱워치
    //    run/stop과 같은 "토글" 방식. C는 현재 화씨일 때만,
    //    F는 현재 섭씨일 때만 실제로 전환됨 (이미 그 상태면
    //    같은 커맨드를 또 보내도 무시 - r/s 처리 방식과 동일)
    // ========================================================
    assign dht11_start = dht11_btn_L || cmd_A;

    reg dht11_f_reg;  // 추가: 0 = 섭씨, 1 = 화씨
    wire i_dht11_unit_trig = dht11_btn_R || (cmd_C && dht11_f_reg) || (cmd_F && !dht11_f_reg);  // 추가

    always @(posedge clk, posedge reset) begin  // 추가
        if (reset) dht11_f_reg <= 1'b0;         // 추가: 기본값 섭씨
        else if (i_dht11_unit_trig) dht11_f_reg <= ~dht11_f_reg;  // 추가
    end

    assign dht11_mode_celsius_req    = ~dht11_f_reg;  // 수정: 토글 레지스터 기반으로 변경
    assign dht11_mode_fahrenheit_req = dht11_f_reg;   // 수정: 토글 레지스터 기반으로 변경

    // ========================================================
    // AsciiSender 트리거 (확정 아님)
    //   지금은 "커맨드가 뭐가 왔든 관련 데이터소스를 한 번 보낸다"
    //   정도로만 임시로 짜둠.
    // ========================================================
    reg [1:0] r_send_src_sel;
    reg       r_send_trig;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_send_src_sel <= 2'b00;
            r_send_trig    <= 1'b0;
        end else begin
            r_send_trig <= 1'b0;

            if (cmd_B) begin
                r_send_src_sel <= 2'b00;  // SR04   // 수정: cmd_A -> cmd_B로 정정
                r_send_trig    <= 1'b1;
            end else if (cmd_r || cmd_s || cmd_c || cmd_m) begin
                r_send_src_sel <= 2'b01;  // Stopwatch
                r_send_trig    <= 1'b1;
            end else if (cmd_S || cmd_M || cmd_H) begin
                r_send_src_sel <= 2'b10;  // Watch
                r_send_trig    <= 1'b1;
            end else if (cmd_A) begin
                r_send_src_sel <= 2'b11;  // DHT11  // 수정: cmd_B -> cmd_A로 정정
                r_send_trig    <= 1'b1;
            end
        end
    end

    assign send_src_sel = r_send_src_sel;
    assign send_trig    = r_send_trig;

endmodule