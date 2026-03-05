
class HSSMTester #(
    parameter axi_params::gp0_addr_t GP_0_BASE_ADDR = 32'h4000_0000
) extends Tester #
    (.GP_0_BASE_ADDR(GP_0_BASE_ADDR)
);
    typedef enum{
        GENERIC_RD_CH = GENERIC_RD_CH,
        EVG_RD_CH,
        EV_SEQ_0_RD_CH,
        EV_SEQ_1_RD_CH,
        EV_SEQ_CTRL_RD_CH
    } HSSM_rd_ch_enum;

    link_csr_generator evg_generator_i;
    ev_seq_generator ev_seq_generator_i[2];
    ev_seq_ctrl_generator #(
        .SEQ_N(HSSM_axi_params::EV_SEQ_N)
    ) ev_seq_ctrl_generator_i;

    function new(virtual virtual_clock_if clk_if,  virtual axi4_lite_if #(.DW(DW), .AW(AW)) axi, string module_name);
        super.new(clk_if, axi, module_name);
        evg_generator_i = new(clk_if, base_from_device_number(HSSM_axi_params::EVG), req_mbx, resp_mbx, EVG_RD_CH, name);
        ev_seq_generator_i[0] = new(clk_if, base_from_device_number(HSSM_axi_params::EV_SEQ_0 + 0), req_mbx, resp_mbx, EV_SEQ_0_RD_CH);
        ev_seq_generator_i[1] = new(clk_if, base_from_device_number(HSSM_axi_params::EV_SEQ_0 + 1), req_mbx, resp_mbx, EV_SEQ_1_RD_CH);
        ev_seq_ctrl_generator_i = new(clk_if, base_from_device_number(HSSM_axi_params::EV_SEQ_CTRL), req_mbx, resp_mbx, EV_SEQ_CTRL_RD_CH);
    endfunction

    task select_I2C_mux(i2c_mux_sel_t sel);
        generic_generator.write(base_from_device_number(HSSM_axi_params::I2C_MUX) + 'h4, sel);
        driver.sync();
    endtask

    function set_name(string new_name);
        super.set_name(new_name);
        evg_generator_i.name = new_name;
    endfunction

    task setup_event_generators();
        ev_seq_generator_i[0].write_seq('{
            '{0,    'h1},
            '{1,    'h2},
            '{2,    'h3},
            '{3,    'h4},
            '{10,   'h10},
            '{20,   'h20},
            '{40,   'h40},
            '{80,   'h80},
            '{8000, 'h1234},
            '{8001, event_generator_pkg::END_OF_SEQ}
        });
        ev_seq_ctrl_generator_i.setup('{
            '{event_generator_pkg::PROG, event_generator_pkg::RECYCLE},
            '{event_generator_pkg::PROG, event_generator_pkg::SINGLE}
        });
        ev_seq_ctrl_generator_i.enable(0);
        ev_seq_ctrl_generator_i.sw_trig(0);
        driver.sync();
    endtask

    task wait_downstream_links(input int ports []);
        evg_generator_i.wait_delay_statuses(ports, evn::INITIAL, 10us);
        #10us;
        display_key.get();
        $display("%s downstream\n"          , name, 
                 "Get INITIAL state at %t\n", $realtime);
        evg_generator_i.dump();
        display_key.put();

        evg_generator_i.wait_delay_statuses(ports, evn::ONE_CYCLE, 1ms);
        #10us;
        display_key.get();
        $display("%s downstream\n"            , name, 
                 "Get ONE_CYCLE state at %t\n", $realtime);
        evg_generator_i.dump();
        display_key.put();

        evg_generator_i.wait_delay_statuses(ports, evn::FINE, 100ms);
        #10us;
        display_key.get();
        $display("%s downstream\n"       , name, 
                 "Get FINE state at %t\n", $realtime);
        evg_generator_i.dump();
        display_key.put();
    endtask

    task wait_upstream_link();
        topo_id_t topo_id;
        evg_generator_i.wait_delay_status(0, evn::INITIAL, 10us);
        #10us;
        $display("%s upstream\n"            , name, 
                 "Get INITIAL state at %t\n", $realtime);

        evg_generator_i.get_topo_id(topo_id);
        assert(topo_id == link_conf.topo_id)
        else begin 
            $display("ERROR: HSSM topo_id %x mismatch, expected %x", topo_id, link_conf.topo_id);
        end
    endtask

    task run();
        realtime max_sub_delay;
        $timeformat(-5, 5, " ms");
        wait(clk_if.reset === 0);
        #50us;
        setup_name();
        fork 
            periodic_dump();
        join_none
        if(link_conf.topo_id == 0) begin
            setup_event_generators();
            evg_generator_i.set_head();
            Globals::get_network_configuration().get_max_sub_delay(max_sub_delay);

            evg_generator_i.set_tgt_delay((evg_generator_i.time_to_delay_t(max_sub_delay) 
                                        & ~((1 << evn::DELAY_FRAC_W) - 1)) // зануляем дробную часть
                                        + (10 << evn::DELAY_FRAC_W));       // + 10 тактов
            #10us;
            evg_generator_i.set_rf_in();
        end else begin
            wait_upstream_link();
        end
        set_name(name.substr(0, name.len() - 2));
        wait_downstream_links(link_conf.ports_used);
    endtask

    task periodic_dump();
        forever begin
            display_key.get();
            $display("%s Periodic Dump", name);
            evg_generator_i.dump();
            display_key.put();
            #1ms;
        end
    endtask
endclass
