`timescale 1ns / 1ps

module uart_controller (
    input       clk,
    input       reset,
    input       sw_watch,
    input       sw_stop,
    input       btn_L,
    input       btn_R,
    input       btn_U,
    input       btn_D,
    input       rx,
    output      tx,
    output      watch_btn_L_out,
    output      watch_btn_R_out,
    output      watch_btn_U_out,
    output      watch_btn_D_out,
    output      stop_btn_L_out,
    output      stop_btn_R_out,
    output      stop_btn_U_out,
    output      stop_btn_D_out
);

    wire w_debounced_btn_L, w_debounced_btn_R, w_debounced_btn_U, w_debounced_btn_D;
    wire w_baud_tick_x16;
    wire [7:0] w_rx_data;
    wire w_rx_done;
    wire w_tx_busy, w_tx_done;

    baud_tick_x16 U_BAUD_TICK_x16 (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(w_baud_tick_x16)
    );

    uart_rx U_UART_RX (
        .clk        (clk),
        .reset      (reset),
        .i_baud_tick(w_baud_tick_x16),
        .rx         (rx),
        .rx_data    (w_rx_data),
        .rx_done    (w_rx_done)
    );

    uart_tx U_UART_TX (
        .clk        (clk),
        .reset      (reset),
        .tx_start   (w_rx_done),
        .tx_data    (w_rx_data),
        .i_baud_tick(w_baud_tick_x16),
        .tx_busy    (w_tx_busy),
        .tx_done    (w_tx_done),
        .tx         (tx)
    );

    btn_debouncer U_BTN_L (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_L),
        .o_btn(w_debounced_btn_L)
    );
    btn_debouncer U_BTN_R (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_R),
        .o_btn(w_debounced_btn_R)
    );
    btn_debouncer U_BTN_U (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_U),
        .o_btn(w_debounced_btn_U)
    );
    btn_debouncer U_BTN_D (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_D),
        .o_btn(w_debounced_btn_D)
    );

    reg r_watch_L, r_watch_R, r_watch_U, r_watch_D;
    reg r_stop_run_cmd, r_stop_stop_cmd;
    reg r_stop_R, r_stop_U;
    reg r_sw_running;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_watch_L       <= 1'b0;
            r_watch_R       <= 1'b0;
            r_watch_U       <= 1'b0;
            r_watch_D       <= 1'b0;
            r_stop_run_cmd  <= 1'b0;
            r_stop_stop_cmd <= 1'b0;
            r_stop_R        <= 1'b0;
            r_stop_U        <= 1'b0;
            r_sw_running    <= 1'b0;
        end else begin
            r_watch_L       <= 1'b0;
            r_watch_R       <= 1'b0;
            r_watch_U       <= 1'b0;
            r_watch_D       <= 1'b0;
            r_stop_run_cmd  <= 1'b0;
            r_stop_stop_cmd <= 1'b0;
            r_stop_R        <= 1'b0;
            r_stop_U        <= 1'b0;

            if (sw_watch == 1'b1) begin
                if (w_debounced_btn_L) r_watch_L <= 1'b1;
                if (w_debounced_btn_R) r_watch_R <= 1'b1;
                if (w_debounced_btn_U) r_watch_U <= 1'b1;
                if (w_debounced_btn_D) r_watch_D <= 1'b1;

                if (w_rx_done) begin
                    case (w_rx_data)
                        8'h55:   r_watch_U <= 1'b1;
                        8'h44:   r_watch_D <= 1'b1;
                        8'h4C:   r_watch_L <= 1'b1;
                        8'h52:   r_watch_R <= 1'b1;
                        default: ;
                    endcase
                end
            end 

            else if (sw_stop == 1'b1) begin
                if (w_debounced_btn_L) begin
                    r_sw_running    <= ~r_sw_running;
                    r_stop_run_cmd  <= ~r_sw_running;
                    r_stop_stop_cmd <= r_sw_running;
                end
                if (w_debounced_btn_R) r_stop_R <= 1'b1;
                if (w_debounced_btn_U) r_stop_U <= 1'b1;

                if (w_rx_done) begin
                    case (w_rx_data)
                        8'h72: begin
                            if (!r_sw_running) begin
                                r_stop_run_cmd <= 1'b1;
                                r_sw_running   <= 1'b1;
                            end
                        end
                        8'h73: begin
                            if (r_sw_running) begin
                                r_stop_stop_cmd <= 1'b1;
                                r_sw_running    <= 1'b0;
                            end
                        end
                        8'h63:   r_stop_R <= 1'b1;
                        8'h6D:   r_stop_U <= 1'b1;
                        default: ;
                    endcase
                end
            end
        end
    end

    assign watch_btn_L_out = (sw_watch == 1'b1) ? r_watch_L : 1'b0;
    assign watch_btn_R_out = (sw_watch == 1'b1) ? r_watch_R : 1'b0;
    assign watch_btn_U_out = (sw_watch == 1'b1) ? r_watch_U : 1'b0;
    assign watch_btn_D_out = (sw_watch == 1'b1) ? r_watch_D : 1'b0;

    assign stop_btn_L_out  = (sw_stop == 1'b1) ? (r_stop_run_cmd | r_stop_stop_cmd) : 1'b0;
    assign stop_btn_R_out  = (sw_stop == 1'b1) ? r_stop_R : 1'b0;
    assign stop_btn_U_out  = (sw_stop == 1'b1) ? r_stop_U : 1'b0;
    assign stop_btn_D_out  = (sw_stop == 1'b1) ? w_debounced_btn_D : 1'b0;

endmodule