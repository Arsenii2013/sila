`timescale 1ns/1ps
`include "top.svh"

module topTB(

    );

    import evn::topo_id_t;
    import evn::TOPO_ID_LEVEL_W;
    import evn::TOPO_ID_MAX_LEVEL;
    typedef NetworkConfiguration::device_type_t device_type_t;
    localparam HSSR = NetworkConfiguration::HSSR;
    localparam HSSM = NetworkConfiguration::HSSM;
    typedef NetworkConfiguration::link_conf_t link_conf_t;

    parameter int         LINKS_SIZE          = 4;
    parameter link_conf_t LINKS [LINKS_SIZE]  = 
        '{'{'h0, 0ns, 0, HSSM, '{}}, '{'h1, 2700ns, 0, HSSR, '{}}, 
                                      '{'h2, 461ns,  0, HSSM, '{}}, '{'h22, 1241.45ns, 1, HSSR, '{}}};
    
    localparam realtime MAX_SUBTREE_DELAY = 1231.56ns * 2; // алгоритмически сложно считать

    function int count_device(link_conf_t conf [LINKS_SIZE], device_type_t search_type);
        int count;
        count = 0;
        foreach(conf[i]) begin
            if(conf[i].device_type == search_type)
                count ++;
        end
        return count;
    endfunction

    localparam int      HSSM_CNT            = count_device(LINKS, HSSM);
    localparam int      HSSR_CNT            = count_device(LINKS, HSSR);

    typedef link_conf_t link_conf_arr_t[LINKS_SIZE];
    function link_conf_arr_t compile_time_sort_by_topo_id(link_conf_arr_t conf);
        bit sorted;
        link_conf_t tmp;
        sorted = 0;
        while(!sorted) begin
            sorted = 1;
            for(int i = 0; i < LINKS_SIZE; i ++) begin
                if(conf[i + 1].topo_id == 0) break;
                if(conf[i].topo_id > conf[i + 1].topo_id) begin
                    sorted = 0;
                    tmp = conf[i + 1];
                    conf[i + 1] = conf[i];
                    conf[i] = tmp;
                end
            end
        end
        return conf;
    endfunction

    function link_conf_arr_t get_devices_on_level(link_conf_t conf [LINKS_SIZE], int level);
        link_conf_arr_t res;
        topo_id_t       mask;
        int             offset;
        int             res_ptr;
        res = '{default: '{'0, 0ns, 0, HSSR, '{}}};
        if(level == 0) begin 
            foreach(conf[i]) begin
                if (conf[i].topo_id == '0) begin
                    res[0] = conf[i];
                    break;
                end 
            end
        end else begin
            mask    = topo_id_t'('1) << ((level - 1) * TOPO_ID_LEVEL_W);
            offset  =                    (level - 1) * TOPO_ID_LEVEL_W;
            res_ptr = 0;
            foreach(conf[i]) begin
                if (((conf[i].topo_id & mask) >> offset) inside {['h1: 2 ** TOPO_ID_LEVEL_W]}) begin
                    res[res_ptr] = conf[i];
                    res_ptr++;
                end 
            end
            //res.sort(r) with (r.topo_id == 0 ? 2**TOPO_ID_LEVEL_W + 1 : r.topo_id);
            res = compile_time_sort_by_topo_id(res);
            
        end
        return res;
    endfunction

    typedef link_conf_t HSSR_link_conf_arr_t[HSSR_CNT];
    function HSSR_link_conf_arr_t get_all_HSSRs(link_conf_t conf [LINKS_SIZE]);
        link_conf_t     flat_confs [HSSR_CNT];
        link_conf_arr_t level_devices;
        int             level;
        int             src_ptr;
        int             dest_ptr;

        dest_ptr = 0;
        for(level = 0; level < TOPO_ID_MAX_LEVEL; level ++) begin
            level_devices = get_devices_on_level(conf, level);
            src_ptr = 0;
            while(level_devices[src_ptr] != '{'0, 0ns, 0, HSSR, '{}}) begin
                if(level_devices[src_ptr].device_type == HSSR) begin
                    flat_confs[dest_ptr] = level_devices[src_ptr];
                    dest_ptr++;
                end
                src_ptr++;
            end
        end
        return flat_confs;
    endfunction

    typedef link_conf_t HSSM_link_conf_arr_t[HSSM_CNT];
    function HSSM_link_conf_arr_t get_all_HSSMs(link_conf_t conf [LINKS_SIZE]);
        link_conf_t     flat_confs [HSSM_CNT];
        link_conf_arr_t level_devices;
        int             level;
        int             src_ptr;
        int             dest_ptr;

        dest_ptr = 0;
        for(level = 0; level < TOPO_ID_MAX_LEVEL; level ++) begin
            level_devices = get_devices_on_level(conf, level);
            src_ptr = 0;
            while(level_devices[src_ptr] != '{'0, 0ns, 0, HSSR, '{}}) begin
                if(level_devices[src_ptr].device_type == HSSM) begin
                    flat_confs[dest_ptr] = level_devices[src_ptr];
                    dest_ptr++;
                end
                src_ptr++;
            end
        end
        return flat_confs;
    endfunction

    function int get_level_up_ind(link_conf_t HSSM_confs[HSSM_CNT], link_conf_t conf);
        topo_id_t search_id;
        search_id = conf.topo_id >> TOPO_ID_LEVEL_W;
        foreach(HSSM_confs[i]) begin
            if(HSSM_confs[i].topo_id == search_id) 
                return i;
        end
        $error("HSSM not found!");
    endfunction
    function int get_level_up_port(link_conf_t conf);
        return conf.topo_id[TOPO_ID_LEVEL_W : 0] - 1;
    endfunction

    function int get_HSSR_ind(link_conf_t HSSR_confs[HSSR_CNT], link_conf_t conf);
        topo_id_t search_id;
        search_id = conf.topo_id;
        foreach(HSSR_confs[i]) begin
            if(HSSR_confs[i].topo_id == search_id) begin
                return i;
            end
        end
        $error("HSSR not found!");
    endfunction
    function int get_HSSM_ind(link_conf_t HSSM_confs[HSSM_CNT], link_conf_t conf);
        topo_id_t search_id;
        search_id = conf.topo_id;
        foreach(HSSM_confs[i]) begin
            if(HSSM_confs[i].topo_id == search_id) begin
                return i;
            end
        end
        $error("HSSM not found!");
    endfunction

    logic hssm_rx_n [HSSM_CNT][gtx::HSSM_PORT_N];
    logic hssm_rx_p [HSSM_CNT][gtx::HSSM_PORT_N];
    logic hssm_tx_n [HSSM_CNT][gtx::HSSM_PORT_N];
    logic hssm_tx_p [HSSM_CNT][gtx::HSSM_PORT_N];

    logic hssr_rx_n [HSSR_CNT][gtx::HSSR_PORT_N];
    logic hssr_rx_p [HSSR_CNT][gtx::HSSR_PORT_N];
    logic hssr_tx_n [HSSR_CNT][gtx::HSSR_PORT_N];
    logic hssr_tx_p [HSSR_CNT][gtx::HSSR_PORT_N];

    generate
    for(genvar i = 0; i < HSSM_CNT; i ++) begin : HSSM_insts
        HSSM_board_emulator #(
            .REFCLK_OFFSET(HSSM_confs[i].delay - $rtoi(HSSM_confs[i].delay / 5714ps) * 5714ps)
        ) HSSM_emulator_i (
            .sfp_rx_n(hssm_rx_n[i]),
            .sfp_rx_p(hssm_rx_p[i]),
            .sfp_tx_n(hssm_tx_n[i]),
            .sfp_tx_p(hssm_tx_p[i])
        );
    end
    for(genvar i = 0; i < HSSR_CNT; i ++) begin : HSSR_insts
        HSSR_board_emulator #(
            .REFCLK_OFFSET(HSSR_confs[i].delay - $rtoi(HSSM_confs[i].delay / 5714ps) * 5714ps)
        ) HSSR_emulator_i (
            .sfp_rx_n(hssr_rx_n[i]),
            .sfp_rx_p(hssr_rx_p[i]),
            .sfp_tx_n(hssr_tx_n[i]),
            .sfp_tx_p(hssr_tx_p[i])
        );
    end
    endgenerate

    parameter link_conf_t HSSM_confs [HSSM_CNT] = get_all_HSSMs(LINKS);
    parameter link_conf_t HSSR_confs [HSSR_CNT] = get_all_HSSRs(LINKS);

    generate
    for(genvar i = 0; i < HSSM_CNT; i ++) begin : HSSM_connections
        if(HSSM_confs[i].topo_id != '0) begin
            localparam up_ind  = get_level_up_ind(HSSM_confs, HSSM_confs[i]);
            localparam up_port = get_level_up_port(HSSM_confs[i]);
            link_emulator #(
                .PROPAGATION_DELAY(HSSM_confs[i].delay),
                .ASYMMETRIC(HSSM_confs[i].asymmetric_delay)
            ) link_emulator_i (
                .up_rx_n(hssm_rx_n[up_ind][up_port]),
                .up_rx_p(hssm_rx_p[up_ind][up_port]),
                .up_tx_n(hssm_tx_n[up_ind][up_port]),
                .up_tx_p(hssm_tx_p[up_ind][up_port]),
                .down_rx_n(hssm_rx_n[i][0]),
                .down_rx_p(hssm_rx_p[i][0]),
                .down_tx_n(hssm_tx_n[i][0]),
                .down_tx_p(hssm_tx_p[i][0])
            );
        end
    end
    for(genvar i = 0; i < HSSR_CNT; i ++) begin : HSSR_connections
        localparam up_ind  = get_level_up_ind(HSSM_confs, HSSR_confs[i]);
        localparam up_port = get_level_up_port(HSSR_confs[i]);
        link_emulator #(
            .PROPAGATION_DELAY(HSSR_confs[i].delay),
            .ASYMMETRIC(HSSR_confs[i].asymmetric_delay)
        ) link_emulator_i (
            .up_rx_n(hssm_rx_n[up_ind][up_port]),
            .up_rx_p(hssm_rx_p[up_ind][up_port]),
            .up_tx_n(hssm_tx_n[up_ind][up_port]),
            .up_tx_p(hssm_tx_p[up_ind][up_port]),
            .down_rx_n(hssr_rx_n[i][0]),
            .down_rx_p(hssr_rx_p[i][0]),
            .down_tx_n(hssr_tx_n[i][0]),
            .down_tx_p(hssr_tx_p[i][0])
        );
    end
    endgenerate

    NetworkConfiguration network_conf;
    initial begin
        link_conf_t links_confs [string];
        string module_name;
        int up_port;
        foreach(HSSR_confs[i]) begin
            module_name = $sformatf("topTB.HSSR_insts[%0d].HSSR_emulator_i.DUT_HSSR.PS_wrapper_i", i);
            links_confs[module_name] = HSSR_confs[i];
        end
        foreach(HSSM_confs[i]) begin
            module_name = $sformatf("topTB.HSSM_insts[%0d].HSSM_emulator_i.DUT_HSSM.PS_wrapper_i", i);
            links_confs[module_name] = HSSM_confs[i];
            foreach(LINKS[j]) begin
                if(LINKS[j].topo_id != 0 && get_level_up_ind(HSSM_confs, LINKS[j]) == i) begin
                    up_port = get_level_up_port(LINKS[j]);
                    links_confs[module_name].ports_used = {links_confs[module_name].ports_used, up_port};
                end
            end
        end
        network_conf = Globals::get_network_configuration();
        network_conf.set_links_conf(links_confs);
        network_conf.set_max_sub_delay(MAX_SUBTREE_DELAY);
        network_conf.finalize();
    end

    initial begin
        #500ms;
        $stop();
    end
endmodule

module HSSM_board_emulator #(
    parameter REFCLK_OFFSET = 0ns
)(
    input  logic       sfp_rx_n[gtx::HSSM_PORT_N],
    input  logic       sfp_rx_p[gtx::HSSM_PORT_N],
    output logic       sfp_tx_n[gtx::HSSM_PORT_N],
    output logic       sfp_tx_p[gtx::HSSM_PORT_N]
);
    logic     SYS_CLK;
    logic     REFCLK;
    logic     DM_CLK;
    sys_clk_gen #(
        .halfcycle (2500), // 2500 ps = 200 MHz on board system clock
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (SYS_CLK)
    );
    sys_clk_gen #(
        .halfcycle (2857), // 2857 ps = 175 MHz
        .offset    (REFCLK_OFFSET)
    ) REFCLK_gen (
        .sys_clk (REFCLK)
    );
    sys_clk_gen #(
        .halfcycle (2856), // 2857 ps = 175 MHz
        .offset    (0)
    ) DM_CLK_gen (
        .sys_clk (DM_CLK)
    );

    logic SFP_RX_LOSS[gtx::HSSM_PORT_N] = '{1, 1, 1, 1};
    generate
    for(genvar i = 0; i < gtx::HSSM_PORT_N; i ++) begin
        initial begin 
            repeat (5000) @(posedge sfp_rx_p[i]);
            SFP_RX_LOSS[i] <= 0;
        end
    end
    endgenerate

    logic PLL_LOL_N = 0;
    initial begin 
        repeat (5000) @(posedge REFCLK);
        PLL_LOL_N <= 1;
    end

    logic SFP_TX_N[gtx::HSSM_PORT_N], SFP_TX_P[gtx::HSSM_PORT_N];
    logic SFP_TX_DIS[gtx::HSSM_PORT_N];

    generate
    for(genvar i = 0; i < gtx::HSSM_PORT_N; i ++) begin
        assign sfp_tx_p[i] = SFP_TX_DIS[i] ? 0 : SFP_TX_P[i];
        assign sfp_tx_n[i] = SFP_TX_DIS[i] ? 0 : SFP_TX_N[i];
    end
    endgenerate

    topHSSM DUT_HSSM(
        .SYS_CLK_n(~SYS_CLK),
        .SYS_CLK_p(SYS_CLK),
        .REFCLK_n(~REFCLK),
        .REFCLK_p(REFCLK),

        .SFP_RX_N(sfp_rx_p),
        .SFP_RX_P(sfp_rx_n),
        .SFP_TX_N(SFP_TX_N),
        .SFP_TX_P(SFP_TX_P),
        .SFP_TX_DIS(SFP_TX_DIS),

        .SFP_RX_LOS(SFP_RX_LOSS),
        
        .DM_CLK_n(DM_CLK),
        .DM_CLK_p(~DM_CLK),

        .PLL_LOL_N(PLL_LOL_N)
    );
endmodule

module HSSR_board_emulator#(
    parameter REFCLK_OFFSET = 0ns
)(
    input  logic       sfp_rx_n[gtx::HSSR_PORT_N],
    input  logic       sfp_rx_p[gtx::HSSR_PORT_N],
    output logic       sfp_tx_n[gtx::HSSR_PORT_N],
    output logic       sfp_tx_p[gtx::HSSR_PORT_N],
    inout  logic       START[HSSR_board_pkg::START_N]
);
    import HSSR_board_pkg::START_N;
    import HSSR_board_pkg::START_POLARITY;
    import HSSR_board_pkg::START_MODES;
    import HSSR_board_pkg::polarity_t;
    import HSSR_board_pkg::POSITIVE;
    import HSSR_board_pkg::NEGATIVE;

    // On SOM clock generators
    logic      REFCLK_SFP;
    logic      SYS_CLK;
    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps = 175 MHz
        .offset    (REFCLK_OFFSET)
    ) REFCLK_SFP_gen (
        .sys_clk (REFCLK_SFP)
    );
    sys_clk_gen
    #(
        .halfcycle (2500), // 2500 ps = 200 MHz 
        .offset    (0)
    ) CLK_GEN1 (
        .sys_clk (SYS_CLK)
    );

    // MOU si570 si5344 si5342

    logic      MGTREFCLK;
    logic      DM_CLK;
    logic      DC_CLK;
    logic      FPGA_OUTCLK;
    logic      PLL1_LOL_N = 0;
    logic      PLL2_LOL_N = 0;
    // TODO simulate MGTREFCLK clock switch
    sys_clk_gen
    #(
        .halfcycle (2857), // 2857 ps = 125 MHz
        .offset    (0)
    ) MGTREFCLK_gen (
        .sys_clk (MGTREFCLK)
    );
    sys_clk_gen
    #(
        .halfcycle (2856), // 2857 ps = 125 MHz
        .offset    (0)
    ) DM_CLK_gen (
        .sys_clk (DM_CLK)
    );
    assign #1ns FPGA_OUTCLK = DC_CLK;
    initial begin 
        repeat (5000) @(posedge FPGA_OUTCLK);
        PLL1_LOL_N <= 1;
    end
    initial begin 
        repeat (5000) @(posedge MGTREFCLK);
        PLL2_LOL_N <= 1;
    end

    logic SFP_RX_LOSS[gtx::HSSR_PORT_N] = '{1};
    generate
    for(genvar i = 0; i < gtx::HSSR_PORT_N; i ++) begin
        initial begin 
            repeat (5000) @(posedge sfp_rx_p[i]);
            SFP_RX_LOSS[i] <= 0;
        end
    end
    endgenerate

    tri0 START_p[START_N];
    tri1 START_n[START_N];

    logic SER, SRCLK, RCLK;

    logic SFP_TX_N[gtx::HSSR_PORT_N], SFP_TX_P[gtx::HSSR_PORT_N];
    logic SFP_TX_DIS[gtx::HSSR_PORT_N];

    generate
    for(genvar i = 0; i < gtx::HSSR_PORT_N; i ++) begin
        assign sfp_tx_p[i] = SFP_TX_DIS[i] ? 0 : SFP_TX_P[i];
        assign sfp_tx_n[i] = SFP_TX_DIS[i] ? 0 : SFP_TX_N[i];
    end
    endgenerate

    topHSSR DUT_HSSR(
        .REFCLK_SFP_n(~REFCLK_SFP),
        .REFCLK_SFP_p(REFCLK_SFP),
        .MGTREFCLK_n(~MGTREFCLK),
        .MGTREFCLK_p(MGTREFCLK),

        .SYS_CLK_n(~SYS_CLK),
        .SYS_CLK_p(SYS_CLK),

        .DM_CLK_n(~DM_CLK),
        .DM_CLK_p(DM_CLK),
        .DC_CLK_p(DC_CLK),

        .SFP_RX_N(sfp_rx_p),
        .SFP_RX_P(sfp_rx_n),
        .SFP_TX_N(SFP_TX_N),
        .SFP_TX_P(SFP_TX_P),
        .SFP_TX_DIS(SFP_TX_DIS),
        .SFP_RX_LOS(SFP_RX_LOSS),
        .START_p(START_p),
        .START_n(START_n),
        .FPGA_OUTCLK_n(~FPGA_OUTCLK),
        .FPGA_OUTCLK_p(FPGA_OUTCLK),

        .PLL1_LOL_N(PLL1_LOL_N),
        .PLL2_LOL_N(PLL2_LOL_N),

        .SER(SER),
        .RCLK(RCLK),
        .SRCLK(SRCLK)
    );

    localparam int unsigned PRECISE_CNT   = 8;
    localparam int unsigned SN74HC595_CNT = PRECISE_CNT * diff_io_pkg::PRECISE_DELAY_ADJ_W / 8;

    logic [SN74HC595_CNT-1: 0][7: 0] sn74hc595_Q;
    logic [PRECISE_CNT  -1: 0][9: 0] mc100ep195B_D;
    assign mc100ep195B_D = sn74hc595_Q;

    logic SERS [SN74HC595_CNT];
    assign SERS[0] = SER;
    generate 
    for(genvar i = 0; i < SN74HC595_CNT; i ++) begin
        if(i != SN74HC595_CNT - 1) begin
            sn74hc595_emulator sn74hc595_emulator_inst(
                .Q(sn74hc595_Q[i]),
                .Q_H_backtick(SERS[i+1]),

                .SER(SERS[i]),
                .RCLK(RCLK),
                .SRCLK(SRCLK),
                .OE_N(0),
                .SRCLR_N(1)
            );
        end else begin
            sn74hc595_emulator sn74hc595_emulator_inst(
                .Q(sn74hc595_Q[i]),
                .SER(SERS[i]),
                .RCLK(RCLK),
                .SRCLK(SRCLK),
                .OE_N(0),
                .SRCLR_N(1)
            );
        end
    end
    endgenerate

    generate
    for(genvar i = 0; i < START_N; i ++) begin
        if(START_MODES[i] == diff_io_pkg::PRECISE) begin
            if(START_POLARITY[i] == diff_io_pkg::POSITIVE) begin
                mc100ep195b_emulator mc100ep195b_emulator_inst(
                    .D(mc100ep195B_D[i]),
                    .IN(START_p[i]),
                    .Q(START[i])
                );
            end else begin
                mc100ep195b_emulator mc100ep195b_emulator_inst(
                    .D(mc100ep195B_D[i]),
                    .IN(START_n[i]),
                    .Q(START[i])
                );
            end
        end else begin
            if(START_POLARITY[i] == diff_io_pkg::POSITIVE) begin
                assign START[i] = START_p[i];
            end else begin
                assign START[i] = START_n[i];
            end
        end

    end
    endgenerate

endmodule