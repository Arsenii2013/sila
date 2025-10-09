package gen_map_pkg;
    localparam ENTRY_SIZE    = 1;
    typedef axi_params::mmr_data_t  axi_data_t;
endpackage


module gen_map #(
    parameter SIG_GEN_N = 16,
    parameter DIFF_IO_N = 16
)(
    input  logic    app_clk,
    input  logic    app_rst,
    axi4_lite_if.s  mmr,

    input  logic    gen_out[SIG_GEN_N],

    output logic    o1[DIFF_IO_N],
    output logic    o2[DIFF_IO_N]
);
    localparam WORD_WIDTH    = $bits(gen_map_pkg::axi_data_t);
    localparam ENTRY_NUM     = SIG_GEN_N;

    import gen_map_pkg::*;

    logic map [SIG_GEN_N][DIFF_IO_N * 2];

    logic interconnect_in[SIG_GEN_N];
    logic interconnect_out[DIFF_IO_N * 2];

    assign interconnect_in = gen_out;

    genvar out_i;
    generate for(out_i = 0; out_i < DIFF_IO_N; out_i ++) begin
        assign o1[out_i] = interconnect_out[out_i*2 + 0];
        assign o2[out_i] = interconnect_out[out_i*2 + 1];
    end
    endgenerate

    signal_interconnect #(
        .IN_N(SIG_GEN_N),
        .OUT_N(DIFF_IO_N * 2),
        .PIPELINE(2)
    ) signal_interconnect_i (
        .clk(app_clk),
        .in(interconnect_in),
        .out(interconnect_out),
        .map(map)
    );


    gen_map_axi_core_pkg::gen_map_axi_core__in_t  hwif_in;
    gen_map_axi_core_pkg::gen_map_axi_core__out_t hwif_out;

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

    assign hwif_in.map_mem.rd_data = regblk_selected < ENTRY_SIZE ? {<<{map[regblk_addr][(regblk_selected) * 32 +: 32]}} :
                                     '0;
    assign hwif_in.map_mem.rd_ack = regblk_addr_valid && !regblk_addr_is_wr;

    logic [WORD_WIDTH-1: 0] wr_data;
    assign wr_data = hwif_out.map_mem.wr_data;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            map <= '{default:'{default : '0}};
        end else begin
            if(regblk_selected >= 0 && regblk_selected < ENTRY_SIZE && regblk_addr_valid && regblk_addr_is_wr) begin
                map[regblk_addr][(regblk_selected) * 32 +: 32] <= '{wr_data[0],  wr_data[1],  wr_data[2],  wr_data[3],
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
    gen_map_axi_core gen_map_axi_core_i(
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

    generate 
    if($clog2(REGBLK_N) != 0) begin
        assign regblk_n     = addr[BYTES_TO_WORD_W +: $clog2(REGBLK_N)];
    end else begin
        assign regblk_n     = 0;
    end
    endgenerate

    assign regblk_addr  = addr[ADDR_W - 1 : BYTES_TO_WORD_W + $clog2(REGBLK_N)];
    assign output_is_wr = addr_is_wr;
endmodule
