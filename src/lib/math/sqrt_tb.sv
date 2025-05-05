module sqrt_tb;

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Parameters
//
localparam DW = 8;

//------------------------------------------------
//
//      Types
//
typedef logic [DW-1:0] data_t;

typedef struct {
    logic  start;
    logic  ready;
    data_t r;
    data_t q;
} sqrt_t;

//------------------------------------------------
//
//      Objects
//
logic  clk = 1'b0;
sqrt_t sqrt;

//------------------------------------------------
//
//      Logic
//
always #5ns clk <= ~clk;

initial begin
    sqrt.start = 0;
    sqrt.r     = 0;
    #100ns;
    while(1) begin
        @(posedge clk) sqrt.start <= 1;
        wait (~sqrt.ready);
        @(posedge clk) sqrt.start <= 0;
        wait (sqrt.ready);

        $display("sqrt(%0d) = %0d", sqrt.r, sqrt.q);
        if (sqrt.q != $floor($sqrt(sqrt.r)))
            $display("Error: sqrt(%0d) = %0d, exppected %0d", sqrt.r, sqrt.q, $sqrt(sqrt.r));

        if (sqrt.r != '1)
            sqrt.r++;
        else
            break;
    end
    $display("Success!");
    $stop();
end

//------------------------------------------------
//
//      instances
//
sqrt_m #(.DW(DW)) sqrt_dut
(
    .clk   ( clk        ),
    .rst   ( 0          ),
    .start ( sqrt.start ),
    .ready ( sqrt.ready ),
    .r     ( sqrt.r     ),
    .q     ( sqrt.q     )
);

//------------------------------------------------
endmodule : sqrt_tb