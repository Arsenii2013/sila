`timescale 1ns/1ps

class NetworkConfiguration;
    typedef evn::topo_id_t topo_id_t;
    typedef evn::delay_t delay_t;

    typedef enum bit [$bits(device_info_axi_core_pkg::device_info_axi_core__device_type_encoding_e) - 1:0] {
        HSSR = device_info_axi_core_pkg::device_info_axi_core__device_type_encoding__HSSR,
        HSSM = device_info_axi_core_pkg::device_info_axi_core__device_type_encoding__HSSM
    } device_type_t;
    typedef struct {
        topo_id_t       topo_id; // линьк определяется тополог. идентификатором принимающего устройства
        realtime        delay;
        bit             asymmetric_delay;
        device_type_t   device_type;
        int             ports_used[];
    } link_conf_t;

    local link_conf_t links_confs [string];
    local realtime    max_sub_delay;
    local bit         creation_done_flag = 0;

    function set_links_conf(link_conf_t links_confs [string]); // строки - имена модулей
        this.links_confs = links_confs;
    endfunction

    function set_max_sub_delay(realtime max_sub_delay);
        this.max_sub_delay = max_sub_delay;
    endfunction

    function finalize();
        creation_done_flag = 1;
    endfunction

    task get_link_conf(input string name, output link_conf_t link_conf);
        wait(creation_done_flag);
        link_conf = links_confs[name];
    endtask

    task get_max_sub_delay(output realtime max_sub_delay);
        wait(creation_done_flag);
        max_sub_delay = this.max_sub_delay;
    endtask
endclass
