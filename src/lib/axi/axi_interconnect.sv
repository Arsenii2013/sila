`timescale 1ns/1ns

`include "axi4_lite_if.svh"

module axi_interconnect
#(
    parameter AW = 32,
    parameter DW = 32
)
(
    input  logic  aclk,
    input  logic  aresetn,
    axi4_lite_if.s m1,
    axi4_lite_if.s m2,
    axi4_lite_if.m s
);
    typedef enum  { IDLE, M1_READ, M1_WRITE, M1_DELAY, M2_READ, M2_WRITE, M2_DELAY } state_t;

    state_t state = IDLE, next_state;

    assign m1.bresp = s.bresp;
    assign m1.rdata = s.rdata;
    assign m1.rresp = s.rresp;
    assign m2.bresp = s.bresp;
    assign m2.rdata = s.rdata;
    assign m2.rresp = s.rresp;

    always_comb begin 
        if( (next_state == M1_READ || next_state == M1_WRITE || state == M1_DELAY)) begin
            s.awaddr    = m1.awaddr;
            s.awprot    = m1.awprot;
            s.awvalid   = m1.awvalid;
            s.wdata     = m1.wdata;
            s.wstrb     = m1.wstrb;
            s.wvalid    = m1.wvalid;
            s.bready    = m1.bready;
            s.araddr    = m1.araddr;
            s.arprot    = m1.arprot;
            s.arvalid   = m1.arvalid;
            s.rready    = m1.rready;

            m1.awready  = s.awready;
            m1.wready   = s.wready;
            m1.bvalid   = s.bvalid;
            m1.arready  = s.arready;
            m1.rvalid   = s.rvalid;

            m2.awready  = 0;
            m2.wready   = 0;
            m2.bvalid   = 0;
            m2.arready  = 0;
            m2.rvalid   = 0;
        end
        else if((state == M2_READ || state == M2_WRITE || state == M2_DELAY)) begin
            s.awaddr    = m2.awaddr;
            s.awprot    = m2.awprot;
            s.awvalid   = m2.awvalid;
            s.wdata     = m2.wdata;
            s.wstrb     = m2.wstrb;
            s.wvalid    = m2.wvalid;
            s.bready    = m2.bready;
            s.araddr    = m2.araddr;
            s.arprot    = m2.arprot;
            s.arvalid   = m2.arvalid;
            s.rready    = m2.rready;

            m2.awready  = s.awready;
            m2.wready   = s.wready;
            m2.bvalid   = s.bvalid;
            m2.arready  = s.arready;
            m2.rvalid   = s.rvalid;

            m1.awready  = 0;
            m1.wready   = 0;
            m1.bvalid   = 0;
            m1.arready  = 0;
            m1.rvalid   = 0;
        end
        else begin
            s.awaddr    = 0;
            s.awprot    = 0;
            s.awvalid   = 0;
            s.wdata     = 0;
            s.wstrb     = 0;
            s.wvalid    = 0;
            s.bready    = 0;
            s.araddr    = 0;
            s.arprot    = 0;
            s.arvalid   = 0;
            s.rready    = 0;
            m2.awready  = 0;
            m2.wready   = 0;
            m2.bvalid   = 0;
            m2.arready  = 0;
            m2.rvalid   = 0;
            m1.awready  = 0;
            m1.wready   = 0;
            m1.bvalid   = 0;
            m1.arready  = 0;
            m1.rvalid   = 0;
        end
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
            IDLE  : begin
                if(m1.arvalid && m1.rready) 
                    next_state = M1_READ;
                else if(m1.awvalid && m1.wvalid)
                    next_state = M1_WRITE;
                else if(m2.arvalid && m2.rready) 
                    next_state = M2_READ;
                else if(m2.awvalid && m2.wvalid)
                    next_state = M2_WRITE;
                else 
                    next_state = IDLE;
            end
            M1_READ  : next_state = (s.rready && m1.rvalid) ? M1_DELAY : M1_READ;
            M1_WRITE : next_state = (m1.bready && s.bvalid) ? M1_DELAY : M1_WRITE;
            M2_READ  : next_state = (s.rready && m2.rvalid) ? M2_DELAY : M2_READ;
            M2_WRITE : next_state = (m2.bready && s.bvalid) ? M2_DELAY : M2_WRITE;
            M1_DELAY : next_state = IDLE;
            M2_DELAY : next_state = IDLE;
        endcase;
    end


endmodule