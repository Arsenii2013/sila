
module sfp_control(
    input  logic   app_clk,
    input  logic   app_rst,
    axi4_lite_if.s mmr,

    output logic   sfp_loss[4]
);
    sfp_control_axi_core_pkg::sfp_control_axi_core__out_t hwif_out;

    assign sfp_loss[0] = hwif_out.sfp_loss.sfp_loss.value[0];
    assign sfp_loss[1] = hwif_out.sfp_loss.sfp_loss.value[1];
    assign sfp_loss[2] = hwif_out.sfp_loss.sfp_loss.value[2];
    assign sfp_loss[3] = hwif_out.sfp_loss.sfp_loss.value[3];

    sfp_control_axi_core sfp_control_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_out(hwif_out)
    );
endmodule