`timescale 1ns/1ns

`include "axi4_lite_if.svh"

`define SLAVES 8

module axi_crossbarTB(
    );
    logic aresetn = 0;
    logic aclk    = 0;

    axi4_lite_if #(.AW(32), .DW(32)) m();
    axi4_lite_if #(.AW(32), .DW(32)) s[`SLAVES]();

    axi_transaction_generator #(.AW(32), .DW(32))
    generator (
        .bus(m),
        .aresetn(aresetn),
        .aclk(aclk)
    );
    axi_crossbar
    #(
        .N(`SLAVES),
        .AW(32),
        .DW(32)
    ) 
    DUT 
    (
        .aresetn(aresetn),
        .aclk(aclk),
        .m(m),
        .s(s)
    );

    genvar i;
    generate
        for (i=0; i<`SLAVES; i++) begin 
            mem_wrapper mem_i(
                .aresetn(aresetn),
                .aclk(aclk),
                .axi(s[i]),
                .offset(0)
            );
        end
    endgenerate

    initial begin 
        forever begin
            #10; 
            aclk = ~aclk;
        end 
    end
    initial begin
        aresetn = 0;
        #100ns;
        aresetn = 1;

        #10000000ns;
        $finish();
    end

endmodule : axi_crossbarTB


module axi_transaction_generator #(
    parameter AW        = 10,
    parameter DW        = 32
)
(
    axi4_lite_if.m    bus,

    input  logic      aresetn,
    input  logic      aclk
);

typedef logic [DW-1:0] data_t;
typedef logic [AW-1:0] addr_t;

task automatic read(input addr_t addr, output data_t data);
    begin

    logic [3:0] rresp;
    
    $display("[%t] : Read", $realtime);
    @(posedge aclk)
    bus.araddr  <= addr;
    bus.arvalid <= 1;
    bus.rready  <= 1;

    for(;;) begin
        @(posedge aclk)
        if(bus.arready)
            break;
    end
    bus.arvalid <= 0;

    for(;;) begin
        @(posedge aclk)
        if(bus.rvalid)
            break;
    end
    data        = bus.rdata;
    rresp       = bus.rresp;
    bus.rready  <= 0;

    if(rresp != 'b000)
        $display("RRESP isnt equal 0! RRESP = %x", rresp);

    $display("[%t] : Address: %x, Data: %x", $realtime, addr, data);
    end
endtask

task automatic write(input addr_t addr, input data_t data);
    begin

    logic [3:0] wresp;

    $display("[%t] : Write", $realtime);
    @(posedge aclk)
    bus.awaddr  <= addr;
    bus.wdata   <= data;
    bus.awvalid <= 1;
    bus.wvalid  <= 1;
    bus.wstrb   <= 'hFFFF;
    bus.bready  <= 1;

    for(;;) begin
        @(posedge aclk)
        if(bus.awready && bus.wready)
            break;
    end
    bus.awvalid <= 0;
    bus.wvalid  <= 0;

    for(;;) begin
        @(posedge aclk)
        if(bus.bvalid)
            break;
    end
    wresp       = bus.bresp;
    bus.rready  <= 0;

    if(wresp != 'b000)
        $display("BRESP isnt equal 0! BRESP = %x", wresp);

    $display("[%t] : Address: %x, Data: %x", $realtime, addr, data);
    end
endtask

//------------------------------------------------
//
//      Logic
//
localparam BASE      = $clog2(`SLAVES);
localparam SAW       = AW - BASE;

initial begin

    automatic data_t wdata;
    automatic data_t rdata;
    automatic int i = 0;
    automatic int j = 0;


    @(posedge aresetn)
    #100ns

    read(0 , rdata);
    write(2 ** SAW, 'hdead);
    write(2 * 2 ** SAW, 'hdead);
    read(0 , rdata);
    #100ns
    $stop();

    for (i = 0; i < `SLAVES; i++) begin
        for (j = 0; j < 256; j++) begin
            wdata = data_t'(i * 2 ** SAW + j);

            read(i * 2 ** SAW + j * 4, rdata);

            if (rdata != 0) begin
                $display("Error: wdata = 0x%x, rdata = 0x%x", wdata, rdata);
                $stop();
            end

            write(i * 2 ** SAW + j * 4, wdata);
            read(i * 2 ** SAW + j * 4, rdata);

            if (wdata != rdata) begin
                $display("Error: wdata = 0x%x, rdata = 0x%x", wdata, rdata);
                $stop();
            end
            else begin
                $display("wdata = 0x%x, rdata = 0x%x", wdata, rdata);
            end
        end
    end

    $display("Success");
    
    $stop();
end

//------------------------------------------------
endmodule : axi_transaction_generator
