module mmcm_wrapper(
        input         clk_in1,
        input         clk_in2,
        input         clk_in_sel,
        
        output        clk_out1,

        // Dynamic phase shift ports
        input         psclk,
        input         psen,
        input         psincdec,
        output        psdone,

        // Status and control signals
        input         resetn,
        output        locked
    );
    logic clk_in1_clk_wiz;
    logic clk_in2_clk_wiz;
    IBUF clkin1_ibufg
    (.O (clk_in1_clk_wiz), .I (clk_in1));

    IBUF clkin2_ibufg
    (.O (clk_in2_clk_wiz), .I (clk_in2));


    logic        clk_out1_clk_wiz;

    logic        clkfbout;
    logic        clkfbout_buf;

    logic        locked_int;
    logic        reset_high;

    `ifdef SYNTHESIS // костыль, потому что у mmcm2 в симуляции не работает fine phase shift
    MMCME2_ADV
    `else            // а у mmcm3, работает
    MMCME3_ADV
    `endif
    #(.BANDWIDTH            ("OPTIMIZED"),
        .CLKOUT4_CASCADE      ("FALSE"),
        .COMPENSATION         ("ZHOLD"),
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (1),
        .CLKFBOUT_MULT_F      (5.000),
        .CLKFBOUT_PHASE       (0.000),
        .CLKFBOUT_USE_FINE_PS ("FALSE"),
        .CLKOUT0_DIVIDE_F     (5.000),
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKOUT0_USE_FINE_PS  ("TRUE"),
        .CLKIN1_PERIOD        (8.000),
        .CLKIN2_PERIOD        (8.000)
    )
    mmcm_adv_inst
    (
        .CLKFBOUT            (clkfbout),
        .CLKFBOUTB           (),
        .CLKOUT0             (clk_out1_clk_wiz),
        .CLKOUT0B            (),
        .CLKOUT1             (),
        .CLKOUT1B            (),
        .CLKOUT2             (),
        .CLKOUT2B            (),
        .CLKOUT3             (),
        .CLKOUT3B            (),
        .CLKOUT4             (),
        .CLKOUT5             (),
        .CLKOUT6             (),
        .CLKFBIN             (clkfbout_buf),
        .CLKIN1              (clk_in1_clk_wiz),
        .CLKIN2              (clk_in2_clk_wiz),
        .CLKINSEL            (clk_in_sel),
        .DADDR               (7'h0),
        .DCLK                (1'b0),
        .DEN                 (1'b0),
        .DI                  (16'h0),
        .DO                  (),
        .DRDY                (),
        .DWE                 (1'b0),
        .PSCLK               (psclk),
        .PSEN                (psen),
        .PSINCDEC            (psincdec),
        .PSDONE              (psdone),
        .LOCKED              (locked_int),
        .CLKINSTOPPED        (),
        .CLKFBSTOPPED        (),
        .PWRDWN              (1'b0),
        .RST                 (reset_high)
    );
    assign reset_high = ~resetn; 

    assign locked = locked_int;

    BUFG clkf_buf
    (.O (clkfbout_buf),
        .I (clkfbout));

    BUFG clkout1_buf
    (.O   (clk_out1),
        .I   (clk_out1_clk_wiz));

endmodule


module mmcm_controller
    #(
        parameter PERIOD_NS = 10
    )
    (
        input  logic aresetn,
        input  logic clk,

        input  logic incdec,

        output logic psen,
        output logic psincdec,
        input  logic psdone
    );
    localparam CYCLES = 1000000000 / PERIOD_NS; // clk in one second
    localparam CNT_W  = $clog2(CYCLES);

    typedef enum {
        IDLE,
        WRITE,
        WAIT
    } state_t;

    state_t state, next_state;

    logic [CNT_W-1:0] cnt;


    assign psincdec = incdec;
    assign psen     = state == WRITE;

    always_ff @(posedge clk) begin
    if (!aresetn) begin
        state <= IDLE;
        cnt <= '0;
    end
    else begin
        state <= next_state;
        if(state == IDLE)
            cnt <= cnt + 1;
        else 
            cnt <= '0;
    end
    end 

    always_comb begin
    if (!aresetn) begin
        next_state = IDLE;
    end
    else begin
        case (state)
            IDLE:   next_state = cnt == CYCLES ? WRITE : IDLE;
            WRITE:  next_state = WAIT;
            WAIT:   next_state = psdone ? IDLE : WAIT;
        endcase        
    end
    end


endmodule