package ev_seq_generator_pkg;
typedef event_generator_pkg::timestamp_t timestamp_t;
typedef event_generator_pkg::ev_t        ev_t;
typedef struct{
    event_generator_pkg::timestamp_t timestamp;
    event_generator_pkg::ev_t        ev;
} seq_item_t;
endpackage

class ev_seq_generator#(
    parameter BASE  = 'h0
) extends axi_generator;

    local int entrys_num;
    typedef ev_seq_generator_pkg::timestamp_t timestamp_t;
    typedef ev_seq_generator_pkg::ev_t        ev_t;
    typedef ev_seq_generator_pkg::seq_item_t  seq_item_t;

    function new (
        virtual virtual_clock_if clk_if,
        axi_transaction_pkg::item_mailbox_t req_mailbox,
        axi_transaction_pkg::item_mailbox_t resp_mailbox,
        int resp_channel
    );
        super.new(clk_if, req_mailbox, resp_mailbox, resp_channel);
        entrys_num = 0;
    endfunction

    local task write_event(input int entry, input timestamp_t timestamp, input ev_t ev);
        write(BASE + entry * 'h10 + 'h00, timestamp[31:0]);
        write(BASE + entry * 'h10 + 'h04, timestamp[63:32]);
        write(BASE + entry * 'h10 + 'h08, {8'h0, ev});
    endtask

    task read_event(input int entry, output timestamp_t timestamp, output ev_t ev);
        read(BASE + entry * 'h10 + 'h00, timestamp[31:0]);
        read(BASE + entry * 'h10 + 'h04, timestamp[63:32]);
        read(BASE + entry * 'h10 + 'h08, ev);
    endtask

    task add_event(input timestamp_t timestamp, input ev_t ev);
        write_event(entrys_num, timestamp, ev);
        entrys_num = entrys_num + 1;
    endtask
    
    task add_end_of_sequency(input timestamp_t timestamp);
        add_event(timestamp, event_generator_pkg::END_OF_SEQ);
    endtask

    task clear_events();
        while(entrys_num) begin
            write_event(entrys_num, '0, '0);
        end
    endtask

    task write_seq(seq_item_t seq[]);
        entrys_num = 0;
        foreach (seq[i]) begin
            add_event(seq[i].timestamp, seq[i].ev);
        end
    endtask

    task verify_seq(seq_item_t seq[]);
        timestamp_t rd_timestamp;
        ev_t        rd_ev;
        foreach (seq[i]) begin
            read_event(i, rd_timestamp, rd_ev);
            if(rd_timestamp != seq[i].timestamp || rd_ev != seq[i].ev) begin
                $display("error read timestamp : %016h, event : %08h, expect timestamp : %016h, event : %08h,", 
                        rd_timestamp, rd_ev, seq[i].timestamp, seq[i].ev);
                $stop();
            end
        end
    endtask

    task dump();
        timestamp_t rd_timestamp;
        ev_t        rd_ev;
        $display("ev_seq dump");
        for(int i = 0; i < entrys_num; i++) begin
            read_event(i, rd_timestamp, rd_ev);
            $display("timestamp : %016h, event : %08h", rd_timestamp, rd_ev);
        end
    endtask
endclass