class link_csr_generator#(
    parameter BASE  = 'h0,
    parameter PRD   = 5714ps
) extends axi_generator;
    localparam SR_ADDR              = BASE + 32'h0;
    localparam CR_ADDR              = BASE + 32'h4;
    localparam CR_S_ADDR            = BASE + 32'h8;
    localparam CR_C_ADDR            = BASE + 32'hc;
    localparam PORT_SR_0_ADDR       = BASE + 32'h10;
    localparam PORT_SR_1_ADDR       = BASE + 32'h14;
    localparam PORT_SR_2_ADDR       = BASE + 32'h18;
    localparam PORT_SR_3_ADDR       = BASE + 32'h1c;
    localparam PORT_SR_4_ADDR       = BASE + 32'h20;
    localparam PORT_SR_5_ADDR       = BASE + 32'h24;
    localparam PORT_SR_6_ADDR       = BASE + 32'h28;
    localparam PORT_SR_7_ADDR       = BASE + 32'h2c;
    localparam TOPO_ID_ADDR         = BASE + 32'h30;
    localparam LINK_DELAY_ADDR      = BASE + 32'h34;
    localparam UPSTREAM_DELAY_ADDR  = BASE + 32'h38;
    localparam SUBTREE_DELAY_ADDR   = BASE + 32'h3c;
    localparam TGT_DELAY_ADDR       = BASE + 32'h40;
    localparam DELAY_COMP_ADDR      = BASE + 32'h44;

    function new (
        virtual virtual_clock_if clk_if,
        axi_transaction_pkg::item_mailbox_t req_mailbox,
        axi_transaction_pkg::item_mailbox_t resp_mailbox,
        int resp_channel
    );
        super.new(clk_if, req_mailbox, resp_mailbox, resp_channel);
    endfunction

    static function time delay_t_to_time(evn::delay_t delay);
        return (delay * PRD) >> evn::DELAY_FRAC_W;
    endfunction
    static function evn::delay_t time_to_delay_t(time delay);
        return (delay << evn::DELAY_FRAC_W) / PRD;
    endfunction

    task verify_topo_id(input evn::topo_id_t topo_id);
        this.verify(TOPO_ID_ADDR, topo_id);
    endtask

    task read_link_delay(output evn::delay_t link_delay);
        this.read(LINK_DELAY_ADDR, link_delay);
    endtask
    task verify_link_delay(input evn::delay_t link_delay);
        this.verify(LINK_DELAY_ADDR, link_delay);
    endtask

    task read_up_delay(output evn::delay_t up_delay);
        this.read(UPSTREAM_DELAY_ADDR, up_delay);
    endtask
    task verify_up_delay(input evn::delay_t up_delay);
        this.verify(UPSTREAM_DELAY_ADDR, up_delay);
    endtask

    task read_sub_delay(output evn::delay_t sub_delay);
        this.read(UPSTREAM_DELAY_ADDR, sub_delay);
    endtask
    task verify_sub_delay(input evn::delay_t sub_delay);
        this.verify(UPSTREAM_DELAY_ADDR, sub_delay);
    endtask

    task set_tgt_delay(input evn::delay_t tgt_delay);
        this.write(TGT_DELAY_ADDR, tgt_delay);
    endtask
    task verify_tgt_delay(input evn::delay_t tgt_delay);
        this.verify(TGT_DELAY_ADDR, tgt_delay);
    endtask

    task enable_dc();
        this.write(CR_S_ADDR, 32'h1);
        this.verify(CR_ADDR,   32'h1);
    endtask
    task disable_dc();
        this.write(CR_C_ADDR, 32'h1);
        this.verify(CR_ADDR,   32'h0);
    endtask

    task get_port_status(input int port, output logic link_up, output evn::link_delay_st_t link_delay_st, output evn::link_delay_st_t delay_comp_st);
        axi_transaction_pkg::data_t rd_word;
        case (port)
        0 : this.read(PORT_SR_0_ADDR, rd_word);
        1 : this.read(PORT_SR_1_ADDR, rd_word);
        2 : this.read(PORT_SR_2_ADDR, rd_word);
        3 : this.read(PORT_SR_3_ADDR, rd_word);
        4 : this.read(PORT_SR_4_ADDR, rd_word);
        5 : this.read(PORT_SR_5_ADDR, rd_word);
        6 : this.read(PORT_SR_6_ADDR, rd_word);
        7 : this.read(PORT_SR_7_ADDR, rd_word);
        default : $error("There is only 8 ports");
        endcase
        @(posedge this.clk_if.clk);
        link_up       = rd_word[0];
        link_delay_st = evn::link_delay_st_t'(rd_word[7:4]);
        delay_comp_st = evn::link_delay_st_t'(rd_word[11:8]);
        @(posedge this.clk_if.clk);
    endtask

    task wait_delay_status(input int port, input evn::link_delay_st_t pool_status, input time pool_duration);
        static logic                rd_link_up;
        static evn::link_delay_st_t rd_status;
        static evn::link_delay_st_t rd_dc_status;

        get_port_status(port, rd_link_up, rd_status, rd_dc_status);
        do begin
            $display("Wait link_delay_st %s for device %m port %d: current link_up %x, current link_delay_st %s", 
                                                            pool_status.name, port, rd_link_up, rd_status.name);
            #(pool_duration);
            get_port_status(port, rd_link_up, rd_status, rd_dc_status);
        end while(!(rd_link_up == 1 && rd_status == pool_status));
    endtask

    task wait_dc_status(input int port, input evn::link_delay_st_t pool_dc_status, input time pool_duration);
        static logic                rd_link_up;
        static evn::link_delay_st_t rd_status;
        static evn::link_delay_st_t rd_dc_status;
        get_port_status(port, rd_link_up, rd_status, rd_dc_status);
        $display("Wait delay_comp_st %s for device %m port %d: current link_up %x, current delay_comp_st %s", 
                                                        pool_dc_status.name, port, rd_link_up, rd_dc_status.name);
        do begin
            $display("Wait delay_comp_st %s for device %m port %d: current link_up %x, current delay_comp_st %s", 
                                                            pool_dc_status.name, port, rd_link_up, rd_dc_status.name);
            #(pool_duration);
            get_port_status(port, rd_link_up, rd_status, rd_dc_status);
        end while(!(rd_link_up == 1 && rd_dc_status == pool_dc_status));
    endtask

    task dump();
        axi_transaction_pkg::data_t rd_word;
        $display("dump link csr for : %m");
        this.read(SR_ADDR, rd_word);
        $display("status            : %x", rd_word);
        this.read(CR_ADDR, rd_word);
        $display("control           : %x", rd_word);

        this.read(PORT_SR_0_ADDR, rd_word);
        $display("port 0 status     : %x", rd_word);
        this.read(PORT_SR_1_ADDR, rd_word);
        $display("port 1 status     : %x", rd_word);
        this.read(PORT_SR_2_ADDR, rd_word);
        $display("port 2 status     : %x", rd_word);
        this.read(PORT_SR_3_ADDR, rd_word);
        $display("port 3 status     : %x", rd_word);
        this.read(PORT_SR_4_ADDR, rd_word);
        $display("port 4 status     : %x", rd_word);
        this.read(PORT_SR_5_ADDR, rd_word);
        $display("port 5 status     : %x", rd_word);
        this.read(PORT_SR_6_ADDR, rd_word);
        $display("port 6 status     : %x", rd_word);
        this.read(PORT_SR_7_ADDR, rd_word);
        $display("port 7 status     : %x", rd_word);

        this.read(TOPO_ID_ADDR, rd_word);
        $display("topo id           : %x", rd_word);
        this.read(LINK_DELAY_ADDR, rd_word);
        $display("link delay        : %x = %e s", rd_word, (rd_word >> 16) / 175e6);
        this.read(UPSTREAM_DELAY_ADDR, rd_word);
        $display("upstream delay    : %x = %e s", rd_word, (rd_word >> 16) / 175e6);
        this.read(SUBTREE_DELAY_ADDR, rd_word);
        $display("subtree delay     : %x = %e s", rd_word, (rd_word >> 16) / 175e6);
        this.read(TGT_DELAY_ADDR, rd_word);
        $display("target delay      : %x = %e s", rd_word, (rd_word >> 16) / 175e6);
        this.read(DELAY_COMP_ADDR, rd_word);
        $display("delay compensation: %x = %e s", rd_word, (rd_word >> 16) / 175e6);
    endtask
endclass