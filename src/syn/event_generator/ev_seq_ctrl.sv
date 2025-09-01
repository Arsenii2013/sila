module ev_seq_ctrl #(
    parameter EV_SEQ_N  = 1
) (
    input  logic                        app_clk,
    input  logic                        app_rst,
    axi4_lite_if.s                      mmr,

    output logic                        seq_enable[EV_SEQ_N],
    output logic                        seq_start[EV_SEQ_N],
    output logic                        seq_stop[EV_SEQ_N],
    input  logic                        seq_running[EV_SEQ_N],
    input  event_generator_pkg::ev_t    ev_in[EV_SEQ_N],
    output event_generator_pkg::ev_t    ev_out
);

    import event_generator_pkg::*;

    trig_source_t seq_trig_src      [EV_SEQ_N];
    seq_mode_t    seq_mode          [EV_SEQ_N];
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

    input  event_generator_pkg::seq_mode_t    mode,
    input  event_generator_pkg::trig_source_t trig_src,

    output logic start,
    output logic stop,
    input  logic running
);
    import event_generator_pkg::*;

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
