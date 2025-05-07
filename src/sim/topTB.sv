`timescale 1ns/1ns
`include "top.svh"

module topTB(

    );

    logic [4] led;
    logic     sysclk;

    sys_clk_gen
    #(
        .halfcycle (5000), // 5000 ps = 100 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (sysclk)
    );

    top DUT(
        .sysclk_n(~sysclk),
        .sysclk_p(sysclk),
        .led(led)
    );

initial begin
    #5000;
    $stop();
end
endmodule
