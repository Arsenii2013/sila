`ifndef _GTX_
`define _GTX_

package gtx;

localparam DATA_W = 32;
typedef logic [DATA_W  -1:0] data_t;
typedef logic [DATA_W/8-1:0] is_k_t;

localparam ALIGNMENT_COMMA = 8'hBC;
localparam ALIGNMENT_WORD   = {ALIGNMENT_COMMA,  8'h00,      8'h00, 8'h00};
localparam ALIGNMENT_IS_K   = 'h8;

function logic is_alignment(gtx::data_t data, gtx::is_k_t is_k);
    return data == ALIGNMENT_WORD && is_k == ALIGNMENT_IS_K;
endfunction

localparam EVG_PORT_N    = 4;
localparam FANOUT_PORT_N = 4;
localparam EVR_PORT_N    = 1;
`define PORT_N(DEVICE) \
    ((DEVICE == "EVG") ? gtx::EVG_PORT_N : ((DEVICE == "FANOUT") ? gtx::FANOUT_PORT_N  : ((DEVICE == "EVG") ? gtx::EVR_PORT_N: 0)))

endpackage

interface gtx_if;
    logic        tx_clk;
    gtx::data_t  tx_data;
    gtx::is_k_t  tx_is_k;
    logic        tx_reset_done;

    logic        rx_clk;
    gtx::data_t  rx_data;
    gtx::is_k_t  rx_is_k;
    logic        rx_reset_done;
    logic        aligned;

modport gtx(
    output tx_clk,
    input  tx_data,
    input  tx_is_k,
    output tx_reset_done,

    output rx_clk,
    output rx_data,
    output rx_is_k,
    output rx_reset_done,
    output aligned
);

modport app(
    input  tx_clk,
    output tx_data,
    output tx_is_k,
    input  tx_reset_done,

    input  rx_clk,
    input  rx_data,
    input  rx_is_k,
    input  rx_reset_done,
    input  aligned
);

modport monitor(
    input  tx_clk,
    input  tx_data,
    input  tx_is_k,
    input  tx_reset_done,

    input  rx_clk,
    input  rx_data,
    input  rx_is_k,
    input  rx_reset_done,
    input  aligned
);
endinterface

`endif // _GTX_