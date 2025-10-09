package gen_map_generator_pkg;
localparam MAX_DIFF_IOS = 16;
typedef struct{
    logic o1;
    logic o2;
} single_map_t;

function logic[1:0] single_map_to_logic(single_map_t map);
    return {map.o2, map.o1};
endfunction
function single_map_t logic_to_single_map(logic [1:0] map);
    return '{map[0], map[1]};
endfunction

typedef struct{
    single_map_t     map[];
} mapping_item_t;

endpackage

class gen_map_generator#(
    parameter BASE  = 'h0
) extends axi_generator;

    localparam MAX_DIFF_IOS = gen_map_generator_pkg::MAX_DIFF_IOS;
    local int entrys_num;
    typedef gen_map_generator_pkg::single_map_t   single_map_t;
    typedef gen_map_generator_pkg::mapping_item_t mapping_item_t;

    function new (
        virtual virtual_clock_if clk_if,
        axi_transaction_pkg::item_mailbox_t req_mailbox,
        axi_transaction_pkg::item_mailbox_t resp_mailbox,
        int resp_channel
    );
        super.new(clk_if, req_mailbox, resp_mailbox, resp_channel);
        entrys_num = 0;
    endfunction

    local task _write_map(input int entry, input single_map_t map [MAX_DIFF_IOS]);
        import gen_map_generator_pkg::*;

        write(BASE + entry * 'h4 + 'h00, {single_map_to_logic(map[15]), single_map_to_logic(map[14]), 
                                           single_map_to_logic(map[13]), single_map_to_logic(map[12]), 
                                           single_map_to_logic(map[11]), single_map_to_logic(map[10]), 
                                           single_map_to_logic(map[9 ]), single_map_to_logic(map[8 ]),
                                           single_map_to_logic(map[7 ]), single_map_to_logic(map[6 ]), 
                                           single_map_to_logic(map[5 ]), single_map_to_logic(map[4 ]), 
                                           single_map_to_logic(map[3 ]), single_map_to_logic(map[2 ]), 
                                           single_map_to_logic(map[1 ]), single_map_to_logic(map[0 ])});
    endtask

    local task _read_map(input int entry, output single_map_t map [MAX_DIFF_IOS]);
        import gen_map_generator_pkg::*;
        data_t rd_data;
        read(BASE + entry * 'h4 + 'h00, rd_data);
        map[0]  = logic_to_single_map(rd_data[1 :0 ]); map[1]  = logic_to_single_map(rd_data[3 :2 ]); 
        map[2]  = logic_to_single_map(rd_data[5 :4 ]); map[3]  = logic_to_single_map(rd_data[7 :6 ]); 
        map[4]  = logic_to_single_map(rd_data[9 :8 ]); map[5]  = logic_to_single_map(rd_data[11:10]); 
        map[6]  = logic_to_single_map(rd_data[13:12]); map[7]  = logic_to_single_map(rd_data[15:14]); 
        map[8]  = logic_to_single_map(rd_data[17:16]); map[9]  = logic_to_single_map(rd_data[19:18]); 
        map[10] = logic_to_single_map(rd_data[21:20]); map[11] = logic_to_single_map(rd_data[23:22]); 
        map[12] = logic_to_single_map(rd_data[25:24]); map[13] = logic_to_single_map(rd_data[27:26]); 
        map[14] = logic_to_single_map(rd_data[29:28]); map[15] = logic_to_single_map(rd_data[31:30]); 
    endtask

    local task write_map(input int entry, input single_map_t map []);
        single_map_t map_full [MAX_DIFF_IOS];
        int size = map.size();
        assert(size <= MAX_DIFF_IOS) else $display("mapping size greater than diff_ios number");

        foreach(map_full[i]) begin
            if(i < size) begin
                map_full[i] = map[i];
            end else begin
                map_full[i] = '{0, 0};
            end
        end
        _write_map(entry, map_full);
    endtask

    task read_map(input int entry, output single_map_t map []);
        single_map_t rd_map [MAX_DIFF_IOS];
        int copy_to = 0;
        _read_map(entry, rd_map);
        if(map.size() == 0) begin
            copy_to = MAX_DIFF_IOS - 1;
            map = new [copy_to + 1];
        end else begin
            copy_to = map.size() - 1;
        end

        for(int i = 0; i <= copy_to; i ++) begin
            map[i] = rd_map[i];
        end
    endtask

    task add_map(input single_map_t map []);
        write_map(entrys_num, map);
        entrys_num = entrys_num + 1;
    endtask

    task clear_mapping();
        while(entrys_num) begin
            _write_map(entrys_num, '{default:'{0, 0}});
            entrys_num -= 1;
        end
    endtask

    task write_mapping(mapping_item_t mapping[]);
        entrys_num = 0;
        foreach (mapping[i]) begin
            add_map(mapping[i].map);
        end
    endtask

    task verify_mapping(mapping_item_t mapping[]);
        single_map_t rd_map[];
        foreach (mapping[i]) begin
            read_map(i, rd_map);
            if(rd_map != mapping[i].map) begin
                $display("error read generator : %d map : %p, size : %d expect map : %p, size : %d", 
                        i, rd_map, rd_map.size(), mapping[i].map, mapping[i].map.size());
                $stop();
                rd_map.delete();
            end
        end
    endtask

    task dump();
        single_map_t rd_map[];
        $display("gen_map dump");
        for(int i = 0; i < entrys_num; i++) begin
            read_map(i, rd_map);
            $display("generator %d, map : %p", i, rd_map);
            rd_map.delete();
        end
    endtask
endclass