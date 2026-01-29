class link_csr_generator#(
    parameter PRD   = 5714ps
) extends axi_generator;
    localparam SR_ADDR              = 32'h0;
    localparam CR_ADDR              = 32'h4;
    localparam CR_S_ADDR            = 32'h8;
    localparam CR_C_ADDR            = 32'hc;
    localparam DC_ENA_OFFS          = 0;
    localparam HEAD_MODE_OFFS       = 1;
    localparam PORT_SR_0_ADDR       = 32'h10;
    localparam PORT_SR_1_ADDR       = 32'h14;
    localparam PORT_SR_2_ADDR       = 32'h18;
    localparam PORT_SR_3_ADDR       = 32'h1c;
    localparam PORT_SR_4_ADDR       = 32'h20;
    localparam PORT_SR_5_ADDR       = 32'h24;
    localparam PORT_SR_6_ADDR       = 32'h28;
    localparam PORT_SR_7_ADDR       = 32'h2c;
    localparam TOPO_ID_ADDR         = 32'h30;
    localparam LINK_DELAY_ADDR      = 32'h34;
    localparam UPSTREAM_DELAY_ADDR  = 32'h38;
    localparam SUBTREE_DELAY_ADDR   = 32'h3c;
    localparam TGT_DELAY_ADDR       = 32'h40;
    localparam DELAY_COMP_ADDR      = 32'h44;

    localparam int MAX_PORTS_ARRAY []  = '{0, 1, 2, 3};
    localparam string MAX_PORTS_STRING = $sformatf("%p", MAX_PORTS_ARRAY);
    localparam int PORTS_PRINT_SIZE    = MAX_PORTS_STRING.len();

    localparam real FCLK = 175e6;

    string name;
    function new (
        virtual virtual_clock_if clk_if,
        addr_t base,
        axi_transaction_pkg::item_mailbox_t req_mailbox,
        axi_transaction_pkg::item_mailbox_t resp_mailbox,
        int resp_channel,
        string name = "name"
    );
        super.new(clk_if, base, req_mailbox, resp_mailbox, resp_channel);
        this.name = name;
    endfunction

    static function time delay_t_to_time(evn::delay_t delay);
        return (delay * PRD) >> evn::DELAY_FRAC_W;
    endfunction
    static function evn::delay_t time_to_delay_t(time delay);
        return (delay << evn::DELAY_FRAC_W) / PRD;
    endfunction

    task get_topo_id(output evn::topo_id_t topo_id);
        this.read(TOPO_ID_ADDR, topo_id);
    endtask
    task check_topo_id(input evn::topo_id_t topo_id);
        this.verify(TOPO_ID_ADDR, topo_id);
    endtask

    task get_link_delay(output evn::delay_t link_delay);
        this.read(LINK_DELAY_ADDR, link_delay);
    endtask
    task check_link_delay(input evn::delay_t link_delay);
        this.verify(LINK_DELAY_ADDR, link_delay);
    endtask

    task get_up_delay(output evn::delay_t up_delay);
        this.read(UPSTREAM_DELAY_ADDR, up_delay);
    endtask
    task check_up_delay(input evn::delay_t up_delay);
        this.verify(UPSTREAM_DELAY_ADDR, up_delay);
    endtask

    task get_sub_delay(output evn::delay_t sub_delay);
        this.read(UPSTREAM_DELAY_ADDR, sub_delay);
    endtask
    task check_sub_delay(input evn::delay_t sub_delay);
        this.verify(UPSTREAM_DELAY_ADDR, sub_delay);
    endtask

    task set_tgt_delay(input evn::delay_t tgt_delay);
        this.write(TGT_DELAY_ADDR, tgt_delay);
    endtask
    task check_tgt_delay(input evn::delay_t tgt_delay);
        this.verify(TGT_DELAY_ADDR, tgt_delay);
    endtask
    task get_tgt_delay(output evn::delay_t tgt_delay);
        this.read(TGT_DELAY_ADDR, tgt_delay);
    endtask

    task get_delay_comp(output evn::delay_t delay_comp);
        this.read(DELAY_COMP_ADDR, delay_comp);
    endtask
    task check_delay_comp(input evn::delay_t delay_comp);
        this.verify(DELAY_COMP_ADDR, delay_comp);
    endtask

    task get_status(output logic link_up, output evn::link_delay_st_t link_delay_st, output evn::link_delay_st_t delay_comp_st);
        axi_transaction_pkg::data_t rd_word;
        read(SR_ADDR, rd_word);
        @(posedge this.clk_if.clk);
        link_up       = rd_word[0];
        link_delay_st = evn::link_delay_st_t'(rd_word[7:4]);
        delay_comp_st = evn::link_delay_st_t'(rd_word[11:8]);
        @(posedge this.clk_if.clk);
    endtask

    task enable_dc();
        this.write(CR_S_ADDR, 32'h1 << DC_ENA_OFFS);
        this.verify(CR_ADDR,   32'h1 << DC_ENA_OFFS);
    endtask
    task disable_dc();
        this.write(CR_C_ADDR, 32'h1 << DC_ENA_OFFS);
        this.verify(CR_ADDR,   32'h0);
    endtask

    task set_head();
        this.write(CR_S_ADDR, 32'h1 << HEAD_MODE_OFFS);
        this.verify(CR_ADDR,   32'h1 << HEAD_MODE_OFFS);
    endtask
    task unset_head();
        this.write(CR_C_ADDR, 32'h1 << HEAD_MODE_OFFS);
        this.verify(CR_ADDR,   32'h0);
    endtask

    task get_control(output logic is_head, output logic dc_on);
        axi_transaction_pkg::data_t rd_word;
        this.read(CR_ADDR, rd_word);
        @(posedge this.clk_if.clk);
        is_head = rd_word[1];
        dc_on   = rd_word[0];
        @(posedge this.clk_if.clk);
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
        logic                rd_link_up;
        evn::link_delay_st_t rd_status;
        evn::link_delay_st_t rd_dc_status;

        string port_str = $sformatf("%d", port);
        int space_cnt = PORTS_PRINT_SIZE - port_str.len();

        do begin
            get_port_status(port, rd_link_up, rd_status, rd_dc_status);
            $display("Wait link_delay_st %s for device %s port %s%d: current link_up %s%b, current link_delay_st %s", 
                                                            pool_status.name, name, {space_cnt{" "}}, port, 
                                                            {space_cnt{" "}}, rd_link_up, rd_status.name);
            #(pool_duration);
        end while(!(rd_link_up == 1 && rd_status >= pool_status));
    endtask

    task get_ports_statuses(input int ports[], ref logic link_ups[], ref evn::link_delay_st_t link_delay_sts[], 
                                ref evn::link_delay_st_t delay_comp_sts[]);
        assert(ports.size() == link_ups.size());
        assert(ports.size() == link_delay_sts.size());
        assert(ports.size() == delay_comp_sts.size());
        for(int i = 0; i < ports.size(); i++) begin
            get_port_status(ports[i], link_ups[i], link_delay_sts[i], delay_comp_sts[i]);
        end
    endtask

    local function void statuses_to_strings(evn::link_delay_st_t arr [], ref string arr_str []);
        assert (arr.size() == arr_str.size());
        foreach (arr[i]) begin
            arr_str[i] = arr[i].name;
        end
    endfunction

    task wait_delay_statuses(input int ports[], input evn::link_delay_st_t pool_status, input time pool_duration);
        logic                rd_link_ups    [] = new[ports.size()];
        evn::link_delay_st_t rd_statuses    [] = new[ports.size()];
        evn::link_delay_st_t rd_dc_statuses [] = new[ports.size()];
        string               statuses_names [] = new[ports.size()];

        string ports_str = $sformatf("%p", ports);
        int space_cnt = PORTS_PRINT_SIZE - ports_str.len();

        do begin
            get_ports_statuses(ports, rd_link_ups, rd_statuses, rd_dc_statuses);
            statuses_to_strings(rd_statuses, statuses_names);
            $display("Wait link_delay_st %s for device %s ports %s%p: current link_up %s%p, current link_delay_st %p", 
                                                            pool_status.name, name, {space_cnt{" "}}, ports,
                                                            {space_cnt{" "}}, rd_link_ups, statuses_names);
            #(pool_duration);
        end while(!(rd_link_ups.and() == 1 && rd_statuses.and() with (item >= pool_status)));
    endtask

    task wait_dc_status(input int port, input evn::link_delay_st_t pool_dc_status, input time pool_duration);
        static logic                rd_link_up;
        static evn::link_delay_st_t rd_status;
        static evn::link_delay_st_t rd_dc_status;

        string port_str = $sformatf("%d", port);
        int space_cnt = PORTS_PRINT_SIZE - port_str.len();

        do begin
            get_port_status(port, rd_link_up, rd_status, rd_dc_status);
            $display("Wait delay_comp_st %s for device %s port %s%d: current link_up %s%b, current delay_comp_st %s", 
                                                            pool_dc_status.name, name, {space_cnt{" "}}, port, 
                                                            {space_cnt{" "}}, rd_link_up, rd_dc_status.name);
            #(pool_duration);
        end while(!(rd_link_up == 1 && rd_dc_status >= pool_dc_status));
    endtask

    task dump();
        logic link_up, is_head, dc_on, port_link_up [];
        evn::link_delay_st_t link_delay_st, delay_comp_st, port_delay_st [], port_comp_st [];
        evn::topo_id_t topo_id;
        evn::delay_t link_delay, up_delay, sub_delay, tgt_delay, delay_comp;
        string port_string;

        port_link_up = new[8];
        port_delay_st = new[8];
        port_comp_st = new[8];

        get_status(link_up, link_delay_st, delay_comp_st);
        get_control(is_head, dc_on);
        get_ports_statuses('{0, 1, 2, 3, 4, 5, 6, 7}, port_link_up, port_delay_st, port_comp_st);
        get_topo_id(topo_id);
        get_link_delay(link_delay);
        get_up_delay(up_delay);
        get_sub_delay(sub_delay);
        get_tgt_delay(tgt_delay);
        get_delay_comp(delay_comp);

        foreach(port_link_up[i]) begin
            if(port_link_up[i] === 1) begin
                port_string = {
                    port_string, 
                    $sformatf({
                        "port %0d status       : \n",
                        "   up                  : %b\n",
                        "   link delay status   : %s\n",
                        "   delay comp status   : %s\n"
                        },
                        i, port_link_up[i], port_delay_st[i].name, port_comp_st[i].name
                    )
                };
            end
        end

        $display(
            "dump link csr for      : %s\n", name,
            "status                 : \n",
            "   up                  : %b\n", link_up,
            "   link delay status   : %s\n", link_delay_st.name,
            "   delay comp status   : %s\n", delay_comp_st.name,
            "control                : \n",
            "   is head             : %b\n", is_head,
            "   dc on               : %b\n", dc_on,
            "%s", port_string,
            "topo id                : %x\n", topo_id,
            "link delay             : %x = %e s\n", link_delay, (link_delay >> evn::DELAY_FRAC_W) / FCLK,
            "upstream delay         : %x = %e s\n", up_delay,   (up_delay   >> evn::DELAY_FRAC_W) / FCLK,
            "subtree delay          : %x = %e s\n", sub_delay,  (sub_delay  >> evn::DELAY_FRAC_W) / FCLK,
            "target delay           : %x = %e s\n", tgt_delay,  (tgt_delay  >> evn::DELAY_FRAC_W) / FCLK,
            "delay compensation     : %x = %e s\n", delay_comp, (delay_comp >> evn::DELAY_FRAC_W) / FCLK
        );

    endtask
endclass