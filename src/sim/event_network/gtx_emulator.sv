module gtx_emulator#(
    parameter PROPAGATION_DELAY = 12345.56ns
)(
    input  logic reset,
    gtx_if.gtx   from,
    gtx_if.gtx   to,
    input  logic from_ref_clk,
    input  logic to_ref_clk
);
    assign to.tx_clk     = to_ref_clk;
    assign from.tx_clk   = from_ref_clk;

    always @(from.tx_clk) to.rx_clk     <= #(PROPAGATION_DELAY) from.tx_clk;
    always @(to.tx_clk) from.rx_clk     <= #(PROPAGATION_DELAY) to.tx_clk;

    always @(from.tx_data) to.rx_data   <= #(PROPAGATION_DELAY) from.tx_data;
    always @(from.tx_is_k) to.rx_is_k   <= #(PROPAGATION_DELAY) from.tx_is_k;

    always @(to.tx_data) from.rx_data   <= #(PROPAGATION_DELAY) to.tx_data;
    always @(to.tx_is_k) from.rx_is_k   <= #(PROPAGATION_DELAY) to.tx_is_k;

    initial begin
        from.tx_reset_done <= 0;
        to.tx_reset_done   <= 0;
        from.rx_reset_done <= 0;
        to.rx_reset_done   <= 0;
    end
    always begin
        if(reset) begin
            from.tx_reset_done <= 0;
        end else begin
            repeat (1000) @(posedge from_ref_clk);
            from.tx_reset_done <= 1;
        end
    end
    always begin
        if(reset) begin
            to.tx_reset_done <= 0;
        end else begin
            repeat (1000) @(posedge to_ref_clk);
            to.tx_reset_done <= 1;
        end
    end
    always begin
        if(reset) begin
            from.rx_reset_done <= 0;
        end else begin
            repeat (1000) @(posedge from.rx_clk);
            from.rx_reset_done <= 1;
        end
    end
    always begin
        if(reset) begin
            to.rx_reset_done <= 0;
        end else begin
            repeat (1000) @(posedge to.rx_clk);
            to.rx_reset_done <= 1;
        end
    end

    assign to.aligned   = to.rx_reset_done;
    assign from.aligned = from.rx_reset_done;

endmodule