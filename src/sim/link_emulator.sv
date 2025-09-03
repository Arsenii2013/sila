module link_emulator #(
    parameter PROPAGATION_DELAY = 12345.56ns
)(
    output logic up_rx_n,
    output logic up_rx_p,
    input  logic up_tx_n,
    input  logic up_tx_p,

    output logic down_rx_n,
    output logic down_rx_p,
    input  logic down_tx_n,
    input  logic down_tx_p
);
    always @(up_tx_n)    down_rx_n    <= #(PROPAGATION_DELAY) up_tx_n;
    always @(up_tx_p)    down_rx_p    <= #(PROPAGATION_DELAY) up_tx_p;
    always @(down_tx_n)    up_rx_n    <= #(PROPAGATION_DELAY) down_tx_n;
    always @(down_tx_p)    up_rx_p    <= #(PROPAGATION_DELAY) down_tx_p;
endmodule