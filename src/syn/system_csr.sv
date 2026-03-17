module system_csr(
    input  logic        app_clk,
    input  logic        app_rst,
    axi4_lite_if.s      mmr,

    input  evn::ev_t    ev_in,
    output evn::ev_t    ev_out
);
    system_csr_axi_core_pkg::system_csr_axi_core__in_t  hwif_in;
    system_csr_axi_core_pkg::system_csr_axi_core__out_t hwif_out;

    assign hwif_in.sr.reserved.next     = 0;
    assign hwif_in.cr.reserved.next     = 0;
    assign hwif_in.cr_s.reserved.next   = 0;
    assign hwif_in.cr_c.reserved.next   = 0;

    assign hwif_in.prog_ev.send.next    = 0;

    logic prog_ev_req = 0;

    always_ff @(posedge app_clk) begin
        if(app_rst) begin
            prog_ev_req <= 0;
        end else begin
            if(hwif_out.prog_ev.send.value) begin
                prog_ev_req <= 1;
            end else if(prog_ev_req && ev_in == '0) begin
                prog_ev_req <= 0;
            end
        end
    end

    always_comb begin
        if(prog_ev_req && ev_in == '0)
            ev_out = hwif_out.prog_ev.ev.value;
        else 
            ev_out = ev_in;
    end

    system_csr_axi_core system_csr_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule