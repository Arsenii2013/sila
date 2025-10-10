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
    output logic led,
    input  logic sync
);
    localparam CLK_PERIOD = 1000000000/FREQ_HZ;
    localparam COUNT_TO = LED_PERIOD_NS/CLK_PERIOD;
    
    logic [32:0] count=0;
    logic sync_rst_req;
    always_ff @(posedge clk) begin
        if(reset || sync_rst_req) begin
            count   <= 0;
            led     <= 0;
        end
        else
            if(count == COUNT_TO) begin
                led     <= !led;
                count   <= 0;
            end
            else 
                count   <= count+1;
    end

    typedef enum{
        WAIT_LED_POSEDGE,
        WAIT_LED_NEGEDGE,
        READY
    } sync_state_t;

    sync_state_t sync_state;
    logic led_prev;

    assign sync_rst_req = sync_state == READY && sync;

    always_ff @(posedge clk) begin
        if(reset || sync_rst_req) begin
            sync_state <= WAIT_LED_POSEDGE;
        end
        else
            case(sync_state)
                WAIT_LED_POSEDGE: sync_state <= led_prev == 0 && led == 1 ? WAIT_LED_NEGEDGE : WAIT_LED_POSEDGE;
                WAIT_LED_NEGEDGE: sync_state <= led_prev == 1 && led == 0 ? READY            : WAIT_LED_NEGEDGE;
                READY           : sync_state <= READY;
                default         : sync_state <= WAIT_LED_POSEDGE;
            endcase
    end

    always_ff @(posedge clk) led_prev <= led;
endmodule
