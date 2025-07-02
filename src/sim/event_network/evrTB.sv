`timescale 1ns/1ns
`include "top.svh"
`include "evn.svh"

module evrTB(

    );

    logic     sfp_tx_clk;
    logic     sfp_rx_clk;
    logic     app_clk;
    logic     app_rst;
    logic     beacon_clk;

    axi4_lite_if #(.AW(GP0_ADDR_W), .DW(GP0_DATA_W)) mmr();

    axi_stream_if #(.DW(32)) in_packet();
    axi_stream_if #(.DW(32)) out_packet();

    sys_clk_gen
    #(
        .halfcycle (2857), // 5000 ps = 125 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (sfp_tx_clk)
    );
    assign #1.5ns sfp_rx_clk = sfp_tx_clk;

    sys_clk_gen
    #(
        .halfcycle (2856.5), // 2856.5 ps ~ 175_039_383  Hz
        .offset    (0)
    ) CLK_GEN2 (
        .sys_clk (beacon_clk)
    );

    int trig_cnt = 0;
    logic [23:0] trig;
    always_ff @(posedge app_clk) begin
        if(trig_cnt == 0) begin
            trig     <= 'h123456;
            trig_cnt <= 4;
        end else begin
            trig     <= '0;
            trig_cnt <= trig_cnt - 1;
        end
    end

    logic         tx_resetdone = 0;
    logic [31: 0] tx_data;
    logic [ 3: 0] tx_charisk;
    logic         rx_resetdone = 0;
    logic [31: 0] rx_data;
    logic [ 3: 0] rx_charisk;
    logic [31: 0] rx_usr_data = 0;
    logic [ 3: 0] rx_usr_charisk = 0;

    logic user_transaction = 0;

    beacon_cnt_t beacon_cnt = BEACON_PERIOD;
    logic        beacon_req;
    logic        event_req;

    assign  beacon_req = beacon_cnt == 0;
    assign  event_req  = beacon_cnt[2:0] == 0;

    always_ff @(posedge sfp_rx_clk) begin
        if(app_rst) begin
            beacon_cnt   <= BEACON_PERIOD;
        end else begin
            if(beacon_cnt == 0) begin
                beacon_cnt   <= BEACON_PERIOD;
            end else begin
                beacon_cnt   <= beacon_cnt - 1;
            end
        end
    end

    always_comb begin
        if(user_transaction) begin
            rx_data     = rx_usr_data;
            rx_charisk  = rx_usr_charisk;
        end else begin
            if(beacon_req) begin
                rx_data     = BEACON_WORD;
                rx_charisk  = BEACON_IS_K;
            end else if(event_req) begin
                rx_data     = {EVENT_COMMA, 24'h123456};
                rx_charisk  = 'h8;
            end else begin
                rx_data     = '0;
                rx_charisk  = '0;
            end
        end
    end

    evr DUT(
        .beacon_clk(beacon_clk),

        //------GTP signals-------
        .aligned(~app_rst),

        .tx_resetdone(~app_rst),
        .tx_clk(sfp_tx_clk),
        .tx_data(tx_data),
        .tx_charisk(tx_charisk),

        .rx_resetdone(~app_rst),
        .rx_clk(sfp_rx_clk),
        .rx_data(rx_data),
        .rx_charisk(rx_charisk),

        //------Application signals-------
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        
        .ev(), 
        .trig(trig),
        .in_packet(in_packet),
        .out_packet(out_packet)
    );

    axi_master axi_master_i(
        .aclk(app_clk),
        .aresetn(app_rst),
        .axi(mmr)
    );

    logic [31:0] status;
    logic [31:0] topo_id;
    logic [31:0] measured_delay;
    logic [31:0] delay_comp;

    initial begin
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;

        #100us;
        user_transaction <= 1;
        @(posedge app_clk);
        rx_usr_data    <= TOPO_ID_PACKET_START;
        rx_usr_charisk <= PACKET_START_IS_K;
        @(posedge app_clk);
        rx_usr_data    <= 'h123456789;
        rx_usr_charisk <= 'h0;
        @(posedge app_clk);
        rx_usr_data    <= TOPO_ID_PACKET_START + 'h123456789;
        rx_usr_charisk <= 'h0;
        @(posedge app_clk);
        rx_usr_data    <= '0;
        rx_usr_charisk <= '0;

        @(posedge app_clk);
        rx_usr_data    <= MEAS_DELAY_PACKET_START;
        rx_usr_charisk <= PACKET_START_IS_K;
        @(posedge app_clk);
        rx_usr_data    <= 'h1001000; // 64,5 такта
        rx_usr_charisk <= 'h0;
        @(posedge app_clk);
        rx_usr_data    <= 'h7; // fine
        rx_usr_charisk <= 'h0;
        @(posedge app_clk);
        rx_usr_data    <= MEAS_DELAY_PACKET_START + 'h1001000 + 'h7;
        rx_usr_charisk <= 'h0;
        @(posedge app_clk);
        rx_usr_data    <= '0;
        rx_usr_charisk <= '0;

        @(posedge app_clk);
        rx_usr_data    <= TGT_DELAY_PACKET_START;
        rx_usr_charisk <= PACKET_START_IS_K;
        @(posedge app_clk);
        rx_usr_data    <= 'h1060000; // 70 тактов
        rx_usr_charisk <= 'h0;
        @(posedge app_clk);
        rx_usr_data    <= TGT_DELAY_PACKET_START + 'h1060000;
        rx_usr_charisk <= 'h0;
        @(posedge app_clk);
        rx_usr_data    <= '0;
        rx_usr_charisk <= '0;
        user_transaction <= 0;

        #10us;
        axi_master_i.write('h04, 'h1);

        $timeformat(-3, 5, " ms");

        wait(DUT.dc_status == 4'h1);
        $display("Get compensation INITIAL state at %t\n", $realtime);
        #100us;
        axi_master_i.read('h00, status);
        axi_master_i.read('h1C, delay_comp);
        $display("EVR status:\t %x", status);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $display("EVR delay comp:\t %e", (delay_comp >> 16) / 175e6);

        wait(DUT.dc_status == 4'h3);
        $display("Get compensation ONE_CYCLE state at %t\n", $realtime);
        #100us;
        axi_master_i.read('h00, status);
        axi_master_i.read('h1C, delay_comp);
        $display("EVR status:\t %x", status);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $display("EVR delay comp:\t %e", (delay_comp >> 16) / 175e6);

        wait(DUT.dc_status == 4'h7);
        $display("Get compensation FINE state at %t\n", $realtime);
        #100us;
        axi_master_i.read('h00, status);
        axi_master_i.read('h1C, delay_comp);
        $display("EVR status:\t %x", status);
        $display("EVR link delay:\t %e", (measured_delay >> 16) / 175e6);
        $display("EVR delay comp:\t %e", (delay_comp >> 16) / 175e6);


        $stop();
    end

endmodule
