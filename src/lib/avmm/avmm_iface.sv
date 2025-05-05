`ifndef __AVMM_IFACE_SV__
`define __AVMM_IFACE_SV__

interface avmm_if #(
    parameter AW        = 16,
    parameter DW        = 64,
    parameter MAX_BURST = 1
);

localparam BCW = $clog2(MAX_BURST);

    logic [  AW-1:0] address;
    logic            read;
    logic            write;
    logic [   BCW:0] burstcount;
    logic [  DW-1:0] writedata;
    logic [DW/8-1:0] byteenable;
    logic            waitrequest;
    logic [  DW-1:0] readdata;
    logic            readdatavalid;
    
    modport master
    (
        output address,
        output read,	
        output write,
        output burstcount,
        output writedata,
        output byteenable,
        input  waitrequest,
        input  readdata,
        input  readdatavalid
    );
    
    modport slave
    (
        input  address,
        input  read,
        input  write,
        input  burstcount,
        input  writedata,
        input  byteenable,
        output waitrequest,
        output readdata,
        output readdatavalid
    );
endinterface // avmm_if

`endif // __AVMM_IFACE_SV__