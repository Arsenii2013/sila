package ev_seq_ctrl_generator_pkg;
typedef struct{
    event_generator_pkg::trig_source_t trig_src;
    event_generator_pkg::seq_mode_t    mode;
} item_t;
endpackage

class ev_seq_ctrl_generator#(
    parameter SEQ_N = 2
) extends axi_generator;

    localparam SR            = 'h0;
    localparam CR            = 'h4;
    localparam CR_S          = 'h8;
    localparam CR_C          = 'hC;
    localparam PROG_EV       = 'h10;
    localparam SEQ_REGS_BASE = 'h20;
    localparam SQ_SR_OFFS    = 'h0;
    localparam SQ_CR_OFFS    = 'h4;
    localparam SQ_CR_S_OFFS  = 'h8;
    localparam SQ_CR_C_OFFS  = 'hC;
    localparam TRIG_OFFS     = 'h10;
    localparam MODE_OFFS     = 'h14;
    localparam SEQ_REGS_SIZE = 'h18;

    function new (
        virtual virtual_clock_if clk_if,
        addr_t base,
        mailbox_t req_mailbox,
        mailbox_t resp_mailbox,
        int resp_channel
    );
        super.new(clk_if, base, req_mailbox, resp_mailbox, resp_channel);
    endfunction

    function int unsigned reg_by_offs(input int unsigned seq_n, input int unsigned reg_offs);
        return SEQ_REGS_BASE + SEQ_REGS_SIZE * seq_n + reg_offs;
    endfunction

    task get_running_all(output logic [SEQ_N-1:0] running);
        data_t rd_data;
        read(SR, rd_data);
        running = rd_data[SEQ_N-1:0];
        @(posedge clk_if.clk);
    endtask
    task check_running_all(input logic [SEQ_N-1:0] running);
        verify(SR, running);
    endtask
    task get_running(input int unsigned seq_n, output logic running);
        data_t rd_data;
        read(reg_by_offs(seq_n, SQ_SR_OFFS), rd_data);
        running = rd_data[0];
        @(posedge clk_if.clk);
    endtask
    task check_running(input int unsigned seq_n, input logic running);
        verify(reg_by_offs(seq_n, SQ_SR_OFFS), running);
    endtask

    task enable_all();
        write(CR_S, ('h1 << SEQ_N) - 'h1);
    endtask
    task get_enabled_all(output logic [SEQ_N-1:0] enabled);
        data_t rd_data;
        read(CR, rd_data);
        enabled = rd_data[SEQ_N-1:0];
        @(posedge clk_if.clk);
    endtask
    task check_enabled_all(input logic [SEQ_N-1:0] enabled);
        verify(CR, enabled);
    endtask
    task disable_all();
        write(CR_C, ('h1 << SEQ_N) - 'h1);
    endtask
    task reset_all();
        write(CR_S, (('h1 << SEQ_N) - 'h1) << SEQ_N);
    endtask
    task enable(input int unsigned seq_n);
        write(reg_by_offs(seq_n, SQ_CR_S_OFFS), 'h1);
    endtask
    task get_enabled(input int unsigned seq_n, output logic enabled);
        data_t rd_data;
        read(reg_by_offs(seq_n, SQ_CR_OFFS), rd_data);
        enabled = rd_data[0];
        @(posedge clk_if.clk);
    endtask
    task check_enabled(input int unsigned seq_n, input logic enabled);
        verify(reg_by_offs(seq_n, SQ_CR_OFFS), enabled);
    endtask
    task disable_(input int unsigned seq_n);
        write(reg_by_offs(seq_n, SQ_CR_C_OFFS), 'h1);
    endtask
    task reset(input int unsigned seq_n);
        write(reg_by_offs(seq_n, SQ_CR_S_OFFS), 'h2);
    endtask
    task sw_trig(input int unsigned seq_n);
        write(reg_by_offs(seq_n, SQ_CR_S_OFFS), 'h4);
    endtask

    task set_trig_src(input int unsigned seq_n, input event_generator_pkg::trig_source_t trig);
        write(reg_by_offs(seq_n, TRIG_OFFS), trig);
    endtask
    task set_mode(input int unsigned seq_n, input event_generator_pkg::seq_mode_t mode);
        write(reg_by_offs(seq_n, MODE_OFFS), mode);
    endtask

    task setup(input ev_seq_ctrl_generator_pkg::item_t cfg[SEQ_N]);
        foreach(cfg[i]) begin
            set_trig_src(i, cfg[i].trig_src);
            set_mode(i, cfg[i].mode);
        end
    endtask

    task send_prog_ev(input event_generator_pkg::ev_t ev);
        write(PROG_EV, data_t'({1, ev}));
    endtask

    task dump();
        data_t rd_data;
        event_generator_pkg::trig_source_t rd_trig_src;
        event_generator_pkg::seq_mode_t    rd_mode;
        $display("ev_seq_ctrl dump");
        read(SR, rd_data);
        $display("sr running    : %b", rd_data[SEQ_N-1:0]);
        read(CR, rd_data);
        $display("cr enable     : %b", rd_data[SEQ_N-1:0]);
        read(PROG_EV, rd_data);
        $display("program event : %x", event_generator_pkg::ev_t'(rd_data));
        for(int i = 0; i < SEQ_N; i++) begin
            $display("ev_seq_ctrl seq %d", i);
            read(reg_by_offs(i, SQ_SR_OFFS), rd_data);
            $display("sq_sr running : %b", rd_data[0]);
            read(reg_by_offs(i, SQ_CR_OFFS), rd_data);
            $display("sq_cr enable  : %b", rd_data[0]);
            read(reg_by_offs(i, TRIG_OFFS), rd_data);
            rd_trig_src = event_generator_pkg::trig_source_t'(rd_data);
            $display("trig_src      : %b", rd_trig_src.name);
            read(reg_by_offs(i, MODE_OFFS), rd_data);
            rd_mode = event_generator_pkg::seq_mode_t'(rd_data);
            $display("mode          : %b", rd_mode.name);
        end
    endtask
endclass