module reset_fanout #(
    parameter N  = 16
) (
    input  logic clk,
    input  logic reset_in,
    output logic reset_out [N]
);
    (* keep = "true" *) logic reset_reg [N];
    genvar reset_i;
    generate
    for(reset_i = 0 ; reset_i < N; reset_i ++) begin : reset_gen
        always_ff @( posedge clk ) reset_reg[reset_i] <= reset_in;
    end
    endgenerate
    assign reset_out = reset_reg;
endmodule