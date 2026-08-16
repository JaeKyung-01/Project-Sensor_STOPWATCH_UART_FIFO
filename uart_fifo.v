`timescale 1ns / 1ps

module uart_fifo #(
    parameter FIFO_WIDTH = 4
) (
    input        clk,
    input        reset,
    input        rx,
    output       tx
);

    wire [7:0] w_rx_data_from_uart;
    wire       w_rx_done;

    wire [7:0] w_rx_fifo_data;
    wire       w_rx_fifo_empty;
    wire       w_rx_fifo_full;

    wire       w_rx_fifo_pop;

    wire [7:0] w_tx_data_to_uart;
    wire       w_tx_fifo_empty;
    wire       w_tx_fifo_full;

    wire       w_tx_fifo_push;

    wire       w_uart_tx_busy;
    wire       w_uart_tx_start;

    uart_controller U_UART_CTRL (
        .clk      (clk),
        .reset    (reset),
        .tx_start (w_uart_tx_start),
        .tx_data  (w_tx_data_to_uart),
        .rx       (rx),
        .rx_data  (w_rx_data_from_uart),
        .rx_done  (w_rx_done),
        .tx_busy  (w_uart_tx_busy),
        .tx_done  (),
        .tx       (tx)
    );

    fifo #(
        .WIDTH(FIFO_WIDTH)
    ) U_RX_FIFO (
        .clk   (clk),
        .reset (reset),
        .push  (w_rx_done),
        .pop   (w_rx_fifo_pop),
        .wdata (w_rx_data_from_uart),
        .rdata (w_rx_fifo_data),
        .full  (w_rx_fifo_full),
        .empty (w_rx_fifo_empty)
    );

    fifo #(
        .WIDTH(FIFO_WIDTH)
    ) U_TX_FIFO (
        .clk   (clk),
        .reset (reset),
        .push  (w_tx_fifo_push),
        .pop   (w_uart_tx_start),
        .wdata (w_rx_fifo_data),
        .rdata (w_tx_data_to_uart),
        .full  (w_tx_fifo_full),
        .empty (w_tx_fifo_empty)
    );

    assign w_rx_fifo_pop = ~w_rx_fifo_empty & ~w_tx_fifo_full;

    assign w_tx_fifo_push = w_rx_fifo_pop;

    assign w_uart_tx_start = ~w_tx_fifo_empty & ~w_uart_tx_busy;

endmodule