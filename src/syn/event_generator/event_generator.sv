module event_generator #(
    parameter EV_SEQ_N  = 1,
    parameter EV_WIDTH  = 24,
    parameter CNT_WIDTH = 64,
    parameter ENTRY_NUM = 2048
) (
    input  logic                        app_clk,
    input  logic                        app_rst,
    axi4_lite_if.s                      mmr_ctrl,
    axi4_lite_if.s                      mmr_mem[EV_SEQ_N],

    output logic [EV_WIDTH-1:0]         ev
);

    logic                seq_start[EV_SEQ_N];
    logic                seq_stop[EV_SEQ_N];
    logic                seq_running[EV_SEQ_N];
    logic [EV_WIDTH-1:0] seq_ev[EV_SEQ_N];

    ev_seq_ctrl #(
        .EV_WIDTH(EV_WIDTH),
        .EV_SEQ_N(EV_SEQ_N)
    ) ev_seq_ctrl_i (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr_ctrl),

        .seq_start(seq_start),
        .seq_stop(seq_stop),
        .seq_running(seq_running),
        .ev_in(seq_ev),
        .ev_out(ev)
    );

    genvar i;
    generate
    for(i = 0; i < EV_SEQ_N; i++) begin
    ev_seq #(
        .EV_WIDTH(EV_WIDTH),
        .CNT_WIDTH(CNT_WIDTH),
        .ENTRY_NUM(ENTRY_NUM)
    ) (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr_mem[i]),

        .start(seq_start[i]),
        .stop(seq_stop[i]),
        .running(seq_running[i]),
        .ev(seq_ev[i])
    )
    end
    endgenerate
endmodule