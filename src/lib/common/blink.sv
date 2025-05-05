`timescale 1ns / 1ps
// FREQ_HZ 
module blink
#(
    parameter FREQ_HZ=100000000,
    parameter LED_PERIOD_NS=1000000000 
)
(
    input  logic reset,
    input  logic clk,
    output logic led
);
    localparam CLK_PERIOD = 1000000000/FREQ_HZ;
    localparam COUNT_TO = LED_PERIOD_NS/CLK_PERIOD;
    
    logic [32:0] count=0;
    always_ff @(posedge clk) begin
        if(reset) begin
            count <= 0;
            led <= 0;
        end
        else
            if(count == COUNT_TO) begin
                led <= !led;
                count <= 0;
            end
            else 
                count <= count+1;
    end
endmodule
