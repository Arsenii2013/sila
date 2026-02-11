
class HSSRTester #(
    parameter axi_params::gp0_addr_t GP_0_BASE_ADDR = 32'h4000_0000
) extends Tester #
    (.GP_0_BASE_ADDR(GP_0_BASE_ADDR)
);
    typedef enum{
        GENERIC_RD_CH = GENERIC_RD_CH,
        EVR_RD_CH,
        SIG_GEN_RD_CH,
        EV_MAP_RD_CH,
        GEN_MAP_RD_CH,
        DIFF_IO_RD_CH
    } HSSR_rd_ch_enum;


    link_csr_generator evr_generator_i;

    signal_generator_generator #(
        .GEN_N(HSSR_axi_params::SIG_GEN_N)
    ) signal_generator_generator_i;

    ev_map_generator ev_map_generator_i;
    gen_map_generator gen_map_generator_i;
    diff_io_generator diff_io_generator_i;

    function new(virtual virtual_clock_if clk_if, virtual axi4_lite_if #(.DW(DW), .AW(AW)) axi, string module_name);
        super.new(clk_if, axi, module_name);
        evr_generator_i = new(clk_if, base_from_device_number(HSSR_axi_params::EVR), req_mbx, resp_mbx, EVR_RD_CH, name);
        signal_generator_generator_i = new(clk_if, base_from_device_number(HSSR_axi_params::SIG_GEN_CTRL), req_mbx, resp_mbx, SIG_GEN_RD_CH);
        ev_map_generator_i = new(clk_if, base_from_device_number(HSSR_axi_params::EV_MAP), req_mbx, resp_mbx, EV_MAP_RD_CH);
        gen_map_generator_i = new(clk_if, base_from_device_number(HSSR_axi_params::SIG_GEN_MAP), req_mbx, resp_mbx, GEN_MAP_RD_CH);
        diff_io_generator_i = new(clk_if, base_from_device_number(HSSR_axi_params::DIFF_IO), req_mbx, resp_mbx, DIFF_IO_RD_CH);
    endfunction

    task select_I2C_mux(i2c_mux_sel_t sel);
        generic_generator.write(base_from_device_number(HSSR_axi_params::I2C_MUX) + 'h4, sel);
        driver.sync();
    endtask

    function set_name(string new_name);
        super.set_name(new_name);
        evr_generator_i.name = new_name;
    endfunction

    task setup_io();
        gen_map_generator_pkg::single_map_t map2 [16];
        diff_io_generator_i.setup('{
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    0, 0},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GATE,         0, 10},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::FLIP_FLOP,    0, 20},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::CLK,          0, 40},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::FORCE_CLEAR,  0, 80},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::FORCE_SET,    0, 160},
            '{diff_io_pkg::NEGATIVE, diff_io_pkg::GENERATOR,    0, 320},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    0, 640},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    1, 0},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    2, 0},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    4, 0},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    8, 0},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    16, 0},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    32, 0},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    64, 0},
            '{diff_io_pkg::POSITIVE, diff_io_pkg::GENERATOR,    0, 0}
        });

        map2 = '{0: '{o1:1, o2:0}, 1: '{o1:1, o2:0}, 2: '{o1:0, o2:0}, 3: '{o1:1, o2:0}, default: '{o1:1, o2:0}};
        gen_map_generator_i.write_mapping('{
            '{map: '{'{o1:0, o2:0}, '{o1:0, o2:0}, '{o1:0, o2:1} }},
            '{map: map2},
            '{map: '{'{o1:0, o2:0}, '{o1:0, o2:0}, '{o1:1, o2:0}}},
            '{map: '{'{o1:0, o2:0}, '{o1:0, o2:0}, '{o1:0, o2:0}, '{o1:0, o2:1}}}
        });

        signal_generator_generator_i.setup('{
            '{'{default:1}, signal_generator_pkg::POSITIVE, signal_generator_pkg::GENERATOR, signal_generator_pkg::EVENT,   0,  0,    0},
            '{'{default:1}, signal_generator_pkg::POSITIVE, signal_generator_pkg::GENERATOR, signal_generator_pkg::EVENT,   0,  100,  100},
            '{'{default:1}, signal_generator_pkg::POSITIVE, signal_generator_pkg::GENERATOR, signal_generator_pkg::PERIOD,  10, 2,    2},
            '{'{default:1}, signal_generator_pkg::POSITIVE, signal_generator_pkg::GENERATOR, signal_generator_pkg::EVENT,   0,  1000, 100}
        });

        ev_map_generator_i.write_mapping('{
            '{ev: 'h1,    map: '{'{set  :1, default:0},     '{           default:0},    '{cnt_reset:1, default:0}}},
            '{ev: 'h20,   map: '{'{         default:0},     '{trigger:1, default:0},    '{             default:0}, '{trigger:1, default:0}}},
            '{ev: 'h80,   map: '{'{clear:1, default:0}                                                           }},
            '{ev: 'h1234, map: '{'{         default:0},     '{trigger:1, default:0},    '{             default:0}, '{trigger:1, default:0}}}
        });
        driver.sync();
    endtask

    task wait_upstream_link();
        topo_id_t topo_id;
        evr_generator_i.wait_delay_status(0, evn::INITIAL, 10us);
        #10us;
        evr_generator_i.get_topo_id(topo_id);
        assert(topo_id == link_conf.topo_id)
        else begin 
            $display("ERROR: HSSR topo_id %x mismatch with expected topo_id %x", topo_id, link_conf.topo_id);
        end
        set_name(name.substr(0, name.len() - 2)); // убрать звездочку

        evr_generator_i.enable_dc();

        #10us;
        display_key.get();
        $display("%s upstream\n"            , name, 
                 "Get INITIAL state at %t\n", $realtime);
        evr_generator_i.dump();
        display_key.put();

        evr_generator_i.wait_delay_status(0, evn::ONE_CYCLE, 1ms);
        #10us;
        display_key.get();
        $display("%s upstream\n"              , name, 
                 "Get ONE_CYCLE state at %t\n", $realtime);
        evr_generator_i.dump();
        display_key.put();
        
        evr_generator_i.wait_delay_status(0, evn::FINE, 100ms);
        #10us;
        display_key.get();
        $display("%s upstream\n"         , name, 
                 "Get FINE state at %t\n", $realtime);
        evr_generator_i.dump();
        display_key.put();
    endtask

    task run();
        $timeformat(-5, 5, " ms");
        wait(clk_if.reset === 0);
        #50us;
        setup_name();
        fork 
            periodic_dump();
        join_none
        setup_io();
        wait_upstream_link();
    endtask

    task periodic_dump();
        forever begin
            display_key.get();
            $display("%s Periodic Dump", name);
            evr_generator_i.dump();
            display_key.put();
            #1ms;
        end
    endtask

endclass