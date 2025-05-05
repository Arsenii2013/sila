module div_tb;

//------------------------------------------------
//`timescale 1ns / 1ps

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

//------------------------------------------------
//
//      Objects
//
logic  clk   = 1'b0;
logic  start = 1'b0;
logic  ready;

data_t n;
data_t d;
data_t q;
data_t r;

//------------------------------------------------
//
//      Logic
//
always #5ns clk <= ~clk;

initial begin
    d = 1;   
    while (1) begin
        n = 1;
        while(1) begin
            @(posedge clk) start <= 1'b1;
            @(posedge clk) start <= 1'b0;
            wait(ready);
            @(posedge clk) $display("%0d / %0d = %0d, reminder  = %0d", n, d, q, r);
            
            if ((n / d != q) || (n % d != r)) begin
                $display("Error");
                $stop();
            end
            
            if (n == 2**DW - 1) break;
            n++;
        end
        if (d == 2**DW - 1) break;
        d++;
    end
    $display("Success");
    $stop();
end

//------------------------------------------------
//
//      Instances
//
div_m #(
    .DW    ( DW    )
)
div
(
    .clk   ( clk   ),
    .rst   ( 1'b0  ),
    
    .start ( start ),
    .ready ( ready ),

    .n     ( n     ),
    .d     ( d     ),
    .q     ( q     ),
    .r     ( r     )
);

//------------------------------------------------
endmodule : div_tb