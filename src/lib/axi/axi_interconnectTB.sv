`timescale 1ns/1ns

`include "axi4_lite_if.svh"

module axi_interconnectTB(
    );
    logic aresetn = 0;
    logic aclk    = 0;

    axi4_lite_if #(.AW(32), .DW(32)) m1();
    axi4_lite_if #(.AW(32), .DW(32)) m2();
    axi4_lite_if #(.AW(32), .DW(32)) s();

    axi_transaction_generator1 #(.AW(32), .DW(32))
    master1 (
        .bus(m1),
        .aresetn(aresetn),
        .aclk(aclk)
    );

    axi_transaction_generator2 #(.AW(32), .DW(32))
    master2 (
        .bus(m2),
        .aresetn(aresetn),
        .aclk(aclk)
    );

    axi_interconnect
    #(
        .AW(32),
        .DW(32)
    ) 
    DUT 
    (
        .aresetn(aresetn),
        .aclk(aclk),
        .m1(m1),
        .m2(m2),
        .s(s)
    );

    mem_wrapper mem_i(
        .aresetn(aresetn),
        .aclk(aclk),
        .axi(s)
    );

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

endmodule : axi_interconnectTB


module axi_transaction_generator1 #(
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

initial begin

    automatic data_t wdata;
    automatic data_t rdata;
    automatic int i = 0;
    automatic int j = 0;


    @(posedge aresetn)
    #100ns

    for (j = 0; j < 256; j++) begin
        wdata = data_t'(j);

        write(j * 4, wdata);
        
        if (rdata != wdata) begin
            $display("Error: wdata = 0x%x, rdata = 0x%x", wdata, rdata);
            $stop();
        end
    end

    $display("Success");
    
    //$stop();
end
endmodule : axi_transaction_generator1


module axi_transaction_generator2 #(
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

initial begin

    automatic data_t wdata;
    automatic data_t rdata;
    automatic int i = 0;
    automatic int j = 0;


    @(posedge aresetn)
    #100ns;
    #100ns;

    
    for (j = 0; j < 256; j++) begin
        wdata = data_t'(j);

        read(j * 4, rdata);

        if (rdata != wdata) begin
            $display("Error: wdata = 0x%x, rdata = 0x%x", wdata, rdata);
            $stop();
        end
    end

    $display("Success");
    
    $stop();
end
endmodule : axi_transaction_generator2