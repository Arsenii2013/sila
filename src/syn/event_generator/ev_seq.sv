module ev_seq #(
    parameter EV_WIDTH  = 24,
    parameter CNT_WIDTH = 64,
    parameter ENTRY_NUM = 2048
) (
    input  logic                        app_clk,
    input  logic                        app_rst,
    axi4_lite_if.s                      mmr,

    input  logic                        start,
    input  logic                        stop,
    output logic                        running,
    output logic [EV_WIDTH-1:0]         ev
);
    localparam WORD_WIDTH    = 32;
    localparam ENTRY_SIZE    = 3; // три 32 битных слова
    localparam READ_LATENCY  = 1;
    localparam END_OF_EVENTS = 'h50DEAD;

    `ifndef SYNTHESIS
    initial begin
        assert(EV_WIDTH  <= WORD_WIDTH)
            else $error("ev_seq: Event should be less than or equal to 32 bit");
        assert(CNT_WIDTH <= WORD_WIDTH*2)
            else $error("ev_seq: Cnt should be less than or equal to 64 bit");
    end
    `endif

    typedef logic [EV_WIDTH         -1: 0] ev_t;
    typedef logic [CNT_WIDTH        -1: 0] cnt_t;
    typedef logic [WORD_WIDTH       -1: 0] mem_word_t;
    typedef logic [$clog2(ENTRY_NUM)-1: 0] mem_addr_t;

    typedef enum {
        SQ_WAIT,
        SQ_START,
        SQ_RUNNING
    } rd_fsm_state_t;

    typedef struct {
        mem_word_t cnt_lsb;
        mem_word_t cnt_msb;
        mem_word_t ev;
    } mem_entry_t;

    rd_fsm_state_t state = SQ_WAIT, next;
    
    mem_addr_t     rd_ptr  = 0;
    mem_entry_t    rd_data, rd_prefetch[READ_LATENCY];
    logic          rd_ena  = 0;

    cnt_t          cnt     = 0;

    ev_t           rd_ev;
    cnt_t          rd_cnt;
    cnt_t          next_rd_cnt;
    cnt_t          prev_rd_cnt;

    logic [$clog2(READ_LATENCY):0] prefetch_cnt = READ_LATENCY;

    assign running     = state == SQ_RUNNING;
    assign rd_ev       = ev_t'(rd_data.ev);
    assign rd_cnt      = cnt_t'({rd_data.cnt_msb, rd_data.cnt_lsb});
    assign next_rd_cnt = cnt_t'({rd_prefetch[READ_LATENCY-1].cnt_msb, rd_prefetch[READ_LATENCY-1].cnt_lsb});
    always_ff @(posedge app_clk) begin
        if(rd_ena)
            prev_rd_cnt <= rd_cnt;
    end

    genvar k;
    generate
    for (k = 1; k < READ_LATENCY; k = k + 1) begin
        always_ff @(posedge app_clk) begin
            if(rd_ena)
                rd_prefetch[k] <= rd_prefetch[k-1];
        end
    end
    endgenerate

    always_ff @(posedge app_clk) begin
        if(rd_ena)
            rd_data <= rd_prefetch[READ_LATENCY-1];
    end

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            ev    <= '0;
            state <= SQ_WAIT;
        end else begin
            state  <= next;
            rd_ptr <= rd_ptr;
            ev     <= '0;
            rd_ena <= 0;
            case (state)
                SQ_WAIT    : begin 
                    cnt          <= '0;
                    rd_ptr       <= '0;
                    prefetch_cnt <= READ_LATENCY;
                end
                SQ_START   : begin 
                    prefetch_cnt <= prefetch_cnt - 1;
                    rd_ptr       <= rd_ptr+1;
                    rd_ena       <= 1;
                end
                SQ_RUNNING : begin 
                    if(cnt == rd_cnt) begin
                        ev      <= rd_ev;
                    end
                    if(cnt == rd_cnt && !(rd_cnt - prev_rd_cnt == 1 && next_rd_cnt - rd_cnt != 1)) begin
                        rd_ptr  <= rd_ptr+1;
                        rd_ena  <= 1;
                    end
                    if(cnt + 2 == next_rd_cnt) begin // prefetch
                        rd_ptr  <= rd_ptr+1;
                        rd_ena  <= 1;
                    end
                    cnt <= cnt + 1;
                end
                default;
            endcase
        end
    end

    always_comb begin
        case (state)
            SQ_WAIT    : next = start ? SQ_START : SQ_WAIT;
            SQ_START   : next = stop  ? SQ_WAIT  : (prefetch_cnt == 0   ? SQ_RUNNING : SQ_START);
            SQ_RUNNING : next = stop  ? SQ_WAIT  : (ev == END_OF_EVENTS ? SQ_WAIT    : SQ_RUNNING);
            default    : next = SQ_WAIT;
        endcase
    end

// MM logic
    mem_addr_t axi_addr;
    mem_word_t axi_wr_word;
    mem_word_t axi_rd_word [ENTRY_SIZE];
    logic      axi_we      [ENTRY_SIZE];

    mem_addr_t seq_addr;
    mem_word_t seq_rd_word [ENTRY_SIZE];
    assign seq_addr               = rd_ptr;
    assign rd_prefetch[0].cnt_lsb = seq_rd_word[0];
    assign rd_prefetch[0].cnt_msb = seq_rd_word[1];
    assign rd_prefetch[0].ev      = seq_rd_word[2];

    genvar i;
    generate
    for (i = 0; i < ENTRY_SIZE; i = i + 1) begin
        xpm_memory_tdpram #(
            .ADDR_WIDTH_A($clog2(ENTRY_NUM)),
            .ADDR_WIDTH_B($clog2(ENTRY_NUM)),
            .BYTE_WRITE_WIDTH_A(WORD_WIDTH),
            .BYTE_WRITE_WIDTH_B(WORD_WIDTH),
            .CASCADE_HEIGHT(0),
            .CLOCKING_MODE("common_clock"),
            .ECC_MODE("no_ecc"),
            .MEMORY_INIT_FILE("none"),
            .MEMORY_INIT_PARAM("0"),
            .MEMORY_OPTIMIZATION("true"),
            .MEMORY_PRIMITIVE("auto"),
            .MEMORY_SIZE(WORD_WIDTH*ENTRY_NUM),
            .MESSAGE_CONTROL(1),
            .RAM_DECOMP("auto"),
            .READ_DATA_WIDTH_A(WORD_WIDTH),
            .READ_DATA_WIDTH_B(WORD_WIDTH),
            .READ_LATENCY_A(READ_LATENCY),
            .READ_LATENCY_B(READ_LATENCY),
            .READ_RESET_VALUE_A("0"),
            .READ_RESET_VALUE_B("0"),
            .RST_MODE_A("SYNC"),
            .RST_MODE_B("SYNC"),
            .SIM_ASSERT_CHK(1),
            .USE_EMBEDDED_CONSTRAINT(0),
            .WAKEUP_TIME("disable_sleep"),
            .WRITE_DATA_WIDTH_A(WORD_WIDTH),
            .WRITE_DATA_WIDTH_B(WORD_WIDTH),
            .WRITE_MODE_A("no_change"),
            .WRITE_MODE_B("no_change"),
            .WRITE_PROTECT(1)
        )
        xpm_memory_tdpram_inst (
            .addra(axi_addr),
            .addrb(seq_addr),
            
            .douta(axi_rd_word[i]),
            .doutb(seq_rd_word[i]),
            
            .dina(axi_wr_word),
            .dinb('0),

            .wea(axi_we[i]),
            .web(0),

            .clka(app_clk),
            .clkb(app_clk),
            .ena(1),
            .enb(1),
            .regcea(1),
            .regceb(1),
            .rsta(app_rst),
            .rstb(app_rst)
        );
    end
    endgenerate

    logic [$clog2(ENTRY_SIZE):0] mem_selected;
    logic                        mem_addr_valid;
    logic                        mem_addr_is_wr;

    mem_n_by_addr #(
        .ADDR_W($clog2(ENTRY_NUM) + $clog2(WORD_WIDTH/8)),
        .DATA_W(WORD_WIDTH),
        .MEM_N(ENTRY_SIZE)
    ) mem_n_by_addr_i (
        .addr(hwif_out.seq_mem.addr),
        .addr_valid(hwif_out.seq_mem.req),
        .addr_is_wr(hwif_out.seq_mem.req_is_wr),
        .mem_n(mem_selected),
        .mem_addr(axi_addr),
        .output_valid(mem_addr_valid),
        .output_is_wr(mem_addr_is_wr)
    );

    ev_seq_axi_core_pkg::ev_seq_axi_core__in_t  hwif_in;
    ev_seq_axi_core_pkg::ev_seq_axi_core__out_t hwif_out;

    logic [$clog2(ENTRY_SIZE):0] mem_selected_dly;
    genvar j;
    generate
    for (j = 0; j < ENTRY_SIZE; j = j + 1) begin
        assign axi_we[j] = mem_selected == j && mem_addr_valid && mem_addr_is_wr;
    end
    endgenerate
    assign hwif_in.seq_mem.wr_ack  = mem_addr_valid && mem_addr_is_wr;
    assign hwif_in.seq_mem.rd_data = axi_rd_word[mem_selected_dly];
    assign axi_wr_word             = hwif_out.seq_mem.wr_data;

    logic [$clog2(READ_LATENCY):0] read_dly_cnt = 0;
    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            read_dly_cnt <= READ_LATENCY;
        end else begin
            if(mem_addr_valid && !mem_addr_is_wr) begin
                read_dly_cnt <= read_dly_cnt-1;
                mem_selected_dly <= mem_selected;
                if(read_dly_cnt == 0) begin
                    read_dly_cnt <= READ_LATENCY;
                end
            end else begin
                read_dly_cnt <= READ_LATENCY;
            end
        end
    end
    assign hwif_in.seq_mem.rd_ack = read_dly_cnt == 0;
    ev_seq_axi_core ev_seq_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule

module mem_n_by_addr #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    parameter MEM_N  = 3
)(
    input  logic [ADDR_W-1     :0] addr,
    input  logic                   addr_valid,
    input  logic                   addr_is_wr,
    output logic [$clog2(MEM_N):0] mem_n,
    output logic [ADDR_W - $clog2(MEM_N) - $clog2(DATA_W/8):0] mem_addr,
    output logic                   output_valid,
    output logic                   output_is_wr
);
    localparam BYTES_TO_WORD_W = $clog2(DATA_W/8);
    assign output_valid = addr_valid;
    assign mem_n        = addr[BYTES_TO_WORD_W +: $clog2(MEM_N)];
    assign mem_addr     = addr[ADDR_W - 1 : BYTES_TO_WORD_W + $clog2(MEM_N)];
    assign output_is_wr = addr_is_wr;
endmodule

module ev_seqTB();
    logic app_clk;
    logic app_rst = 0;
    logic [23:0] ev;
    logic start = 0;
    logic stop  = 0;
    
    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    axi4_lite_if #(.AW(32), .DW(32)) mmr();

    seq_writer seq_writer(
        .aclk(app_clk),
        .areset(app_rst),
        .axi(mmr)
    );

    ev_seq #(
        .EV_WIDTH(24),
        .CNT_WIDTH(64),
        .ENTRY_NUM(2048)
        
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .ev(ev),
        .start(start),
        .stop(stop)
    );

    ev_recv ev_recv_i(
        .aclk(app_clk),
        .areset(app_rst),
        .ev(ev)
    );

    logic [63:0] rd_timestamp;
    logic [31:0] rd_ev;

    initial begin
        reset();
        #10us;
        seq_writer.add_event(0,  'h1);
        seq_writer.add_event(1,  'h2);
        seq_writer.add_event(2,  'h3);
        seq_writer.add_event(3,  'h4);
        seq_writer.add_event(10, 'h10);
        seq_writer.add_event(20, 'h20);
        seq_writer.add_event(40, 'h40);
        seq_writer.add_event(80, 'h80);
        seq_writer.add_event(8000, 'h1234);
        seq_writer.add_end_of_sequency(8001);
        #1us;
        for (int i = 0; i < 11; i++) begin
            seq_writer.read_event(i, rd_timestamp, rd_ev);
            $display("timestamp : %016h, event : %08h", rd_timestamp, rd_ev);
        end

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
        wait (ev == 'h50DEAD);
    endtask
endmodule

module seq_writer(
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
    logic [31:0] rd_timestamp_lsb;
    logic [31:0] rd_timestamp_msb;
    logic [31:0] rd_ev;

    task add_event(input logic [63:0] timestamp, input logic [23:0] ev);
        @(posedge aclk);
        axi_master.write(entrys_num * 'h10 + 'h00, timestamp[31:0]);
        axi_master.write(entrys_num * 'h10 + 'h04, timestamp[63:32]);
        axi_master.write(entrys_num * 'h10 + 'h08, {8'h0, ev});
        entrys_num <= entrys_num + 1;
    endtask
    
    task add_end_of_sequency(input logic [63:0] timestamp);
        @(posedge aclk);
        add_event(timestamp, 'h50DEAD);
    endtask

    task reset_events();
        entrys_num <= 0;
    endtask

    task read_event(int entry, output logic [63:0] timestamp, output logic [23:0] ev);
        @(posedge aclk);
        axi_master.read(entry * 'h10 + 'h00, rd_timestamp_lsb);
        axi_master.read(entry * 'h10 + 'h04, rd_timestamp_msb);
        axi_master.read(entry * 'h10 + 'h08, rd_ev);
        @(posedge aclk);
        timestamp <= {rd_timestamp_msb, rd_timestamp_lsb};
        ev        <= rd_ev;
        @(posedge aclk);
    endtask
endmodule

module ev_recv(
    input  logic        aclk,
    input  logic        areset,
    input  logic [23:0] ev
);
    logic [63:0] timestamp      = '0;
    logic [63:0] prev_timestamp = '0;
    always_ff @(posedge aclk) begin
        if(areset) begin
            timestamp      <= '0;
            prev_timestamp <= '0;
        end else begin
            if(ev != 0) begin
                $display("recieved event %08h at cycle %0d, spend %0d", ev, timestamp, timestamp - prev_timestamp);
                prev_timestamp <= timestamp;
            end
            timestamp <= timestamp+1;
        end
    end

endmodule