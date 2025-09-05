module max #(
    parameter W = 32,
    parameter N = 8
)(
    input  logic         app_clk,
    input  logic         app_rst,

    input  logic [W-1:0] in[N],
    input  logic         in_upd[N],
    output logic [W-1:0] out,
    output logic         out_upd
);
    typedef logic [$clog2(N)  : 0] ptr_t;
    typedef logic [W        -1: 0] data_t;
    typedef enum { 
        WAIT,
        PROCESS
    } state_t;

    state_t state = WAIT;
    ptr_t   ptr   = '0;
    data_t  max   = '0;

    logic        in_upd_ored;
    always_comb begin
        in_upd_ored = 0;
        for(int i = 0; i < N; i++)
            in_upd_ored |= in_upd[i];
    end


    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            state   <= WAIT;
            ptr     <= '0;
            max     <= '0;
            out     <= '0;
            out_upd <= 0;
        end else begin
            out_upd <= 0;
            if(state == WAIT) begin
                ptr <= '0;
                max <= '0;
                if(in_upd_ored) begin
                    state   <= PROCESS;
                end
            end else if(state == PROCESS) begin
                if(in[ptr] > max) begin
                    max <= in[ptr];
                end
                if(in_upd_ored) begin
                    ptr     <= '0;
                    max     <= '0;
                end else if(ptr == N) begin
                    state   <= WAIT;
                    out     <= max;
                    out_upd <= 1;
                end else begin
                    ptr <= ptr + 1;
                end
            end
        end
    end
endmodule

`ifndef SYNTHESIS
module maxTB();
    localparam W = 32;
    localparam N = 8;
    typedef logic [W-1: 0] data_t;

    logic app_clk;
    logic app_rst = 1;

    data_t in[N] = '{default:'0};
    logic  in_upd[N] = '{default:0};
    data_t out;
    logic  out_upd;


    sys_clk_gen
    #(
        .halfcycle (2500),
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (app_clk)
    );

    max #(
        .W(W),
        .N(N)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),

        .in(in),
        .in_upd(in_upd),
        .out(out),
        .out_upd(out_upd)
    );

    initial begin
        app_rst <= 1;
        repeat (10) @(posedge app_clk);
        app_rst <= 0;
        testRandom();
        testRestart();
        $stop();
    end

    task testRandom();
        for(int cycle = 0; cycle < 100; cycle++) begin
            change_random();
            repeat (10) @(posedge app_clk);
        end
    endtask

    task testRestart();
        for(int cycle = 0; cycle < 100; cycle++) begin
            change_random();
            change_random();
            repeat (10) @(posedge app_clk);
        end
    endtask

    task automatic change_random();
        int choise = $urandom_range(0, N-1);
        @(posedge app_clk);
        in[choise]     <= $urandom();
        in_upd[choise] <= 1;
        @(posedge app_clk);
        in_upd[choise] <= 0;
    endtask

    genvar  in_upd_i;
    generate
    for(in_upd_i = 0; in_upd_i < N; in_upd_i++) begin
    assert property (@(posedge app_clk) in_upd[in_upd_i] |=> ##[N:$] out_upd);
    end
    endgenerate
    assert property (@(posedge app_clk) out_upd   |=> (out == in.max()[0])) ;
    assert property (@(posedge app_clk) out_upd   |=> (out == in.max()[0])) else $display("expect %d got %d", in.max()[0], out);;
endmodule
`endif