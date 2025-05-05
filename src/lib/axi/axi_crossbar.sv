`timescale 1ns/1ns

`include "axi4_lite_if.svh"

module axi_crossbar
#(
    parameter N = 10,
    parameter AW = 32,
    parameter DW = 32
)
(    
    input  logic  aclk,
    input  logic  aresetn,
    axi4_lite_if.s m,
    axi4_lite_if.m s[N]
);
    localparam BASE      = $clog2(N);
    localparam SAW       = AW - BASE;
    localparam PAGE_SIZE = 2 ** AW / N;

    typedef enum  { IDLE, READ, WRITE } state_t;

    state_t state = IDLE, next_state;
    logic [BASE-1:0] id = 0;
    logic [BASE-1:0] id_reg = 0;

    logic [N-1:0]    awvalid;
    logic [N-1:0]    awready;
    logic [N-1:0]    wvalid;
    logic [N-1:0]    wready;
    logic [N-1:0]    bresp1;
    logic [N-1:0]    bresp2;
    logic [N-1:0]    bvalid;
    logic [N-1:0]    bready;

    logic [N-1:0]    arvalid;
    logic [N-1:0]    arready;
    logic [N-1:0]    rresp1;
    logic [N-1:0]    rresp2;
    logic [N-1:0]    rvalid;
    logic [N-1:0]    rready;
    logic [DW-1:0]   rdata[N];

    genvar i;
    generate
        for (i=0; i<N; i++) begin 
            assign s[i].awaddr      = m.awaddr[SAW-1:0];
            assign s[i].awprot      = m.awprot;
            assign s[i].wdata       = m.wdata;
            assign s[i].wstrb       = m.wstrb;

            assign s[i].awvalid     = awvalid[i];
            assign awready[i]       = s[i].awready;
            assign s[i].wvalid      = wvalid[i];
            assign wready[i]        = s[i].wready;
            assign bresp1[i]        = s[i].bresp[0];
            assign bresp2[i]        = s[i].bresp[1];

            assign s[i].araddr      = m.araddr[SAW-1:0];
            assign s[i].arprot      = m.arprot;

            assign s[i].arvalid     = arvalid[i];
            assign arready[i]       = s[i].arready;
            assign rdata[i]         = s[i].rdata;
            assign rresp1[i]        = s[i].rresp[0];
            assign rresp2[i]        = s[i].rresp[1];
            assign rvalid[i]        = s[i].rvalid;
            assign s[i].rready      = rready[i];
            assign bvalid[i]        = s[i].bvalid;
            assign s[i].bready      = bready[i];
        end
    endgenerate

    /*always_comb begin 
        if(state == WRITE)
            id = m.awaddr[AW-1:SAW];
        else if(state == READ)
            id = m.araddr[AW-1:SAW];
        else 
            id = 0;
    end*/

    always_ff @(posedge aclk) begin
        if(m.awvalid)
            id <= m.awaddr[AW-1:SAW];
        else if(m.arvalid)
            id <= m.araddr[AW-1:SAW];
    end
    
    assign m.awready     = state != IDLE ? awready[id] : 0;
    assign m.wready      = state != IDLE ? wready[id] : 0;
    assign m.bresp       = state != IDLE ? {bresp1[id], bresp2[id]} : 0;
    assign m.bvalid      = state != IDLE ? bvalid[id] : 0;

    assign m.arready     = state != IDLE ? arready[id] : 0;
    assign m.rresp       = state != IDLE ? {rresp1[id], rresp2[id]} : 0;
    assign m.rvalid      = state != IDLE ? rvalid[id] : 0;
    assign m.rdata       = state != IDLE ? rdata[id] : 0;

    always_comb begin
        for(int i=0;i<N;i++) begin
            awvalid[i] = 0;
            wvalid[i]  = 0;
            bready[i]  = 0;
            arvalid[i] = 0;
            rready[i]  = 0;
        end

        awvalid[id]   = state != IDLE ? m.awvalid : 0;
        wvalid[id]    = state != IDLE ? m.wvalid : 0;
        bready[id]    = state != IDLE ? m.bready : 0;
        arvalid[id]   = state != IDLE ? m.arvalid : 0;
        rready[id]    = state != IDLE ? m.rready : 0;
    end

    always_ff @( posedge aclk ) begin 
        if(~aresetn) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always_comb begin 
        case(state)
        IDLE  :  next_state = (m.arvalid && m.rready) ? READ : (m.awvalid && m.wvalid) ? WRITE : IDLE;
        READ  :  next_state = (m.rready  && m.rvalid) ? IDLE : READ;
        WRITE :  next_state = (m.bready  && m.bvalid) ? IDLE : WRITE;
        default: next_state = IDLE;
        endcase;
    end
endmodule