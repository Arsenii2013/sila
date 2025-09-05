package ev_map_pkg;
    localparam ENTRY_SIZE    = 3; // четыре 32 битных слова: событие, маппинг 0-7, маппинг 8-15, маппинг 16-23
    typedef evn::ev_t               ev_t;
    typedef axi_params::mmr_data_t  axi_data_t;
endpackage

module ev_map #(
    parameter COMP_N    = 64,
    parameter SIG_GEN_N = 16
)(
    input  logic                app_clk,
    input  logic                app_rst,
    axi4_lite_if.s              mmr,

    input  ev_map_pkg::ev_t     ev, 

    output logic                set      [SIG_GEN_N],
    output logic                clear    [SIG_GEN_N],
    output logic                trigger  [SIG_GEN_N],
    output logic                cnt_reset[SIG_GEN_N]
);
    localparam WORD_WIDTH    = $bits(ev_map_pkg::axi_data_t);
    localparam ENTRY_NUM     = COMP_N;

    import ev_map_pkg::*;

    ev_t  ev_comp [COMP_N];
    logic map [COMP_N][SIG_GEN_N * 4];

    logic interconnect_in[COMP_N];
    logic interconnect_out[SIG_GEN_N * 4];

    genvar i;

    generate for(i = 0; i < COMP_N; i ++) begin
        assign interconnect_in[i] = ev != 0 && ev == ev_comp[i];
    end
    endgenerate

    generate for(i = 0; i < SIG_GEN_N; i ++) begin
        assign set[i]       = interconnect_out[i*4 + 0];
        assign clear[i]     = interconnect_out[i*4 + 1];
        assign trigger[i]   = interconnect_out[i*4 + 2];
        assign cnt_reset[i] = interconnect_out[i*4 + 3];
    end
    endgenerate

    signal_interconnect #(
        .IN_N(COMP_N),
        .OUT_N(SIG_GEN_N * 4),
        .PIPELINE(2)
    ) signal_interconnect_i (
        .clk(app_clk),
        .in(interconnect_in),
        .out(interconnect_out),
        .map(map)
    );


    ev_map_axi_core_pkg::ev_map_axi_core__in_t  hwif_in;
    ev_map_axi_core_pkg::ev_map_axi_core__out_t hwif_out;

    logic [$clog2(ENTRY_SIZE):0]  regblk_selected;
    logic [$clog2(ENTRY_NUM)-1:0] regblk_addr;
    logic                         regblk_addr_valid;
    logic                         regblk_addr_is_wr;

    regblk_n_by_addr #(
        .ADDR_W($clog2(ENTRY_NUM) + $clog2(WORD_WIDTH/8)),
        .DATA_W(WORD_WIDTH),
        .REGBLK_N(ENTRY_SIZE)
    ) regblk_n_by_addr_i (
        .addr(hwif_out.map_mem.addr),
        .addr_valid(hwif_out.map_mem.req),
        .addr_is_wr(hwif_out.map_mem.req_is_wr),

        .regblk_n(regblk_selected),
        .regblk_addr(regblk_addr),
        .output_valid(regblk_addr_valid),
        .output_is_wr(regblk_addr_is_wr)
    );

    assign hwif_in.map_mem.rd_data = regblk_selected == 0         ? ev_comp[regblk_addr] : (
                                     regblk_selected < ENTRY_SIZE ? {<<{map[regblk_addr][(regblk_selected - 1) * 32 +: 32]}} :
                                     '0);
    assign hwif_in.map_mem.rd_ack = regblk_addr_valid && !regblk_addr_is_wr;

    logic [WORD_WIDTH-1: 0] wr_data;
    assign wr_data = hwif_out.map_mem.wr_data;
    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            ev_comp <= '{default : '0};
        end else begin
            if(regblk_selected == 0 && regblk_addr_valid && regblk_addr_is_wr) begin
                ev_comp[regblk_addr] <= wr_data;
            end
        end
    end

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            map <= '{default:'{default : '0}};
        end else begin
            if(regblk_selected > 0 && regblk_selected < ENTRY_SIZE && regblk_addr_valid && regblk_addr_is_wr) begin
                map[regblk_addr][(regblk_selected - 1) * 32 +: 32] <= '{wr_data[0],  wr_data[1],  wr_data[2],  wr_data[3],
                                                                        wr_data[4],  wr_data[5],  wr_data[6],  wr_data[7],
                                                                        wr_data[8],  wr_data[9],  wr_data[10], wr_data[11],
                                                                        wr_data[12], wr_data[13], wr_data[14], wr_data[15],
                                                                        wr_data[16], wr_data[17], wr_data[18], wr_data[19],
                                                                        wr_data[20], wr_data[21], wr_data[22], wr_data[23],
                                                                        wr_data[24], wr_data[25], wr_data[26], wr_data[27],
                                                                        wr_data[28], wr_data[29], wr_data[30], wr_data[31]};
            end
        end
    end

    assign hwif_in.map_mem.wr_ack  = regblk_addr_valid && regblk_addr_is_wr;
    ev_map_axi_core ev_map_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );
endmodule

module regblk_n_by_addr #(
    parameter ADDR_W   = 32,
    parameter DATA_W   = 32,
    parameter REGBLK_N = 4
)(
    input  logic [ADDR_W-1     :0] addr,
    input  logic                   addr_valid,
    input  logic                   addr_is_wr,
    output logic [$clog2(REGBLK_N):0] regblk_n,
    output logic [ADDR_W - $clog2(REGBLK_N) - $clog2(DATA_W/8):0] regblk_addr,
    output logic                   output_valid,
    output logic                   output_is_wr
);
    localparam BYTES_TO_WORD_W = $clog2(DATA_W/8);
    assign output_valid = addr_valid;
    assign regblk_n     = addr[BYTES_TO_WORD_W +: $clog2(REGBLK_N)];
    assign regblk_addr  = addr[ADDR_W - 1 : BYTES_TO_WORD_W + $clog2(REGBLK_N)];
    assign output_is_wr = addr_is_wr;
endmodule
