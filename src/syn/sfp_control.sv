`include "top.svh"
`include "axi4_lite_if.svh"

module sfp_control#(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)(
    input  logic   app_clk,
    input  logic   app_rst,
    axi4_lite_if.s mmr,

    output logic   sfp_loss[4]
);
//MMR logic 
    typedef logic [ADDR_W-1:0] addr_t;
    typedef logic [DATA_W-1:0] data_t;

    typedef enum addr_t {
        SR            = addr_t'(8'h00),
        CR            = addr_t'(8'h04),
        CR_S          = addr_t'(8'h08),
        CR_C          = addr_t'(8'h0C),
        SFP_LOSS      = addr_t'(8'h10)
    } sfp_regs;

    typedef struct packed {
        logic none;
    } sr_t;

    typedef struct packed {
        logic none;
    } cr_t;

    sr_t sr;
    cr_t cr;
    addr_t addr;
    data_t data;
    logic read;
    logic write_addr;
    logic write_data;

    logic [3:0] sfp_loss_reg;
    assign sfp_loss[0] = sfp_loss_reg[0];
    assign sfp_loss[1] = sfp_loss_reg[1];
    assign sfp_loss[2] = sfp_loss_reg[2];
    assign sfp_loss[3] = sfp_loss_reg[3];

    always_ff @(posedge app_clk) begin
        if (app_rst) begin
            mmr.arready <= 0;
            mmr.rvalid  <= 0;
            mmr.awready <= 0;
            mmr.wready  <= 0;
            mmr.bvalid  <= 0;
            mmr.rresp   <= '0;
            mmr.bresp   <= '0;
            mmr.rdata   <= '0;
            read        <= 0;
            write_addr  <= 0;
            write_data  <= 0;

            sfp_loss_reg<= '1;
        end
        else begin
            mmr.arready <= 0;
            if(mmr.arvalid && !read) begin
                addr <= mmr.araddr;
                read <= 1;
                mmr.arready <= 1;
            end 

            mmr.rvalid <= read;
            if(mmr.rready && read) begin
                read <= 0;
                case (addr)
                    SR            : mmr.rdata <= data_t'(sr);
                    CR            : mmr.rdata <= data_t'(cr);
                    SFP_LOSS      : mmr.rdata <= data_t'(sfp_loss_reg);
                    default       : mmr.rdata <= '0;
                endcase 
            end 


            mmr.awready <= 0;
            if(mmr.awvalid && !write_addr) begin
                addr <= mmr.awaddr;
                write_addr  <= 1;
                mmr.awready <= 1;
            end 

            mmr.wready <= 0;
            if(mmr.wvalid && !write_data) begin
                data <= mmr.wdata;
                write_data <= 1;
                mmr.wready <= 1;
            end 

            mmr.bvalid <= write_addr && write_data;
            if(mmr.bready && write_addr && write_data) begin
                write_addr <= 0;
                write_data <= 0;
                case (addr)
                    CR        : cr <= cr_t'(data);
                    CR_S      : cr <= cr | cr_t'(data);
                    CR_C      : cr <= cr & ~(cr_t'(data));
                    SFP_LOSS : sfp_loss_reg <= data;
                    default;
                endcase
            end 
            
        end
    end
endmodule