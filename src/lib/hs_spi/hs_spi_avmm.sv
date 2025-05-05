`ifndef __HS_SPI_AVMM_SV__
`define __HS_SPI_AVMM_SV__

//------------------------------------------------
module hs_spi_master_avmm_m
#(
    parameter AW           = 10,
    parameter DW           = 32,
    parameter MAX_BURST    = 256,
    parameter SPI_W        = 4,
    parameter DUMMY_CYCLES = 4
)
(
    input  logic              clk,
    input  logic              oclk,
    input  logic              rst,
    output logic              idle,
    
    avmm_if.slave             bus,

    output logic              SCK,
    output logic              CSn,
    input  logic  [SPI_W-1:0] MISO,
    output logic  [SPI_W-1:0] MOSI
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Parameters
//
localparam ALIGN    = $clog2(DW/8);
localparam SPI_AW   = AW - ALIGN;
localparam SPI_DW   = DW;

// 32bit package header = opdcode + burst length + address length
localparam OPCODE_W = SPI_DW - ($clog2(MAX_BURST)+1) - SPI_AW;

//------------------------------------------------
//
//      Types
//
typedef logic [            SPI_DW-1:0] data_t;
typedef logic [            SPI_AW-1:0] addr_t;
typedef logic [   $clog2(MAX_BURST):0] count_t;
typedef logic [      (OPCODE_W-2)-1:0] head_rsrv_t;
typedef logic [$clog2(DUMMY_CYCLES):0] dummy_t;

typedef enum logic [OPCODE_W-1:0] {
    NOP   = {2'b00, head_rsrv_t'(0)},
    READ  = {2'b01, head_rsrv_t'(0)},
    WRITE = {2'b10, head_rsrv_t'(0)}
} opcode_t;

typedef struct packed {
    opcode_t opcode;
    count_t  count;
    addr_t   addr;
} header_t;

typedef enum {
    IDLE,
    LOAD_HEAD,
    WAIT_HEAD_SEND,
    LOAD_DATA,
    WAIT_DATA_SEND,
    DUMMY,
    TRIG_READ,
    WAIT_DATA_READ
} state_t;

//------------------------------------------------
//
//      Objects
//
logic    load;
logic    empty;
logic    busy;
logic    stc;

addr_t   addr;
count_t  count;
opcode_t opcode;
header_t header;

count_t  cnt;
dummy_t  dummy;

data_t   wdata;
data_t   rdata;

state_t  state = IDLE, next;

//------------------------------------------------
//
//      Logic
//
assign header.opcode = opcode;
assign header.count  = count;
assign header.addr   = addr;

always_comb begin
    if (bus.write)     opcode = WRITE;
    else if (bus.read) opcode = READ;
    else               opcode = NOP;
end

//------------------------------------------------
assign idle              = state == IDLE;

assign bus.waitrequest   = ~((bus.write && state == LOAD_DATA && !empty) || (bus.read && state == LOAD_HEAD && !empty));
assign bus.readdatavalid = state == WAIT_DATA_READ && stc && next != DUMMY;
assign bus.readdata      = rdata;

assign load              = state == LOAD_HEAD || state == LOAD_DATA || state == TRIG_READ;
assign wdata             = load ? (state == LOAD_HEAD ? header : bus.writedata) : '0;  

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end
    else begin
        state <= next;
        case (state)
            IDLE: begin
                cnt   <= '0;
                dummy <= '0;
                addr  <= bus.address[ALIGN +: SPI_AW];
                count <= addr_t'(bus.burstcount);
            end
            //------------------------------------------------
            LOAD_DATA: if (bus.write & !empty) cnt <= cnt + count_t'(1);
            //------------------------------------------------
            DUMMY:     dummy <= dummy + dummy_t'(1);
            //------------------------------------------------
            TRIG_READ: if (!empty) cnt <= cnt + count_t'(1);
            //------------------------------------------------
            default;
        endcase
    end
end

always_comb begin
    automatic logic start = bus.write | bus.read;
    if (rst) begin
        next = IDLE;
    end
    else begin
        case (state)
            //------------------------------------------------
            IDLE:        next = start ? LOAD_HEAD : IDLE;
            //------------------------------------------------
            LOAD_HEAD:   next = !empty ? WAIT_HEAD_SEND : LOAD_HEAD;
            //------------------------------------------------
            WAIT_HEAD_SEND: begin
                if (stc) next = bus.write ? LOAD_DATA : DUMMY;
                else     next = WAIT_HEAD_SEND;
            end
            //------------------------------------------------
            LOAD_DATA:   next = bus.write & !empty ? WAIT_DATA_SEND : LOAD_DATA;
            //------------------------------------------------
            WAIT_DATA_SEND: begin
                if (stc) next = cnt == count ? IDLE : LOAD_DATA;
                else     next = WAIT_DATA_SEND;
            end
            //------------------------------------------------
            DUMMY:       next = dummy == dummy_t'(DUMMY_CYCLES - 1) ? TRIG_READ : DUMMY;
            //------------------------------------------------
            TRIG_READ:   next = !empty ? WAIT_DATA_READ : TRIG_READ;
            //------------------------------------------------
            WAIT_DATA_READ: begin
                if (stc) next = cnt == count ? IDLE : TRIG_READ;
                else     next = WAIT_DATA_READ;
            end
            //------------------------------------------------
            default:     next = IDLE;
        endcase
    end
end

//------------------------------------------------
logic busy_r;
assign stc = ~busy & busy_r;

always_ff @(posedge clk) busy_r <= busy;

//------------------------------------------------
//
//      Instances
//
hs_spi_master_m 
#(
    .DW        ( SPI_DW    ),
    .SPI_W     ( SPI_W     )
)
hs_spi_master
(
    .clk       ( clk       ),
    .oclk      ( oclk      ),
    .rst       ( rst       ),

    .load      ( load      ),
    .empty     ( empty     ),
    .busy      ( busy      ),
    .data_in   ( wdata     ),
    .data_out  ( rdata     ),

    .SCK       ( SCK       ),
    .CSn       ( CSn       ),
    .MISO      ( MISO      ),
    .MOSI      ( MOSI      )
);

//------------------------------------------------
endmodule : hs_spi_master_avmm_m

//------------------------------------------------
module hs_spi_slave_avmm_m
#(
    parameter AW        = 10,
    parameter DW        = 32,
    parameter MAX_BURST = 256,
    parameter SPI_W     = 4
)
(
    output logic              clkout,
    input  logic              rst,
    output logic              idle,

    avmm_if.master            bus,

    input  logic              SCK,
    input  logic              CSn,
    output logic  [SPI_W-1:0] MISO,
    input  logic  [SPI_W-1:0] MOSI
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Parameters
//
localparam ALIGN    = $clog2(DW/8);
localparam SPI_AW   = AW - ALIGN;
localparam SPI_DW   = DW;

// 32bit package header = opdcode + package length + address length
localparam OPCODE_W = SPI_DW - ($clog2(MAX_BURST)+1) - SPI_AW;

//------------------------------------------------
//
//      Types
//
typedef logic [         SPI_DW-1:0] data_t;
typedef logic [         SPI_AW-1:0] addr_t;
typedef logic [$clog2(MAX_BURST):0] count_t;
typedef logic [   (OPCODE_W-2)-1:0] head_rsrv_t;

typedef enum logic [OPCODE_W-1:0] {
    NOP   = {2'b00, head_rsrv_t'(0)},
    READ  = {2'b01, head_rsrv_t'(0)},
    WRITE = {2'b10, head_rsrv_t'(0)}
} opcode_t;

typedef struct packed {
    opcode_t opcode;
    count_t  count;
    addr_t   addr;
} header_t;

typedef enum {
    IDLE,
    WAIT_WDATA,
    WAIT_WRITE_ACK,
    WAIT_READ_ACK,
    WAIT_RDATA,
    WAIT_EMPTY,
    LOAD_RDATA,
    WAIT_LAST_SEND
} state_t;

//------------------------------------------------
//
//      Objects
//
logic    clk;

logic    load;
logic    empty;
logic    busy;
logic    stc;

addr_t   addr;
count_t  count;
opcode_t opcode;
header_t header;

count_t  cnt;
count_t  sent;

data_t   wdata;
data_t   rdata;

state_t  state = IDLE, next;

//------------------------------------------------
//
//      Logic
//
assign clk  = clkout;

//------------------------------------------------
assign idle                         = state == IDLE;

assign bus.address[ALIGN +: SPI_AW] = addr;
assign bus.address[0     +: ALIGN ] = '0;
assign bus.read                     = state == WAIT_READ_ACK;
assign bus.burstcount               = 1;
assign bus.byteenable               = '1;

assign load                         = empty && state == LOAD_RDATA;
assign header                       = wdata;

initial begin
    bus.write     = 0;
    bus.writedata = '0;
end

always_ff @(posedge clk) begin
    if (rst) begin
        state     <= IDLE;
        bus.write <= 0;
    end
    else begin
        state <= next;
        case (state)
            IDLE: begin
                cnt   <= '0;
                sent  <= '0;
                count <= header.count;
                addr  <= header.addr;
            end
            WAIT_WDATA: begin
                bus.write     <= stc;
                bus.writedata <= wdata;
            end
            WAIT_WRITE_ACK: begin
                if (~bus.waitrequest) begin
                    bus.write <= 0;
                    cnt       <= cnt  + count_t'(1);
                    addr      <= addr + addr_t'(1);
                    sent      <= sent + count_t'(1);
                end
            end
            WAIT_READ_ACK, WAIT_RDATA: begin
                if (bus.readdatavalid) begin
                    rdata <= bus.readdata;
                    cnt   <= cnt  + count_t'(1);
                    addr  <= addr + addr_t'(1);
                end            
            end
            default;
        endcase
        if (state != IDLE && stc) sent <= sent + count_t'(1);
    end
end

always_comb begin
    automatic logic ack    = ~bus.waitrequest;
    automatic logic rvalid =  bus.readdatavalid;
    if (rst) begin
        next = IDLE;
    end
    else begin
        case (state)
            //-------------------------------------------------------------------------
            IDLE: begin
                if (stc)      next = header.opcode == WRITE ? WAIT_WDATA : WAIT_READ_ACK;
                else          next = IDLE;
            end
            //-------------------------------------------------------------------------
            WAIT_WDATA:       next = stc ? WAIT_WRITE_ACK : WAIT_WDATA;
            //-------------------------------------------------------------------------
            WAIT_WRITE_ACK: begin
                if (ack)      next = cnt == count - 1 ? IDLE : WAIT_WDATA;
                else          next = WAIT_WRITE_ACK;
            end
            //-------------------------------------------------------------------------
            WAIT_READ_ACK:  begin
                if (rvalid)   next = WAIT_EMPTY;
                else if (ack) next = WAIT_RDATA;
                else          next = WAIT_READ_ACK;
            end
            //-------------------------------------------------------------------------
            WAIT_RDATA:       next = rvalid ? WAIT_EMPTY : WAIT_RDATA;
            //-------------------------------------------------------------------------
            WAIT_EMPTY:       next = empty ? LOAD_RDATA : WAIT_EMPTY;
            //-------------------------------------------------------------------------
            LOAD_RDATA: begin
                if (!empty)   next = cnt == count ? WAIT_LAST_SEND : WAIT_READ_ACK;
                else          next = LOAD_RDATA;
            end
            //-------------------------------------------------------------------------
            WAIT_LAST_SEND: next = (sent == count) ? IDLE : WAIT_LAST_SEND;
        endcase
    end
end

//------------------------------------------------
logic busy_r;
assign stc = ~busy & busy_r;

always_ff @(posedge clkout) busy_r <= busy;

//------------------------------------------------
//
//      Instances
//
hs_spi_slave_m
#(
    .DW        ( SPI_DW    ),
    .SPI_W     ( SPI_W     )
)
hs_spi_slave
(
    .clkout    ( clkout    ),
    .rst       ( rst       ),

    .load      ( load      ),
    .empty     ( empty     ),
    .busy      ( busy      ),
    .data_in   ( rdata     ),
    .data_out  ( wdata     ),

    .SCK       ( SCK       ),
    .CSn       ( CSn       ),
    .MISO      ( MISO      ),
    .MOSI      ( MOSI      )
);
//------------------------------------------------
endmodule : hs_spi_slave_avmm_m

//------------------------------------------------
`endif // __HS_SPI_AVMM_SV__
