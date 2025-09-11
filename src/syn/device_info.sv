module device_info #(
    parameter DEVICE      = "EVG",
    parameter FW_MAJOR    = 0,
    parameter FW_MINOR    = 0,
    parameter FW_HASH     = 0
)(
    input  logic                                 app_clk,
    input  logic                                 app_rst,
    axi4_lite_if.s                               mmr
);
    device_info_axi_core_pkg::device_info_axi_core__in_t  hwif_in;
    device_info_axi_core_pkg::device_info_axi_core__out_t hwif_out;

    assign hwif_in.sr.reserved.next             = 0;
    assign hwif_in.cr.reserved.next             = (hwif_out.cr.reserved.value | hwif_out.cr_s.reserved.value) & ~hwif_out.cr_c.reserved.value;
    assign hwif_in.cr_s.reserved.next           = 0;
    assign hwif_in.cr_c.reserved.next           = 0;
    generate 
    case (DEVICE)
    "EVG"    : assign hwif_in.device_type.device_type.next = device_info_axi_core_pkg::device_info_axi_core__device_type_encoding__EVG;
    "EVR"    : assign hwif_in.device_type.device_type.next = device_info_axi_core_pkg::device_info_axi_core__device_type_encoding__EVR;
    "Fanout" : assign hwif_in.device_type.device_type.next = device_info_axi_core_pkg::device_info_axi_core__device_type_encoding__FANOUT;
    endcase
    endgenerate
    assign hwif_in.fw_version.major.next        = FW_MAJOR;
    assign hwif_in.fw_version.minor.next        = FW_MINOR;
    assign hwif_in.fw_hash.fw_hash.next         = FW_HASH;

    device_info_axi_core device_info_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule