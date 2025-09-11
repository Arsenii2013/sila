`ifndef _EVN_
`define _EVN_
`include "gtx.svh"

package evn;
// Parameters and types
localparam EVENT_COMMA     = 8'h5C;
localparam TRIGGER_COMMA   = 8'h7C;
localparam PACKET_COMMA    = 8'hDC;

localparam BEACON_WORD     = {EVENT_COMMA,      EVENT_COMMA, 8'h00, 8'h00};
localparam BEACON_IS_K     = 'hC;
localparam BEACON_PERIOD   = 2 ** 10 - 1;
typedef logic [$clog2(BEACON_PERIOD): 0] beacon_cnt_t;
function logic is_beacon(gtx::data_t data, gtx::is_k_t is_k);
    return data == BEACON_WORD && is_k == BEACON_IS_K;
endfunction

localparam ALIGNMENT_WORD = gtx::ALIGNMENT_WORD;
localparam ALIGNMENT_IS_K = gtx::ALIGNMENT_IS_K;
localparam ALIGNMENT_PERIOD = 4;
typedef logic [$clog2(ALIGNMENT_PERIOD): 0] alignment_cnt_t;
import gtx::is_alignment;

localparam DELAY_INT_W      = 16;
localparam DELAY_FRAC_W     = 16;
localparam DELAY_W          = DELAY_INT_W + DELAY_FRAC_W;
typedef logic [DELAY_W-1: 0] delay_t;

localparam MAX_COMPENSATION = 2 ** 10; // должна быть степенью двойки; 2 ** 10 тактов = 1.76 км

localparam TOPO_ID_W        = 32;
typedef logic [TOPO_ID_W               -1: 0] topo_id_t;

localparam EVENT_W          = 24;
typedef logic [EVENT_W                 -1: 0] ev_t;
function logic is_event(gtx::data_t data, gtx::is_k_t is_k);
    return data[31:24] == EVENT_COMMA && is_k == 'b1000;
endfunction

localparam TRIGGER_W        = 24;
typedef logic [TRIGGER_W               -1: 0] trig_t;
function logic is_trigger(gtx::data_t data, gtx::is_k_t is_k);
    return data[31:24] == TRIGGER_COMMA && is_k == 'b1000;
endfunction

typedef enum {
    ZERO      = link_csr_axi_core_pkg::link_csr_axi_core__link_delay_st__ZERO,
    INITIAL   = link_csr_axi_core_pkg::link_csr_axi_core__link_delay_st__INITIAL,
    ONE_CYCLE = link_csr_axi_core_pkg::link_csr_axi_core__link_delay_st__ONE_CYCLE,
    FINE      = link_csr_axi_core_pkg::link_csr_axi_core__link_delay_st__FINE,
    ERROR     = link_csr_axi_core_pkg::link_csr_axi_core__link_delay_st__ERROR
} link_delay_st_t;
// System packets

localparam SYSTEM_PACKET_ID_START   = 8'h00;
localparam TOPO_ID_PACKET_ID        = SYSTEM_PACKET_ID_START + 8'h01;
localparam MEAS_DELAY_PACKET_ID     = TOPO_ID_PACKET_ID      + 8'h01;
localparam TGT_DELAY_PACKET_ID      = MEAS_DELAY_PACKET_ID   + 8'h01;
localparam UP_DELAY_PACKET_ID       = TGT_DELAY_PACKET_ID    + 8'h01;
localparam SUB_DELAY_PACKET_ID      = UP_DELAY_PACKET_ID     + 8'h01;

localparam TOPO_ID_PACKET_LEN       = 16'h0001;
localparam MEAS_DELAY_PACKET_LEN    = 16'h0002;
localparam TGT_DELAY_PACKET_LEN     = 16'h0001;
localparam UP_DELAY_PACKET_LEN      = 16'h0001;
localparam SUB_DELAY_PACKET_LEN     = 16'h0001;

localparam TOPO_ID_PACKET_START     = {PACKET_COMMA, TOPO_ID_PACKET_ID,    TOPO_ID_PACKET_LEN   };
localparam MEAS_DELAY_PACKET_START  = {PACKET_COMMA, MEAS_DELAY_PACKET_ID, MEAS_DELAY_PACKET_LEN};
localparam TGT_DELAY_PACKET_START   = {PACKET_COMMA, TGT_DELAY_PACKET_ID,  TGT_DELAY_PACKET_LEN };
localparam UP_DELAY_PACKET_START    = {PACKET_COMMA, UP_DELAY_PACKET_ID,   UP_DELAY_PACKET_LEN  };
localparam SUB_DELAY_PACKET_START   = {PACKET_COMMA, SUB_DELAY_PACKET_ID,  SUB_DELAY_PACKET_LEN };

localparam PACKET_START_IS_K     = 4'h8;

function logic is_packet(gtx::data_t data, gtx::is_k_t is_k);
    return (data[31:24] == PACKET_COMMA && is_k == PACKET_START_IS_K) || is_k == '0;
endfunction

// User packets

localparam USER_ID_START    = 8'h80;
localparam TAMESTAMP_ID     = USER_ID_START + 1;

endpackage

// Interface from masler/slave/fanout
interface link_data;
    logic                 link_up;
    evn::delay_t          link_delay;
    evn::link_delay_st_t  link_delay_st;
    logic                 link_delay_upd;
    evn::topo_id_t        topo_id;
    logic                 topo_id_upd;
    evn::delay_t          tgt_delay;
    logic                 tgt_delay_upd;
    evn::delay_t          up_delay;
    logic                 up_delay_upd;
    evn::delay_t          sub_delay;
    logic                 sub_delay_upd;
    logic                 delay_comp_ena;
    evn::delay_t          delay_comp;
    evn::link_delay_st_t  delay_comp_st;
    logic                 delay_comp_upd;

modport master(
    output link_up,
    output link_delay,
    output link_delay_st,
    output link_delay_upd,
    input  topo_id,
    input  topo_id_upd,
    input  tgt_delay,
    input  tgt_delay_upd,
    input  up_delay,
    input  up_delay_upd,
    output sub_delay,
    output sub_delay_upd
);

modport slave(
    output link_up,
    output link_delay,
    output link_delay_st,
    output link_delay_upd,
    output topo_id,
    output topo_id_upd,
    output tgt_delay,
    output tgt_delay_upd,
    output up_delay,
    output up_delay_upd,
    input  sub_delay,
    input  sub_delay_upd,
    output delay_comp,
    input  delay_comp_ena,
    output delay_comp_st,
    output delay_comp_upd
);

modport slave_no_dc(
    output link_up,
    output link_delay,
    output link_delay_st,
    output link_delay_upd,
    output topo_id,
    output topo_id_upd,
    output tgt_delay,
    output tgt_delay_upd,
    output up_delay,
    output up_delay_upd,
    input  sub_delay,
    input  sub_delay_upd
);

modport monitor(
    input  link_up,
    input  link_delay,
    input  link_delay_st,
    input  link_delay_upd,
    input  topo_id,
    input  topo_id_upd,
    input  tgt_delay,
    input  tgt_delay_upd,
    input  up_delay,
    input  up_delay_upd,
    input  sub_delay,
    input  sub_delay_upd,
    input  delay_comp,
    input  delay_comp_ena,
    input  delay_comp_st,
    input  delay_comp_upd
);

function dump();
    $display("link dump for : %m");
    $display("link_up       : %x", link_up);
    $display("link_delay_st : %x", link_delay_st);
    $display("delay_comp_st : %x", delay_comp_st);
    $display("topo_id       : %x", topo_id);
    $display("link_delay    : %x = %e s", link_delay, (link_delay >> 16) / 175e6);
    $display("up_delay      : %x = %e s", up_delay,   (up_delay >> 16) / 175e6);
    $display("sub_delay     : %x = %e s", sub_delay,  (sub_delay >> 16) / 175e6);
    $display("tgt_delay     : %x = %e s", tgt_delay,  (tgt_delay >> 16) / 175e6);
    $display("delay_comp    : %x = %e s", delay_comp, (delay_comp >> 16) / 175e6);
endfunction
endinterface

`endif //_EVN_ 