`include "axi4_lite_if.svh"
`include "top.svh"

module PS_wrapper_sv(
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
    axi4_lite_if.m     GP_0
   );
   
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
        .GP_0_araddr(GP_0.araddr),
        .GP_0_arprot(GP_0.arprot),
        .GP_0_arready(GP_0.arready),
        .GP_0_arvalid(GP_0.arvalid),
        .GP_0_awaddr(GP_0.awaddr),
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
        .peripheral_reset(peripheral_reset)
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
    `endif //SYNTHESIS 
        
 endmodule