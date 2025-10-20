module ls_spi_master #(
    parameter unsigned  DATA_W      = 32,
    parameter unsigned  SPI_W       = 1,
    parameter unsigned  PRESCALER   = 2,
    parameter unsigned  FRONT       = "rise",
    parameter unsigned  FIRST       = "LSB",
    parameter string    ALWAYS_SCK  = "no"
)(
    input  logic                clk,
    input  logic                reset,

    input  logic [DATA_W-1: 0]  tx_data,
    output logic [DATA_W-1: 0]  rx_data,

    input  logic                tx_load,
    output logic                tx_empty,
    output logic                rx_full,
    output logic                busy,

    output logic                SCK,
    input  logic [SPI_W -1: 0]  MISO,
    output logic [SPI_W -1: 0]  MOSI,
    output logic                CS_N
);
    if (DATA_W % SPI_W != 0) begin
        $error("DATA_W must be a multiple of SPI_W");
    end
    if (PRESCALER <= 1) begin
        $error("PRESCALER must be greater than 1");
    end
    if (PRESCALER % 2 != 0) begin
        $error("PRESCALER must be even");
    end
    if (FRONT != "rise" && FRONT != "fall") begin
        $error("FRONT allowed values are rise or fall");
    end
    if (ALWAYS_SCK != "no" && ALWAYS_SCK != "yes") begin
        $error("ALWAYS_SCK allowed values are no or yes");
    end
    localparam NIBBLE_COUNT = DATA_W / SPI_W;

    typedef logic [DATA_W               -1: 0] data_t;
    typedef logic [SPI_W                -1: 0] spi_t;
    typedef logic [$clog2(PRESCALER)    -1: 0] prescaler_t;
    typedef logic [$clog2(NIBBLE_COUNT)   : 0] nibble_cnt_t;
    typedef enum logic [1:0]{
        IDLE,
        START,
        TRANSFER,
        FINISH
    } state_t;

    state_t state = IDLE;
    logic finish = 0;

// Free run SCK prescaler
    prescaler_t psc_cnt = '0;
    logic SCK_iternal = 0;
    always_ff @(posedge clk) begin

        if(psc_cnt == PRESCALER) begin
            psc_cnt <= '0;
        end else begin
            psc_cnt <= psc_cnt + 1;
        end
        if(psc_cnt == 0) begin
            SCK_iternal <= 1;
        end
        if(psc_cnt == PRESCALER / 2) begin
            SCK_iternal <= 0;
        end
    end

// Posedge and negedge of free run SCK
    logic SCK_posedge;
    logic SCK_negedge;
    logic SCK_iternal_prev;
    always_ff @(posedge clk) SCK_iternal_prev <= SCK_iternal;
    assign SCK_posedge = SCK_iternal  && !SCK_iternal_prev;
    assign SCK_negedge = !SCK_iternal && SCK_iternal_prev;

    logic drive_front, sample_front;
    generate
    if(FRONT == "rise") begin
        assign drive_front = SCK_negedge;
        assign sample_front = SCK_posedge;
    end else if(FRONT == "fall") begin
        assign drive_front = SCK_posedge;
        assign sample_front = SCK_negedge;
    end
    endgenerate


// SCK gate
    logic SCK_gate;
    generate
    if(ALWAYS_SCK == "yes") begin
        assign SCK_gate = 1;
    end else begin
        assign SCK_gate = state == TRANSFER || state == FINISH;
    end
    endgenerate

    assign SCK = SCK_gate ? SCK_iternal : 0;

// State logic
    logic tx_load_reg = 0;
    always_ff @(posedge clk) begin
        if(reset) begin
            tx_load_reg <= 0;
        end else if(tx_load) begin
            tx_load_reg <= 1;
        end else if(state == START) begin
            tx_load_reg <= 0;
        end
    end

    assign busy     = state != IDLE;
    assign CS_N     = state != IDLE;
    always_ff @(posedge clk) begin
        if(reset) begin
            state <= IDLE;
        end else begin
            case(state)
            IDLE        : state <= tx_load_reg ? START     : IDLE;
            START       : state <= drive_front ? TRANSFER  : START;
            TRANSFER    : state <= tx_empty    ? FINISH    : TRANSFER;
            FINISH      : state <= drive_front ? 
                                  (tx_load_reg ? START     : IDLE)
                                                           : FINISH;
            endcase
        end
    end

// TX logic 
    data_t tx_data_buf = 0;
    always_ff @(posedge clk) begin
        if(tx_load) begin
            tx_data_buf <= tx_data;
        end
    end

    nibble_cnt_t tx_cnt = 0;
    assign MOSI = spi_t'(tx_data_buf);

    always_ff @(posedge clk) begin
        if(tx_load || reset) begin
            tx_cnt      <= 0;
        end else if(drive_front && state == TRANSFER) begin
            tx_cnt      <= tx_cnt + 1;
            tx_data_buf <= {spi_t'(0), tx_data_buf[DATA_W-1: SPI_W]};
        end
    end

    logic tx_empty_reg = 1;
    assign tx_empty = tx_empty_reg;
    always_ff @(posedge clk) begin
        if(reset) begin
            tx_empty_reg <= 1;
        end else begin
            if(tx_load)
                tx_empty_reg <= 0;
            else if(tx_cnt == NIBBLE_COUNT - 1)
                tx_empty_reg <= 1;
        end
    end

// RX logic 
    logic rx_full_reg_0 = 0, rx_full_reg_1 = 0, rx_full_reg_2 = 0;
    always_ff @(posedge clk) rx_full_reg_1 <= rx_full_reg_0;
    always_ff @(posedge clk) rx_full_reg_2 <= rx_full_reg_1;
    assign rx_full = rx_full_reg_2;

    always_ff @(posedge clk) begin
        if(reset) begin
            rx_full_reg_0 <= 0;
        end else begin
            if(tx_load) begin
                rx_full_reg_0 <= 0;
                rx_full_reg_1 <= 0;
                rx_full_reg_2 <= 0;
            end else if(tx_empty && sample_front) begin
                rx_full_reg_0 <= 1;
                rx_full_reg_1 <= rx_full_reg_0;
                rx_full_reg_2 <= rx_full_reg_1;
            end else begin
                rx_full_reg_0 <= rx_full_reg_0;
                rx_full_reg_1 <= rx_full_reg_0;
                rx_full_reg_2 <= rx_full_reg_1;
            end
        end
    end

    data_t rx_data_buf;
    always_ff @(posedge clk) begin
        if(!rx_full_reg_1 && rx_full_reg_0) begin
            rx_data <= rx_data_buf;
        end
    end

    always_ff @(posedge clk) begin
        if(sample_front) begin
            rx_data_buf <= {MISO, rx_data_buf[DATA_W-1: SPI_W]};
        end
    end
endmodule