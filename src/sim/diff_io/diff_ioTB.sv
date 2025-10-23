module diff_ioTB();
    import diff_io_pkg::*;
    localparam unsigned OUTPUT_N = 16;

    localparam polarity_t BOARD_POLARITY [OUTPUT_N] = 
    '{POSITIVE, NEGATIVE, POSITIVE, NEGATIVE, 
      NEGATIVE, NEGATIVE, NEGATIVE, POSITIVE, 
      NEGATIVE, POSITIVE, NEGATIVE, NEGATIVE, 
      NEGATIVE, POSITIVE, NEGATIVE, NEGATIVE};

    localparam diff_io_mode_t DIFF_IO_MODES [OUTPUT_N] = 
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
    wire lemo[OUTPUT_N];

    logic SER, SRCLK, RCLK;

    axi4_lite_if #(.DW(32), .AW(32)) mmr();

    diff_io #(
        .OUTPUT_N(OUTPUT_N),
        .STATIC_POLARITY(BOARD_POLARITY),
        .DIFF_IO_MODES(DIFF_IO_MODES)
    ) DUT (
        .app_clk(app_clk),
        .clear_clk(clear_clk),
        .app_rst(app_rst),
        .iodelayctrl_refclk(iodelayctrl_refclk),
        .mmr(mmr),

        .o1(o1),
        .o2(o2),

        .IO_P(IO_P),
        .IO_N(IO_N),

        .SER(SER),
        .SRCLK(SRCLK),
        .RCLK(RCLK)
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

    diff_io_board_emulator #(
        .OUTPUT_N(OUTPUT_N),
        .POLARITY(BOARD_POLARITY),
        .MODES(DIFF_IO_MODES)
    ) diff_io_board_inst (
        .FPGA_IO_P(IO_P),
        .FPGA_IO_N(IO_N),
        .lemo_output(lemo),

        .SER(SER),
        .SRCLK(SRCLK),
        .RCLK(RCLK)
    );

    delay_adj_checker #(
        .OUTPUT_N(OUTPUT_N),
        .POLARITY(BOARD_POLARITY)
    ) delay_adj_checker_inst (
        .lemo_output(lemo)
    );

    virtual_clock_if clk_if (app_clk, app_rst);
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    axi_driver driver;
    diff_io_generator generator;

    initial begin
        driver = new(clk_if, mmr, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0);
        $timeformat(-9 , 3, " ns", 10);
        reset();
        TestModes();
        TestDelayAdj();
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

    task pulse_o1();
        @(posedge app_clk);
        o1 <= '{default: 0};
        o2 <= '{default: 0};
        repeat (10) @(posedge app_clk);
        o1 <= '{default: 1};
        o2 <= '{default: 0};
        repeat (10) @(posedge app_clk);
        o1 <= '{default: 0};
        o2 <= '{default: 0};
        repeat (10) @(posedge app_clk);
    endtask

    task TestModes();
        test_mode(TRI);
        test_mode(FORCE_CLEAR);
        test_mode(FORCE_SET);
        test_mode(GENERATOR);
        test_mode(GATE);
        test_mode(FLIP_FLOP);
        test_mode(CLK);
    endtask

    task test_mode(mode_t _mode);
        for(int i = 0; i < OUTPUT_N; i ++)
            generator.set_cfg(i, '{POSITIVE, _mode});
        driver.sync();
        iterate_o1_o2();
        for(int i = 0; i < OUTPUT_N; i ++)
            generator.set_cfg(i, '{NEGATIVE, _mode});
        driver.sync();
        iterate_o1_o2();
    endtask

    task TestDelayAdj();
        test_delay_adj('{OUTPUT_N{PRECISE_DELAY_ADJ_MIN}});
        test_delay_adj('{OUTPUT_N{3ns}});
        test_delay_adj('{3ns                            , 3ns + PRECISE_DELAY_ADJ_TAP    ,
                         3ns + PRECISE_DELAY_ADJ_TAP * 2, 3ns + PRECISE_DELAY_ADJ_TAP * 3,
                         3ns + PRECISE_DELAY_ADJ_TAP * 4, 3ns + PRECISE_DELAY_ADJ_TAP * 5,
                         3ns + PRECISE_DELAY_ADJ_TAP * 6, 3ns + PRECISE_DELAY_ADJ_TAP * 7,
                         3ns, 3ns, 3ns, 3ns, 3ns, 3ns, 3ns, 3ns
                         });
        for(int i = 0; i < 10; i ++) begin
            test_delay_adj(random_delay_adj());
        end

    endtask

    typedef realtime random_delay_adj_return_t [OUTPUT_N];
    function random_delay_adj_return_t random_delay_adj();
        for(int i = 0; i < OUTPUT_N; i ++) begin
            if(DIFF_IO_MODES[i] == COMMON) begin
                random_delay_adj[i] = $urandom_range(2 ** ROUGH_DELAY_ADJ_W, 
                                                    ROUGH_DELAY_ADJ_MIN / ROUGH_DELAY_ADJ_TAP)
                                                    * ROUGH_DELAY_ADJ_TAP;
            end
            if(DIFF_IO_MODES[i] == PRECISE) begin
                random_delay_adj[i] = $urandom_range(2 ** PRECISE_DELAY_ADJ_W , 
                                                    PRECISE_DELAY_ADJ_MIN / PRECISE_DELAY_ADJ_TAP)
                                                    * PRECISE_DELAY_ADJ_TAP;
            end
        end
    endfunction

    task test_delay_adj(realtime delays [OUTPUT_N]);
        for(int i = 0; i < OUTPUT_N; i ++) begin
            generator.set_cfg(i, '{POSITIVE, GENERATOR});

            if(DIFF_IO_MODES[i] == COMMON) begin
                delays[i] = PRECISE_DELAY_ADJ_MIN; // currently common channels have static delay adjustment 
                generator.set_rough_delay_adj_time(i, delays[i]);
            end
            if(DIFF_IO_MODES[i] == PRECISE) begin
                generator.set_precise_delay_adj_time(i, delays[i]);
            end
        end
        driver.sync();
        @(negedge RCLK);
        @(negedge RCLK);
        delay_adj_checker_inst.set_expected_delays(delays);
        delay_adj_checker_inst.set_uncertainty(ROUGH_DELAY_ADJ_TAP);
        delay_adj_checker_inst.set_enable();
        pulse_o1();
        delay_adj_checker_inst.set_disable();
    endtask


endmodule

// симулирует работу осциллографа, подключенного на выходы устройства,
// настроенного на триггер по каналу с наименьшей задержкой,
// проверяет задержку от фронта триггера до первого фронта сигнала
module delay_adj_checker #(
    parameter unsigned                OUTPUT_N             = 16,
    parameter diff_io_pkg::polarity_t POLARITY [OUTPUT_N]  = '{default: diff_io_pkg::POSITIVE}
)(
    input  logic    lemo_output[OUTPUT_N]
);
    import diff_io_pkg::*;
    realtime min_delay                  = 0ps;
    int      min_delay_ind              = 0;
    realtime delays_relative [OUTPUT_N] = '{default: 0ps};
    realtime delays_measured [OUTPUT_N] = '{default: 0ps};
    realtime timeout                    = 0ps;
    realtime uncertainty                = 100ns;
    bit      enabled                    = 0;

    function set_expected_delays(input  realtime expected_delays [OUTPUT_N]);
        realtime max_delay;
        int      min_delay_ind_temp_q[$];
        min_delay               = expected_delays.min()[0];
        min_delay_ind_temp_q    = expected_delays.find_first_index() with (item == min_delay);
        min_delay_ind           = min_delay_ind_temp_q[0];
        foreach(expected_delays[i]) begin
            delays_relative[i] = expected_delays[i] - min_delay;
        end
        max_delay = delays_relative.max()[0];
        timeout = max_delay + uncertainty * 2;
    endfunction
    function set_uncertainty(input  realtime new_uncertainty);
        realtime max_delay;
        uncertainty = new_uncertainty;
        max_delay = delays_relative.max()[0];
        timeout = max_delay + uncertainty * 2;
    endfunction
    function set_enable();
        enabled = 1;
    endfunction
    function set_disable();
        enabled = 0;
    endfunction

    logic trigger;
    assign trigger = lemo_output[min_delay_ind];

    generate
    for(genvar i = 0; i < OUTPUT_N; i++) begin : delay_measure
        realtime start;
        always @(posedge trigger) begin
            start = $realtime;
            fork
            begin
                wait(lemo_output[i] == 1);
                delays_measured[i] <= $realtime - start;
            end
            begin
                #(timeout);
                delays_measured[i] <= timeout;
            end
            join_any
            disable fork;
        end
    end
    endgenerate

    always @(posedge trigger) begin
        #(timeout);
        if(enabled) begin
            foreach(delays_measured[i]) begin
                assert(delays_measured[i] <= delays_relative[i] + uncertainty)
                else begin 
                    $display("Channel %d delay too big! measured %t, expected %t", i, delays_measured[i], delays_relative[i] + uncertainty);
                    $display("time %t", $realtime);
                end
                assert(delays_measured[i] >= delays_relative[i] - uncertainty)
                else begin
                    $display("Channel %d delay too small! measured %t, expected %t", i, delays_measured[i], delays_relative[i] - uncertainty);
                    $display("time %t", $realtime);
                end
                assert(delays_measured[i] != timeout)
                else begin
                    $display("Channel %d timeout!", i);
                    $display("time %t", $realtime);
                end
            end
        end
    end

endmodule

module diff_io_board_emulator #(
    parameter unsigned OUTPUT_N = 16,
    parameter diff_io_pkg::polarity_t     POLARITY [OUTPUT_N] = '{default: diff_io_pkg::POSITIVE},
    parameter diff_io_pkg::diff_io_mode_t MODES    [OUTPUT_N] = '{default: diff_io_pkg::COMMON}
)(
    input  logic FPGA_IO_P      [OUTPUT_N],
    input  logic FPGA_IO_N      [OUTPUT_N],
    output logic lemo_output    [OUTPUT_N],

    input  logic SER,
    input  logic SRCLK,
    input  logic RCLK
);
    import diff_io_pkg::*;

    localparam int unsigned PRECISE_CNT   = 8;
    localparam int unsigned SN74HC595_CNT = PRECISE_CNT * PRECISE_DELAY_ADJ_W / 8;

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
    for(genvar i = 0; i < OUTPUT_N; i ++) begin
        if(MODES[i] == PRECISE) begin
            if(POLARITY[i] == POSITIVE) begin
                mc100ep195b_emulator mc100ep195b_emulator_inst(
                    .D(mc100ep195B_D[i]),
                    .IN(FPGA_IO_P[i]),
                    .Q(lemo_output[i])
                );
            end else begin
                mc100ep195b_emulator mc100ep195b_emulator_inst(
                    .D(mc100ep195B_D[i]),
                    .IN(FPGA_IO_N[i]),
                    .Q(lemo_output[i])
                );
            end
        end else begin
            if(POLARITY[i] == POSITIVE) begin
                assign lemo_output[i] = FPGA_IO_P[i];
            end else begin
                assign lemo_output[i] = FPGA_IO_N[i];
            end
        end

    end
    endgenerate

endmodule