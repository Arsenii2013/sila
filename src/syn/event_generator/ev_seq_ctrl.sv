package ev_seq_ctrl_pkg;

import ev_seq_ctrl_axi_core_pkg::*;

localparam ev_seq_ctrl_axi_core__trig_src_t_e TRIG_PROG_EVAL    = ev_seq_ctrl_axi_core__trig_src_t__PROG;
localparam ev_seq_ctrl_axi_core__sq_mode_t_e  MODE_SINGLE_EVAL  = ev_seq_ctrl_axi_core__sq_mode_t__SINGLE;
localparam ev_seq_ctrl_axi_core__sq_mode_t_e  MODE_CYCLE_EVAL   = ev_seq_ctrl_axi_core__sq_mode_t__CYCLE;
localparam ev_seq_ctrl_axi_core__sq_mode_t_e  MODE_RECYCLE_EVAL = ev_seq_ctrl_axi_core__sq_mode_t__RECYCLE;

localparam TRIG_PROG    = unsigned'(TRIG_PROG_EVAL);
localparam MODE_SINGLE  = unsigned'(MODE_SINGLE_EVAL);
localparam MODE_CYCLE   = unsigned'(MODE_CYCLE_EVAL);
localparam MODE_RECYCLE = unsigned'(MODE_RECYCLE_EVAL);

typedef enum{
    PROG    = ev_seq_ctrl_pkg::TRIG_PROG
} trig_source_t;
typedef enum{
    SINGLE  = ev_seq_ctrl_pkg::MODE_SINGLE,
    CYCLE   = ev_seq_ctrl_pkg::MODE_CYCLE,
    RECYCLE = ev_seq_ctrl_pkg::MODE_RECYCLE
} seq_mode_t;

endpackage

module ev_seq_ctrl #(
    parameter EV_WIDTH  = 24,
    parameter EV_SEQ_N  = 1
) (
    input  logic                        app_clk,
    input  logic                        app_rst,
    axi4_lite_if.s                      mmr,

    output logic                        seq_start[EV_SEQ_N],
    output logic                        seq_stop[EV_SEQ_N],
    input  logic                        seq_running[EV_SEQ_N],
    input  logic [EV_WIDTH-1:0]         ev_in[EV_SEQ_N],
    output logic [EV_WIDTH-1:0]         ev_out
);

    import ev_seq_ctrl_pkg::*;
    typedef logic [EV_WIDTH  -1:0] ev_t;

    trig_source_t seq_trig_src      [EV_SEQ_N];
    seq_mode_t    seq_mode          [EV_SEQ_N];
    logic         seq_enable        [EV_SEQ_N];
    logic         seq_sw_enable     [EV_SEQ_N];
    logic         seq_sw_enable_mod [EV_SEQ_N];
    logic         seq_reset         [EV_SEQ_N];

    logic         seq_sw_trig       [EV_SEQ_N];

    ev_t       prog_ev;
    logic      prog_ev_send;
    
    always_comb begin
        ev_out = 0;
        for (int loop_i = EV_SEQ_N-1; loop_i >= 0; loop_i = loop_i - 1) begin 
        if(ev_in[loop_i] != 0)
            ev_out = ev_in[loop_i];
        end
        if(prog_ev_send)
            ev_out = prog_ev;
    end

    genvar sq_ctrl_n;
    generate
    for (sq_ctrl_n = 0; sq_ctrl_n < EV_SEQ_N; sq_ctrl_n = sq_ctrl_n + 1) begin
    seq_control_fsm seq_control_fsm_i(
        .app_clk(app_clk),
        .app_rst(app_rst),

        .sw_enable(seq_sw_enable[sq_ctrl_n]),
        .sw_enable_wr(seq_sw_enable_mod[sq_ctrl_n]),
        .enable(seq_enable[sq_ctrl_n]),
        .reset(seq_reset[sq_ctrl_n]),

        .sw_trig(seq_sw_trig[sq_ctrl_n]),

        .mode(seq_mode[sq_ctrl_n]),
        .trig_src(seq_trig_src[sq_ctrl_n]),

        .start(seq_start[sq_ctrl_n]),
        .stop(seq_stop[sq_ctrl_n]),
        .running(seq_running[sq_ctrl_n])
    );
    end
    endgenerate;

    ev_seq_ctrl_axi_core_pkg::ev_seq_ctrl_axi_core__in_t  hwif_in;
    ev_seq_ctrl_axi_core_pkg::ev_seq_ctrl_axi_core__out_t hwif_out;

    assign hwif_in.sr.seq_running.next  = { << { seq_running }};
    assign hwif_in.cr.seq_enable.next   = { << { seq_enable }};
    assign hwif_in.cr.seq_reset.next    = 0;

    assign hwif_in.cr_s.seq_enable.next  = '0;
    assign hwif_in.cr_s.seq_reset.next   = '0;
    assign hwif_in.cr_c.seq_enable.next  = '0;
    assign hwif_in.cr_c.seq_reset.next   = '0;

    assign hwif_in.prog_ev.send.next    = '0;

    assign prog_ev      = hwif_out.prog_ev.ev.value;
    assign prog_ev_send = hwif_out.prog_ev.send.value;

    logic seq_reset_swmod, seq_enable_swmod, sq_cr_enable_swmod[EV_SEQ_N];

    always_ff @(posedge app_clk) begin
        seq_reset_swmod    <= hwif_out.cr.seq_reset.swmod || hwif_out.cr_s.seq_reset.swmod || hwif_out.cr_c.seq_reset.swmod;
        seq_enable_swmod   <= hwif_out.cr.seq_enable.swmod || hwif_out.cr_s.seq_enable.swmod || hwif_out.cr_c.seq_enable.swmod;
    end

    genvar sq_n;
    generate
    for (sq_n = 0; sq_n < EV_SEQ_N; sq_n ++) begin
    always_ff @(posedge app_clk) begin
        sq_cr_enable_swmod[sq_n] <= hwif_out.seq_regs[sq_n].sq_cr.enable.swmod || hwif_out.seq_regs[sq_n].sq_cr_s.enable.swmod || 
                                     hwif_out.seq_regs[sq_n].sq_cr_c.enable.swmod;
    end
    assign seq_reset[sq_n] = seq_reset_swmod ?
                            (hwif_out.cr.seq_reset.value[sq_n] | hwif_out.cr_s.seq_reset.value[sq_n]) & ~hwif_out.cr_c.seq_reset.value[sq_n] :
                            (hwif_out.seq_regs[sq_n].sq_cr.reset.value | 
                            hwif_out.seq_regs[sq_n].sq_cr_s.reset.value) & 
                            ~hwif_out.seq_regs[sq_n].sq_cr_c.reset.value;
    assign seq_sw_enable[sq_n] = seq_enable_swmod ?
                            (hwif_out.cr.seq_enable.value[sq_n] | hwif_out.cr_s.seq_enable.value[sq_n]) & ~hwif_out.cr_c.seq_enable.value[sq_n] :
                            (hwif_out.seq_regs[sq_n].sq_cr.enable.value | 
                            hwif_out.seq_regs[sq_n].sq_cr_s.enable.value) & 
                            ~hwif_out.seq_regs[sq_n].sq_cr_c.enable.value;
    assign seq_sw_enable_mod[sq_n] = seq_enable_swmod || sq_cr_enable_swmod[sq_n];

    assign hwif_in.seq_regs[sq_n].sq_sr.running.next   = seq_running[sq_n];
    assign hwif_in.seq_regs[sq_n].sq_cr.reset.next     = 0;
    assign hwif_in.seq_regs[sq_n].sq_cr.enable.next    = seq_enable[sq_n];
    assign hwif_in.seq_regs[sq_n].sq_cr.sw_trig.next   = 0;
    assign seq_sw_trig[sq_n]                           = hwif_out.seq_regs[sq_n].sq_cr.sw_trig.value | hwif_out.seq_regs[sq_n].sq_cr_s.sw_trig.value;

    assign hwif_in.seq_regs[sq_n].sq_cr_s.enable.next  = 0;
    assign hwif_in.seq_regs[sq_n].sq_cr_s.reset.next   = 0;
    assign hwif_in.seq_regs[sq_n].sq_cr_c.enable.next  = 0;
    assign hwif_in.seq_regs[sq_n].sq_cr_c.reset.next   = 0;
    assign hwif_in.seq_regs[sq_n].sq_cr_s.sw_trig.next = 0;
    assign hwif_in.seq_regs[sq_n].sq_cr_c.sw_trig.next = 0;

    assign seq_trig_src[sq_n] = trig_source_t'(hwif_out.seq_regs[sq_n].trig.src.value);
    assign seq_mode[sq_n]     = seq_mode_t'(hwif_out.seq_regs[sq_n].mode.mode.value);
    end
    endgenerate;

    ev_seq_ctrl_axi_core ev_seq_ctrl_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );
endmodule

module seq_control_fsm(
    input  logic app_clk,
    input  logic app_rst,

    input  logic sw_enable,
    input  logic sw_enable_wr,
    input  logic sw_trig,
    output logic enable,
    input  logic reset,

    input  ev_seq_ctrl_pkg::seq_mode_t    mode,
    input  ev_seq_ctrl_pkg::trig_source_t trig_src,

    output logic start,
    output logic stop,
    input  logic running
);
    import ev_seq_ctrl_pkg::*;

    typedef enum{
        DISABLED,
        ARMED,
        START,
        TRIGGERED
    } control_fsm_state_t;

    logic trig = 0;

    control_fsm_state_t state = DISABLED, next;

    logic prev_running    = 0;
    logic running_posedge;
    logic running_negedge;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            prev_running <= 0;
        end else begin
            prev_running <= running;
        end
    end
    assign running_posedge = running & ~prev_running;
    assign running_negedge = ~running & prev_running;

    assign start = state == START;
    assign stop  = reset;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            trig   <= 0;
            enable <= 0;
            state  <= DISABLED;
        end else begin
            state <= next;
            if(!running && enable) begin // установка триггеров только когда не запущен
                if(trig_src == PROG && sw_trig)
                    trig <= 1;
                if(running_negedge && mode == RECYCLE)
                    trig <= 1;
            end

            if(running_posedge) begin // сброс триггера и разрешения по запуску
                if(mode == SINGLE)
                    enable <= 0;
                trig   <= 0;
            end

            if(sw_enable_wr) begin
                enable <= sw_enable;
            end

            if(reset) begin // сброс разрешения 
                enable <= 0;
                trig   <= 0;
            end
        end 
    end

    always_comb begin
        case (state)
            DISABLED  : begin
                if(enable)
                    next = ARMED;
                else
                    next = DISABLED;
            end
            ARMED     : begin
                if(!enable)
                    next = DISABLED;
                else if(trig)
                    next = START;
                else 
                    next = ARMED;
            end
            START     : begin
                if(running)
                    next = TRIGGERED;
                else 
                    next = START;
            end
            TRIGGERED : begin
                if(!running)
                    next = DISABLED;
                else 
                    next = TRIGGERED;
            end
            default   : next = DISABLED;
        endcase
    end
endmodule


`ifndef SYNTHESIS
module ev_seq_ctrlTB();
    localparam SEQ_NUM = 2;
    logic app_clk;
    logic app_rst = 0;
    logic [23:0] ev_in[SEQ_NUM];
    logic [23:0] ev_out;
    logic start   [SEQ_NUM];
    logic stop    [SEQ_NUM];
    logic running [SEQ_NUM];
    
    sys_clk_gen
    #(
        .halfcycle (2857), // 5714 ps = 175 MHz
        .offset    (0)
    ) CLK_GEN (
        .sys_clk (app_clk)
    );

    axi4_lite_if #(.AW(32), .DW(32)) mmrSEQ[SEQ_NUM]();
    axi4_lite_if #(.AW(32), .DW(32)) mmrDUT();

    genvar i;
    generate
    for(i = 0; i < SEQ_NUM; i++) begin : seq_inst
    ev_seq #(
        .EV_WIDTH(24),
        .CNT_WIDTH(64),
        .ENTRY_NUM(2048)
    ) sequencer1 (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmrSEQ[i]),
        .ev(ev_in[i]),
        .start(start[i]),
        .stop(stop[i]),
        .running(running[i])
    );
    seq_writer #(
        .EV_N(9)
    ) seq_writer (
        .aclk(app_clk),
        .areset(app_rst),
        .axi(mmrSEQ[i])
    );
    end
    endgenerate


    ev_seq_ctrl #(
        .EV_WIDTH(24),
        .EV_SEQ_N(SEQ_NUM)
    ) DUT (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmrDUT),

        .seq_start(start),
        .seq_stop(stop),
        .seq_running(running),
        .ev_in(ev_in),
        .ev_out(ev_out)
    );
    axi_master axi_master(
        .aclk(app_clk),
        .aresetn(app_rst),
        .axi(mmrDUT)
    );

    ev_recv ev_recv_i(
        .aclk(app_clk),
        .areset(app_rst),
        .ev(ev_out)
    );
    logic [31:0] rd_data;
    int test_number = 0;
    initial begin
        reset();
        #1us;
        seq_inst[0].seq_writer.write_seq('{'h1, 'h2, 'h3, 'h4, 'h10, 'h20, 'h40, 'h80, 'h1234},
                                         '{  0,   1,   2,   3,   10,   20,   40,   80,   8000});
        seq_inst[1].seq_writer.write_seq('{'h11, 'h12, 'h13, 'h14, 'h110, 'h120, 'h140, 'h180, 'h11234},
                                         '{   0,    1,    2,    3,    10,    20,    40,    80,    8000});
        $display("Start GENERIC test");
        test_number <= test_number + 1;
        axi_master.check('h00, 'h0); // running
        axi_master.check('h20, 'h0); // running
        axi_master.check('h3c, 'h0); // running

        axi_master.write('h08, 'h1); // cr_s enable 
        axi_master.check('h04, 'h1); // cr enable
        axi_master.check('h24, 'h1); // sq_cr enable 

        axi_master.write('h0c, 'h1); // cr_c enable
        axi_master.check('h04, 'h0); // cr enable
        axi_master.check('h24, 'h0); // sq_cr enable

        axi_master.write('h28, 'h1); // sq_cr_s enable
        axi_master.check('h04, 'h1); // cr enable
        axi_master.check('h24, 'h1); // sq_cr enable

        axi_master.write('h2c, 'h1); // sq_cr_c enable
        axi_master.check('h04, 'h0); // cr enable
        axi_master.check('h24, 'h0); // sq_cr enable

        axi_master.write('h04, 'h1); // cr enable
        axi_master.check('h24, 'h1); // sq_cr enable
        axi_master.write('h24, 'h0); // sq_cr enable
        axi_master.check('h04, 'h0); // cr enable

        axi_master.write('h28, 'h1); // sq_cr_s enable
        axi_master.write('h28, 'h4); // sq_cr_s sw trig
        #20ns;
        axi_master.check('h00, 'h1); // running
        axi_master.check('h20, 'h1); // running
        axi_master.check('h04, 'h0); // cr enable
        axi_master.check('h24, 'h0); // sq_cr enable
        wait_seq_end();
        #20ns;
        axi_master.check('h00, 'h0); // running
        axi_master.check('h20, 'h0); // running

        axi_master.write('h24, 'h1); // sq_cr enable
        axi_master.write('h24, 'h5); // sq_cr sw trig
        wait_seq_end();
        #10us;
        $display("Start TWO_SEQ_NO_OVELAP test");
        test_number <= test_number + 1;
        axi_master.write('h08, 'h3); // cr enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        axi_master.write('h40, 'h4); // sq_cr sw trig
        wait_seq_end();
        wait_seq_end();
        #10us;
        $display("Start TWO_SEQ_OVELAP test");
        test_number <= test_number + 1;
        axi_master.write('h08, 'h3); // cr enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        @(posedge app_clk);
        @(posedge app_clk);
        @(posedge app_clk);
        axi_master.write('h40, 'h4); // sq_cr sw trig
        wait_seq_end();
        wait_seq_end();
        #100us;
        $display("Start RESET test");
        test_number <= test_number + 1;
        axi_master.write('h08, 'h1); // cr_s enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        axi_master.write('h08, 'h4); // cr_s reset
        #100ns;
        axi_master.check('h00, 'h0); // running

        axi_master.write('h08, 'h1); // cr_s enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        axi_master.write('h04, 'h4); // cr reset
        #100ns;
        axi_master.check('h00, 'h0); // running

        axi_master.write('h08, 'h1); // cr_s enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        axi_master.write('h28, 'h2); // sq_cr_s reset
        #100ns;
        axi_master.check('h00, 'h0); // running

        axi_master.write('h08, 'h1); // cr_s enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        axi_master.write('h24, 'h2); // sq_cr reset
        #100ns;
        axi_master.check('h00, 'h0); // running

        $display("Start CYCLE test");
        test_number <= test_number + 1;
        axi_master.write('h08, 'h1); // cr enable 
        axi_master.write('h34, 'h1); // mode = CYCLE
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        wait_seq_end();
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        wait_seq_end();
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        axi_master.write('h24, 'h2); // sq_cr reset
        #100ns;
        axi_master.check('h00, 'h0); // running
        axi_master.write('h08, 'h1); // cr_s enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        wait_seq_end();
        axi_master.write('h0c, 'h1); // cr_c enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h0); // running
        axi_master.write('h08, 'h1); // cr_s enable 
        #100ns;
        axi_master.check('h00, 'h0); // running
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        axi_master.write('h24, 'h2); // sq_cr reset

        $display("Start RECYCLE test");
        test_number <= test_number + 1;
        axi_master.write('h08, 'h1); // cr enable 
        axi_master.write('h34, 'h2); // mode = RECYCLE
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        wait_seq_end();
        #100ns;
        axi_master.check('h00, 'h1); // running
        axi_master.write('h24, 'h2); // sq_cr reset
        #100ns;
        axi_master.check('h00, 'h0); // running
        axi_master.write('h08, 'h1); // cr_s enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        wait_seq_end();
        axi_master.write('h0c, 'h1); // cr_c enable 
        #100ns;
        axi_master.check('h00, 'h1); // running
        wait_seq_end();
        axi_master.check('h00, 'h0); // running
        axi_master.write('h08, 'h1); // cr_s enable 
        #100ns;
        axi_master.check('h00, 'h0); // running
        axi_master.write('h28, 'h4); // sq_cr sw trig
        #100ns;
        axi_master.check('h00, 'h1); // running
        axi_master.write('h34, 'h0); // mode = SINGLE
        wait_seq_end();
        #100ns;

        $display("Start TWO_SEQ_EV_OVELAP test");
        test_number <= test_number + 1;
        axi_master.write('h08, 'h3); // cr enable 
        axi_master.write('h28, 'h4); // sq_cr sw trig
        @(posedge app_clk);
        @(posedge app_clk);
        @(posedge app_clk);
        axi_master.write('h40, 'h4); // sq_cr sw trig
        @(posedge app_clk);
        @(posedge app_clk);
        axi_master.write('h10, 'h1123456); // prov ev
        wait_seq_end();
        wait_seq_end();

        #100us;
        $stop();
    end
    

    task reset();
        app_rst <= 1;
        for(int i = 0; i < 10; i++)
            @(posedge app_clk);
        app_rst <= 0;
    endtask

    task wait_seq_end();
        wait (ev_out == 'h50DEAD);
    endtask
endmodule

module seq_writer #(
    parameter EV_N = 0
)(
    axi4_lite_if.m  axi,
    input  logic    aclk,
    input  logic    areset
);
    axi_master axi_master(
        .aclk(aclk),
        .aresetn(areset),
        .axi(axi)
    );

    int entrys_num = 0;
    logic [31:0] rd_timestamp_lsb;
    logic [31:0] rd_timestamp_msb;
    logic [31:0] rd_ev;
    logic [63:0] rd_timestamp_seq;
    logic [31:0] rd_ev_seq;

    task add_event(input logic [63:0] timestamp, input logic [23:0] ev);
        @(posedge aclk);
        axi_master.write(entrys_num * 'h10 + 'h00, timestamp[31:0]);
        axi_master.write(entrys_num * 'h10 + 'h04, timestamp[63:32]);
        axi_master.write(entrys_num * 'h10 + 'h08, {8'h0, ev});
        entrys_num <= entrys_num + 1;
    endtask
    
    task add_end_of_sequency(input logic [63:0] timestamp);
        @(posedge aclk);
        add_event(timestamp, 'h50DEAD);
    endtask

    task reset_events();
        entrys_num <= 0;
    endtask

    task read_event(int entry, output logic [63:0] timestamp, output logic [23:0] ev);
        @(posedge aclk);
        axi_master.read(entry * 'h10 + 'h00, rd_timestamp_lsb);
        axi_master.read(entry * 'h10 + 'h04, rd_timestamp_msb);
        axi_master.read(entry * 'h10 + 'h08, rd_ev);
        @(posedge aclk);
        timestamp <= {rd_timestamp_msb, rd_timestamp_lsb};
        ev        <= rd_ev;
        @(posedge aclk);
    endtask

    task write_seq(logic [23:0] events [EV_N], logic [63:0] timestamps [EV_N]);
        begin
        reset_events();
        for (int i = 0; i < EV_N; i++) begin
            add_event(timestamps[i], events[i]);
        end
        add_end_of_sequency(timestamps[EV_N-1] + 1);
        #1us;
        for (int i = 0; i < 11; i++) begin
            read_event(i, rd_timestamp_seq, rd_ev_seq);
            if(rd_timestamp_seq != timestamps[i] || rd_ev_seq != events[i]) begin
                $display("error read timestamp : %016h, event : %08h, expect timestamp : %016h, event : %08h,", 
                        rd_timestamp_seq, rd_ev_seq, timestamps[i], events[i]);
                $stop();
            end
        end
        end
    endtask
endmodule

module ev_recv(
    input  logic        aclk,
    input  logic        areset,
    input  logic [23:0] ev
);
    logic [63:0] timestamp      = '0;
    logic [63:0] prev_timestamp = '0;
    always_ff @(posedge aclk) begin
        if(areset) begin
            timestamp      <= '0;
            prev_timestamp <= '0;
        end else begin
            if(ev != 0) begin
                $display("recieved event %08h at cycle %0d, spend %0d", ev, timestamp, timestamp - prev_timestamp);
                prev_timestamp <= timestamp;
            end
            timestamp <= timestamp+1;
        end
    end

endmodule
`endif //SYNTHESIS 