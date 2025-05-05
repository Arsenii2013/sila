`ifndef __DPRAM_AVMM_SV__
`define __DPRAM_AVMM_SV__

module dpram_avmm_m
#(
    parameter AVMM_AW        = 12,
    parameter AVMM_DW        = 64,
    parameter AVMM_MAX_BURST = 8,
    parameter APP_AW         = 8,
    parameter APP_DW         = 8,
    parameter INIT_FILE      = "none"
)
(
    input logic               clk,
    input logic               rst,

    avmm_if.slave             bus,

    input  logic [APP_AW-1:0] app_addr,
    output logic [APP_DW-1:0] app_data
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Parameters
//
localparam SIZE    = APP_DW * (1<<APP_AW);
localparam DEPTH   = SIZE / AVMM_DW;
localparam MEM_AW  = $clog2(DEPTH);

localparam COUNT_W = $clog2(AVMM_MAX_BURST);

typedef enum {
    IDLE,
    FETCH,
    WRITE, 
    READ
} state_t;

//------------------------------------------------
//
//      Types
//
typedef logic [  AVMM_AW-1:0] addr_t;
typedef logic [   MEM_AW-1:0] mem_addr_t;
typedef logic [  AVMM_DW-1:0] data_t;
typedef logic [    COUNT_W:0] count_t;

//------------------------------------------------
//
//      Objects
//
addr_t     addr;
mem_addr_t mem_addr;
data_t     wdata;
data_t     rdata;
data_t     wmask;

logic      wren;
logic      avalid;
logic      rvalid;

count_t    count;
count_t    cnt = '0;

state_t    state = IDLE;
state_t    next  = IDLE;

//------------------------------------------------
//
//      Logic
//
genvar i;
generate
    for (i=0; i<AVMM_DW/8; i++) begin : bytemask
        assign wmask[8*i+7:8*i] = bus.byteenable[i] ? 8'hFF : 8'h00;
    end
endgenerate

//------------------------------------------------
assign bus.waitrequest = ~((state == WRITE && bus.write) || (state == IDLE && bus.read));

assign mem_addr        = mem_addr_t'(addr / (AVMM_DW/8));
assign avalid          = mem_addr <= mem_addr_t'(DEPTH-1);
assign wren            = bus.write & avalid & !bus.waitrequest;
assign wdata           = (wmask & bus.writedata) | (~wmask & rdata);
assign bus.readdata    = rvalid ? rdata : '0;

always_ff @(posedge clk) begin
    bus.readdatavalid <= state == READ;
    rvalid            <= avalid;
end

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        cnt   <= '0;
    end
    else begin
        state <= next;
        case (state)
            IDLE: begin
                cnt   <= '0;
                addr  <= bus.address;
                count <= bus.burstcount;
            end
            WRITE: begin
                if (bus.write) begin
                    cnt  <= count_t'(cnt + 1);
                    addr <= addr_t'(addr + 1);
                end
            end
            READ: begin
                cnt  <= count_t'(cnt + 1);
                addr <= addr_t'(addr + 1);
            end
        endcase
    end
end
//------------------------------------------------
always_comb begin
    if (rst) begin
        next = IDLE;
    end
    else begin
        case (state)
            IDLE: begin
                if (bus.write | bus.read) next = bus.write ? FETCH : READ;
                else                      next = IDLE;
            end
            FETCH:                        next = WRITE;
            WRITE: begin
                if (bus.write)            next = cnt == count_t'(count - 1) ? IDLE : FETCH;
                else                      next = WRITE;
            end
            READ:                         next = cnt == count_t'(count - 1) ? IDLE : READ;
        endcase
    end
end

//------------------------------------------------
//
//      Instances
//
assign rdata = 'hdead;

xpm_memory_sdpram #(
   .ADDR_WIDTH_A(MEM_AW),
   .ADDR_WIDTH_B(APP_AW),
   .BYTE_WRITE_WIDTH_A(AVMM_DW),
   .CLOCKING_MODE("common_clock"),
   .IGNORE_INIT_SYNTH(0),
   .MEMORY_INIT_FILE(INIT_FILE),
   .MEMORY_OPTIMIZATION("true"),
   .MEMORY_PRIMITIVE("auto"),
   .MEMORY_SIZE(SIZE),
   .READ_DATA_WIDTH_B(APP_DW), 
   .READ_LATENCY_B(2),
   .SIM_ASSERT_CHK(1), 
   .USE_EMBEDDED_CONSTRAINT(1),
   .USE_MEM_INIT(1),
   .USE_MEM_INIT_MMI(0),
   .WAKEUP_TIME("disable_sleep"),
   .WRITE_DATA_WIDTH_A(AVMM_DW),
   .WRITE_MODE_B("no_change"),
   .WRITE_PROTECT(1)
)
xpm_memory_sdpram_inst (
   .doutb(app_data),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
   .addra(mem_addr),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
   .addrb(app_addr),
   .clka(clk),
   .dina(wdata),
   .ena(wren),
   .enb('1),
   .sleep('0),
   .regceb('1),
   .rstb(rst),
   .wea('1)

);

//------------------------------------------------
endmodule : dpram_avmm_m

`endif//__DPRAM_AVMM_SV__