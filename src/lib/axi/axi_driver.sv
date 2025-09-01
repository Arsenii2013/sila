package axi_transaction_pkg;
localparam AW = 32;
localparam DW = 32;

typedef logic [AW-1:0] addr_t;
typedef logic [DW-1:0] data_t;

typedef enum {
    READ,
    READ_RESPONCE,
    WRITE,
    VERIFY,
    WRITE_VERIFY
} item_type_t;

typedef struct {
    item_type_t item_type;
    addr_t      addr;
    data_t      data;
    int         resp_channel;
} item_t;

function display_item(item_t item);
    $display("item: type %s, addr %x, data %x, resp channel %d", item.item_type.name, item.addr, item.data, item.resp_channel);
endfunction

typedef mailbox #(item_t) item_mailbox_t;
endpackage

interface virtual_clock_if(
    input clk,
    input reset
);
endinterface

class axi_driver;

    virtual axi4_lite_if #(.AW(axi_transaction_pkg::AW), .DW(axi_transaction_pkg::DW)) axi;
    virtual virtual_clock_if            clk_if;
    axi_transaction_pkg::item_mailbox_t req_mailbox;
    axi_transaction_pkg::item_mailbox_t resp_mailbox;

    function new (
        virtual virtual_clock_if clk_if, 
        virtual axi4_lite_if #(.AW(axi_transaction_pkg::AW), .DW(axi_transaction_pkg::DW)) axi, 
        axi_transaction_pkg::item_mailbox_t req_mailbox, 
        axi_transaction_pkg::item_mailbox_t resp_mailbox
    );
        this.clk_if       = clk_if;
        this.axi          = axi;
        this.req_mailbox  = req_mailbox;
        this.resp_mailbox = resp_mailbox;
        fork
            serve_mailboxes();
        join_none
    endfunction

    task automatic serve_mailboxes();
        axi_transaction_pkg::item_t req_item;
        axi_transaction_pkg::item_t resp_item = '{item_type:axi_transaction_pkg::READ_RESPONCE};
        axi_transaction_pkg::data_t rd_data;
        forever begin
            this.req_mailbox.get(req_item);
            case (req_item.item_type)
            axi_transaction_pkg::READ  : begin
                this.read(req_item.addr, rd_data);
                resp_item.addr         = req_item.addr;
                resp_item.data         = rd_data;
                resp_item.resp_channel = req_item.resp_channel;
                @(posedge this.clk_if.clk);
                this.resp_mailbox.put(resp_item);
            end
            axi_transaction_pkg::WRITE :        this.write(req_item.addr, req_item.data);
            axi_transaction_pkg::VERIFY :       this.verify(req_item.addr, req_item.data);
            axi_transaction_pkg::WRITE_VERIFY : this.write_verify(req_item.addr, req_item.data);
            endcase
        end
    endtask

    task sync();
    forever @(posedge clk_if.clk) if(req_mailbox.num() == 0) return;
    endtask

    task automatic read(input axi_transaction_pkg::addr_t addr, output axi_transaction_pkg::data_t data);
        begin

        logic [3:0] rresp;
        
        @(posedge this.clk_if.clk)
        this.axi.araddr  <= addr;
        this.axi.arvalid <= 1;
        this.axi.rready  <= 1;

        for(;;) begin
            @(posedge this.clk_if.clk)
            if(this.axi.arready)
                break;
        end
        this.axi.arvalid <= 0;

        for(;;) begin
            @(posedge this.clk_if.clk)
            if(this.axi.rvalid)
                break;
        end
        data        = this.axi.rdata;
        rresp       = this.axi.rresp;
        this.axi.rready  <= 0;

        if(rresp != 'b000)
            $display("RRESP isnt equal 0! RRESP = %x", rresp);

        //$display("[%t] : Address: %x, Data: %x", $realtime, addr, data);
        end
    endtask

    task automatic verify(input axi_transaction_pkg::addr_t addr, input axi_transaction_pkg::data_t data);
        begin
        axi_transaction_pkg::data_t rdata;
        this.read(addr, rdata);
        assert(rdata == data) else $error("Read at addr %h expect %h, but got %h", addr, data, rdata);
        end
    endtask

    task automatic write(input axi_transaction_pkg::addr_t addr, input axi_transaction_pkg::data_t data);
        begin

        logic [3:0] wresp;
        
        @(posedge this.clk_if.clk)
        this.axi.awaddr  <= addr;
        this.axi.wdata   <= data;
        this.axi.awvalid <= 1;
        this.axi.wvalid  <= 1;
        this.axi.wstrb   <= 'hFFFF;
        this.axi.bready  <= 1;
        this.axi.rready  <= 0;

        for(;;) begin
            @(posedge clk_if.clk)
            if(this.axi.awready && this.axi.wready)
                break;
        end
        this.axi.awvalid <= 0;
        this.axi.wvalid  <= 0;

        for(;;) begin
            @(posedge this.clk_if.clk)
            if(this.axi.bvalid)
                break;
        end
        wresp       = this.axi.bresp;
        this.axi.rready  <= 0;

        if(wresp != 'b000)
            $display("BRESP isnt equal 0! BRESP = %x", wresp);

        //$display("[%t] : Address: %x, Data: %x", $realtime, addr, data);
        end
    endtask

    task automatic write_verify(input axi_transaction_pkg::addr_t addr, input axi_transaction_pkg::data_t data);
        begin
        axi_transaction_pkg::data_t rdata;
        this.write(addr, data);
        this.read(addr, rdata);
        assert(rdata == data) else $error("Read at addr %h expect %h, but got %h", addr, data, rdata);
        end
    endtask

endclass