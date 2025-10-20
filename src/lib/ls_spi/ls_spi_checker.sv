module ser_checker #(
    parameter unsigned  PARALLEL_W = 32,
    parameter unsigned  SERIAL_W   = 1,
    parameter unsigned  FRONT      = "rise"
) (
    input  logic                   clk,
    input  logic [SERIAL_W  -1: 0] serial_data,
    input  logic [PARALLEL_W-1: 0] parallel_data,
    input  logic                   load
);
    localparam NIBBLE_COUNT = PARALLEL_W / SERIAL_W;
    typedef logic [PARALLEL_W -1: 0] parallel_t;
    typedef logic [SERIAL_W   -1: 0] serial_t;

    parallel_t parallel_data_reg;
    serial_t expected_serial;
    int current_nibble = 0;
    logic busy = 0;

    event front_event;
    generate
    if(FRONT == "rise") begin
        always @(posedge clk) -> front_event;
    end else if(FRONT == "fall") begin
        always @(negedge clk) -> front_event;
    end
    endgenerate

    always @(front_event) begin
        if(load) begin
            parallel_data_reg <= parallel_data;
            current_nibble    <= 0;
            busy              <= 1;
        end else begin
            parallel_data_reg <= {serial_t'(0), parallel_data_reg[PARALLEL_W-1: SERIAL_W]};
            current_nibble    <= current_nibble + 1;
            if(current_nibble == NIBBLE_COUNT - 1) begin
                busy    <= 0;
            end
        end
    end

    assign expected_serial = serial_t'(parallel_data_reg);

    assert property (@(posedge clk) disable iff(!busy) expected_serial == serial_data);
endmodule

module des_checker #(
    parameter unsigned  PARALLEL_W = 32,
    parameter unsigned  SERIAL_W   = 1,
    parameter unsigned  FRONT      = "rise"
) (
    input  logic                   clk,
    input  logic [SERIAL_W  -1: 0] serial_data,
    input  logic [PARALLEL_W-1: 0] parallel_data,
    input  logic                   full
);
    logic [PARALLEL_W-1: 0] parallel_data_reg;

    event front_event;
    generate
    if(FRONT == "rise") begin
        always @(posedge clk) -> front_event;
    end else if(FRONT == "fall") begin
        always @(negedge clk) -> front_event;
    end
    endgenerate

    always @(front_event) begin
        parallel_data_reg <= {serial_data, parallel_data_reg[PARALLEL_W-1: SERIAL_W]};
    end

    assert property (@(posedge full) parallel_data_reg === parallel_data);
endmodule


module ls_spi_checker #(
    parameter unsigned  DATA_W      = 32,
    parameter unsigned  SPI_W       = 1,
    parameter unsigned  PRESCALER   = 2,
    parameter unsigned  FRONT       = "rise",
    parameter string    ALWAYS_SCK  = "no"
)(
    input  logic                clk,
    input  logic                reset,

    input  logic [DATA_W-1: 0]  master_tx_data,
    input  logic [DATA_W-1: 0]  master_rx_data,
    input  logic [DATA_W-1: 0]  slave_tx_data,
    input  logic [DATA_W-1: 0]  slave_rx_data,

    input  logic                master_load,
    input  logic                master_empty,
    input  logic                master_full,
    input  logic                slave_load,
    input  logic                slave_empty,
    input  logic                slave_full,

    input  logic                SCK,
    input  logic [SPI_W -1: 0]  MISO,
    input  logic [SPI_W -1: 0]  MOSI
);
    typedef logic [DATA_W-1: 0] data_t;
    localparam NIBBLE_COUNT = DATA_W / SPI_W;

    ser_checker #(
        .PARALLEL_W(DATA_W),
        .SERIAL_W(SPI_W),
        .FRONT(FRONT)
    ) MOSI_ser_checker (
        .clk(SCK),
        .serial_data(MOSI),
        .parallel_data(master_tx_data),
        .load(master_load)
    );

    ser_checker #(
        .PARALLEL_W(DATA_W),
        .SERIAL_W(SPI_W),
        .FRONT(FRONT)
    ) MISO_ser_checker (
        .clk(SCK),
        .serial_data(MISO),
        .parallel_data(slave_tx_data),
        .load(slave_load)
    );


    des_checker #(
        .PARALLEL_W(DATA_W),
        .SERIAL_W(SPI_W),
        .FRONT(FRONT)
    ) MOSI_des_checker (
        .clk(SCK),
        .serial_data(MOSI),
        .parallel_data(slave_rx_data),
        .full(slave_full)
    );


    des_checker #(
        .PARALLEL_W(DATA_W),
        .SERIAL_W(SPI_W),
        .FRONT(FRONT)
    ) MISO_des_checker (
        .clk(SCK),
        .serial_data(MISO),
        .parallel_data(master_rx_data),
        .full(master_full)
    );

// empty/load golden model
    localparam SCK_HALF_PRD      = PRESCALER / 2;
    localparam SCK_PRD           = PRESCALER;
    localparam NIBBLES_CLK_COUNT = NIBBLE_COUNT * PRESCALER;
    int SCK_posedge_cnt = 0; 
    int SCK_negedge_cnt = 0; 
    generate 
    if(FRONT == "rise") begin
        always @(posedge SCK) SCK_posedge_cnt <= SCK_posedge_cnt + 1;
        always @(negedge SCK) SCK_negedge_cnt <= SCK_negedge_cnt + 1;
    end else begin
        always @(negedge SCK) SCK_posedge_cnt <= SCK_posedge_cnt + 1;
        always @(posedge SCK) SCK_negedge_cnt <= SCK_negedge_cnt + 1;
    end
    endgenerate

    int master_last_load_cnt = -NIBBLE_COUNT, slave_last_load_cnt = -NIBBLE_COUNT;
    always @(posedge clk) begin
        if(reset) begin
            master_last_load_cnt <= -NIBBLE_COUNT;
            slave_last_load_cnt  <= -NIBBLE_COUNT;
        end else begin
            if(master_load) begin
                master_last_load_cnt <= SCK_negedge_cnt;
            end
            if(slave_load) begin
                slave_last_load_cnt <= SCK_negedge_cnt;
            end
        end
    end

    assert property (@(posedge clk) (SCK_negedge_cnt - master_last_load_cnt >= NIBBLE_COUNT - 1) |-> ##[0:SCK_PRD*2] master_empty);
    assert property (@(posedge clk) (SCK_negedge_cnt - slave_last_load_cnt  >= NIBBLE_COUNT - 1) |-> ##[0:SCK_PRD*2] slave_empty);


// transaction checker
    property transaction_control(
        logic  tx_load,
        logic  tx_empty,
        logic  rx_full
    );
        @(posedge clk) tx_load |=> ##[NIBBLES_CLK_COUNT:NIBBLES_CLK_COUNT+SCK_PRD*5] tx_empty ##[SCK_HALF_PRD/2:SCK_HALF_PRD*2] rx_full;
    endproperty
    property transaction_data(
        logic  tx_load,
        logic  rx_full,
        data_t tx_data,
        data_t rx_data
    );
        data_t tx_data_reg;
        @(posedge clk) (tx_load, tx_data_reg = tx_data) |=> ##[NIBBLES_CLK_COUNT:NIBBLES_CLK_COUNT+SCK_PRD*5] (rx_full && rx_data == tx_data_reg);
    endproperty

    assert property (transaction_control(
        master_load,
        master_empty,
        slave_full
    ));
    assert property (transaction_data(
        master_load,
        slave_full,
        master_tx_data,
        slave_rx_data
    ));

    assert property (transaction_control(
        slave_load,
        slave_empty,
        master_full
    ));
    assert property (transaction_data(
        slave_load,
        master_full,
        slave_tx_data,
        master_rx_data
    ));
endmodule