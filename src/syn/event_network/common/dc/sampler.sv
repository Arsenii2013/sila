module sampler #(
    parameter INT_W           = 16,
    parameter BEACON_PERIOD_W = 10
)
(
    input  logic                     start,
    input  logic                     start_clk,
    input  logic                     stop,
    input  logic                     stop_clk,
    input  logic                     measure_clk,

    input  logic                     app_clk,
    input  logic                     app_rst,
    input  logic                     fine,
    output logic                     sample_upd,
    output logic [INT_W       -1: 0] sample,
    output logic                     error
);
    localparam BEACON_CNT_W   = INT_W - BEACON_PERIOD_W;
    localparam BEACON_CNT_MAX = 2**BEACON_CNT_W - 1;

    typedef enum
    {
        mfsmINITIAL,
        mfsmWAIT,
        mfsmWAITFIFO,
        mfsmCHECK
    } state_t;

    typedef logic [INT_W       -1: 0] sample_t;

    logic stop_sync;
    logic start_sync;

    beacon_cdc beacon_cdc_i(
        .start(start),
        .start_clk(start_clk),
        .stop(stop),
        .stop_clk(stop_clk),
        .measure_clk(measure_clk),
        .stop_sync(stop_sync),
        .start_sync(start_sync)
    );

    logic app_rst_pulse;
    pf_m #(
        .WIDTH(10)
    ) pf_beacon_rst (
        .clk(app_clk),
        .in(app_rst),
        .out(app_rst_pulse)
    );

    logic beacon_rst;
    xpm_cdc_async_rst beacon_rst_sunchronizer_i(
        .dest_clk(measure_clk),
        .dest_arst(beacon_rst),
        .src_arst(app_rst || app_rst_pulse) // для синхронизации ресет должен быть не меньше ~10 тактов. он формируется в pulse
                                            // но если ресет больше 10 тактов то rst продолжит его держать
    );

    logic fine_sync;

    xpm_cdc_single fine_sunchronizer_i(
        .dest_clk(measure_clk),
        .dest_out(fine_sync),
        .src_clk(app_clk),
        .src_in(fine)
    );

    // sample не синхронизовывал, потому что считаю, что 
    // он будет читаться по импульсу sample_upd, 
    // который в свою очередь синхронизуется 4 такта
    // и sample успеет установиться за это время

    logic sample_upd_sync = 0;
    logic error_sync = 0;

    xpm_cdc_pulse sample_upd_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(sample_upd),
        .dest_rst(app_rst),
        .src_clk(measure_clk),
        .src_pulse(sample_upd_sync),
        .src_rst(beacon_rst)
    );
    xpm_cdc_pulse error_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(error),
        .dest_rst(app_rst),
        .src_clk(measure_clk),
        .src_pulse(error_sync),
        .src_rst(beacon_rst)
    );

    logic       no_beacons;
    logic       beacons_over;
    sample_t    current_cnt = '0;
    sample_t    sample_cnt;

    always_ff @(posedge measure_clk) begin
        if (beacon_rst) begin
            current_cnt     <= '0;
        end else begin
            current_cnt <= current_cnt + 1;
        end
    end

    logic fifo_rst_done, fifo_rd_rst_busy, fifo_wr_rst_busy;
    assign fifo_rst_done = !fifo_rd_rst_busy && !fifo_wr_rst_busy;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),
        .DOUT_RESET_VALUE("0"),
        .FIFO_MEMORY_TYPE("block"),
        .FIFO_READ_LATENCY(1),
        .FIFO_WRITE_DEPTH(2**10),
        .READ_DATA_WIDTH(18),
        .READ_MODE("std"),
        .SIM_ASSERT_CHK(1),
        .WRITE_DATA_WIDTH(18),
        .PROG_FULL_THRESH(BEACON_CNT_MAX)
    ) xpm_fifo_sync_inst (
        .rd_en(fifo_rst_done && stop_sync && ~no_beacons),
        .dout(sample_cnt),

        .wr_clk(measure_clk),
        .wr_en(fifo_rst_done && start_sync),
        .din(current_cnt),

        .empty(no_beacons),
        .prog_full(beacons_over),
        .rst(beacon_rst),
        .rd_rst_busy(fifo_rd_rst_busy),
        .wr_rst_busy(fifo_wr_rst_busy)
    );

    state_t     state = mfsmINITIAL;

    sample_t    prev_sample = '0;

    logic sample_valid;

    always_ff @(posedge measure_clk) begin
        if (beacon_rst || !fifo_rst_done) begin
            state           <= mfsmINITIAL;
            sample          <= '0;
            prev_sample     <= '0;
            sample_upd_sync <= '0;
            error_sync      <= '0;
        end
        else begin
            case (state)
                mfsmINITIAL: begin 
                    if (stop_sync)
                        state <= mfsmWAIT;
                end
                mfsmWAIT: begin 
                    sample_upd_sync <= 0;
                    if (stop_sync)
                        state <= mfsmWAITFIFO;
                    if (beacons_over)
                        state <= mfsmCHECK;
                end
                mfsmWAITFIFO : state <= mfsmCHECK;
                mfsmCHECK: begin
                    if (sample_valid & !beacons_over) begin
                        sample_upd_sync <= 1;
                        sample          <= current_cnt > sample_cnt ? current_cnt - sample_cnt : (sample_t'('1) - sample_cnt) + current_cnt;
                        prev_sample     <= sample;
                    end else begin
                        error_sync      <= 1;
                    end
                    state <= mfsmWAIT;
                end
            endcase
        end
    end

    always_comb begin
        if(fine_sync)
            sample_valid = sample > prev_sample ? sample - prev_sample < sample_t'(4) : prev_sample - sample < sample_t'(4);
        else 
            sample_valid = 1;
    end
endmodule


module beacon_cdc(
    input  logic start,
    input  logic start_clk,
    input  logic stop,
    input  logic stop_clk,
    input  logic measure_clk,
    output logic start_sync,
    output logic stop_sync
);
    logic       stop_expand;
    logic [1:0] stop_cnt = '0;
    logic       stop_sync_expanded;
    logic       stop_sync_expanded_prev;

    always_ff @(posedge stop_clk) stop_expand <= stop_cnt != 'b0;

    always_ff @(posedge stop_clk) begin
        if(stop) 
            stop_cnt <= 2'b11;
        else
            if(stop_cnt != 2'b0)
                stop_cnt <= stop_cnt - 1;         
    end

    xpm_cdc_single #(
        .SRC_INPUT_REG(0)
    ) stop_sunchronizer_i (
        .dest_clk(measure_clk),
        .dest_out(stop_sync_expanded),
        .src_clk(stop_clk),
        .src_in(stop_expand)
    );

    always_ff @(posedge measure_clk) stop_sync_expanded_prev <= stop_sync_expanded;
    assign stop_sync = stop_sync_expanded && !stop_sync_expanded_prev;


    logic       start_expand;
    logic [1:0] start_cnt = '0;
    logic       start_sync_expanded;
    logic       start_sync_expanded_prev;


    always_ff @(posedge start_clk) start_expand <= start_cnt != 'b0;

    always_ff @(posedge start_clk) begin
        if(start) 
            start_cnt <= 2'b11;
        else
            if(start_cnt != 2'b0)
                start_cnt <= start_cnt - 1;         
    end

    xpm_cdc_single #(
        .SRC_INPUT_REG(0)
    ) start_sunchronizer_i (
        .dest_clk(measure_clk),
        .dest_out(start_sync_expanded),
        .src_clk(start_clk),
        .src_in(start_expand)
    );

    always_ff @(posedge measure_clk) start_sync_expanded_prev <= start_sync_expanded;
    assign start_sync = start_sync_expanded && !start_sync_expanded_prev;
endmodule