//******************************************************************************
//*
//*      SPI 
//*
//*      Version 2.0
//*
//*      Copyright (c) 2004-2005, Harry E. Zhurov
//*
//*      $Revision: 77 $
//*      $Date:: 2010-08-25 12:19:39 #$
//*
//------------------------------------------------------------------------------

`timescale 1ns / 1ps


module ls_spi_master #(
                parameter PRESCALER   = 100, 
                parameter CPOL        = 0,
                parameter DATA_WIDTH  = 8,
                parameter T_SETUP     = 1
              )
(
    //----------------------------------
    //
    //    External interface
    //
    output logic  SCK,       // serial clock
    output logic  MOSI,      // serial data output
    input  wire   MISO,      // serial data input
       
    //----------------------------------
    //
    //    Internal interface
    //
    input  wire                     clk,       // system clock
    input  wire                     rst,       // system reset
                                
    input  wire                     enable,    // enable processing
    input  wire                     load,      // load data for shift out
    input  wire [DATA_WIDTH-1:0]    data_in,   // data to write out to output shift register
    output logic [DATA_WIDTH-1:0]   data_out,  // received data from serial input
    
    output logic                    busy,      // data register not empty or serial transfer is active
    output logic                    dre,       // data register empty
    output logic                    stc        // serial transfer is completed

);

//------------------------------------------------------------------------------
//
//    Objects
//

localparam CPHA       = 1;

localparam SCK_PERIOD = PRESCALER; // in clk ticks
localparam SCK_DRIVE  = T_SETUP;
localparam SCK_SAMPLE = SCK_PERIOD/2 + 1;
localparam SCK_STOP   = CPHA ? 0 : SCK_SAMPLE-1;

bit [$clog2(SCK_PERIOD)-1:0] SCK_cnt;
bit [        DATA_WIDTH-1:0] bufreg;
bit                         bufempty;
bit [        DATA_WIDTH-1:0] shiftreg;
bit [                   1:0] miso_sync;
bit [ $bits(DATA_WIDTH)-1:0] bitcnt;
bit                         ready;


//------------------------------------------------------------------------------
//
//    Logic
//

//assign SCK = SCK_cnt < SCK_PERIOD/2 ? CPOL : ~CPOL;

//------------------------------------------------------------------------------
//
//    SPI clock generation logic
//
always_ff @(posedge clk, posedge rst) begin
    if(rst) begin
        SCK_cnt <= SCK_STOP;
        SCK     <= CPOL;
    end
    else begin

        if( (!bufempty && ready && enable) || bitcnt || SCK_cnt != SCK_STOP ) begin
            SCK_cnt <= SCK_cnt + 1;
            if(SCK_cnt == SCK_PERIOD-1) begin
                SCK_cnt <= 0;
            end
        end

//      if( !busy ) begin
//          SCK_cnt <= SCK_SAMPLE;
//      end


        if(CPHA) begin
            SCK <= SCK_cnt >= SCK_DRIVE && SCK_cnt < SCK_SAMPLE ? ~CPOL : CPOL; 
        end
        else begin
            SCK <= SCK_cnt >= SCK_SAMPLE ? CPOL : ~CPOL; 
        end

    end
end

//------------------------------------------------------------------------------
//
//    Load and Shift logic
//
always_ff @(posedge clk) begin
    if(rst) begin
        bufreg   <= 0;
        bufempty <= 1;
        shiftreg <= 0;
        bitcnt   <= 0; 
        ready    <= 0;

        data_out <= 0;
    end
    else begin

        if(!ready) begin
            ready <= load;     // start processing
        end

        miso_sync[0] <= MISO;
        miso_sync[1] <= miso_sync[0];

        if(load) begin
            bufreg   <= data_in;
            bufempty <= 0;
        end

        case(SCK_cnt)
            //-------------------------------------
            1: begin 
                MOSI                     <= shiftreg[DATA_WIDTH-1];
                shiftreg[DATA_WIDTH-1:1] <= shiftreg[DATA_WIDTH-2:0];
            end
            //-------------------------------------
            SCK_SAMPLE: begin 
                //shiftreg[0] <= miso_sync[1];
                shiftreg[0] <= MISO;
            end
            //-------------------------------------
        endcase

        //if( CPHA ? SCK_cnt == SCK_SAMPLE : SCK_cnt == SCK_DRIVE ) begin
        if( SCK_cnt == SCK_STOP ) begin
            if(bitcnt) begin
                bitcnt <= bitcnt - 1;
            end
        end

        //if( !bitcnt && ( CPHA ? SCK_cnt == SCK_SAMPLE : SCK_cnt == SCK_DRIVE) ) begin
        if( !bitcnt && SCK_cnt == SCK_STOP ) begin
            data_out <= shiftreg;
            if(ready && enable) begin
                if( !bufempty ) begin
                    shiftreg <= bufreg;
                    bufempty <= 1;
                    bitcnt   <= DATA_WIDTH-1;
                end
            end
        end
    end
end

assign dre  = bufempty;
assign busy = bitcnt || !bufempty || SCK_cnt != SCK_STOP;

//------------------------------------------------------------------------------
pf_m
#(
    .WIDTH(1),
    .POR("OFF")
)
STC
(
    .clk ( clk    ),
    .in  ( !bitcnt && SCK_cnt == SCK_STOP  ),
    .out ( stc    )
);
//------------------------------------------------------------------------------

endmodule 

//------------------------------------------------------------------------------

