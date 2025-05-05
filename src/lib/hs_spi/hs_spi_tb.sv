module hs_spi_tb;

//------------------------------------------------
`timescale 1ns / 1ps;

//------------------------------------------------
//
//      Parameters
//
localparam PRD          = 10ns;

localparam SPI_AXI_AW  = 10;
localparam SPI_AXI_DW  = 32;
localparam SPI_AVMM_AW  = 10;
localparam SPI_AVMM_DW  = 32;
localparam MAX_BURST    = 128;
localparam SPI_W        = 4;

//------------------------------------------------
//
//      Objects
//
logic             clk     = 1;
logic             oclk;
logic             rst     = 1;
logic             aresetn  = 0;
logic             clkout;

logic             sck;
logic             cs_n;
logic [SPI_W-1:0] mosi;
logic [SPI_W-1:0] miso;

axi4_lite_if #(
    .AW        ( SPI_AXI_AW  ),
    .DW        ( SPI_AXI_DW  )
) m_i();

avmm_if #(
    .AW        ( SPI_AVMM_AW ),
    .DW        ( SPI_AVMM_DW ),
    .MAX_BURST ( MAX_BURST   )
) s_i();

//------------------------------------------------
//
//      Logic
//
always #(PRD/2) clk <= ~clk;
assign          oclk = ~clk;

initial begin
    #20ns
    rst    = 0;
    aresetn = 1;
end

//------------------------------------------------
//
//      Instances
//
hs_spi_master_axi_m
#(
    .AW        ( SPI_AVMM_AW ),
    .DW        ( SPI_AVMM_DW ),
    .SPI_W     ( SPI_W       )
)
spi_master
(
    .aclk      ( clk         ),
    .oclk      ( oclk        ),
    .aresetn   ( aresetn     ),
    .bus_axi   ( m_i         ),
    .SCK       ( sck         ),
    .CSn       ( cs_n        ),
    .MISO      ( miso        ),
    .MOSI      ( mosi        )
);
//------------------------------------------------
hs_spi_slave_avmm_m
#(
    .AW        ( SPI_AVMM_AW ),
    .DW        ( SPI_AVMM_DW ),
    .SPI_W     ( SPI_W       ),
    .MAX_BURST ( MAX_BURST   )
)
spi_slave
(
    .clkout    ( clkout      ),
    .rst       ( rst         ),
    .bus       ( s_i         ),
    .SCK       ( sck         ),
    .CSn       ( cs_n        ),
    .MISO      ( miso        ),
    .MOSI      ( mosi        )
);
//------------------------------------------------
axi_transaction_generator
#(
)
axi_master
(
    .aresetn   ( aresetn     ),
    .aclk      ( clk         ),
    .bus       ( m_i         )
);
//------------------------------------------------
avmm_slave_stub #(
    .AW        ( SPI_AVMM_AW ),
    .DW        ( SPI_AVMM_DW ),
    .MAX_BURST ( MAX_BURST   )
)
avmm_slave
(
    .clk       ( clkout      ),
    .rst       ( rst         ),
    .bus       ( s_i         )
);
//------------------------------------------------
endmodule : hs_spi_tb


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
initial begin

    automatic data_t wdata;
    automatic data_t rdata;
    automatic int i = 0;

    @(posedge aresetn)
    #100ns
    
    for (i = 0; i < 2 ** AW; i++) begin
        wdata = data_t'(i);

        write(i, wdata);
        read(i, rdata);

        if (wdata != rdata) begin
            $display("Error: wdata = 0x%x, rdata = 0x%x", wdata, rdata);
            $stop();
        end
        else begin
            $display("wdata = 0x%x, rdata = 0x%x", wdata, rdata);
        end
    end

    $display("Success");
    
    #100ns
    $stop();
end

//------------------------------------------------
endmodule : axi_transaction_generator
