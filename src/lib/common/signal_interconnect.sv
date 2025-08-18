
module signal_interconnect #(
    parameter IN_N     = 16,
    parameter OUT_N    = 16,
    parameter PIPELINE = 0
)(
    input  logic  clk,

    input  logic  in[IN_N],
    output logic  out[OUT_N],
    input  logic  map[IN_N][OUT_N]
);

    genvar i;
    generate 
    if(PIPELINE <= 3) begin
        logic in_[IN_N];
        logic out_[IN_N];
        if(PIPELINE >= 2) begin
            always_ff @(posedge clk) in_ <= in;
            always_ff @(posedge clk) out <= out_;
        end else begin
            assign in_ = in;
            assign out = out_;
        end
        if(PIPELINE == 1 || PIPELINE == 3) begin
            logic in_map_anded[IN_N][OUT_N];
            logic out_or[OUT_N];
            for(i = 0; i < OUT_N; i ++) begin
                int j, k;
                always_comb begin 
                    for (j = 0; j < IN_N; j ++) begin
                        in_map_anded[j][i] = in_[j] & map[j][i];
                    end
                end
                always_ff @(posedge clk) begin 
                    out_or[i] = 0;
                    for (k = 0; k < IN_N; k ++) begin
                        out_or[i] |= in_[k] & map[k][i];
                    end
                    out_ <= out_or;
                end
            end
        end else begin
            for(i = 0; i < OUT_N; i ++) begin
                int j;
                always_comb begin 
                    out_[i] = 0;
                    for (j = 0; j < IN_N; j ++) begin
                        out_[i] |= in_[j] & map[j][i];
                    end
                end
            end
        end
    end else begin
        $error("signal_interconnect PIPELINE parameter = %d is not supported", PIPELINE);
    end
    endgenerate
endmodule

module signal_interconnectTB ();
    logic  in2x4[2];
    logic  in4x2[4];
    logic  in4x4[4];
    logic  out2x4[4];
    logic  out4x2[2];
    logic  out4x4[4];
    logic  map2x4[2][4];
    logic  map4x2[4][2];
    logic  map4x4[4][4];

    signal_interconnect #(
        .IN_N(2),
        .OUT_N(4)
    ) DUT2x4 (
        .in(in2x4),
        .out(out2x4),
        .map(map2x4)
    );

    signal_interconnect #(
        .IN_N(4),
        .OUT_N(2)
    ) DUT4x2 (
        .in(in4x2),
        .out(out4x2),
        .map(map4x2)
    );

    signal_interconnect #(
        .IN_N(4),
        .OUT_N(4)
    ) DUT4x4 (
        .in(in4x4),
        .out(out4x4),
        .map(map4x4)
    );

    assign in2x4  = '{1, 0};
    assign in4x2  = '{1, 0, 1, 0};
    assign in4x4  = '{1, 0, 1, 0};

    assign map2x4 = '{'{1, 0, 1, 0},  // первый вход активирует 1 и 3 выход
                      '{1, 1, 1, 1}}; // второй вход активирует все

    assign map4x2 = '{'{0, 0},  // первый не активирует ничего
                      '{0, 1},  // второй - 2 выход
                      '{1, 0},  // третий - 1 выход
                      '{1, 1}}; // четвертный - оба

    assign map4x4 = '{'{1, 0, 0, 0},  // первый вход активриует первый вход
                      '{0, 1, 1, 1},  // второй вход активирует все кроме первого выхода
                      '{0, 1, 0, 1},  // третий вход активирует 2 и 4 выходы
                      '{0, 1, 1, 0}}; // четвертый вход активирует 2 и 3 выход
    initial begin
        #1;
        assert(out2x4 == '{1'b1, 1'b0, 1'b1, 1'b0});
        assert(out4x2 == '{1'b1, 1'b0});
        assert(out4x4 == '{1'b1, 1'b1, 1'b0, 1'b1});
    end
endmodule