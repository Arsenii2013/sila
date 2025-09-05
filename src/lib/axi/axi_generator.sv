
class axi_generator;
    typedef axi_transaction_pkg::item_mailbox_t mailbox_t;
    typedef axi_transaction_pkg::item_t         item_t;
    typedef axi_transaction_pkg::addr_t         addr_t;
    typedef axi_transaction_pkg::data_t         data_t;
    virtual virtual_clock_if    clk_if;
    mailbox_t                   req_mailbox;
    mailbox_t                   resp_mailbox;
    int                         resp_channel;

    function new (
        virtual virtual_clock_if clk_if,
        mailbox_t req_mailbox,
        mailbox_t resp_mailbox,
        int resp_channel
    );
        this.clk_if       = clk_if;
        this.req_mailbox  = req_mailbox;
        this.resp_mailbox = resp_mailbox;
        this.resp_channel = resp_channel;
    endfunction

    task automatic read(input addr_t addr, output data_t data);
        item_t req_item = '{item_type:axi_transaction_pkg::READ, 
                                                addr:addr, data:data, resp_channel:this.resp_channel};
        item_t resp_item;
        req_mailbox.put(req_item);
        forever begin
            resp_mailbox.peek(resp_item);
            @(posedge clk_if.clk);
            
            if(resp_item.item_type == axi_transaction_pkg::READ_RESPONCE && resp_item.resp_channel == this.resp_channel) begin
                @(posedge clk_if.clk);
                resp_mailbox.get(resp_item);
                data = resp_item.data;
                break;
            end
        end;
    endtask

    task automatic verify(input addr_t addr, input data_t data);
        req_mailbox.put('{item_type:axi_transaction_pkg::VERIFY, addr:addr, data:data, resp_channel:this.resp_channel});
    endtask

    task automatic write(input addr_t addr, input data_t data);
        req_mailbox.put('{item_type:axi_transaction_pkg::WRITE, addr:addr, data:data, resp_channel:this.resp_channel});
    endtask

    task automatic write_verify(input addr_t addr, input data_t data);
        req_mailbox.put('{item_type:axi_transaction_pkg::WRITE_VERIFY, addr:addr, data:data, resp_channel:this.resp_channel});
    endtask

endclass