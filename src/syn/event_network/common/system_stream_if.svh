`ifndef _SYS_STREAM_
`define _SYS_STREAM_

interface system_stream_if #(
    parameter DW = 64
);
    logic [DW-1  :0] tdata;
    logic [DW/8-1:0] tisk;
    logic            tvalid;
    logic            tready;
    
    modport m(
        output tdata,
        output tisk,
        output tvalid,
        input  tready
    );
    
    modport s(
        input  tdata,
        input  tisk,
        input  tvalid,
        output tready
    );
endinterface

`endif //_SYS_STREAM_ 