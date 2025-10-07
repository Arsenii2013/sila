
module sfp_control #(
    parameter PORT_N = 1
)(
    input  logic   app_clk,
    input  logic   app_rst,
    axi4_lite_if.s mmr,

    output logic   sfp_loss[PORT_N],
    input  logic   sfp_loss_clk
);
    sfp_control_axi_core_pkg::sfp_control_axi_core__out_t hwif_out;

    genvar gen_i;
    generate 
    for(gen_i = 0; gen_i < PORT_N; gen_i ++) begin
        xpm_cdc_async_rst sfp_loss_cdc(
            .dest_clk(sfp_loss_clk),
            .dest_arst(sfp_loss[gen_i]),
            .src_arst(hwif_out.sfp_loss.sfp_loss.value[gen_i])
        );
    end
    endgenerate

    sfp_control_axi_core sfp_control_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_out(hwif_out)
    );
endmodule