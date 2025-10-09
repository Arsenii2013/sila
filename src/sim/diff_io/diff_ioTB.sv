module diff_ioTB();
    import diff_io_pkg::*;
    localparam unsigned OUTPUT_N = 16;

    localparam polarity_t BOARD_POLARITY [OUTPUT_N] = 
    '{POSITIVE, NEGATIVE, POSITIVE, NEGATIVE, 
      NEGATIVE, NEGATIVE, NEGATIVE, POSITIVE, 
      NEGATIVE, POSITIVE, NEGATIVE, NEGATIVE, 
      NEGATIVE, POSITIVE, NEGATIVE, NEGATIVE};

    localparam delay_adj_t BOARD_DELAY_ADJ [OUTPUT_N] = 
    '{PRECISE, PRECISE, PRECISE, PRECISE, 
      PRECISE, PRECISE, PRECISE, PRECISE, 
      COMMON,  COMMON,  COMMON,  COMMON, 
      COMMON,  COMMON,  COMMON,  COMMON};

    logic app_clk;
    logic idelayctrl_refclk;
    logic clear_clk;
    logic app_rst;

    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) APP_CLK_GEN (
        .sys_clk (app_clk)
    );
    sys_clk_gen
    #(
        .halfcycle (2500), // 5000 ps = 200 MHz
        .offset    (0)
    ) REFCLK_GEN (
        .sys_clk (idelayctrl_refclk)
    );

    assign clear_clk = app_clk;

    logic o1[OUTPUT_N];
    logic o2[OUTPUT_N];

    wire IO_P[OUTPUT_N];
    wire IO_N[OUTPUT_N];

    axi4_lite_if #(.DW(32), .AW(32)) mmr();

    diff_io #(
        .OUTPUT_N(OUTPUT_N),
        .STATIC_POLARITY(BOARD_POLARITY),
        .DELAY_ADJ(BOARD_DELAY_ADJ)
    ) DUT (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),
        .iodelayctrl_refclk(iodelayctrl_refclk),
        .mmr(mmr),

        .o1(o1),
        .o2(o2),

        .IO_P(IO_P),
        .IO_N(IO_N)
    );

    genvar bind_i;
    generate
    for(bind_i = 0; bind_i < OUTPUT_N; bind_i ++) begin : monitors
        bind DUT.outputs[bind_i].single_output_inst single_output_monitor #(
            .STATIC_DELAY_PS(STATIC_ODELAY_TAPS * 78ps),
            .STATIC_POLARITY(STATIC_POLARITY)
        ) monitor_i (
            .app_clk(app_clk),
            .clear_clk(clear_clk),
            .app_rst(app_rst),

            .o1(o1),
            .o2(o2),
            .i(i),
            .mode(mode),
            .polarity(polarity),
            .IO_P(IO_P),
            .IO_N(IO_N)
        );
        end
    endgenerate

    virtual_clock_if clk_if (app_clk, app_rst);
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    axi_driver driver;
    diff_io_generator generator;

    initial begin
        driver = new(clk_if, mmr, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0);
        reset();
        test_mode(TRI);
        test_mode(FORCE_CLEAR);
        test_mode(FORCE_SET);
        test_mode(GENERATOR);
        test_mode(GATE);
        test_mode(FLIP_FLOP);
        test_mode(CLK);
        $stop();
    end

    task reset();
        app_rst <= 1;
        repeat (10) @(posedge app_clk);
        app_rst <= 0;
    endtask

    task iterate_o1_o2();
        @(posedge app_clk);
        o1 <= '{default: 0};
        o2 <= '{default: 0};
        repeat (10) @(posedge app_clk);
        o1 <= '{default: 1};
        o2 <= '{default: 0};
        repeat (10) @(posedge app_clk);
        o1 <= '{default: 0};
        o2 <= '{default: 1};
        repeat (10) @(posedge app_clk);
        o1 <= '{default: 1};
        o2 <= '{default: 1};
        repeat (10) @(posedge app_clk);
        o1 <= '{default: 0};
        o2 <= '{default: 0};
        repeat (10) @(posedge app_clk);
    endtask

    task test_mode(mode_t _mode);
        generator.setup('{16{'{POSITIVE, _mode}}});
        driver.sync();
        iterate_o1_o2();
        generator.setup('{16{'{NEGATIVE, _mode}}});
        driver.sync();
        iterate_o1_o2();
    endtask
endmodule