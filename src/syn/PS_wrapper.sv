`include "axi4_lite_if.svh"
`include "topEVG.svh"

module PS_wrapper_sv #(
    parameter GP0_ADDR_W   = 32,
    parameter GP0_DATA_W   = 32,
    parameter MMR_DEV_CNT2 = 1,
    parameter SIM_DEVICE   = "EVG"
)
(
    `ifdef SYNTHESIS
    inout wire [14:0]  DDR_addr,
    inout wire [2:0]   DDR_ba,
    inout wire         DDR_cas_n,
    inout wire         DDR_ck_n,
    inout wire         DDR_ck_p,
    inout wire         DDR_cke,
    inout wire         DDR_cs_n,
    inout wire [3:0]   DDR_dm,
    inout wire [31:0]  DDR_dq,
    inout wire [3:0]   DDR_dqs_n,
    inout wire [3:0]   DDR_dqs_p,
    inout wire         DDR_odt,
    inout wire         DDR_ras_n,
    inout wire         DDR_reset_n,
    inout wire         DDR_we_n,
    inout wire         FIXED_IO_ddr_vrn,
    inout wire         FIXED_IO_ddr_vrp,
    inout wire [53:0]  FIXED_IO_mio,
    inout wire         FIXED_IO_ps_clk,
    inout wire         FIXED_IO_ps_porb,
    inout wire         FIXED_IO_ps_srstb,
    `endif //SYNTHESIS 

    output logic       peripheral_aresetn,
    output logic       peripheral_clock,
    output logic       peripheral_reset,
    input  logic       app_aresetn,
    input  logic       app_clk,
    axi4_lite_if.m     GP_0
   );

    localparam GP_0_BASE_ADDR = 'h4000_0000;
    logic [GP0_ADDR_W-1: 0] GP_0_araddr;
    logic [GP0_ADDR_W-1: 0] GP_0_awaddr;
    assign GP_0.araddr = GP_0_araddr - GP_0_BASE_ADDR;
    assign GP_0.awaddr = GP_0_awaddr - GP_0_BASE_ADDR;
   
    `ifdef SYNTHESIS
    PS PS_i   (
        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .GP_0_araddr(GP_0_araddr),
        .GP_0_arprot(GP_0.arprot),
        .GP_0_arready(GP_0.arready),
        .GP_0_arvalid(GP_0.arvalid),
        .GP_0_awaddr(GP_0_awaddr),
        .GP_0_awprot(GP_0.awprot),
        .GP_0_awready(GP_0.awready),
        .GP_0_awvalid(GP_0.awvalid),
        .GP_0_bready(GP_0.bready),
        .GP_0_bresp(GP_0.bresp),
        .GP_0_bvalid(GP_0.bvalid),
        .GP_0_rdata(GP_0.rdata),
        .GP_0_rready(GP_0.rready),
        .GP_0_rresp(GP_0.rresp),
        .GP_0_rvalid(GP_0.rvalid),
        .GP_0_wdata(GP_0.wdata),
        .GP_0_wready(GP_0.wready),
        .GP_0_wstrb(GP_0.wstrb),
        .GP_0_wvalid(GP_0.wvalid),

        .peripheral_aresetn(peripheral_aresetn),
        .peripheral_clock(peripheral_clock),
        .peripheral_reset(peripheral_reset),
        .app_aresetn(app_aresetn),
        .app_clk(app_clk)
    );
    `endif //SYNTHESIS 

    `ifndef SYNTHESIS
    sys_clk_gen
    #(
        .halfcycle (CLK_PRD / 2 * 1000), 
        .offset    (CLK_PRD / 4 * 1000) // for simulate async with PCIE clock signal
    ) CLK_GEN (
        .sys_clk (peripheral_clock)
    );

    initial begin
        peripheral_aresetn <= 0;
        peripheral_reset   <= 1;
        for(int i = 0; i < 500; i++) begin
            @(posedge peripheral_clock);
        end
        peripheral_aresetn <= 1;
        peripheral_reset   <= 0;
    end

    axi4_lite_if #(.DW(GP0_DATA_W), .AW(GP0_ADDR_W)) GP_0_iternal();
    assign GP_0_awaddr = GP_0_iternal.awaddr;
    assign GP_0.awprot = GP_0_iternal.awprot;
    assign GP_0.awvalid = GP_0_iternal.awvalid;
    assign GP_0_iternal.awready = GP_0.awready;
    assign GP_0.wdata = GP_0_iternal.wdata;
    assign GP_0.wstrb = GP_0_iternal.wstrb;
    assign GP_0.wvalid = GP_0_iternal.wvalid;
    assign GP_0_iternal.wready = GP_0.wready;
    assign GP_0_iternal.bresp = GP_0.bresp;
    assign GP_0_iternal.bvalid = GP_0.bvalid;
    assign GP_0.bready = GP_0_iternal.bready;
    assign GP_0_araddr = GP_0_iternal.araddr;
    assign GP_0.arprot = GP_0_iternal.arprot;
    assign GP_0.arvalid = GP_0_iternal.arvalid;
    assign GP_0_iternal.arready = GP_0.arready;
    assign GP_0_iternal.rdata = GP_0.rdata;
    assign GP_0_iternal.rresp = GP_0.rresp;
    assign GP_0_iternal.rvalid = GP_0.rvalid;
    assign GP_0.rready = GP_0_iternal.rready;

    axi_master axi_master(
        .aclk(app_clk),
        .aresetn(~app_aresetn),
        .axi(GP_0_iternal)
    );

    logic [31:0] status;
    logic [31:0] topo_id;
    logic [31:0] measured_delay;
    initial begin
        if(SIM_DEVICE == "EVG")
            EVG_test();
        else if(SIM_DEVICE == "EVR")
            EVR_test();
    end

    initial begin
        #500ms;
        $display("Timeout! Cant get FINE state in %t\n", $realtime);
        $stop();
    end
    `endif //SYNTHESIS 
    
    task automatic EVG_test();
        typedef logic [63: 0] uint64_t;
        localparam uint64_t SFP_CTRL_BASE_ADDR = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVG_axi_params::SFP_CONTROL;
        localparam uint64_t EVG1_BASE_ADDR     = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVG_axi_params::EVG1;

        $timeformat(-3, 5, " ms");

        @(posedge app_aresetn);
        @(posedge app_aresetn);
        #50us;
        axi_master.write(SFP_CTRL_BASE_ADDR + 'h10, 'h0);

        wait(DUT_EVG.evg1.delay_st == 5'h1);
        $display("EVG Get INITIAL state at %t\n", $realtime);
        #10us;
        axi_master.read(EVG1_BASE_ADDR + 'h00, status);
        axi_master.read(EVG1_BASE_ADDR + 'h10, topo_id);
        axi_master.read(EVG1_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(DUT_EVG.evg1.delay_st == 5'h3);
        $display("EVG Get ONE_CYCLE state at %t\n", $realtime);
        #10us;
        axi_master.read(EVG1_BASE_ADDR + 'h00, status);
        axi_master.read(EVG1_BASE_ADDR + 'h10, topo_id);
        axi_master.read(EVG1_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(DUT_EVG.evg1.delay_st == 5'h7);
        $display("EVG Get FINE state at %t\n", $realtime);
        #10us;
        axi_master.read(EVG1_BASE_ADDR + 'h00, status);
        axi_master.read(EVG1_BASE_ADDR + 'h10, topo_id);
        axi_master.read(EVG1_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);
        $stop();
    endtask

    task automatic EVR_test();
        typedef logic [63: 0] uint64_t;
        localparam uint64_t SFP_CTRL_BASE_ADDR = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVR_axi_params::SFP_CONTROL;
        localparam uint64_t EVR_BASE_ADDR      = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVR_axi_params::EVR;

        $timeformat(-3, 5, " ms");

        @(posedge app_aresetn);
        @(posedge app_aresetn);
        #50us;
        axi_master.write(SFP_CTRL_BASE_ADDR + 'h10, 'h0);

        wait(DUT_EVR.evr1.link_delay_st == 5'h1);
        $display("EVR Get INITIAL state at %t\n", $realtime);
        #10us;
        axi_master.read(EVR_BASE_ADDR + 'h00, status);
        axi_master.read(EVR_BASE_ADDR + 'h10, topo_id);
        axi_master.read(EVR_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(DUT_EVR.evr1.link_delay_st == 5'h3);
        $display("EVR Get ONE_CYCLE state at %t\n", $realtime);
        #10us;
        axi_master.read(EVR_BASE_ADDR + 'h00, status);
        axi_master.read(EVR_BASE_ADDR + 'h10, topo_id);
        axi_master.read(EVR_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(DUT_EVR.evr1.link_delay_st == 5'h7);
        $display("EVR Get FINE state at %t\n", $realtime);
        #10us;
        axi_master.read(EVR_BASE_ADDR + 'h00, status);
        axi_master.read(EVR_BASE_ADDR + 'h10, topo_id);
        axi_master.read(EVR_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);
        $stop();
    endtask
 endmodule