package diff_io_generator_pkg;

typedef struct packed {
    diff_io_pkg::polarity_t polarity;
    diff_io_pkg::mode_t     mode;
} cfg_t;

endpackage

class diff_io_generator#(
    parameter BASE  = 'h0,
    parameter OUTPUT_N = 16
) extends axi_generator;

    typedef diff_io_pkg::polarity_t      polarity_t;
    typedef diff_io_pkg::mode_t          mode_t;
    typedef diff_io_generator_pkg::cfg_t cfg_t;

    localparam SR               = 'h0;
    localparam OUT_REGS_BASE    = 'h10;
    localparam OUT_REGS_SIZE    = 'h10;
    localparam OUT_SR_OFFS      = 'h0;
    localparam OUT_CR_OFFS      = 'h4;
    localparam OUT_CR_S_OFFS    = 'h8;
    localparam OUT_CR_C_OFFS    = 'hC;

    function int unsigned reg_by_offs(input int unsigned gen_n, input int unsigned reg_offs);
        return OUT_REGS_BASE + OUT_REGS_SIZE * gen_n + reg_offs;
    endfunction

    function new (
        virtual virtual_clock_if clk_if,
        axi_transaction_pkg::item_mailbox_t req_mailbox,
        axi_transaction_pkg::item_mailbox_t resp_mailbox,
        int resp_channel
    );
        super.new(clk_if, req_mailbox, resp_mailbox, resp_channel);
    endfunction

    task get_outputs_all(output logic [OUTPUT_N-1:0] outs);
        read(BASE + SR, outs);
    endtask
    task check_outputs_all(input logic [OUTPUT_N-1:0] outs);
        verify(BASE + SR, outs);
    endtask
    task get_output(input int unsigned out_n, output logic out);
        read(BASE + reg_by_offs(out_n, OUT_SR_OFFS), out);
    endtask
    task check_output(input int unsigned out_n, input logic out);
        verify(BASE + reg_by_offs(out_n, OUT_SR_OFFS), out);
    endtask

    task set_cfg(input int unsigned out_n, input cfg_t cfg);
        data_t mask = 9'b11111111;
        data_t wr_word;

        if(cfg.polarity == diff_io_pkg::POSITIVE)
            wr_word = 0;
        else
            wr_word = 1;
        wr_word |= cfg.mode << 1;

        write(BASE + reg_by_offs(out_n, OUT_CR_C_OFFS), mask);
        write(BASE + reg_by_offs(out_n, OUT_CR_S_OFFS), wr_word);
    endtask
    task get_cfg(input int unsigned out_n, output cfg_t cfg);
        data_t rd_word;
        read(BASE + reg_by_offs(out_n, OUT_CR_OFFS), rd_word);
        cfg.polarity = polarity_t'(rd_word[0]);
        cfg.mode = mode_t'(rd_word[8:1]);
    endtask

    task setup(input cfg_t setup[]);
        assert(setup.size() <= OUTPUT_N) else $display("diff_io setup greater than diff_ios number");
        foreach(setup[i]) begin
            set_cfg(i, setup[i]);
        end
    endtask

    task dump();
        cfg_t rd_cfg;
        $display("diff_io dump");
        for(int i = 0; i < OUTPUT_N; i++) begin
            $display("out %d", i);
            get_cfg(i, rd_cfg);
            $display("polarity : %S", rd_cfg.polarity.name);
            $display("mode     : %s", rd_cfg.mode.name);
        end
    endtask
endclass