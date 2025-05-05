module mult_tb;

//------------------------------------------------
`timescale 1ns / 1ps

`define N 10000000

//------------------------------------------------
//
//      Parameters
//
localparam DW = 64;

//------------------------------------------------
//
//      Types
//
typedef logic [  DW-1:0] data_t;
typedef logic [2*DW-1:0] prod_t;

typedef struct {
    logic  start;
    logic  ready;
    data_t a;
    data_t b;
    prod_t p;
} mult64x64_t;

//------------------------------------------------
//
//      Objects
//
logic       clk = 1'b0;
mult64x64_t mult;

//------------------------------------------------
//
//      Logic
//
always #5ns clk <= ~clk;

initial begin
    automatic int cnt = 0;
    mult.start = 0;
    #100ns;
    while(1) begin
        while(1) begin
            mult.a = {$urandom_range(0, 2**32-1),$urandom_range(0, 2**32-1)};
            mult.b = {$urandom_range(0, 2**32-1),$urandom_range(0, 2**32-1)};    

            @(posedge clk) mult.start <= 1;
            wait (~mult.ready);
            @(posedge clk) mult.start <= 0;
            wait (mult.ready);

            $display("%0d: 0x%16x * 0x%16x = 0x%32x", cnt, mult.a, mult.b, mult.p);
            if (prod_t'(mult.a) * prod_t'(mult.b) != mult.p) begin
                $display("\nError: 0x%16x * 0x%16x = 0x%32x, expected 0x%32x\n", mult.a, mult.b, mult.p, prod_t'(mult.a) * prod_t'(mult.b));
                $stop();
            end
            
            cnt++;
            if (cnt == `N) $stop();
        end
    end
end

//------------------------------------------------
//
//      instances
//
mult64x64_m mult64x64_dut
(
    .clk   ( clk        ),
    .rst   ( 0          ),
    .start ( mult.start ),
    .ready ( mult.ready ),
    .a     ( mult.a     ),
    .b     ( mult.b     ),
    .p     ( mult.p     )
);

//------------------------------------------------
endmodule : mult_tb