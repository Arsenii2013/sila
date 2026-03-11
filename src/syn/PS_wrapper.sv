`include "axi4_lite_if.svh"

interface EMIO_tri_state_if;
    logic i;
    logic o;
    logic t;

    modport in(
        output i,
        input  o,
        input  t
    );
    modport out(
        input  i,
        output o,
        output t
    );
endinterface

module PS_wrapper_sv #(
    parameter GP0_ADDR_W   = 32,
    parameter GP0_DATA_W   = 32,
    parameter MMR_DEV_CNT2 = 1,
    parameter DEVICE       = "HSSM"
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

    EMIO_tri_state_if.out   EMIO_0[emio_params::EMIO_0_WIDTH],
    axi4_lite_if.m          GP_0,
    i2c_tri_state_if.master I2C_0,
    input  logic            UART_1_rx, 
    output logic            UART_1_tx
   );
    axi4_lite_if #(.DW(GP0_DATA_W), .AW(GP0_ADDR_W)) GP_0_slice();

    axi_register_slice_wrapper axi_register_slice( 
        .aclk(app_clk),
        .aresetn(app_aresetn),
        .s_axi(GP_0_slice),
        .m_axi(GP_0)
    );

    localparam GP_0_BASE_ADDR = 'h4000_0000;
    logic [GP0_ADDR_W-1: 0] GP_0_araddr;
    logic [GP0_ADDR_W-1: 0] GP_0_awaddr;
    assign GP_0_slice.araddr = GP_0_araddr - GP_0_BASE_ADDR;
    assign GP_0_slice.awaddr = GP_0_awaddr - GP_0_BASE_ADDR;
   
    `ifdef SYNTHESIS
    localparam EMIO_N = emio_params::EMIO_0_WIDTH;
    logic [EMIO_N-1: 0] EMIO_0_i;
    logic [EMIO_N-1: 0] EMIO_0_o;
    logic [EMIO_N-1: 0] EMIO_0_t;

    generate 
    for( genvar i = 0; i < EMIO_N; i++) begin
        assign EMIO_0_i[i]  = EMIO_0[i].i;
        assign EMIO_0[i].o  = EMIO_0_o[i];
        assign EMIO_0[i].t  = EMIO_0_t[i];
    end
    endgenerate

    generate 
    if(DEVICE == "HSSR") begin
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
            .GP_0_arprot(GP_0_slice.arprot),
            .GP_0_arready(GP_0_slice.arready),
            .GP_0_arvalid(GP_0_slice.arvalid),
            .GP_0_awaddr(GP_0_awaddr),
            .GP_0_awprot(GP_0_slice.awprot),
            .GP_0_awready(GP_0_slice.awready),
            .GP_0_awvalid(GP_0_slice.awvalid),
            .GP_0_bready(GP_0_slice.bready),
            .GP_0_bresp(GP_0_slice.bresp),
            .GP_0_bvalid(GP_0_slice.bvalid),
            .GP_0_rdata(GP_0_slice.rdata),
            .GP_0_rready(GP_0_slice.rready),
            .GP_0_rresp(GP_0_slice.rresp),
            .GP_0_rvalid(GP_0_slice.rvalid),
            .GP_0_wdata(GP_0_slice.wdata),
            .GP_0_wready(GP_0_slice.wready),
            .GP_0_wstrb(GP_0_slice.wstrb),
            .GP_0_wvalid(GP_0_slice.wvalid),

            .EMIO_0_tri_i(EMIO_0_i),
            .EMIO_0_tri_o(EMIO_0_o),
            .EMIO_0_tri_t(EMIO_0_t),

            .I2C_0_scl_i(I2C_0.scl_i),
            .I2C_0_scl_o(I2C_0.scl_o),
            .I2C_0_scl_t(I2C_0.scl_t),
            .I2C_0_sda_i(I2C_0.sda_i),
            .I2C_0_sda_o(I2C_0.sda_o),
            .I2C_0_sda_t(I2C_0.sda_t),

            .peripheral_aresetn(peripheral_aresetn),
            .peripheral_clock(peripheral_clock),
            .peripheral_reset(peripheral_reset),
            .app_aresetn(app_aresetn),
            .app_clk(app_clk)
        );
    end 
    else if(DEVICE == "HSSM") begin
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
            .GP_0_arprot(GP_0_slice.arprot),
            .GP_0_arready(GP_0_slice.arready),
            .GP_0_arvalid(GP_0_slice.arvalid),
            .GP_0_awaddr(GP_0_awaddr),
            .GP_0_awprot(GP_0_slice.awprot),
            .GP_0_awready(GP_0_slice.awready),
            .GP_0_awvalid(GP_0_slice.awvalid),
            .GP_0_bready(GP_0_slice.bready),
            .GP_0_bresp(GP_0_slice.bresp),
            .GP_0_bvalid(GP_0_slice.bvalid),
            .GP_0_rdata(GP_0_slice.rdata),
            .GP_0_rready(GP_0_slice.rready),
            .GP_0_rresp(GP_0_slice.rresp),
            .GP_0_rvalid(GP_0_slice.rvalid),
            .GP_0_wdata(GP_0_slice.wdata),
            .GP_0_wready(GP_0_slice.wready),
            .GP_0_wstrb(GP_0_slice.wstrb),
            .GP_0_wvalid(GP_0_slice.wvalid),

            .EMIO_0_tri_i(EMIO_0_i),
            .EMIO_0_tri_o(EMIO_0_o),
            .EMIO_0_tri_t(EMIO_0_t),

            .I2C_0_scl_i(I2C_0.scl_i),
            .I2C_0_scl_o(I2C_0.scl_o),
            .I2C_0_scl_t(I2C_0.scl_t),
            .I2C_0_sda_i(I2C_0.sda_i),
            .I2C_0_sda_o(I2C_0.sda_o),
            .I2C_0_sda_t(I2C_0.sda_t),

            .UART_1_rxd(UART_1_rx),
            .UART_1_txd(UART_1_tx),

            .peripheral_aresetn(peripheral_aresetn),
            .peripheral_clock(peripheral_clock),
            .peripheral_reset(peripheral_reset),
            .app_aresetn(app_aresetn),
            .app_clk(app_clk)
        );
    end
    endgenerate
    `endif //SYNTHESIS 

    `ifndef SYNTHESIS
    localparam CLK_PRD = 8;
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

    axi4_lite_if #(.DW(GP0_DATA_W), .AW(GP0_ADDR_W)) GP_0_internal();
    assign GP_0_awaddr = GP_0_internal.awaddr;
    assign GP_0_slice.awprot = GP_0_internal.awprot;
    assign GP_0_slice.awvalid = GP_0_internal.awvalid;
    assign GP_0_internal.awready = GP_0_slice.awready;
    assign GP_0_slice.wdata = GP_0_internal.wdata;
    assign GP_0_slice.wstrb = GP_0_internal.wstrb;
    assign GP_0_slice.wvalid = GP_0_internal.wvalid;
    assign GP_0_internal.wready = GP_0_slice.wready;
    assign GP_0_internal.bresp = GP_0_slice.bresp;
    assign GP_0_internal.bvalid = GP_0_slice.bvalid;
    assign GP_0_slice.bready = GP_0_internal.bready;
    assign GP_0_araddr = GP_0_internal.araddr;
    assign GP_0_slice.arprot = GP_0_internal.arprot;
    assign GP_0_slice.arvalid = GP_0_internal.arvalid;
    assign GP_0_internal.arready = GP_0_slice.arready;
    assign GP_0_internal.rdata = GP_0_slice.rdata;
    assign GP_0_internal.rresp = GP_0_slice.rresp;
    assign GP_0_internal.rvalid = GP_0_slice.rvalid;
    assign GP_0_slice.rready = GP_0_internal.rready;

    virtual_clock_if clk_if (app_clk, peripheral_reset);

    i2c_driver I2C_0_driver(
        .clk(peripheral_clock),
        .I2C(I2C_0)
    );

    typedef Tester #(.GP_0_BASE_ADDR(32'h4000_0000))     TesterParametrized;
    typedef HSSRTester #(.GP_0_BASE_ADDR(32'h4000_0000)) HSSRTesterParametrized;
    typedef HSSMTester #(.GP_0_BASE_ADDR(32'h4000_0000)) HSSMTesterParametrized;

    TesterParametrized tester;
    HSSRTesterParametrized hssr_tester;
    HSSMTesterParametrized hssm_tester;

    TesterParametrized::device_type_t device_type;
    initial begin
        tester = new(clk_if, GP_0_internal, $sformatf("%m"));
        wait(app_aresetn === 1);
        #1us;
        tester.get_device_type(device_type);
        tester = null;
        case (device_type)
        TesterParametrized::HSSR : begin
            hssr_tester = new(clk_if, GP_0_internal, $sformatf("%m"));
            tester = hssr_tester;
        end
        TesterParametrized::HSSM :begin
            hssm_tester = new(clk_if, GP_0_internal, $sformatf("%m"));
            tester = hssm_tester;
        end
        endcase
        tester.run();
    end

    initial begin
        wait(app_aresetn === 1);
        #10us;
        forever begin
            for(int i = 0; i < 5; i ++) begin
                tester.select_I2C_mux(TesterParametrized::i2c_mux_sel_t'(i));
                repeat(1) I2C_0_driver.write($urandom, $urandom);
            end
        end
    end

    generate
    if(DEVICE == "HSSM") begin
        initial begin
            forever begin
                UART_1_tx = $random;
                #1us;
            end
        end
    end
    endgenerate

    initial begin
        #500ms;
        $display("Timeout! Cant get FINE state in %t\n", $realtime);
        $stop();
    end
    `endif //SYNTHESIS 
 endmodule

module i2c_driver(
    input  logic            clk,
    i2c_tri_state_if.master I2C
);

    initial begin
        I2C.scl_o = 0;
        I2C.sda_o = 0;
        I2C.scl_t = 1;
        I2C.sda_t = 1;
    end

    task tx_bit(bit b);
        I2C.sda_t <= !b;
        repeat (50) @(posedge clk);
        I2C.scl_t <= 1;
        repeat (50) @(posedge clk);
        I2C.scl_t <= 0;
    endtask

    task rx_bit(output logic b);
        I2C.sda_t <= 1;
        repeat (50) @(posedge clk);
        I2C.scl_t <= 1;
        repeat (25) @(posedge clk);
        b <= I2C.sda_i;
        repeat (25) @(posedge clk);
        I2C.scl_t <= 0;
    endtask

    task write(bit [6:0] addr, bit [7:0] data);
        bit [6:0] addr_reg;
        bit [7:0] data_reg;
        bit       ack;

        @(posedge clk);
        addr_reg    <= addr;
        data_reg    <= data;

        @(posedge clk);
        I2C.sda_t <= 0;
        repeat (50) @(posedge clk);
        I2C.scl_t <= 0;
        repeat (50) @(posedge clk);
        
        repeat (7) begin
            tx_bit(addr_reg);
            addr_reg = addr_reg >> 1;
        end
        tx_bit(1);
        rx_bit(ack);
        repeat (8) begin
            tx_bit(data_reg);
            data_reg = data_reg >> 1;
        end
        rx_bit(ack);

        I2C.scl_t <= 1;
        repeat (50) @(posedge clk);
        I2C.sda_t <= 1;
        repeat (50) @(posedge clk);
    endtask

endmodule