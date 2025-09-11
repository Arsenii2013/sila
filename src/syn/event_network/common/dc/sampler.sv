module sampler #(
    parameter INT_W           = 16,
    parameter BEACON_PERIOD_W = 10
)
(
    input  logic                     beacon_tx,
    input  logic                     tx_clk,
    input  logic                     beacon_rx,
    input  logic                     rx_clk,
    input  logic                     beacon_clk,

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

    logic beacon_rx_sync;
    logic beacon_tx_sync;

    beacon_cdc beacon_cdc_i(
        .beacon_tx(beacon_tx),
        .tx_clk(tx_clk),
        .beacon_rx(beacon_rx),
        .rx_clk(rx_clk),
        .beacon_clk(beacon_clk),
        .beacon_rx_sync(beacon_rx_sync),
        .beacon_tx_sync(beacon_tx_sync)
    );

    logic app_rst_pulse;
    pf_m #(
        .WIDTH(10)
    ) pf_beacon_rst (
        .clk(app_clk),
        .in(app_rst),
        .out(app_rst_pulse)
    );


    xpm_cdc_async_rst beacon_rst_sunchronizer_i(
        .dest_clk(beacon_clk),
        .dest_arst(beacon_rst),
        .src_arst(app_rst_pulse)
    );

    logic fine_sync;

    xpm_cdc_single fine_sunchronizer_i(
        .dest_clk(beacon_clk),
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
        .src_clk(beacon_clk),
        .src_pulse(sample_upd_sync),
        .src_rst(beacon_rst)
    );
    xpm_cdc_pulse error_sunchronizer_i(
        .dest_clk(app_clk),
        .dest_pulse(error),
        .dest_rst(app_rst),
        .src_clk(beacon_clk),
        .src_pulse(error_sync),
        .src_rst(beacon_rst)
    );


    ila_1 ila(
        .clk(app_clk),
        .probe0(error_sync),
        .probe1(error),
        .probe2(beacons_over),
        .probe3(app_rst),
        .probe4(beacon_rst)
    );

    logic       no_beacons;
    logic       beacons_over;
    sample_t    current_cnt = '0;
    sample_t    sample_cnt;

    always_ff @(posedge beacon_clk) begin
        if (beacon_rst) begin
            current_cnt     <= '0;
        end else begin
            current_cnt <= current_cnt + 1;
        end
    end

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
    ) xpm_fifo_async_inst (
        .rd_en(beacon_rx_sync && ~no_beacons),
        .dout(sample_cnt),

        .wr_clk(beacon_clk),
        .wr_en(beacon_tx_sync),
        .din(current_cnt),

        .empty(no_beacons),
        .prog_full(beacons_over),
        .rst(beacon_rst)
    );


    state_t     state = mfsmINITIAL;

    sample_t    prev_sample = '0;

    logic sample_valid;

    always_ff @(posedge beacon_clk) begin
        if (beacon_rst) begin
            state           <= mfsmINITIAL;
            sample          <= '0;
            prev_sample     <= '0;
            sample_upd_sync <= '0;
            error_sync      <= '0;
        end
        else begin
            case (state)
                mfsmINITIAL: begin 
                    if (beacon_rx_sync)
                        state <= mfsmWAIT;
                end
                mfsmWAIT: begin 
                    sample_upd_sync <= 0;
                    if (beacon_rx_sync)
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
    input  logic beacon_tx,
    input  logic tx_clk,
    input  logic beacon_rx,
    input  logic rx_clk,
    input  logic beacon_clk,
    output logic beacon_tx_sync,
    output logic beacon_rx_sync
);
    logic       beacon_rx_expand;
    logic [1:0] beacon_rx_cnt = '0;

    assign beacon_rx_expand = beacon_rx_cnt != 'b0;

    always_ff @(posedge rx_clk) begin
        if(beacon_rx) 
            beacon_rx_cnt <= 2'b11;
        else
            if(beacon_rx_cnt != 2'b0)
                beacon_rx_cnt <= beacon_rx_cnt - 1;         
    end

    xpm_cdc_pulse beacon_rx_sunchronizer_i(
        .dest_clk(beacon_clk),
        .dest_pulse(beacon_rx_sync),
        .dest_rst(1'b0),
        .src_clk(rx_clk),
        .src_pulse(beacon_rx_expand),
        .src_rst(1'b0)
    );


    logic       beacon_tx_expand;
    logic [1:0] beacon_tx_cnt = '0;

    assign beacon_tx_expand = beacon_tx_cnt != 'b0;

    always_ff @(posedge tx_clk) begin
        if(beacon_tx) 
            beacon_tx_cnt <= 2'b11;
        else
            if(beacon_tx_cnt != 2'b0)
                beacon_tx_cnt <= beacon_tx_cnt - 1;         
    end

    xpm_cdc_pulse beacon_tx_sunchronizer_i(
        .dest_clk(beacon_clk),
        .dest_pulse(beacon_tx_sync),
        .dest_rst(1'b0),
        .src_clk(tx_clk),
        .src_pulse(beacon_tx_expand),
        .src_rst(1'b0)
    );
endmodule