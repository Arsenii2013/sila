module ev_map #(
    parameter EV_WIDTH  = 24,
    parameter COMP_N    = 64,
    parameter SIG_GEN_N = 16
)(
    input  logic                app_clk,
    input  logic                app_rst,
    axi4_lite_if.s              mmr,

    input  logic [EV_WIDTH-1:0] ev, 

    output logic                set      [SIG_GEN_N],
    output logic                clear    [SIG_GEN_N],
    output logic                trigger  [SIG_GEN_N],
    output logic                cnt_reset[SIG_GEN_N]
);
    localparam WORD_WIDTH    = 32;
    localparam ENTRY_SIZE    = 4; // четыре 32 битных слова: событие, маппинг 0-7, маппинг 8-15, маппинг 16-23
    localparam ENTRY_NUM     = COMP_N;

    `ifndef SYNTHESIS
    initial begin
        assert(EV_WIDTH  <= WORD_WIDTH)
            else $error("ev_seq: Event should be less than or equal to 32 bit");
        assert(SIG_GEN_N * 4 <= WORD_WIDTH*3)
            else $error("ev_seq: Generator N should be less than or equal to 24");
    end
    `endif

    typedef logic [EV_WIDTH-1:0] ev_t;
    genvar i;

    ev_t  ev_comp [COMP_N];
    logic map [COMP_N][SIG_GEN_N * 4];

    logic interconnect_in[COMP_N];
    logic interconnect_out[SIG_GEN_N * 4];

    generate for(i = 0; i < COMP_N; i ++) begin
        assign interconnect_in[i] = ev == ev_comp[i];
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
        .SLICE(0)
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

module ev_mapTB();
    localparam COMP_N    = 64;
    localparam SIG_GEN_N = 16;

    logic app_clk;
    logic app_rst = 0;
    logic [23:0] ev = '0;

    logic set      [SIG_GEN_N];
    logic clear    [SIG_GEN_N];
    logic trigger  [SIG_GEN_N];
    logic cnt_reset[SIG_GEN_N];

    axi4_lite_if #(.AW(32), .DW(32)) mmr();

    sys_clk_gen
    #(
        .halfcycle (2000),
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    map_writer map_writer_i(
        .aclk(app_clk),
        .areset(app_rst),
        .axi(mmr)
    );

    ev_map #(
        .EV_WIDTH(24),
        .COMP_N(COMP_N),
        .SIG_GEN_N(SIG_GEN_N)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .set(set),
        .clear(clear),
        .trigger(trigger),
        .cnt_reset(cnt_reset),
        .ev(ev)
    );

    initial begin
        reset();
        #1us;
        GenericTest();
        #1us;
        SingleOutputTest();
        #1us;
        ManyOutputTest();
        #1us;
        $stop();
    end

    task GenericTest();
        test_start($sformatf("%m"));
        reset();
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(1);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(2);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(3);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
    endtask

    task SingleOutputTest();
        test_start($sformatf("%m"));
        reset();
        map_writer_i.reset_mapping();
        map_writer_i.add_mapping(1, '{0: 4'b0001, default:4'b0});
        map_writer_i.add_mapping(2, '{0: 4'b0010, default:4'b0});
        map_writer_i.add_mapping(3, '{0: 4'b0100, default:4'b0});
        map_writer_i.add_mapping(4, '{0: 4'b1000, default:4'b0});
        map_writer_i.add_mapping(5, '{0: 4'b1111, default:4'b0});
        map_writer_i.check_mapping(0, 1, '{0: 4'b0001, default:4'b0});
        map_writer_i.check_mapping(1, 2, '{0: 4'b0010, default:4'b0});
        map_writer_i.check_mapping(2, 3, '{0: 4'b0100, default:4'b0});
        map_writer_i.check_mapping(3, 4, '{0: 4'b1000, default:4'b0});
        map_writer_i.check_mapping(4, 5, '{0: 4'b1111, default:4'b0});
        send_ev(1);
        assert (set       == '{0: 1, default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(2);
        assert (set       == '{default:0});
        assert (clear     == '{0: 1, default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{default:0});
        send_ev(3);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{0: 1, default:0});
        assert (cnt_reset == '{default:0});
        send_ev(4);
        assert (set       == '{default:0});
        assert (clear     == '{default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{0: 1, default:0});
        send_ev(5);
        assert (set       == '{0: 1, default:0});
        assert (clear     == '{0: 1, default:0});
        assert (trigger   == '{0: 1, default:0});
        assert (cnt_reset == '{0: 1, default:0});
    endtask

    task ManyOutputTest();
        test_start($sformatf("%m"));
        reset();
        map_writer_i.reset_mapping();
        map_writer_i.add_mapping(1, '{0: 4'b0001, 1: 4'b0010, 2: 4'b0110, default:4'b0});
        map_writer_i.add_mapping(2, '{0: 4'b0010, 1: 4'b1000, 2: 4'b1000, default:4'b0});
        map_writer_i.add_mapping(3, '{0: 4'b0100, 1: 4'b0010, 2: 4'b0010, default:4'b0});
        map_writer_i.add_mapping(4, '{0: 4'b1000, 1: 4'b0001, 2: 4'b1011, default:4'b0});
        map_writer_i.add_mapping(5, '{default:4'b1111});
        map_writer_i.check_mapping(0, 1, '{0: 4'b0001, 1: 4'b0010, 2: 4'b0110, default:4'b0});
        map_writer_i.check_mapping(1, 2, '{0: 4'b0010, 1: 4'b1000, 2: 4'b1000, default:4'b0});
        map_writer_i.check_mapping(2, 3, '{0: 4'b0100, 1: 4'b0010, 2: 4'b0010, default:4'b0});
        map_writer_i.check_mapping(3, 4, '{0: 4'b1000, 1: 4'b0001, 2: 4'b1011, default:4'b0});
        map_writer_i.check_mapping(4, 5, '{default:4'b1111});

        send_ev(1);
        assert (set       == '{0: 1, default:0});
        assert (clear     == '{1: 1, 2: 1, default:0});
        assert (trigger   == '{2: 1, default:0});
        assert (cnt_reset == '{default:0});
        send_ev(2);
        assert (set       == '{default:0});
        assert (clear     == '{0: 1, default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{1: 1, 2: 1,default:0});
        send_ev(3);
        assert (set       == '{default:0});
        assert (clear     == '{1: 1, 2: 1,default:0});
        assert (trigger   == '{0: 1, default:0});
        assert (cnt_reset == '{default:0});
        send_ev(4);
        assert (set       == '{1: 1, 2: 1, default:0});
        assert (clear     == '{2: 1, default:0});
        assert (trigger   == '{default:0});
        assert (cnt_reset == '{0: 1, 2: 1, default:0});
        send_ev(5);
        assert (set       == '{default:1});
        assert (clear     == '{default:1});
        assert (trigger   == '{default:1});
        assert (cnt_reset == '{default:1});
    endtask

    task send_ev(logic [23:0] ev_s);
        @(posedge app_clk);
        ev <= ev_s;
        @(posedge app_clk);
        ev <= 0;
    endtask

    int test_number = 0;
    task test_start(input string name);
        @(posedge app_clk);
        test_number <= test_number + 1;
        @(posedge app_clk);
        $display("Start %s test with numder %d", name, test_number);
    endtask

    task reset();
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;
    endtask
endmodule

module map_writer #(
    parameter SIG_GEN_N = 16
)(
    axi4_lite_if.m  axi,
    input  logic    aclk,
    input  logic    areset
);
    axi_master axi_master(
        .aclk(aclk),
        .aresetn(areset),
        .axi(axi)
    );

    int entrys_num = 0;
    logic [3:0] rd_func [SIG_GEN_N];
    logic [31:0] rd_ev;
    logic [4 * SIG_GEN_N - 1: 0] func_flat;
    localparam SIG_GEN_N_MINUS_MAX_I = SIG_GEN_N <= 8  ? SIG_GEN_N * 4 :
                                       SIG_GEN_N <= 16 ? SIG_GEN_N * 4 - 32:
                                       SIG_GEN_N <= 24 ? SIG_GEN_N * 4 - 64:
                                       SIG_GEN_N * 4 - 96;

    task add_mapping(input logic [23:0] ev, input logic [3:0] func [SIG_GEN_N]);
        @(posedge aclk);
        axi_master.write(entrys_num * 'h10 + 'h00, ev);
        func_flat = {<<4{func}};
        for(int i = 0; i < 3; i ++) begin
            if(i * 32 + 32 < SIG_GEN_N * 4) begin
                axi_master.write(entrys_num * 'h10 + 'h04 + i * 'h04, func_flat[i * 32 +: 32]);
            end else if(i * 32 < SIG_GEN_N * 4) begin
                axi_master.write(entrys_num * 'h10 + 'h04 + i * 'h04, func_flat[i * 32 +: SIG_GEN_N_MINUS_MAX_I]);
            end
        end
        entrys_num <= entrys_num + 1;
    endtask

    task reset_mapping();
        entrys_num <= 0;
    endtask

    task read_mapping(int entry, output logic [23:0] ev, output logic [3:0] func [SIG_GEN_N]);
        @(posedge aclk);
        axi_master.read(entry * 'h10 + 'h00, ev);
        for(int i = 0; i < 3; i ++) begin
            if(i * 32 + 32 < SIG_GEN_N * 4) begin
                axi_master.read(entry * 'h10 + 'h04 + i * 'h04, func_flat[i * 32 +: 32]);
            end else if(i * 32 < SIG_GEN_N * 4) begin
                axi_master.read(entry * 'h10 + 'h04 + i * 'h04, func_flat[i * 32 +: SIG_GEN_N_MINUS_MAX_I]);
            end
        end
        for(int i = 0; i < SIG_GEN_N; i ++) begin
            func[i] = func_flat[i * 4 +: 4];
        end
        @(posedge aclk);
    endtask

    task check_mapping(int entry, input logic [23:0] ev, input logic [3:0] func [SIG_GEN_N]);
        read_mapping(entry, rd_ev, rd_func);
        assert(rd_ev == ev);
        assert(rd_func == func);
    endtask
endmodule