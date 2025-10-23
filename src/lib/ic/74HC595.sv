module sn74hc595_controller #(
    parameter int unsigned CASCADE_LEN      = 1,
    parameter int unsigned SRCLK_PRESCALER  = 1000
)(
    input  logic clk,
    input  logic reset,

    input  logic [7: 0] Q [CASCADE_LEN],
    input  logic send_Q,

    output logic SER,
    output logic RCLK,
    output logic SRCLK,
    output logic OE_N,
    output logic SRCLR_N
);
    typedef logic [7                    : 0] spi_data_t;
    typedef logic [$clog2(CASCADE_LEN)  : 0] ic_number_t;

    assign OE_N    = 0;
    assign SRCLR_N = 0;

    logic spi_enable, spi_load = 0, spi_empty, spi_busy;
    spi_data_t spi_data_out;

    typedef enum logic [1:0] {
        WAIT,
        TX,
        RCLK_PULSE,
        WAIT_RCLK
    } state_t;

    state_t state = WAIT, next_state;

    ic_number_t next_ic = '0;

    always_ff @(posedge clk) begin
        if(reset) begin
            state   <= WAIT;
            next_ic <= '0;
        end else begin
            state <= next_state;
            if(state == TX) begin
                spi_load <= 0;
                if(spi_empty && !spi_load && next_ic != CASCADE_LEN) begin
                    spi_load        <= 1;
                    next_ic         <= next_ic + 1;
                    spi_data_out    <= Q[next_ic];
                end
            end else if(state == WAIT) begin
                next_ic <= '0;
            end
        end
    end

    logic send_Q_reg = 0;
    always_ff @(posedge clk) begin
        if(reset) begin
            send_Q_reg <= 0;
        end else begin
            if(send_Q) begin
                send_Q_reg <= 1;
            end else if(state == WAIT) begin
                send_Q_reg <= 0;
            end
        end
    end

    always_comb begin
        case (state)
            WAIT        : next_state = send_Q_reg                           ? TX            : WAIT;
            TX          : next_state = next_ic == CASCADE_LEN && !spi_busy  ? RCLK_PULSE    : TX;
            RCLK_PULSE  : next_state = WAIT_RCLK;
            WAIT_RCLK   : next_state = !RCLK                                ? WAIT          : WAIT_RCLK;
            default     : next_state = WAIT;
        endcase
    end

    assign spi_enable = state == TX;
    ls_spi_master #(
        .PRESCALER(SRCLK_PRESCALER), 
        .CPOL(0),
        .DATA_WIDTH(8)
    ) ls_spi_master_inst (
        .SCK(SRCLK),
        .MOSI(SER),
        .MISO(0),
    
        .clk(clk),
        .rst(reset),
        .enable(spi_enable),
        .load(spi_load),
        .data_in(spi_data_out),
        .data_out(),
    
        .busy(spi_busy),
        .dre(spi_empty),
        .stc()
    );

    pf_m #(
        .WIDTH(SRCLK_PRESCALER / 2),
        .POR("OFF")
    ) SRCLK_pf (
        .clk(clk),
        .in(state == RCLK_PULSE),
        .out(RCLK)
    );

endmodule

module sn74hc595_emulator (
    output logic [7: 0] Q,
    output logic        Q_H_backtick,

    input  logic SER,
    input  logic RCLK,
    input  logic SRCLK,
    input  logic OE_N,
    input  logic SRCLR_N
);
    typedef logic [7: 0] Q_t;

    Q_t shift_reg = 0;
    always_ff @(posedge SRCLK) begin
        if(SRCLR_N == 0) 
            shift_reg <= '0;
        else
            shift_reg <= {shift_reg[6:0], SER};
    end

    Q_t Q_reg = 0;
    always_ff @(posedge RCLK) begin
        Q_reg <= shift_reg;
    end

    Q_t Q_tri;
    assign Q_tri = OE_N == 0 ? Q_reg : 8'bz;

    assign Q            = Q_tri;
    assign Q_H_backtick = shift_reg[7];
endmodule


