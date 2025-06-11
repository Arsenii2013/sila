`ifndef _AXI_STREAM_IF
`define _AXI_STREAM_IF

interface axi_stream_if #(
    parameter DW = 64
);
    logic [DW-1  :0] tdata;
    logic            tvalid;
    logic            tready;
    
    modport m(
        output tdata,
        output tvalid,
        input  tready
    );
    
    modport s(
        input  tdata,
        input  tvalid,
        output tready
    );
endinterface

`endif //_AXI_STREAM_IF