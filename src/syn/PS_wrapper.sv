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

    localparam EV_N = 9;
    task automatic setup_event_generation();
        typedef logic [63: 0] uint64_t;
        localparam uint64_t SEQ_CTRL_BASE_ADDR = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVG_axi_params::EV_SEQ_CTRL;
        localparam uint64_t SEQ_0_BASE_ADDR = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVG_axi_params::EV_SEQ_0;
        write_seq(SEQ_0_BASE_ADDR, '{'h1, 'h2, 'h3, 'h4, 'h10, 'h20, 'h40, 'h80, 'h1234},
                                   '{  0,   1,   2,   3,   10,   20,   40,   80,   8000});
        axi_master.write(SEQ_CTRL_BASE_ADDR + 'h08, 'h1); // cr enable 
        axi_master.write(SEQ_CTRL_BASE_ADDR + 'h34, 'h2); // mode = RECYCLE
        axi_master.write(SEQ_CTRL_BASE_ADDR + 'h28, 'h4); // sq_cr sw trig
    endtask
    
    task automatic EVG_test();
        typedef logic [63: 0] uint64_t;
        localparam uint64_t SFP_CTRL_BASE_ADDR = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVG_axi_params::SFP_CONTROL;
        localparam uint64_t MASTER1_BASE_ADDR  = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVG_axi_params::MASTER1;

        $timeformat(-3, 5, " ms");

        @(posedge app_aresetn);
        @(posedge app_aresetn);
        #50us;
        axi_master.write(SFP_CTRL_BASE_ADDR + 'h10, 'h0);
        setup_event_generation();

        wait(DUT_EVG.link_master1.delay_st == 5'h1);

        $display("EVG Get INITIAL state at %t\n", $realtime);
        #10us;
        axi_master.read(MASTER1_BASE_ADDR + 'h00, status);
        axi_master.read(MASTER1_BASE_ADDR + 'h10, topo_id);
        axi_master.read(MASTER1_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(DUT_EVG.link_master1.delay_st == 5'h3);
        $display("EVG Get ONE_CYCLE state at %t\n", $realtime);
        #10us;
        axi_master.read(MASTER1_BASE_ADDR + 'h00, status);
        axi_master.read(MASTER1_BASE_ADDR + 'h10, topo_id);
        axi_master.read(MASTER1_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(DUT_EVG.link_master1.delay_st == 5'h7);
        $display("EVG Get FINE state at %t\n", $realtime);
        #10us;
        axi_master.read(MASTER1_BASE_ADDR + 'h00, status);
        axi_master.read(MASTER1_BASE_ADDR + 'h10, topo_id);
        axi_master.read(MASTER1_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);
        $stop();
    endtask

    task automatic setup_signal_generation();
        localparam longint unsigned EV_MAP_BASE_ADDR   = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVR_axi_params::EV_MAP;
        localparam longint unsigned GEN_CTRL_BASE_ADDR = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVR_axi_params::SIG_GEN_CTRL;
        setup_signal_generator(.base(GEN_CTRL_BASE_ADDR), .gen_number(0));
        setup_signal_generator(.base(GEN_CTRL_BASE_ADDR), .gen_number(1), .periodic(0), .delay(100), .width(1000));
        setup_signal_generator(.base(GEN_CTRL_BASE_ADDR), .gen_number(2), .periodic(1), .period(10), .delay(2), .width(2));

        reset_mapping();
        add_mapping(EV_MAP_BASE_ADDR, 'h1,    '{0: 4'b0001, 2: 4'b1000, default:4'b0});
        add_mapping(EV_MAP_BASE_ADDR, 'h20,   '{1: 4'b0100, default:4'b0});
        add_mapping(EV_MAP_BASE_ADDR, 'h80,   '{0: 4'b0010, default:4'b0});
        add_mapping(EV_MAP_BASE_ADDR, 'h1234, '{1: 4'b0100, default:4'b0});
    endtask

    task automatic EVR_test();
        typedef logic [63: 0] uint64_t;
        localparam uint64_t SFP_CTRL_BASE_ADDR = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVR_axi_params::SFP_CONTROL;
        localparam uint64_t SLAVE_BASE_ADDR      = GP_0_BASE_ADDR + 2**GP0_ADDR_W / MMR_DEV_CNT2 * EVR_axi_params::SLAVE;

        $timeformat(-3, 5, " ms");

        @(posedge app_aresetn);
        @(posedge app_aresetn);
        #50us;
        axi_master.write(SFP_CTRL_BASE_ADDR + 'h10, 'h0);
        setup_signal_generation();

        wait(DUT_EVR.link_slave1.link_delay_st == 5'h1);
        $display("EVR Get INITIAL state at %t\n", $realtime);
        #10us;
        axi_master.read(SLAVE_BASE_ADDR + 'h00, status);
        axi_master.read(SLAVE_BASE_ADDR + 'h10, topo_id);
        axi_master.read(SLAVE_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(DUT_EVR.link_slave1.link_delay_st == 5'h3);
        $display("EVR Get ONE_CYCLE state at %t\n", $realtime);
        #10us;
        axi_master.read(SLAVE_BASE_ADDR + 'h00, status);
        axi_master.read(SLAVE_BASE_ADDR + 'h10, topo_id);
        axi_master.read(SLAVE_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);

        wait(DUT_EVR.link_slave1.link_delay_st == 5'h7);
        $display("EVR Get FINE state at %t\n", $realtime);
        #10us;
        axi_master.read(SLAVE_BASE_ADDR + 'h00, status);
        axi_master.read(SLAVE_BASE_ADDR + 'h10, topo_id);
        axi_master.read(SLAVE_BASE_ADDR + 'h14, measured_delay);
        $display("status:\t %x", status);
        $display("topology ID:\t %x", topo_id);
        $display("link delay:\t %e", (measured_delay >> 16) / 175e6);
        $stop();
    endtask


    int entrys_num_SEQ = 0;
    logic [31:0] rd_timestamp_lsb;
    logic [31:0] rd_timestamp_msb;
    logic [31:0] rd_ev;
    logic [63:0] rd_timestamp_seq;
    logic [31:0] rd_ev_seq;

    task add_event(input logic [63: 0] base, input logic [63:0] timestamp, input logic [23:0] ev);
        @(posedge app_clk);
        axi_master.write(base + entrys_num_SEQ * 'h10 + 'h00, timestamp[31:0]);
        axi_master.write(base + entrys_num_SEQ * 'h10 + 'h04, timestamp[63:32]);
        axi_master.write(base + entrys_num_SEQ * 'h10 + 'h08, {8'h0, ev});
        entrys_num_SEQ <= entrys_num_SEQ + 1;
    endtask
    
    task add_end_of_sequency(input logic [63: 0] base, input logic [63:0] timestamp);
        @(posedge app_clk);
        add_event(base, timestamp, 'h50DEAD);
    endtask

    task reset_events();
        entrys_num_SEQ <= 0;
    endtask

    task read_event(input logic [63: 0] base, int entry, output logic [63:0] timestamp, output logic [23:0] ev);
        @(posedge app_clk);
        axi_master.read(base + entry * 'h10 + 'h00, rd_timestamp_lsb);
        axi_master.read(base + entry * 'h10 + 'h04, rd_timestamp_msb);
        axi_master.read(base + entry * 'h10 + 'h08, rd_ev);
        @(posedge app_clk);
        timestamp <= {rd_timestamp_msb, rd_timestamp_lsb};
        ev        <= rd_ev;
        @(posedge app_clk);
    endtask

    task write_seq(input logic [63: 0] base, logic [23:0] events [EV_N], logic [63:0] timestamps [EV_N]);
        begin
        reset_events();
        for (int i = 0; i < EV_N; i++) begin
            add_event(base, timestamps[i], events[i]);
        end
        add_end_of_sequency(base, timestamps[EV_N-1] + 1);
        #1us;
        for (int i = 0; i < 11; i++) begin
            read_event(base, i, rd_timestamp_seq, rd_ev_seq);
            if(rd_timestamp_seq != timestamps[i] || rd_ev_seq != events[i]) begin
                $display("error read timestamp : %016h, event : %08h, expect timestamp : %016h, event : %08h,", 
                        rd_timestamp_seq, rd_ev_seq, timestamps[i], events[i]);
                $stop();
            end
        end
        end
    endtask

    import EVR_axi_params::SIG_GEN_N;
    task setup_signal_generator(input longint unsigned base,       input int unsigned gen_number,     input logic periodic = 0,
                                input longint unsigned period = 0, input longint unsigned delay = 0,  input longint unsigned width = 0);

        axi_master.write(base + 'h10 + gen_number * 'h28 + 'hc, 'hff); // cr_c
        axi_master.write(base + 'h10 + gen_number * 'h28 + 'h8, {periodic ? signal_gen_ctrl_pkg::PERIOD : signal_gen_ctrl_pkg::EVENT, 
                                                                signal_gen_ctrl_pkg::GENERATOR,
                                                                5'b01111}); // all enable, pol normal
        axi_master.write(base + 'h10 + gen_number * 'h28 + 'h10, delay[31:0]);
        axi_master.write(base + 'h10 + gen_number * 'h28 + 'h14, delay[63:32]);
        axi_master.write(base + 'h10 + gen_number * 'h28 + 'h18, width[31:0]);
        axi_master.write(base + 'h10 + gen_number * 'h28 + 'h1c, width[63:32]);
        axi_master.write(base + 'h10 + gen_number * 'h28 + 'h20, period[31:0]);
        axi_master.write(base + 'h10 + gen_number * 'h28 + 'h24, period[63:32]);
    endtask

    int entrys_num_MAP = 0;
    logic [3:0] rd_func [SIG_GEN_N];
    logic [4 * SIG_GEN_N - 1: 0] func_flat;
    localparam SIG_GEN_N_MINUS_MAX_I = SIG_GEN_N <= 8  ? SIG_GEN_N * 4 :
                                       SIG_GEN_N <= 16 ? SIG_GEN_N * 4 - 32:
                                       SIG_GEN_N <= 24 ? SIG_GEN_N * 4 - 64:
                                       SIG_GEN_N * 4 - 96;

    task add_mapping(input longint unsigned base, input logic [23:0] ev, input logic [3:0] func [SIG_GEN_N]);
        @(posedge app_clk);
        axi_master.write(base + entrys_num_MAP * 'h10 + 'h00, ev);
        func_flat = {<<4{func}};
        for(int i = 0; i < 3; i ++) begin
            if(i * 32 + 32 < SIG_GEN_N * 4) begin
                axi_master.write(base + entrys_num_MAP * 'h10 + 'h04 + i * 'h04, func_flat[i * 32 +: 32]);
            end else if(i * 32 < SIG_GEN_N * 4) begin
                axi_master.write(base + entrys_num_MAP * 'h10 + 'h04 + i * 'h04, func_flat[i * 32 +: SIG_GEN_N_MINUS_MAX_I]);
            end
        end
        check_mapping(base, entrys_num_MAP, ev, func);
        entrys_num_MAP <= entrys_num_MAP + 1;
    endtask

    task reset_mapping();
        entrys_num_MAP <= 0;
    endtask

    task read_mapping(input longint unsigned base, int entry, output logic [23:0] ev, output logic [3:0] func [SIG_GEN_N]);
        @(posedge app_clk);
        axi_master.read(entry * 'h10 + 'h00, ev);
        for(int i = 0; i < 3; i ++) begin
            if(i * 32 + 32 < SIG_GEN_N * 4) begin
                axi_master.read(base + entry * 'h10 + 'h04 + i * 'h04, func_flat[i * 32 +: 32]);
            end else if(i * 32 < SIG_GEN_N * 4) begin
                axi_master.read(base + entry * 'h10 + 'h04 + i * 'h04, func_flat[i * 32 +: SIG_GEN_N_MINUS_MAX_I]);
            end
        end
        for(int i = 0; i < SIG_GEN_N; i ++) begin
            func[i] = func_flat[i * 4 +: 4];
        end
        @(posedge app_clk);
    endtask

    task check_mapping(input longint unsigned base, int entry, input logic [23:0] ev, input logic [3:0] func [SIG_GEN_N]);
        read_mapping(base, entry, rd_ev, rd_func);
        assert(rd_ev == ev);
        assert(rd_func == func);
    endtask

    `endif //SYNTHESIS 
 endmodule