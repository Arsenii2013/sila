package ev_map_generator_pkg;
localparam MAX_GENERATORS = 24;
typedef struct{
    logic set;
    logic clear;
    logic trigger;
    logic cnt_reset;
} single_map_t;

function logic[3:0] single_map_to_logic(single_map_t map);
    return {map.cnt_reset, map.trigger, map.clear, map.set};
endfunction
function single_map_t logic_to_single_map(logic [3:0] map);
    return '{map[0], map[1], map[2], map[3]};
endfunction

typedef struct{
    ev_map_pkg::ev_t ev;
    single_map_t     map[];
} mapping_item_t;

endpackage

class ev_map_generator#(
    parameter BASE  = 'h0
) extends axi_generator;

    localparam MAX_GENERATORS = ev_map_generator_pkg::MAX_GENERATORS;
    local int entrys_num;
    typedef ev_map_generator_pkg::single_map_t   single_map_t;
    typedef ev_map_generator_pkg::mapping_item_t mapping_item_t;
    typedef ev_map_pkg::ev_t                     ev_t;

    function new (
        virtual virtual_clock_if clk_if,
        axi_transaction_pkg::item_mailbox_t req_mailbox,
        axi_transaction_pkg::item_mailbox_t resp_mailbox,
        int resp_channel
    );
        super.new(clk_if, req_mailbox, resp_mailbox, resp_channel);
        entrys_num = 0;
    endfunction

    local task _write_map(input int entry, input ev_t ev, input single_map_t map [MAX_GENERATORS]);
        import ev_map_generator_pkg::*;
        write(BASE + entry * 'h10 + 'h00, data_t'(ev));
        write(BASE + entry * 'h10 + 'h04, {single_map_to_logic(map[7]), single_map_to_logic(map[6]), 
                                           single_map_to_logic(map[5]), single_map_to_logic(map[4]), 
                                           single_map_to_logic(map[3]), single_map_to_logic(map[2]), 
                                           single_map_to_logic(map[1]), single_map_to_logic(map[0])});
        write(BASE + entry * 'h10 + 'h08, {single_map_to_logic(map[15]), single_map_to_logic(map[14]), 
                                           single_map_to_logic(map[13]), single_map_to_logic(map[12]), 
                                           single_map_to_logic(map[11]), single_map_to_logic(map[10]), 
                                           single_map_to_logic(map[9]), single_map_to_logic(map[8])});
        write(BASE + entry * 'h10 + 'h0C, {single_map_to_logic(map[23]), single_map_to_logic(map[22]), 
                                           single_map_to_logic(map[21]), single_map_to_logic(map[20]), 
                                           single_map_to_logic(map[19]), single_map_to_logic(map[18]), 
                                           single_map_to_logic(map[17]), single_map_to_logic(map[16])});
    endtask

    local task _read_map(input int entry, output ev_t ev, output single_map_t map [MAX_GENERATORS]);
        import ev_map_generator_pkg::*;
        data_t rd_data1, rd_data2, rd_data3;
        read(BASE + entry * 'h10 + 'h00, rd_data1);
        ev = rd_data1;
        read(BASE + entry * 'h10 + 'h04, rd_data1);
        read(BASE + entry * 'h10 + 'h08, rd_data2);
        read(BASE + entry * 'h10 + 'h0C, rd_data3);
        map[0]  = logic_to_single_map(rd_data1[3 :0 ]); map[1]  = logic_to_single_map(rd_data1[7 :4 ]); 
        map[2]  = logic_to_single_map(rd_data1[11:8 ]); map[3]  = logic_to_single_map(rd_data1[15:12]); 
        map[4]  = logic_to_single_map(rd_data1[19:16]); map[5]  = logic_to_single_map(rd_data1[23:20]); 
        map[6]  = logic_to_single_map(rd_data1[27:24]); map[7]  = logic_to_single_map(rd_data1[31:28]); 
        map[8]  = logic_to_single_map(rd_data2[3 :0 ]); map[9]  = logic_to_single_map(rd_data2[7 :4 ]); 
        map[10] = logic_to_single_map(rd_data2[11:8 ]); map[11] = logic_to_single_map(rd_data2[15:12]); 
        map[12] = logic_to_single_map(rd_data2[19:16]); map[13] = logic_to_single_map(rd_data2[23:20]); 
        map[14] = logic_to_single_map(rd_data2[27:24]); map[15] = logic_to_single_map(rd_data2[31:28]); 
        map[16] = logic_to_single_map(rd_data3[3 :0 ]); map[17] = logic_to_single_map(rd_data3[7 :4 ]); 
        map[18] = logic_to_single_map(rd_data3[11:8 ]); map[19] = logic_to_single_map(rd_data3[15:12]); 
        map[20] = logic_to_single_map(rd_data3[19:16]); map[21] = logic_to_single_map(rd_data3[23:20]); 
        map[22] = logic_to_single_map(rd_data3[27:24]); map[23] = logic_to_single_map(rd_data3[31:28]); 
    endtask

    local task write_map(input int entry, input ev_t ev, input single_map_t map []);
        single_map_t map_full [MAX_GENERATORS];
        int size = map.size();
        assert(size < MAX_GENERATORS) else $display("mapping size greater than generator number");

        foreach(map_full[i]) begin
            if(i < size) begin
                map_full[i] = map[i];
            end else begin
                map_full[i] = '{0, 0, 0, 0};
            end
        end
        _write_map(entry, ev, map_full);
    endtask

    task read_map(input int entry, output ev_t ev, output single_map_t map []);
        single_map_t rd_map [MAX_GENERATORS];
        int copy_to = 0;
        _read_map(entry, ev, rd_map);
        if(map.size() == 0) begin
            foreach(rd_map[i]) begin
                if(rd_map[i] != '{0, 0, 0, 0} && i > copy_to)
                    copy_to = i;
            end
            map = new [copy_to + 1];
        end else begin
            copy_to = map.size() - 1;
        end

        for(int i = 0; i <= copy_to; i ++) begin
            map[i] = rd_map[i];
        end
    endtask

    task add_map(input ev_t ev, input single_map_t map []);
        write_map(entrys_num, ev, map);
        entrys_num = entrys_num + 1;
    endtask

    task clear_mapping();
        while(entrys_num) begin
            _write_map(entrys_num, '0, '{default:'{0, 0, 0, 0}});
            entrys_num -= 1;
        end
    endtask

    task write_mapping(mapping_item_t mapping[]);
        entrys_num = 0;
        foreach (mapping[i]) begin
            add_map(mapping[i].ev, mapping[i].map);
        end
    endtask

    task verify_mapping(mapping_item_t mapping[]);
        single_map_t rd_map[];
        ev_t         rd_ev;
        foreach (mapping[i]) begin
            read_map(i, rd_ev, rd_map);
            if(rd_ev != mapping[i].ev || rd_map != mapping[i].map) begin
                $display("error read event : %8h, map : %p, size : %d expect event : %08h, map : %p, size : %d", 
                        rd_ev, rd_map, rd_map.size(), mapping[i].ev, mapping[i].map, mapping[i].map.size());
                $stop();
                rd_map.delete();
            end
        end
    endtask

    task dump();
        single_map_t rd_map[];
        ev_t         rd_ev;
        $display("ev_map dump");
        for(int i = 0; i < entrys_num; i++) begin
            read_map(i, rd_ev, rd_map);
            $display("event : %08h, map : %p", rd_ev, rd_map);
            rd_map.delete();
        end
    endtask
endclass