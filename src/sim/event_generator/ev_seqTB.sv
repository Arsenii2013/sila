
module ev_seqTB();
    import event_generator_pkg::*;
    logic app_clk;
    logic app_rst = 0;
    ev_t ev;
    logic start = 0;
    logic stop  = 0;
    logic running;
    
    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    axi4_lite_if #(.AW(32), .DW(32)) mmr();

    ev_seq DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .ev(ev),
        .start(start),
        .stop(stop),
        .running(running)
    );

    ev_seq_generator_pkg::seq_item_t seq [];
    monitor ev_recv_i(
        .clk(app_clk),
        .reset(app_rst),
        .ev(ev),
        .seq(seq),
        .start(start),
        .stop(stop),
        .running(running)
    );
    virtual_clock_if clk_if (app_clk, app_rst);
    axi_transaction_pkg::item_mailbox_t req_mbx = new(), resp_mbx = new();
    axi_driver driver;
    ev_seq_generator generator;
    initial begin
        seq = '{
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
        };
        driver = new(clk_if, mmr, req_mbx, resp_mbx);
        generator = new(clk_if, req_mbx, resp_mbx, 0);
        fork
            driver.serve_mailboxes();
        join_none;
        reset();
        #10us;
        generator.write_seq(seq);
        #1us;
        generator.verify_seq(seq);

        start_seq();
        wait_seq_end();
        @(posedge app_clk);

        start_seq();
        wait (ev == 'h40);
        stop_seq();
        #1us;
        @(posedge app_clk);

        start_seq();
        stop_seq();
        #1us;
        @(posedge app_clk);

        start_seq();
        wait_seq_end();
        #1us;
        $stop();
    end

    task reset();
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;
    endtask

    task start_seq();
        @(posedge app_clk);
        start <= 1;
        @(posedge app_clk);
        start <= 0;
    endtask

    task stop_seq();
        @(posedge app_clk);
        stop <= 1;
        @(posedge app_clk);
        stop <= 0;
    endtask

    task wait_seq_end();
        wait (ev == event_generator_pkg::END_OF_SEQ);
    endtask
endmodule

module monitor(
    input  logic                     clk,
    input  logic                     reset,
    input  event_generator_pkg::ev_t    ev,
    input  ev_seq_generator_pkg::seq_item_t seq[],
    input  logic                     start,
    input  logic                     stop,
    input  logic                     running
);
    import event_generator_pkg::*;
    timestamp_t timestamp;
    int ptr;
    logic state;
    always_ff @(posedge clk) begin
        if(reset || !running) begin
            timestamp <= '0;
            ptr       <= 0;
            state     <= 0;
        end else if(state == 0) begin
            state     <= 1;
        end else begin
            timestamp <= timestamp + 1;
            if(timestamp == seq[ptr].timestamp)
                ptr <= ptr+1;
        end
    end

    assert property (@(posedge clk) (running |-> (timestamp <= seq[ptr].timestamp)));
    assert property (@(posedge clk) (running |=> (timestamp != seq[ptr].timestamp  |-> ev == 0)));
    assert property (@(posedge clk) (running |=> (timestamp == seq[ptr].timestamp   |-> ev == seq[ptr].ev)));
    assert property (@(posedge clk) (running |=> (timestamp == seq[ptr].timestamp+1 |-> ev == event_generator_pkg::END_OF_SEQ)));

    assert property (@(posedge clk) (start && !running) |=> ##2 ($rose(running) || $past(stop, 1) || $past(stop, 2)));
    assert property (@(posedge clk) (start && !running) |=> ##[1:$] $fell(running));
    assert property (@(posedge clk) (ev == event_generator_pkg::END_OF_SEQ) |=> $fell(running));
    assert property (@(posedge clk) (stop  && running)  |=> $fell(running));
endmodule
