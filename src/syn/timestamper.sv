module timestamper #(
    parameter CYCLE_CNT_WIDTH = 64,
    parameter PULSE_CNT_WIDTH = 32
) (
    input  logic                        app_clk,
    input  logic                        app_rst,
    axi4_lite_if.s                      mmr,

    input  logic [CYCLE_CNT_WIDTH-1:0]  cycle_start_val,
    output logic [CYCLE_CNT_WIDTH-1:0]  cycle_cnt,
    output logic [PULSE_CNT_WIDTH-1:0]  pulse_cnt,
    input  logic [23:0]                 ev
);
    typedef logic [23               :0] ev_t;
    typedef logic [CYCLE_CNT_WIDTH-1:0] cycle_cnt_t;
    typedef logic [PULSE_CNT_WIDTH-1:0] pulse_cnt_t;

    logic cycle_overflow, pulse_overflow;
    logic error_clrl;
    logic stop;
    logic pulse_inc, pulse_set;
    ev_t pulse_inc_ev, pulse_set_ev;
    pulse_cnt_t pulse_set_val;

    assign pulse_inc = pulse_inc_ev != 0 && ev == pulse_inc_ev;
    assign pulse_set = pulse_set_ev != 0 && ev == pulse_set_ev;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            cycle_cnt      <= cycle_start_val;
            pulse_cnt      <= '0;
            cycle_overflow <= 0;
            pulse_overflow <= 0;
        end else begin
            if (stop) begin
                cycle_cnt <= cycle_cnt;
                pulse_cnt <= pulse_cnt;
            end else if(pulse_set) begin
                cycle_cnt <= cycle_start_val;
                pulse_cnt <= pulse_set_val;
            end else if(pulse_inc) begin
                cycle_cnt <= cycle_start_val;
                pulse_cnt <= pulse_cnt + 1;
                if(pulse_cnt == '1)
                    pulse_overflow <= 1;
            end else begin
                cycle_cnt <= cycle_cnt + 1;
                pulse_cnt <= pulse_cnt;
                if(cycle_cnt == '1)
                    cycle_overflow <= 1;
            end
            if(error_clrl) begin 
                cycle_overflow <= 0;
                pulse_overflow <= 0;
            end
        end
    end

    timestamper_axi_core_pkg::timestamper_axi_core__in_t  hwif_in;
    timestamper_axi_core_pkg::timestamper_axi_core__out_t hwif_out;

    assign stop                           = hwif_out.cr.stop.value;
    assign error_clrl                     = hwif_out.cr.clear_err.value | hwif_out.cr_s.clear_err.value;
    assign hwif_in.sr.cycle_overflow.next = cycle_overflow;
    assign hwif_in.sr.pulse_overflow.next = pulse_overflow;
    assign hwif_in.cr.stop.next           = (hwif_out.cr.stop.value | hwif_out.cr_s.stop.value) & ~hwif_out.cr_c.stop.value;
    assign hwif_in.cr.clear_err.next      = 0;
    assign hwif_in.cr_s.stop.next         = 0;
    assign hwif_in.cr_c.stop.next         = 0;
    assign hwif_in.cr_s.clear_err.next    = 0;
    assign hwif_in.cr_c.clear_err.next    = 0;

    assign hwif_in.pulse_cnt.pulse_cnt.next          = pulse_cnt;
    assign hwif_in.cycle_cnt_low.cycle_cnt_low.next  = cycle_cnt[31:0];
    assign hwif_in.cycle_cnt_high.cycle_cnt_high.next = cycle_cnt[63:32];
    
    assign pulse_inc_ev  = hwif_out.ev_pulse_inc.ev_pulse_inc.value;
    assign pulse_set_val = hwif_out.tgt_pulse.tgt_pulse.value;
    assign pulse_set_ev  = hwif_out.ev_tgt_set.ev_tgt_set.value;

    timestamper_axi_core timestamper_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule

module timestamperTB(

);
    logic app_clk;
    logic app_rst = 0;
    logic [23:0] ev = 0;
    
    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    axi4_lite_if #(.AW(32), .DW(32)) mmr();


    axi_master axi_master(
        .aclk(app_clk),
        .aresetn(app_rst),
        .axi(mmr)
    );

    timestamper #(
        .CYCLE_CNT_WIDTH(12), // для скорейшего переполнения 
        .PULSE_CNT_WIDTH(4)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .cycle_start_val('h12),
        .ev(ev)
    );

    initial begin
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;
        #10us;
        axi_master.write('h1c, 'h1);
        axi_master.write('h20, 'hd);
        axi_master.write('h24, 'h2);
        @(posedge app_clk);
        ev <= 'h1;
        @(posedge app_clk);
        ev <= '0;
        #10us;
        @(posedge app_clk);
        ev <= 'h2;
        @(posedge app_clk);
        ev <= '0;
        #10us;
        @(posedge app_clk);
        ev <= 'h1;
        @(posedge app_clk);
        ev <= '0;
        #10us;
        axi_master.write('h08, 'h2);
        #10us;
        axi_master.write('h0c, 'h2);
        @(posedge DUT.cycle_overflow);
        axi_master.write('h08, 'h1);
        #10us;
        @(posedge app_clk);
        ev <= 'h1;
        @(posedge DUT.pulse_overflow);
        @(posedge app_clk);
        ev <= '0;
        axi_master.write('h08, 'h1);
        #10us;
        $stop();
    end
endmodule