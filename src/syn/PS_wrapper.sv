`include "axi4_lite_if.svh"

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

        .peripheral_aresetn(peripheral_aresetn),
        .peripheral_clock(peripheral_clock),
        .peripheral_reset(peripheral_reset),
        .app_aresetn(app_aresetn),
        .app_clk(app_clk)
    );
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

    axi4_lite_if #(.DW(GP0_DATA_W), .AW(GP0_ADDR_W)) GP_0_iternal();
    assign GP_0_awaddr = GP_0_iternal.awaddr;
    assign GP_0_slice.awprot = GP_0_iternal.awprot;
    assign GP_0_slice.awvalid = GP_0_iternal.awvalid;
    assign GP_0_iternal.awready = GP_0_slice.awready;
    assign GP_0_slice.wdata = GP_0_iternal.wdata;
    assign GP_0_slice.wstrb = GP_0_iternal.wstrb;
    assign GP_0_slice.wvalid = GP_0_iternal.wvalid;
    assign GP_0_iternal.wready = GP_0_slice.wready;
    assign GP_0_iternal.bresp = GP_0_slice.bresp;
    assign GP_0_iternal.bvalid = GP_0_slice.bvalid;
    assign GP_0_slice.bready = GP_0_iternal.bready;
    assign GP_0_araddr = GP_0_iternal.araddr;
    assign GP_0_slice.arprot = GP_0_iternal.arprot;
    assign GP_0_slice.arvalid = GP_0_iternal.arvalid;
    assign GP_0_iternal.arready = GP_0_slice.arready;
    assign GP_0_iternal.rdata = GP_0_slice.rdata;
    assign GP_0_iternal.rresp = GP_0_slice.rresp;
    assign GP_0_iternal.rvalid = GP_0_slice.rvalid;
    assign GP_0_slice.rready = GP_0_iternal.rready;

    virtual_clock_if clk_if (app_clk, peripheral_reset);
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    axi_driver #(
        .AW(axi_params::GP0_ADDR_W),
        .DW(axi_params::GP0_DATA_W)
    ) driver;
    axi_generator generic_generator;

    `define BASE_FROM_NUMBER(number) (GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * (number))

    evn::topo_id_t topo_id = '0;
    `define display_key $root.topTB.display_key
    genvar gen_i;
    generate 
    if(SIM_DEVICE == "EVG") begin
        typedef enum{
            GENERIC_RD_CH = 0,
            EVG_RD_CH,
            EV_SEQ_0_RD_CH,
            EV_SEQ_1_RD_CH,
            EV_SEQ_CTRL_RD_CH
        } rd_ch_enum;

        link_csr_generator #(
            .BASE(`BASE_FROM_NUMBER(EVG_axi_params::EVG))
        ) EVG_generator_i;

        for(gen_i = 0; gen_i < EVG_axi_params::EV_SEQ_N; gen_i++) begin : ev_seq_generator_i
            ev_seq_generator #(
                .BASE(`BASE_FROM_NUMBER(EVG_axi_params::EV_SEQ_0 + gen_i))
            ) inst;
        end

        ev_seq_ctrl_generator #(
            .BASE(`BASE_FROM_NUMBER(EVG_axi_params::EV_SEQ_CTRL)),
            .SEQ_N(EVG_axi_params::EV_SEQ_N)
        ) ev_seq_ctrl_generator_i;

        initial begin
            driver = new(clk_if, GP_0_iternal, req_mbx, resp_mbx);
            generic_generator = new(clk_if, req_mbx, resp_mbx, GENERIC_RD_CH);
            EVG_generator_i = new(clk_if, req_mbx, resp_mbx, EVG_RD_CH, $sformatf("Head EVG with topo id \t%x\t", topo_id));
            ev_seq_generator_i[0].inst = new(clk_if, req_mbx, resp_mbx, EV_SEQ_0_RD_CH);
            ev_seq_generator_i[1].inst = new(clk_if, req_mbx, resp_mbx, EV_SEQ_1_RD_CH);
            ev_seq_ctrl_generator_i = new(clk_if, req_mbx, resp_mbx, EV_SEQ_CTRL_RD_CH);

            wait(app_aresetn === 1);
            #50us;
            fork
            EVG_test();
            periodic_dump();
            join
        end

        localparam MAX_SUBTREE_DELAY  = $root.topTB.MAX_SUBTREE_DELAY;
        localparam int PORTS_USED [2] = '{0, 1};
        task automatic EVG_test();
            $timeformat(-3, 5, " ms");

            generic_generator.write(`BASE_FROM_NUMBER(EVG_axi_params::SFP_CONTROL) + 'h10, 'h0);
            ev_seq_generator_i[0].inst.write_seq('{
                '{0,    'h1},
                '{1,    'h2},
                '{2,    'h3},
                '{3,    'h4},
                '{10,   'h10},
                '{20,   'h20},
                '{40,   'h40},
                '{80,   'h80},
                '{8000, 'h1234},
                '{8001, event_generator_pkg::END_OF_SEQ}
            });
            ev_seq_ctrl_generator_i.setup('{
                '{event_generator_pkg::PROG, event_generator_pkg::RECYCLE},
                '{event_generator_pkg::PROG, event_generator_pkg::SINGLE}
            });
            driver.sync();

            ev_seq_ctrl_generator_i.enable(0);
            ev_seq_ctrl_generator_i.sw_trig(0);
            EVG_generator_i.set_tgt_delay((EVG_generator_i.time_to_delay_t(MAX_SUBTREE_DELAY) 
                                        & ~((1 << evn::DELAY_FRAC_W) - 1)) // зануляем дробную часть
                                        + (10 << evn::DELAY_FRAC_W));       // + 10 тактов

            EVG_generator_i.wait_delay_statuses(PORTS_USED, evn::INITIAL, 10us);
            #10us;
            `display_key.get();
            $display("EVG Head Get INITIAL state at %t\n", $realtime);
            EVG_generator_i.dump();
            `display_key.put();

            EVG_generator_i.wait_delay_statuses(PORTS_USED, evn::ONE_CYCLE, 1ms);
            #10us;
            `display_key.get();
            $display("EVG Head Get ONE_CYCLE state at %t\n", $realtime);
            EVG_generator_i.dump();
            `display_key.put();

            EVG_generator_i.wait_delay_statuses(PORTS_USED, evn::FINE, 100ms);
            #10us;
            `display_key.get();
            $display("EVG Head Get FINE state at %t\n", $realtime);
            EVG_generator_i.dump();
            `display_key.put();
        endtask

        task periodic_dump();
            forever begin
                `display_key.get();
                $display("Periodic Dump Head EVG");
                EVG_generator_i.dump();
                `display_key.put();
                #1ms;
            end
        endtask
    end


    if(SIM_DEVICE == "Fanout") begin
        typedef enum{
            GENERIC_RD_CH = 0,
            EVR_RD_CH
        } rd_ch_enum;

        link_csr_generator #(
            .BASE(`BASE_FROM_NUMBER(EVR_axi_params::EVR))
        ) Fanout_generator_i;

        initial begin
            driver = new(clk_if, GP_0_iternal, req_mbx, resp_mbx);
            generic_generator = new(clk_if, req_mbx, resp_mbx, GENERIC_RD_CH);

            Fanout_generator_i = new(clk_if, req_mbx, resp_mbx, EVR_RD_CH, $sformatf("Fanout with topo id \t%x\t", topo_id));

            wait(app_aresetn === 1);
            #50us;
            fork
            Fanout_test();
            periodic_dump();
            join
        end


        localparam int PORTS_USED [2] = '{0, 1};
        task automatic Fanout_test();
            $timeformat(-3, 5, " ms");

            generic_generator.write(`BASE_FROM_NUMBER(EVR_axi_params::SFP_CONTROL) + 'h10, 'b1110);
            Fanout_generator_i.wait_delay_status(0, evn::INITIAL, 10us);
            generic_generator.write(`BASE_FROM_NUMBER(EVR_axi_params::SFP_CONTROL) + 'h10, '0);

            Fanout_generator_i.wait_delay_statuses(PORTS_USED, evn::INITIAL, 10us);
            #10us;
            Fanout_generator_i.get_topo_id(topo_id);
            Fanout_generator_i.name = $sformatf("Fanout with topo id \t%x\t", topo_id);
            #10us;
            `display_key.get();
            $display("Get Fanout with topo id %x INITIAL state at %t\n", topo_id, $realtime);
            Fanout_generator_i.dump();
            `display_key.put();

            Fanout_generator_i.wait_delay_statuses(PORTS_USED, evn::ONE_CYCLE, 1ms);
            #10us;
            `display_key.get();
            $display("Get Fanout with topo id %x ONE_CYCLE state at %t\n", topo_id, $realtime);
            Fanout_generator_i.dump();
            `display_key.put();
            
            Fanout_generator_i.wait_delay_statuses(PORTS_USED, evn::FINE, 100ms);
            #10us;
            `display_key.get();
            $display("Get Fanout with topo id %x FINE state at %t\n", topo_id, $realtime);
            Fanout_generator_i.dump();
            `display_key.put();
        endtask

        task periodic_dump();
            forever begin
                `display_key.get();
                $display("Periodic Dump FANOUT with topo id %x \t", topo_id);
                Fanout_generator_i.dump();
                `display_key.put();
                #1ms;
            end
        endtask
    end

    if(SIM_DEVICE == "EVR") begin
        typedef enum{
            GENERIC_RD_CH = 0,
            EVR_RD_CH,
            SIG_GEN_RD_CH,
            EV_MAP_RD_CH
        } rd_ch_enum;

        link_csr_generator #(
            .BASE(`BASE_FROM_NUMBER(EVR_axi_params::EVR))
        ) EVR_generator_i;

        signal_generator_generator #(
            .BASE(`BASE_FROM_NUMBER(EVR_axi_params::SIG_GEN_CTRL)),
            .GEN_N(EVR_axi_params::SIG_GEN_N)
        ) signal_generator_generator_i;

        ev_map_generator #(
            .BASE(`BASE_FROM_NUMBER(EVR_axi_params::EV_MAP))
        ) ev_map_generator_i;


        initial begin
            driver = new(clk_if, GP_0_iternal, req_mbx, resp_mbx);
            generic_generator = new(clk_if, req_mbx, resp_mbx, GENERIC_RD_CH);

            EVR_generator_i = new(clk_if, req_mbx, resp_mbx, EVR_RD_CH, $sformatf("EVR with topo id \t%x\t", topo_id));
            signal_generator_generator_i = new(clk_if, req_mbx, resp_mbx, SIG_GEN_RD_CH);
            ev_map_generator_i = new(clk_if, req_mbx, resp_mbx, EV_MAP_RD_CH);

            wait(app_aresetn === 1);
            #50us;
            fork
            EVR_test();
            periodic_dump();
            join
        end


        task automatic EVR_test();
            $timeformat(-3, 5, " ms");

            generic_generator.write(`BASE_FROM_NUMBER(EVR_axi_params::SFP_CONTROL) + 'h10, 'h0);

            signal_generator_generator_i.set_cfg(0, '{'{default:1}, 0, signal_generator_pkg::GENERATOR, signal_generator_pkg::EVENT});
            signal_generator_generator_i.set_cfg(1, '{'{default:1}, 0, signal_generator_pkg::GENERATOR, signal_generator_pkg::EVENT});
            signal_generator_generator_i.set_delay(1, 100);
            signal_generator_generator_i.set_width(1, 100);
            signal_generator_generator_i.set_cfg(2, '{'{default:1}, 0, signal_generator_pkg::GENERATOR, signal_generator_pkg::PERIOD});
            signal_generator_generator_i.set_period(2, 10);
            signal_generator_generator_i.set_delay(2, 2);
            signal_generator_generator_i.set_width(2, 2);

            ev_map_generator_i.write_mapping('{
                '{ev: 'h1,    map: '{'{set  :1, default:0},     '{           default:0},    '{cnt_reset:1, default:0}}},
                '{ev: 'h20,   map: '{'{         default:0},     '{trigger:1, default:0}                              }},
                '{ev: 'h80,   map: '{'{clear:1, default:0}                                                           }},
                '{ev: 'h1234, map: '{'{         default:0},     '{trigger:1, default:0}                              }}
            });
            driver.sync();

            EVR_generator_i.wait_delay_status(0, evn::INITIAL, 10us);
            #10us;
            EVR_generator_i.enable_dc();
            EVR_generator_i.get_topo_id(topo_id);
            EVR_generator_i.name = $sformatf("EVR with topo id \t%x\t", topo_id);
            #10us;
            `display_key.get();
            $display("Get EVR with topo id %x INITIAL state at %t\n", topo_id, $realtime);
            EVR_generator_i.dump();
            `display_key.put();

            EVR_generator_i.wait_delay_status(0, evn::ONE_CYCLE, 1ms);
            #10us;
            `display_key.get();
            $display("Get EVR with topo id %x INITIAL state at %t\n", topo_id, $realtime);
            EVR_generator_i.dump();
            `display_key.put();
            
            EVR_generator_i.wait_delay_status(0, evn::FINE, 100ms);
            #10us;
            `display_key.get();
            $display("Get EVR with topo id %x INITIAL state at %t\n", topo_id, $realtime);
            EVR_generator_i.dump();
            `display_key.put();
        endtask

        task periodic_dump();
            forever begin
                `display_key.get();
                $display("Periodic Dump EVR with topo id %x", topo_id);
                EVR_generator_i.dump();
                `display_key.put();
                #1ms;
            end
        endtask
    end
    endgenerate

    initial begin
        #500ms;
        $display("Timeout! Cant get FINE state in %t\n", $realtime);
        $stop();
    end
    `endif //SYNTHESIS 
 endmodule
