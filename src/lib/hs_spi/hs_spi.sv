`ifndef __HS_SPI_SV__
`define __HS_SPI_SV__

//------------------------------------------------
module hs_spi_master_m
#(
    parameter DW    = 32,
    parameter SPI_W = 4
)
(
    input  logic              clk,
    input  logic              oclk,
    input  logic              rst,

    input  logic              load,
    output logic              empty,
    output logic              busy,
    input  logic [    DW-1:0] data_in,
    output logic [    DW-1:0] data_out,


    output logic              SCK,
    output logic              CSn,
    input  logic [ SPI_W-1:0] MISO,
    output logic [ SPI_W-1:0] MOSI
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Parameters
//
localparam SLICE_COUNT = DW / SPI_W;

//------------------------------------------------
//
//      Types
//
typedef logic [                 DW-1:0] data_t;
typedef logic [              SPI_W-1:0] slice_t;
typedef logic [$clog2(SLICE_COUNT)-1:0] slice_cnt_t;

typedef enum
{
    spiIDLE,
    spiTRANSFER
} state_t;

//------------------------------------------------
//
//      Objects
//
data_t      databuf  = 0;
data_t      tx_sr    = 0;
data_t      rx_sr    = 0;

state_t     tx_state = spiIDLE;
state_t     rx_state = spiIDLE;
slice_cnt_t cnt      = 0;

//------------------------------------------------
//
//      Logic
//
always_ff @(posedge clk) begin : spi_fsm
    if (rst) begin
        tx_state <= spiIDLE;
        CSn      <= 1;
        empty    <= 1;
        cnt      <= 0;
    end
    else begin
        if (empty & load) begin
            databuf <= data_in;
            empty   <= 0;
        end
        case (tx_state)
            spiIDLE: begin
                if (!empty) begin
                    CSn      <= 0;
                    empty    <= 1;
                    databuf  <= 0;
                    tx_state <= spiTRANSFER;
                end
            end
            spiTRANSFER: begin
                if (cnt == SLICE_COUNT-1) begin
                    cnt      <= 0;
                    CSn      <= 1;
                    tx_state <= spiIDLE;
                end
                else begin
                    cnt <= cnt + 1;
                end
            end
        endcase
    end
end

always_ff @(posedge clk) rx_state <= tx_state;

//------------------------------------------------
assign MOSI = tx_sr[DW-1:DW-SPI_W];

always_ff @(posedge clk) tx_sr <= tx_state == spiIDLE ? databuf : {tx_sr[DW-SPI_W-1:0], slice_t'(0)};
always_ff @(posedge clk) rx_sr <= {rx_sr[DW-SPI_W-1:0], MISO};

//------------------------------------------------
logic busy_next;

always_ff @(posedge clk) busy <= busy_next;

always_comb begin
    if (rst) begin
        busy_next = 0;
    end
    else begin
        case (busy)
            0: busy_next = tx_state == spiIDLE && !empty ? 1 : 0;
            1: busy_next = tx_state == spiIDLE && rx_state == spiIDLE ? 0 : 1;
        endcase
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        data_out <= 0;
    end
    else begin
        if (busy && busy_next == 0)
            data_out <= rx_sr;
    end 
end

//------------------------------------------------
//
//      Instances
//
ODDR SCK_OUT
(
   .Q  ( SCK  ),
   .C  ( oclk ),
   .CE ( 1    ),
   .D1 ( 1    ),
   .D2 ( 0    ),
   .R  ( 0    ),
   .S  ( 0    )
);

//------------------------------------------------
endmodule : hs_spi_master_m



//------------------------------------------------
module hs_spi_slave_m
#(
    parameter DW    = 32,
    parameter SPI_W = 4
)
(
    output logic              clkout,
    input  logic              rst,

    input  logic              load,
    output logic              empty,
    output logic              busy,
    input  logic [    DW-1:0] data_in,
    output logic [    DW-1:0] data_out,


    input  logic              SCK,
    input  logic              CSn,
    output logic [ SPI_W-1:0] MISO,
    input  logic [ SPI_W-1:0] MOSI
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Parameters
//
localparam TCO         = 12ns;
localparam SLICE_COUNT = DW / SPI_W;

//------------------------------------------------
//
//      Types
//
typedef logic [                 DW-1:0] data_t;
typedef logic [              SPI_W-1:0] slice_t;
typedef logic [$clog2(SLICE_COUNT)-1:0] slice_cnt_t;

//------------------------------------------------
//
//      Objects
//
data_t      databuf = 0;
data_t      tx_sr   = 0;
data_t      rx_sr   = 0;

logic       cs_n;
slice_cnt_t cnt     = 0;

//------------------------------------------------
//
//      Logic
//
assign clkout = SCK;

//------------------------------------------------
always_ff @(posedge SCK) cs_n <= CSn;

//------------------------------------------------
always_ff @(posedge SCK) begin : spi_fsm
    if (rst) begin
        cnt   <= 0;
        empty <= 1;
    end
    else begin
        if (empty & load) begin
            databuf <= data_in;
            empty   <= 0;
        end
        if (!cs_n) begin
            if (cnt == 0) begin
                databuf <= 0;
                empty   <= 1;
            end
            if (cnt == SLICE_COUNT-1) begin
                cnt <= 0;
            end
            else begin
                cnt <= cnt + 1;
            end
        end
        else begin
            cnt <= 0;
        end
    end
end

//------------------------------------------------
initial 
    MISO = 0;
always @(*) MISO <= #TCO tx_sr[DW-1:DW-SPI_W];

always_ff @(posedge SCK) tx_sr <= cs_n ? databuf : {tx_sr[DW-SPI_W-1:0], slice_t'(0)};
always_ff @(posedge SCK) rx_sr <= {rx_sr[DW-SPI_W-1:0], MOSI};

//------------------------------------------------
assign busy = ~cs_n;

always_ff @(posedge SCK) begin
    if (rst) begin
        data_out <= 0;
    end
    else begin
        if (!cs_n)
            data_out <= rx_sr;
    end
end

//------------------------------------------------
endmodule : hs_spi_slave_m

//------------------------------------------------
`endif // __HS_SPI_SV__