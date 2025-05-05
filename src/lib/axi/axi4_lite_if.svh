`ifndef _AXI_IF
`define _AXI_IF

interface axi4_lite_if #(
    parameter AW = 32,
    parameter DW = 64
);
    logic [AW-1  :0] araddr;
    logic [2     :0] arprot;
    logic            arready;
    logic            arvalid;
    logic [AW-1  :0] awaddr;
    logic [2     :0] awprot;
    logic            awready;
    logic            awvalid;
    logic            bready;
    logic [1     :0] bresp;
    logic            bvalid;
    logic [DW-1  :0] rdata;
    logic            rready;
    logic [1     :0] rresp;
    logic            rvalid;
    logic [DW-1  :0] wdata;
    logic            wready;
    logic [DW/8-1:0] wstrb;
    logic            wvalid;
    
    modport m(
        output awaddr,
        output awprot,
        output awvalid,
        input  awready,
        output wdata,
        output wstrb,
        output wvalid,
        input  wready,
        input  bresp,
        input  bvalid,
        output bready,
        output araddr,
        output arprot,
        output arvalid,
        input  arready,
        input  rdata,
        input  rresp,
        input  rvalid,
        output rready
    );
    
    modport s(
        input  awaddr,
        input  awprot,
        input  awvalid,
        output awready,
        input  wdata,
        input  wstrb,
        input  wvalid,
        output wready,
        output bresp,
        output bvalid,
        input  bready,
        input  araddr,
        input  arprot,
        input  arvalid,
        output arready,
        output rdata,
        output rresp,
        output rvalid,
        input  rready
    );
endinterface

`endif //_AXI_IF