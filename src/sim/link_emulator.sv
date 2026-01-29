module link_emulator #(
    parameter realtime PROPAGATION_DELAY = 12345.56ns,
    parameter bit      ASYMMETRIC        = 0
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
    `timescale 1ns/1ps
    always @(up_tx_n)    down_rx_n    <= #(PROPAGATION_DELAY) up_tx_n;
    always @(up_tx_p)    down_rx_p    <= #(PROPAGATION_DELAY) up_tx_p;

    generate
    if(ASYMMETRIC) begin
        /* 
        143ps это один UI для 7 ГГц
        Ассимметрия нужна для случая, когда получается ситуация, что 
        фаза передающего клока относительно опорного становиться такой, что
        приемник делает на 1 rxslide больше или меньше, чем передатчик. 
        При этом они оба четными быть не могут, а значит не могут выровняться
        */
        always @(down_tx_n)    up_rx_n    <= #(PROPAGATION_DELAY + 143ps) down_tx_n;
        always @(down_tx_p)    up_rx_p    <= #(PROPAGATION_DELAY + 143ps) down_tx_p;
    end else begin
        always @(down_tx_n)    up_rx_n    <= #(PROPAGATION_DELAY) down_tx_n;
        always @(down_tx_p)    up_rx_p    <= #(PROPAGATION_DELAY) down_tx_p;
    end
    endgenerate
endmodule