`include "top.svh"
`include "evn.svh"
`include "axi4_lite_if.svh"

module evr
(
    input  logic            beacon_clk,

    //------GTP signals-------
    input  logic            aligned,

    input  logic            tx_resetdone,
    input  logic            tx_clk,
    output logic [31:0]     tx_data,
    output logic [3:0]      tx_charisk,

    input  logic            rx_resetdone,
    input  logic            rx_clk,
    input  logic [31:0]     rx_data,
    input  logic [3:0]      rx_charisk,

    //------Application signals-------
    output logic            app_clk,
    input  logic            app_rst,
    axi4_lite_if.s          mmr,
    
    output logic [23:0]     ev, // ev_valid = ev != 0
    input  logic [23:0]     trig, // trig_valid = trig != 0
    axi_stream_if.s         in_packet,
    axi_stream_if.m         out_packet
);
    assign in_packet.tready = 0;
    assign out_packet.tvalid = 0;

    typedef logic [DELAY_INT_W+DELAY_FRAC_W-1: 0] delay_t;
    typedef logic [TOPO_ID_W               -1: 0] topo_id_t;

// Trigger
    logic trig_valid;
    assign trig_valid = trig != '0;
    
// Beacon
    logic beacon_pulse;
    pf_m #(
        .POR("OFF")
    ) pf_beacon(
        .clk(rx_clk),
        .in(rx_data == BEACON_WORD && rx_charisk == BEACON_IS_K),
        .out(beacon_pulse)
    );
    logic beacon_pulse_sync;
    xpm_cdc_pulse beacon_sunchronizer_i(
        .dest_clk(tx_clk),
        .dest_pulse(beacon_pulse_sync),
        .dest_rst(app_rst),
        .src_clk(rx_clk),
        .src_pulse(beacon_pulse),
        .src_rst(app_rst)
    );

    logic beacon_valid = 0;
    logic beacon_ready = 0;

    always_ff @(posedge tx_clk) begin
        if(app_rst) begin
            beacon_valid <= 0;
        end else begin
            if(beacon_pulse_sync) begin
                beacon_valid <= 1;
            end else begin
                if(beacon_ready) begin
                    beacon_valid <= 0;
                end else begin
                    beacon_valid <= beacon_valid;
                end
            end
        end
    end

// Alignment 
    logic alignment_valid = 0;
    logic alignment_ready = 0;
    alignment_cnt_t alignment_cnt = ALIGNMENT_PERIOD;

    always_ff @(posedge tx_clk) begin
        if(app_rst) begin
            alignment_cnt   <= ALIGNMENT_PERIOD;
            alignment_valid <= 0;
        end else begin
            if(alignment_cnt == 0) begin
                alignment_cnt   <= ALIGNMENT_PERIOD;
                alignment_valid <= 1;
            end else begin
                alignment_cnt <= alignment_cnt - 1;
                if(alignment_ready) begin
                    alignment_valid <= 0;
                end else begin
                    alignment_valid <= alignment_valid;
                end
            end
        end
    end


// Mux
    always_ff @(posedge tx_clk) begin
        alignment_ready <= 0;
        beacon_ready    <= 0;
        tx_data         <= '0;
        tx_charisk      <= '0;

        if(trig_valid) begin
            tx_data         <= {TRIGGER_COMMA, trig};
            tx_charisk      <= 'h8;
        end else if(beacon_valid && ~beacon_ready) begin
            tx_data         <= BEACON_WORD;
            tx_charisk      <= BEACON_IS_K;
            beacon_ready    <= 1;
        end else if(alignment_valid && ~alignment_ready) begin
            tx_data         <= ALIGNMENT_WORD;
            tx_charisk      <= ALIGNMENT_IS_K;
            alignment_ready <= 1;
        end else begin
            tx_data         <= '0;
            tx_charisk      <= '0;
        end
    end


// System packets
    topo_id_t topo_id;
    delay_t link_delay, tgt_delay;
    logic tgt_delay_recv;
    logic [3:0] link_delay_st;
    logic link_delay_recv;

    system_stream_if #(.DW(32)) system_stream();
    assign system_stream.tdata  = rx_data;
    assign system_stream.tisk   = rx_charisk;
    assign system_stream.tvalid = rx_charisk == 0 || (rx_data[31:24] == PACKET_COMMA && rx_charisk == PACKET_START_IS_K);

    evr_system_packet_reciever evr_system_packet_reciever_i(
        .rx_clk(rx_clk),
        .app_clk(app_clk),
        .app_rst(app_rst),
        .topo_id(topo_id),
        .topo_id_recv(),
        .meas_delay(link_delay),
        .meas_delay_st(link_delay_st),
        .meas_delay_recv(link_delay_recv),
        .tgt_delay(tgt_delay),
        .tgt_delay_recv(tgt_delay_recv),
        .in(system_stream)
    );

// Delay compensation
    logic mmcm_locked;
    logic dc_ena;
    logic fifo_rst_busy;
    logic [3:0] dc_status;
    delay_t delay_comp;

    logic [31:0] fifo_in_data;
    logic [31:0] fifo_out_data;
    logic [ 3:0] fifo_in_isk;
    logic [ 3:0] fifo_out_isk;
    logic fifo_inc, fifo_dec, pll_ph_inc, pll_ph_dec;

    assign fifo_in_data = (rx_data[31:24] == EVENT_COMMA && rx_charisk == 'h8        ) ||
                          (rx_data == BEACON_WORD        && rx_charisk == BEACON_IS_K) 
                          ? rx_data : '0;
    assign fifo_in_isk  = (rx_data[31:24] == EVENT_COMMA && rx_charisk == 'h8        ) ||
                          (rx_data == BEACON_WORD        && rx_charisk == BEACON_IS_K) 
                          ? rx_charisk : '0;
    assign ev = (fifo_out_data[31:24] == EVENT_COMMA && fifo_out_isk == 'h8        )
                ? fifo_out_data[23:0] : '0;

    fifo_wrapper #(
        .DEPTH(MAX_COMPENSATION)
    ) fifo_i (
        .app_rst(app_rst || !mmcm_locked),
        .app_clk(app_clk),
        .rx_clk(rx_clk),

        .data_in(fifo_in_data),
        .isk_in(fifo_in_isk),
        .data_out(fifo_out_data),
        .isk_out(fifo_out_isk),

        .fifo_inc(fifo_inc),
        .fifo_dec(fifo_dec),

        .rst_busy(fifo_rst_busy)
    );

    mmcm_wrapper mmcm_i(
        .clk_in1(rx_clk),
        .clk_in2(beacon_clk),
        .clk_in_sel(aligned),
        
        .clk_out1(app_clk),

        .ph_inc(pll_ph_inc),
        .ph_dec(pll_ph_dec),

        .reset(0),
        .locked(mmcm_locked)
    );

    dc_control #(
        .INT_W(DELAY_INT_W),
        .FRAC_W(DELAY_FRAC_W)
    ) dc_control_i (
        .app_clk(app_clk),
        .app_rst(app_rst || !mmcm_locked),
        .dc_ena(dc_ena),
        .fifo_rst_busy(fifo_rst_busy),

        .beacon_in((fifo_in_data == BEACON_WORD) && (fifo_in_isk == BEACON_IS_K)),
        .rx_clk(rx_clk),
        .beacon_out((fifo_out_data == BEACON_WORD) && (fifo_out_isk == BEACON_IS_K)),
        .beacon_clk(beacon_clk),

        .fifo_inc(fifo_inc),
        .fifo_dec(fifo_dec),
        .pll_ph_inc(pll_ph_inc),
        .pll_ph_dec(pll_ph_dec),
    
        .dc_status(dc_status),
        .delay_req(tgt_delay - link_delay),
        .delay_req_upd(tgt_delay_recv),
        
        .delay_comp(delay_comp)
    );

    evr_axi_core #(
        .ADDR_W(GP0_ADDR_W),
        .DATA_W(GP0_DATA_W)
    ) evr_axi_core_i (
        .app_clk(app_clk),
        .app_rst(app_rst),
        .mmr(mmr),
        .aligned(aligned),
        .dc_ena(dc_ena),
        .topoid(topo_id),
        .delay(link_delay),
        .delay_status(link_delay_st),
        .dc_status(dc_status),
        .tgt_delay(tgt_delay),
        .delay_comp(delay_comp)
    );

endmodule

module evr_axi_core#(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)(
    input  logic                                 app_clk,
    input  logic                                 app_rst,
    axi4_lite_if.s                               mmr,

    input  logic                                 aligned,
    output logic                                 dc_ena,
    input  logic [TOPO_ID_W               -1: 0] topoid,
    input  logic [DELAY_INT_W+DELAY_FRAC_W-1: 0] delay,
    input  logic [3                         : 0] delay_status,
    input  logic [3                         : 0] dc_status,
    input  logic [DELAY_INT_W+DELAY_FRAC_W-1: 0] tgt_delay,
    input  logic [DELAY_INT_W+DELAY_FRAC_W-1: 0] delay_comp
);
//MMR logic 
    typedef logic [ADDR_W-1:0] addr_t;
    typedef logic [DATA_W-1:0] data_t;

    typedef enum addr_t {
        SR            = addr_t'(8'h00),
        CR            = addr_t'(8'h04),
        CR_S          = addr_t'(8'h08),
        CR_C          = addr_t'(8'h0C),
        LINK_TOPO_ID  = addr_t'(8'h10),
        LINK_DELAY    = addr_t'(8'h14),
        TGT_DELAY     = addr_t'(8'h18),
        DELAY_COMP    = addr_t'(8'h1C)
    } evr_regs;

    typedef struct packed {
        logic [3:0] delay_comp_st;
        logic [3:0] link_delay_st;
        logic [2:0] none;
        logic       link_up;
    } sr_t;

    typedef struct packed {
        logic dc_ena;
    } cr_t;

    sr_t sr;
    cr_t cr = 0;
    addr_t addr;
    data_t data;
    logic read;
    logic write_addr;
    logic write_data;

    assign sr.link_up       = aligned;
    assign sr.none          = '0;
    assign sr.link_delay_st = delay_status;
    assign sr.delay_comp_st = dc_status;

    assign dc_ena           = cr.dc_ena;

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
            cr          <= '0;
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
                    LINK_TOPO_ID  : mmr.rdata <= data_t'(topoid);
                    LINK_DELAY    : mmr.rdata <= data_t'(delay);
                    TGT_DELAY     : mmr.rdata <= data_t'(tgt_delay);
                    DELAY_COMP    : mmr.rdata <= data_t'(delay_comp);
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
                    default;
                endcase
            end 
            
        end
    end
endmodule