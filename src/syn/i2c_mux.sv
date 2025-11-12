
interface i2c_tri_state_if;
    logic scl_i;
    logic scl_o;
    logic scl_t;
    logic sda_i;
    logic sda_o;
    logic sda_t;

    modport slave(
        output scl_i,
        input  scl_o,
        input  scl_t,
        output sda_i,
        input  sda_o,
        input  sda_t
    );
    modport master(
        input  scl_i,
        output scl_o,
        output scl_t,
        input  sda_i,
        output sda_o,
        output sda_t
    );

endinterface

module i2c_mux #(
    parameter SFP_N = 8
)(
    input  logic    app_clk,
    input  logic    app_rst,
    axi4_lite_if.s  mmr,

    i2c_tri_state_if.slave I2C_s,

    inout  logic    SI570_SDA,
    inout  logic    SI570_SCL,
    inout  logic    PLL1_SDA,
    inout  logic    PLL1_SCL,
    inout  logic    PLL2_SDA,
    inout  logic    PLL2_SCL,
    inout  logic    SFP_SDA [SFP_N],
    inout  logic    SFP_SCL [SFP_N]
);
    i2c_tri_state_if SI750_tri();
    i2c_tri_state_if PLL1_tri();
    i2c_tri_state_if PLL2_tri();
    i2c_tri_state_if SFP_tri[SFP_N]();

// Tri state buffers
    I2C_oibuf SI570_iobuf(
        .i2c(SI750_tri),
        .SCL(SI570_SCL),
        .SDA(SI570_SDA)
    );
    I2C_oibuf PLL1_iobuf(
        .i2c(PLL1_tri),
        .SCL(PLL1_SCL),
        .SDA(PLL1_SDA)
    );
    I2C_oibuf PLL2_iobuf(
        .i2c(PLL2_tri),
        .SCL(PLL2_SCL),
        .SDA(PLL2_SDA)
    );
    generate;
    for(genvar sfp_i = 0; sfp_i < SFP_N; sfp_i ++) begin : SFP_iobufs
        I2C_oibuf inst(
            .i2c(SFP_tri[sfp_i]),
            .SCL(SFP_SCL[sfp_i]),
            .SDA(SFP_SDA[sfp_i])
        );
    end
    endgenerate

// I2C mux
    localparam DEVICES_N    = SFP_N + 3;
    typedef logic [$clog2(DEVICES_N)-1: 0] sel_t;

    sel_t i2c_sel;

    generate
        case(SFP_N)
        1 :
            I2C_tri_mux #(
                .DEVICES_N(DEVICES_N)
            ) I2C_tri_mux_inst(
                .PS_i2c(I2C_s),
                .devices_i2c('{SI750_tri, PLL1_tri, PLL2_tri, SFP_tri[0]}),
                .sel(i2c_sel)
            );
        8 :
            I2C_tri_mux #(
                .DEVICES_N(DEVICES_N)
            ) I2C_tri_mux_inst(
                .PS_i2c(I2C_s),
                .devices_i2c('{SI750_tri,  PLL1_tri,   PLL2_tri,   SFP_tri[0], 
                               SFP_tri[1], SFP_tri[2], SFP_tri[3], SFP_tri[4], 
                               SFP_tri[5], SFP_tri[6], SFP_tri[7]}),
                .sel(i2c_sel)
            );
        default :
            $error("Stupid sv cant concat arrays of interfaces");
        endcase
    endgenerate

// AXI core

    i2c_mux_axi_core_pkg::i2c_mux_axi_core__in_t  hwif_in;
    i2c_mux_axi_core_pkg::i2c_mux_axi_core__out_t hwif_out;

    assign hwif_in.sr.sel.next      = i2c_sel;
    assign i2c_sel                  = (hwif_out.cr.sel.value | hwif_out.cr_s.sel.value) & ~hwif_out.cr_c.sel.value;
    assign hwif_in.cr.sel.next      = i2c_sel;
    assign hwif_in.cr_s.sel.next    = 0;
    assign hwif_in.cr_c.sel.next    = 0;

    i2c_mux_axi_core i2c_mux_axi_core_i(
        .clk(app_clk),
        .rst(app_rst),

        .s_axil(mmr),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule

module I2C_oibuf(
    i2c_tri_state_if.slave i2c,
    inout  logic           SCL,
    inout  logic           SDA
);
    IOBUF #(
        .SLEW("SLOW")
    ) IOBUF_SCL (
        .O(i2c.scl_i),
        .IO(SCL),
        .I(i2c.scl_o),
        .T(i2c.scl_t)
    );
    IOBUF #(
        .SLEW("SLOW")
    ) IOBUF_SDA (
        .O(i2c.sda_i),
        .IO(SDA),
        .I(i2c.sda_o),
        .T(i2c.sda_t)
    );
endmodule

module I2C_tri_mux #(
    parameter DEVICES_N = 16
)(
    i2c_tri_state_if.slave                  PS_i2c,
    i2c_tri_state_if.master                 devices_i2c [DEVICES_N],
    input logic [$clog2(DEVICES_N)-1: 0]    sel
);
    typedef logic [$clog2(DEVICES_N)-1: 0] sel_t;

    logic [DEVICES_N-1: 0] scl_i_flat;
    logic [DEVICES_N-1: 0] sda_i_flat;
    logic [DEVICES_N-1: 0] scl_t_flat;
    logic [DEVICES_N-1: 0] sda_t_flat;

    assign PS_i2c.scl_i     = sel < DEVICES_N ? scl_i_flat[sel] : 0;
    assign PS_i2c.sda_i     = sel < DEVICES_N ? sda_i_flat[sel] : 0;

    always_comb begin
        scl_t_flat      = '1;
        sda_t_flat      = '1;
        if(sel < DEVICES_N) begin
            scl_t_flat[sel] = PS_i2c.scl_t;
            sda_t_flat[sel] = PS_i2c.sda_t;
        end
    end

    generate
    for(genvar unflat_i = 0; unflat_i < DEVICES_N; unflat_i ++) begin
        assign scl_i_flat[unflat_i]        = devices_i2c[unflat_i].scl_i;
        assign sda_i_flat[unflat_i]        = devices_i2c[unflat_i].sda_i;
        assign devices_i2c[unflat_i].scl_t = scl_t_flat[unflat_i];
        assign devices_i2c[unflat_i].scl_o = PS_i2c.scl_o;
        assign devices_i2c[unflat_i].sda_t = sda_t_flat[unflat_i];
        assign devices_i2c[unflat_i].sda_o = PS_i2c.sda_o;
    end
    endgenerate

endmodule