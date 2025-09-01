package signal_generator_generator_pkg;
typedef struct packed {
    logic set;
    logic clear;
    logic trigger;
    logic cnt_reset;
} ena_t;

typedef struct packed {
    ena_t                               ena;
    logic                               polarity;
    signal_generator_pkg::out_source_t  out_src;
    signal_generator_pkg::trig_source_t trig_src;
} cfg_t;

typedef struct{
    ena_t                               ena;
    logic                               polarity;
    signal_generator_pkg::out_source_t  out_src;
    signal_generator_pkg::trig_source_t trig_src;
    signal_generator_pkg::period_t      period;
    signal_generator_pkg::delay_t       delay;
    signal_generator_pkg::width_t       width;
} setup_item_t;
endpackage

class ev_generator_generator#(
    parameter BASE  = 'h0,
    parameter GEN_N = 16
) extends axi_generator;

    typedef signal_generator_generator_pkg::ena_t        ena_t;
    typedef signal_generator_generator_pkg::cfg_t        cfg_t;
    typedef signal_generator_generator_pkg::setup_item_t setup_item_t;
    typedef signal_generator_pkg::trig_source_t          trig_source_t;
    typedef signal_generator_pkg::out_source_t           out_source_t;
    typedef signal_generator_pkg::period_t               period_t;
    typedef signal_generator_pkg::delay_t                delay_t;
    typedef signal_generator_pkg::width_t                width_t;

    localparam SR               = 'h0;
    localparam GEN_REGS_BASE    = 'h10;
    localparam GEN_REGS_SIZE    = 'h28;
    localparam GEN_SR_OFFS      = 'h0;
    localparam GEN_CR_OFFS      = 'h4;
    localparam GEN_CR_S_OFFS    = 'h8;
    localparam GEN_CR_C_OFFS    = 'hC;
    localparam DELAY_LSB_OFFS   = 'h10;
    localparam DELAY_MSB_OFFS   = 'h14;
    localparam WIDTH_LSB_OFFS   = 'h18;
    localparam WIDTH_MSB_OFFS   = 'h1C;
    localparam PERIOD_LSB_OFFS  = 'h20;
    localparam PERIOD_MSB_OFFS  = 'h24;

    function int unsigned reg_by_offs(input int unsigned gen_n, input int unsigned reg_offs);
        return GEN_REGS_BASE + GEN_REGS_SIZE * gen_n + reg_offs;
    endfunction

    function new (
        virtual virtual_clock_if clk_if,
        axi_transaction_pkg::item_mailbox_t req_mailbox,
        axi_transaction_pkg::item_mailbox_t resp_mailbox,
        int resp_channel
    );
        super.new(clk_if, req_mailbox, resp_mailbox, resp_channel);
    endfunction

    task get_outputs_all(output logic [GEN_N-1:0] outs);
        read(SR, outs);
    endtask
    task check_outputs_all(input logic [GEN_N-1:0] outs);
        verify(SR, outs);
    endtask
    task get_output(input int unsigned gen_n, output logic out);
        read(reg_by_offs(gen_n, GEN_SR_OFFS), out);
    endtask
    task check_output(input int unsigned gen_n, input logic out);
        verify(reg_by_offs(gen_n, GEN_SR_OFFS), out);
    endtask

    task set_ena(input int unsigned gen_n, input ena_t ena);
        write(reg_by_offs(gen_n, GEN_CR_C_OFFS), 4'b1111);
        write(reg_by_offs(gen_n, GEN_CR_S_OFFS), data_t'({ena.cnt_reset, ena.trigger, ena.clear, ena.set}));
    endtask
    task enable_all(input int unsigned gen_n);
        write(reg_by_offs(gen_n, GEN_CR_S_OFFS), 4'b1111);
    endtask
    task disable_all(input int unsigned gen_n);
        write(reg_by_offs(gen_n, GEN_CR_C_OFFS), 4'b1111);
    endtask

    task set_polarity(input int unsigned gen_n, input logic polarity);
        if(polarity)
            write(reg_by_offs(gen_n, GEN_CR_S_OFFS), 5'b10000);
        else
            write(reg_by_offs(gen_n, GEN_CR_C_OFFS), 5'b10000);
    endtask

    task set_out_src(input int unsigned gen_n, input out_source_t out_src);
        write(reg_by_offs(gen_n, GEN_CR_C_OFFS), data_t'(2'b11) << 5);
        write(reg_by_offs(gen_n, GEN_CR_S_OFFS), data_t'(out_src) << 5);
    endtask
    task set_trig_src(input int unsigned gen_n, input trig_source_t trig_src);
        write(reg_by_offs(gen_n, GEN_CR_C_OFFS), data_t'(1'b1) << 7);
        write(reg_by_offs(gen_n, GEN_CR_S_OFFS), data_t'(trig_src) << 7);
    endtask

    task set_cfg(input int unsigned gen_n, input cfg_t cfg);
        write(reg_by_offs(gen_n, GEN_CR_OFFS), data_t'({cfg.trig_src, cfg.out_src, cfg.polarity, 
                                                    {cfg.ena.cnt_reset, cfg.ena.trigger, cfg.ena.clear, cfg.ena.set}}));
    endtask
    task get_cfg(input int unsigned gen_n, output cfg_t cfg);
        data_t rd_word;
        read(reg_by_offs(gen_n, GEN_CR_OFFS), rd_word);
        cfg = cfg_t'(rd_word[3:0]);
    endtask
    task check_cfg(input int unsigned gen_n, input cfg_t cfg);
        verify(reg_by_offs(gen_n, GEN_CR_OFFS), data_t'({cfg.trig_src, cfg.out_src, cfg.polarity, 
                                                    {cfg.ena.cnt_reset, cfg.ena.trigger, cfg.ena.clear, cfg.ena.set}}));
    endtask

    task set_period(input int unsigned gen_n, input period_t period);
        write(reg_by_offs(gen_n, PERIOD_LSB_OFFS), data_t'(period[31:0]));
        write(reg_by_offs(gen_n, PERIOD_MSB_OFFS), data_t'(period[63:32]));
    endtask
    task get_period(input int unsigned gen_n, output period_t period);
        data_t rd_word1, rd_word2;
        read(reg_by_offs(gen_n, PERIOD_LSB_OFFS), rd_word1);
        read(reg_by_offs(gen_n, PERIOD_MSB_OFFS), rd_word2);
        period = period_t'({rd_word2, rd_word1});
    endtask
    task set_delay(input int unsigned gen_n, input delay_t delay);
        write(reg_by_offs(gen_n, DELAY_LSB_OFFS), data_t'(delay[31:0]));
        write(reg_by_offs(gen_n, DELAY_MSB_OFFS), data_t'(delay[63:32]));
    endtask
    task get_delay(input int unsigned gen_n, output delay_t delay);
        data_t rd_word1, rd_word2;
        read(reg_by_offs(gen_n, DELAY_LSB_OFFS), rd_word1);
        read(reg_by_offs(gen_n, DELAY_MSB_OFFS), rd_word2);
        delay = delay_t'({rd_word2, rd_word1});
    endtask
    task set_width(input int unsigned gen_n, input width_t width);
        write(reg_by_offs(gen_n, WIDTH_LSB_OFFS), data_t'(width[31:0]));
        write(reg_by_offs(gen_n, WIDTH_MSB_OFFS), data_t'(width[63:32]));
    endtask
    task get_width(input int unsigned gen_n, output width_t width);
        data_t rd_word1, rd_word2;
        read(reg_by_offs(gen_n, WIDTH_LSB_OFFS), rd_word1);
        read(reg_by_offs(gen_n, WIDTH_MSB_OFFS), rd_word2);
        width = width_t'({rd_word2, rd_word1});
    endtask

    task setup(input setup_item_t setup[]);
        cfg_t cfg;
        assert(setup.size() < GEN_N) else $display("signal generator setup greater than signal generators number");
        foreach(setup[i]) begin
            cfg.ena  = setup[i].ena;
            cfg.polarity = setup[i].polarity;
            cfg.out_src  = setup[i].out_src;
            cfg.trig_src = setup[i].trig_src;
            set_cfg(i, cfg);
            set_period(i, setup[i].period);
            set_delay(i, setup[i].delay);
            set_width(i, setup[i].width);
        end
    endtask

    task dump();
        cfg_t    rd_cfg;
        period_t rd_period;
        delay_t  rd_delay;
        width_t  rd_width;
        $display("signal_generator dump");
        for(int i = 0; i < GEN_N; i++) begin
            $display("generator %d", i);
            get_cfg(i, rd_cfg);
            get_period(i, rd_period);
            get_delay(i, rd_delay);
            get_width(i, rd_width);
            $display("ena            : %b", rd_cfg.ena);
            $display("polarity       : %b", rd_cfg.polarity);
            $display("output source  : %s", rd_cfg.out_src.name);
            $display("trigger source : %s", rd_cfg.trig_src.name);
            $display("period         : %d", rd_period);
            $display("delay          : %d", rd_delay);
            $display("width          : %d", rd_width);
        end
    endtask
endclass