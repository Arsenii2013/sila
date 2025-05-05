`ifndef __AVMM_SLAVE_STUB_SV__
`define __AVMM_SLAVE_STUB_SV__

module avmm_slave_stub #(
    parameter AW        = 16,
    parameter DW        = 64,
    parameter MAX_BURST = 8
)
(
    input  logic  clk,
    input  logic  rst,
    avmm_if.slave bus
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Parameters
//
localparam DEPTH  = (2**AW) / (DW/8);
localparam ALIGN  = $clog2(DW/8);

localparam MEM_AW = AW - ALIGN; 

localparam BCW    = $clog2(MAX_BURST);

//------------------------------------------------
//
//      Types
//
typedef logic [MEM_AW-1:0] addr_t;
typedef logic [    DW-1:0] data_t;
typedef logic [     BCW:0] count_t;

typedef enum {
    IDLE,
    WRITE,
    READ
} state_t;

//------------------------------------------------
//
//      Objects
//
data_t  data[DEPTH] = '{default: '0};
data_t  mask;
addr_t  addr;
count_t count;
count_t cnt;

state_t state = IDLE;
state_t next  = IDLE;

//------------------------------------------------
//
//      Logic
//
genvar i;
generate
    for (i=0; i<DW/8; i++) begin : bytemask
        assign mask[8*i+7:8*i] = bus.byteenable[i] ? 8'hFF : 8'h00;
    end
endgenerate
//------------------------------------------------
assign bus.waitrequest   = state == IDLE;
assign bus.readdatavalid = state == READ;
assign bus.readdata      = data[addr];

always_ff @(posedge clk) begin
    state <= next;
    case (state)
        IDLE: begin
            cnt   <= '0;
            addr  <= bus.address[AW-1:ALIGN];
            count <= bus.burstcount;
        end
        WRITE: begin
            if (bus.write) begin
                cnt        <= cnt + 1;
                addr       <= addr + 1;
                data[addr] <= (mask & bus.writedata) | (~mask & data[addr]);
            end
        end
        READ: begin
            cnt  <= cnt + 1;
            addr <= addr + 1;
        end
    endcase
end
//------------------------------------------------
always_comb begin
    case (state)
        IDLE: begin
            if (bus.write | bus.read) next = bus.write ? WRITE : READ;
            else                      next = IDLE;
        end
        WRITE: begin
            if (bus.write)            next = cnt == count - 1 ? IDLE : WRITE;
            else                      next = WRITE;
        end
        READ:                         next = cnt == count - 1 ? IDLE : READ;
    endcase
end
//------------------------------------------------
endmodule // avmm_slave_stub

`endif // __AVMM_SLAVE_STUB_SV__