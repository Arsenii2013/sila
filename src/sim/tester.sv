class Tester #(
    parameter axi_params::gp0_addr_t GP_0_BASE_ADDR = 32'h4000_0000
);
    localparam unsigned AW = axi_params::GP0_ADDR_W;
    localparam unsigned DW = axi_params::GP0_DATA_W;

    typedef evn::topo_id_t topo_id_t;
    typedef enum bit [$bits(NetworkConfiguration::device_type_t) - 1:0] {
        HSSR = NetworkConfiguration::HSSR,
        HSSM = NetworkConfiguration::HSSM
    } device_type_t;
    typedef NetworkConfiguration::link_conf_t link_conf_t;
    typedef enum bit [$bits(i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t_e) - 1:0] {
        SI570 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SI570,
        PLL1 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__PLL1,
        PLL2 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__PLL2,
        SFP0 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SFP0,
        SFP1 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SFP1,
        SFP2 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SFP2,
        SFP3 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SFP3,
        SFP4 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SFP4,
        SFP5 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SFP5,
        SFP6 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SFP6,
        SFP7 = i2c_mux_axi_core_pkg::i2c_mux_axi_core__select_t__SFP7
    } i2c_mux_sel_t;

    virtual virtual_clock_if clk_if;

    string name;
    device_type_t device_type;
    link_conf_t link_conf;
    semaphore display_key;

    axi_transaction_pkg::item_mailbox_t req_mbx  = new();
    axi_transaction_pkg::item_mailbox_t resp_mbx = new();

    axi_driver #(
        .AW(AW),
        .DW(DW)
    ) driver;
    axi_generator generic_generator;

    typedef enum{
        GENERIC_RD_CH = 0
    } rd_ch_enum;

    function new(virtual virtual_clock_if clk_if, virtual axi4_lite_if #(.DW(DW), .AW(AW)) axi, string module_name);
        driver = new(clk_if, axi, req_mbx, resp_mbx);
        //driver.set_verbose();
        generic_generator = new(clk_if, 0, req_mbx, resp_mbx, GENERIC_RD_CH);

        this.clk_if = clk_if;
        this.name = module_name;
        this.link_conf = '{0, 0ns, 0, NetworkConfiguration::HSSR, '{}};
        this.display_key = Globals::get_display_key();

        fork
        begin
            Globals::get_network_configuration().get_link_conf(module_name, link_conf);
        end
        join_none
    endfunction

    static function axi_params::gp0_addr_t base_from_device_number(int number);
        return GP_0_BASE_ADDR + 2 ** axi_params::GP0_ADDR_W / axi_params::MMR_DEV_CNT2 * number;
    endfunction

    virtual task select_I2C_mux(i2c_mux_sel_t sel);
    endtask

    virtual task read_XADC_temp(output axi_params::gp0_data_t temp);
    endtask

    virtual function set_name(string new_name);
        name = new_name;
    endfunction

    task get_device_type(output device_type_t d_type);
        axi_params::mmr_data_t rd_data;
        generic_generator.read(base_from_device_number(0) + 'h10, rd_data);
        d_type = device_type_t'(rd_data);
    endtask

    task setup_name();
        get_device_type(device_type);
        assert(link_conf.device_type == device_type) 
        else begin 
            $display("ERROR: Device type mismatch");
            $stop();
        end
        set_name($sformatf("%s with topo_id %x*", device_type.name, link_conf.topo_id));
    endtask

    virtual task run();
    endtask
endclass
