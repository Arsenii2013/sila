module ev_seq (
    input  logic                        app_clk,
    input  logic                        app_rst,
    axi4_lite_if.s                      mmr,

    input  logic                        disable_,
    input  logic                        start,
    input  logic                        stop,
    output logic                        running,
    output event_generator_pkg::ev_t    ev
);
    localparam ENTRY_SIZE    = 3; // три 32 битных слова
    localparam READ_LATENCY  = 1;

    import event_generator_pkg::*;

    typedef logic [$clog2(READ_LATENCY):0] prefetch_cnt_t;

    typedef enum {
        SQ_WAIT,
        SQ_START,
        SQ_RUNNING
    } rd_fsm_state_t;

    typedef struct {
        mem_data_t cnt_lsb;
        mem_data_t cnt_msb;
        mem_data_t ev;
    } mem_entry_t;

    rd_fsm_state_t state = SQ_WAIT, next;
    
    mem_addr_t     rd_ptr  = 0;
    mem_entry_t    rd_data, rd_prefetch[READ_LATENCY];
    logic          rd_ena  = 0;

    timestamp_t          cnt     = 0;

    ev_t        rd_ev;
    timestamp_t rd_cnt;
    timestamp_t next_rd_cnt;
    timestamp_t prev_rd_cnt;

    prefetch_cnt_t prefetch_cnt = READ_LATENCY;

    assign running     = state == SQ_RUNNING;
    assign rd_ev       = ev_t'(rd_data.ev);
    assign rd_cnt      = timestamp_t'({rd_data.cnt_msb, rd_data.cnt_lsb});
    assign next_rd_cnt = timestamp_t'({rd_prefetch[READ_LATENCY-1].cnt_msb, rd_prefetch[READ_LATENCY-1].cnt_lsb});
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
            SQ_WAIT    : next = start && !disable_ ? SQ_START : SQ_WAIT;
            SQ_START   : next = stop  ? SQ_WAIT  : (prefetch_cnt == 0   ? SQ_RUNNING : SQ_START);
            SQ_RUNNING : next = stop  ? SQ_WAIT  : (ev == END_OF_SEQ    ? SQ_WAIT    : SQ_RUNNING);
            default    : next = SQ_WAIT;
        endcase
    end

// MM logic
    mem_addr_t axi_addr;
    mem_data_t axi_wr_word;
    mem_data_t axi_rd_word [ENTRY_SIZE];
    logic      axi_we      [ENTRY_SIZE];

    mem_addr_t seq_addr;
    mem_data_t seq_rd_word [ENTRY_SIZE];
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
            .BYTE_WRITE_WIDTH_A($bits(mem_data_t)),
            .BYTE_WRITE_WIDTH_B($bits(mem_data_t)),
            .CASCADE_HEIGHT(0),
            .CLOCKING_MODE("common_clock"),
            .ECC_MODE("no_ecc"),
            .MEMORY_INIT_FILE("none"),
            .MEMORY_INIT_PARAM("0"),
            .MEMORY_OPTIMIZATION("true"),
            .MEMORY_PRIMITIVE("auto"),
            .MEMORY_SIZE($bits(mem_data_t)*ENTRY_NUM),
            .MESSAGE_CONTROL(1),
            .RAM_DECOMP("auto"),
            .READ_DATA_WIDTH_A($bits(mem_data_t)),
            .READ_DATA_WIDTH_B($bits(mem_data_t)),
            .READ_LATENCY_A(READ_LATENCY),
            .READ_LATENCY_B(READ_LATENCY),
            .READ_RESET_VALUE_A("0"),
            .READ_RESET_VALUE_B("0"),
            .RST_MODE_A("SYNC"),
            .RST_MODE_B("SYNC"),
            .SIM_ASSERT_CHK(1),
            .USE_EMBEDDED_CONSTRAINT(0),
            .WAKEUP_TIME("disable_sleep"),
            .WRITE_DATA_WIDTH_A($bits(mem_data_t)),
            .WRITE_DATA_WIDTH_B($bits(mem_data_t)),
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
            .enb(!(disable_ && state == SQ_WAIT)),
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
        .ADDR_W($clog2(ENTRY_NUM) + $clog2($bits(mem_data_t)/8)),
        .DATA_W($bits(mem_data_t)),
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

    prefetch_cnt_t read_dly_cnt = 0;
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
