`timescale 1ns/1ns

`include "cfg_params.svh"
`include "evn.svh"
/*
Wrapper for GTX Wizard IP
*/
module gtwizard_wrapper(
    input  logic        refclk_n,
    input  logic        refclk_p,
    input  logic        sysclk,
    input  logic        soft_reset,
    output logic        tx_reset_done[4],
    output logic        rx_reset_done[4],
    output logic        tx_clk[4],
    output logic        rx_clk[4],
    output logic        aligned[4],
    input  logic        sfp_loss[4],
    //input  logic       data_valid_in,

    output logic [31:0] rx_data[4],
    input  logic [31:0] tx_data[4],
    input  logic [3:0]  txcharisk[4],
    output logic [3:0]  rxcharisk[4],

    input  logic        rx_n[4],
    input  logic        rx_p[4],
    output logic        tx_n[4],
    output logic        tx_p[4]
);
    logic wa_rst_req[4] = '{default: 0};
//Resetdone logic
    logic  txfsmresetdone[4];
    logic  rxfsmresetdone[4];
    logic   data_valid_in[4];
    logic rxmcommaalignen[4];
    logic rxpcommaalignen[4];

    logic rxresetdone[4];
    logic txresetdone[4];

    logic rxresetdone_r[4];
    logic rxresetdone_r2[4];
    logic rxresetdone_r3[4];

    logic rxfsmresetdone_r[4];
    logic rxfsmresetdone_r2[4]; 

    logic txfsmresetdone_r[4];
    logic txfsmresetdone_r2[4];

    genvar i;
    generate
    for (i=0; i < 4; i++) begin
        assign data_valid_in[i] = rxresetdone[i];
        assign tx_reset_done[i] = txfsmresetdone_r2[i] && txresetdone[i];
        assign rx_reset_done[i] = rxfsmresetdone_r2[i] && rxresetdone_r3[i];
        assign rxmcommaalignen[i] = rxresetdone[i];
        assign rxpcommaalignen[i] = rxresetdone[i];
    end
    endgenerate

//Alignment logic
    localparam WA_DETECT_INTERVAL = 32;
    localparam WA_RXSLIDE_MAX_CNT = 40;

    localparam WA_WORD_CNT_W      = $clog2(WA_DETECT_INTERVAL);
    localparam WA_SLIDE_CNT_W     = $clog2(WA_RXSLIDE_MAX_CNT);

    typedef enum {
        wafsmPATTERN_SEARCH,
        wafsmCHECK,
        wafsmALIGNED
    } wafsm_state_t;

    typedef logic [ WA_WORD_CNT_W-1:0] word_cnt_t;
    typedef logic [WA_SLIDE_CNT_W-1:0] slide_cnt_t;

    logic         detect[4]   = '{default: '0};
    word_cnt_t    word_cnt[4] = '{default: '0};

    logic         rxslide[4];
    slide_cnt_t   slide_cnt[4]  = '{default: '0};

    wafsm_state_t state[4] = '{default: wafsmPATTERN_SEARCH};
    wafsm_state_t next[4];


    logic test = 'b0;

    genvar j;
    generate
    for (j=0; j < 4; j++) begin

    assign rxslide[j] = state[j] == wafsmCHECK && !detect[j];
    assign aligned[j] = state[j] == wafsmALIGNED;

    always_ff @(posedge rx_clk[j] or negedge rx_reset_done[j]) begin // async reset becouse rx_clk loss when rx_reset_done fall
        if (!rx_reset_done[j]) begin
            state[j]      <= wafsmPATTERN_SEARCH;
            detect[j]     <= 0;
            word_cnt[j]   <= '0;
            slide_cnt[j]  <= '0;
            wa_rst_req[j] <= 0;
        end
        else begin
            state[j] <= next[j];
            case (state[j])
                wafsmPATTERN_SEARCH: begin
                    if (rxcharisk[j] == ALIGNMENT_IS_K && rx_data[j] == ALIGNMENT_WORD)
                        if (~test)
                            detect[j] <= 1;
                    word_cnt[j] <= word_cnt[j] + word_cnt_t'(1);
                    if (word_cnt[j] == word_cnt_t'(WA_DETECT_INTERVAL - 1))
                        word_cnt[j] <= '0;
                end
                wafsmCHECK: begin
                    if (detect[j]) begin
                        if (slide_cnt[j][0])
                            wa_rst_req[j] <= 1;
                    end
                    else begin
                        slide_cnt[j] <= slide_cnt[j] + slide_cnt_t'(1);
                        if (slide_cnt[j] == slide_cnt_t'(WA_RXSLIDE_MAX_CNT - 1)) begin
                            slide_cnt[j]  <= '0;
                            wa_rst_req[j] <= 1;
                        end
                    end
                end
            endcase
        end
    end

    always_comb begin
        if (!rx_reset_done[j]) begin
            next[j] = wafsmPATTERN_SEARCH;
        end
        else begin
            case (state[j])
                wafsmPATTERN_SEARCH: begin
                    if (word_cnt[j] == word_cnt_t'(WA_DETECT_INTERVAL - 1))
                        next[j] = wafsmCHECK;
                    else
                        next[j] = wafsmPATTERN_SEARCH;
                end
                wafsmCHECK: begin
                    if (detect[j])
                        next[j] = wafsmALIGNED;
                    else
                        next[j] = wafsmPATTERN_SEARCH; 
                end
                wafsmALIGNED: begin
                    next[j] = wafsmALIGNED;
                end
                default: begin
                    next[j] = wafsmPATTERN_SEARCH;
                end
            endcase
        end
    end
    end
    endgenerate;

//Wizard instance
    gtwizard gtwizard_i 
    (
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset),
        .dont_reset_on_data_error_in    ('b0),
    `ifdef TARGET_AX7Z035B
    .q2_clk1_gtrefclk_pad_n_in(refclk_n),
    .q2_clk1_gtrefclk_pad_p_in(refclk_p),
    `elsif TARGET_AX7Z100B
    .q1_clk1_gtrefclk_pad_n_in(refclk_n),
    .q1_clk1_gtrefclk_pad_p_in(refclk_p),
    `endif
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[0]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[0]),
        .gt0_data_valid_in              (data_valid_in[0]),
        .gt1_tx_fsm_reset_done_out      (txfsmresetdone[1]),
        .gt1_rx_fsm_reset_done_out      (rxfsmresetdone[1]),
        .gt1_data_valid_in              (data_valid_in[1]),
        .gt2_tx_fsm_reset_done_out      (txfsmresetdone[2]),
        .gt2_rx_fsm_reset_done_out      (rxfsmresetdone[2]),
        .gt2_data_valid_in              (data_valid_in[2]),
        .gt3_tx_fsm_reset_done_out      (txfsmresetdone[3]),
        .gt3_rx_fsm_reset_done_out      (rxfsmresetdone[3]),
        .gt3_data_valid_in              (data_valid_in[3]),
 
    .gt0_txusrclk_out(),
    .gt0_txusrclk2_out(tx_clk[0]),
    .gt0_rxusrclk_out(),
    .gt0_rxusrclk2_out(rx_clk[0]),
 
    .gt1_txusrclk_out(),
    .gt1_txusrclk2_out(tx_clk[1]),
    .gt1_rxusrclk_out(),
    .gt1_rxusrclk2_out(rx_clk[1]),
 
    .gt2_txusrclk_out(),
    .gt2_txusrclk2_out(tx_clk[2]),
    .gt2_rxusrclk_out(),
    .gt2_rxusrclk2_out(rx_clk[2]),
 
    .gt3_txusrclk_out(),
    .gt3_txusrclk2_out(tx_clk[3]),
    .gt3_rxusrclk_out(),
    .gt3_rxusrclk2_out(rx_clk[3]),


        //_____________________________________________________________________
        //_____________________________________________________________________
        //GT0  (X1Y8)

        //-------------------------- Channel - DRP Ports  --------------------------
        .gt0_drpaddr_in                 (9'd0),
        .gt0_drpdi_in                   (16'd0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   (1'b0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   (1'b0),
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('b0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('b0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (rx_data[0]),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[0]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[0]),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('b0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            (2'b00),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('b0),
        .gt0_rxpmareset_in              (wa_rst_req[0] || sfp_loss[0]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[0]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (rxcharisk[0]),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[0]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('b0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (tx_data[0]),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[0]),
        .gt0_gtxtxp_out                 (tx_p[0]),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (txcharisk[0]),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[0]),



        //_____________________________________________________________________
        //_____________________________________________________________________
        //GT1  (X1Y9)

        //-------------------------- Channel - DRP Ports  --------------------------
        .gt1_drpaddr_in                 (9'd0),
        .gt1_drpdi_in                   (16'd0),
        .gt1_drpdo_out                  (),
        .gt1_drpen_in                   (1'b0),
        .gt1_drprdy_out                 (),
        .gt1_drpwe_in                   (1'b0),
        //------------------------- Digital Monitor Ports --------------------------
        .gt1_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt1_eyescanreset_in            ('b0),
        .gt1_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt1_eyescandataerror_out       (),
        .gt1_eyescantrigger_in          ('b0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt1_rxdata_out                 (rx_data[1]),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt1_rxdisperr_out              (),
        .gt1_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt1_gtxrxp_in                  (rx_p[1]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt1_gtxrxn_in                  (rx_n[1]),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt1_rxdfelpmreset_in           ('b0),
        .gt1_rxmonitorout_out           (),
        .gt1_rxmonitorsel_in            (2'b00),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt1_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt1_gtrxreset_in               ('b0),
        .gt1_rxpmareset_in              (wa_rst_req[1] || sfp_loss[1]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt1_rxslide_in                 (rxslide[1]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt1_rxcharisk_out              (rxcharisk[1]),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt1_rxresetdone_out            (rxresetdone[1]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt1_gttxreset_in               ('b0),
        .gt1_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt1_txdata_in                  (tx_data[1]),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt1_gtxtxn_out                 (tx_n[1]),
        .gt1_gtxtxp_out                 (tx_p[1]),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt1_txoutclkfabric_out         (),
        .gt1_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt1_txcharisk_in               (txcharisk[1]),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt1_txresetdone_out            (txresetdone[1]),



        //_____________________________________________________________________
        //_____________________________________________________________________
        //GT2  (X1Y10)

        //-------------------------- Channel - DRP Ports  --------------------------
        .gt2_drpaddr_in                 (9'd0),
        .gt2_drpdi_in                   (16'd0),
        .gt2_drpdo_out                  (),
        .gt2_drpen_in                   (1'b0),
        .gt2_drprdy_out                 (),
        .gt2_drpwe_in                   (1'b0),
        //------------------------- Digital Monitor Ports --------------------------
        .gt2_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt2_eyescanreset_in            ('b0),
        .gt2_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt2_eyescandataerror_out       (),
        .gt2_eyescantrigger_in          ('b0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt2_rxdata_out                 (rx_data[2]),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt2_rxdisperr_out              (),
        .gt2_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt2_gtxrxp_in                  (rx_p[2]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt2_gtxrxn_in                  (rx_n[2]),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt2_rxdfelpmreset_in           ('b0),
        .gt2_rxmonitorout_out           (),
        .gt2_rxmonitorsel_in            (2'b00),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt2_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt2_gtrxreset_in               (1'b0),
        .gt2_rxpmareset_in              (wa_rst_req[2] || sfp_loss[2]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt2_rxslide_in                 (rxslide[2]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt2_rxcharisk_out              (rxcharisk[2]),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt2_rxresetdone_out            (rxresetdone[2]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt2_gttxreset_in               ('b0),
        .gt2_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt2_txdata_in                  (tx_data[2]),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt2_gtxtxn_out                 (tx_n[2]),
        .gt2_gtxtxp_out                 (tx_p[2]),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt2_txoutclkfabric_out         (),
        .gt2_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt2_txcharisk_in               (txcharisk[2]),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt2_txresetdone_out            (txresetdone[2]),



        //_____________________________________________________________________
        //_____________________________________________________________________
        //GT3  (X1Y11)

        //-------------------------- Channel - DRP Ports  --------------------------
        .gt3_drpaddr_in                 (9'd0),
        .gt3_drpdi_in                   (16'd0),
        .gt3_drpdo_out                  (),
        .gt3_drpen_in                   (1'b0),
        .gt3_drprdy_out                 (),
        .gt3_drpwe_in                   (1'b0),
        //------------------------- Digital Monitor Ports --------------------------
        .gt3_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt3_eyescanreset_in            ('b0),
        .gt3_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt3_eyescandataerror_out       (),
        .gt3_eyescantrigger_in          ('b0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt3_rxdata_out                 (rx_data[3]),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt3_rxdisperr_out              (),
        .gt3_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt3_gtxrxp_in                  (rx_p[3]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt3_gtxrxn_in                  (rx_n[3]),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt3_rxdfelpmreset_in           ('b0),
        .gt3_rxmonitorout_out           (),
        .gt3_rxmonitorsel_in            (2'b00),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt3_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt3_gtrxreset_in               (1'b0),
        .gt3_rxpmareset_in              (wa_rst_req[3] || sfp_loss[3]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt3_rxslide_in                 (rxslide[3]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt3_rxcharisk_out              (rxcharisk[3]),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt3_rxresetdone_out            (rxresetdone[3]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt3_gttxreset_in               ('b0),
        .gt3_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt3_txdata_in                  (tx_data[3]),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt3_gtxtxn_out                 (tx_n[3]),
        .gt3_gtxtxp_out                 (tx_p[3]),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt3_txoutclkfabric_out         (),
        .gt3_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt3_txcharisk_in               (txcharisk[3]),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt3_txresetdone_out            (txresetdone[3]),


    //____________________________COMMON PORTS________________________________
    .gt0_qplllock_out(),
    .gt0_qpllrefclklost_out(),
    .gt0_qplloutclk_out(),
    .gt0_qplloutrefclk_out(),
    .sysclk_in(sysclk)
    );

//Resetdone logic

    genvar k;
    generate
    for (k=0; k < 4; k++) begin
        always @(posedge  rx_clk[k] or negedge rxresetdone[k])
        begin
            if (!rxresetdone[k])
            begin
                rxresetdone_r[k]    <=   #1 1'b0;
                rxresetdone_r2[k]   <=   #1 1'b0;
                rxresetdone_r3[k]   <=   #1 1'b0;
            end
            else
            begin
                rxresetdone_r[k]    <=   #1 rxresetdone[k];
                rxresetdone_r2[k]   <=   #1 rxresetdone_r[k];
                rxresetdone_r3[k]   <=   #1 rxresetdone_r2[k];
            end
        end

        always @(posedge rx_clk[k] or negedge rxfsmresetdone[k])
        begin
        if (!rxfsmresetdone[k])
            begin
                rxfsmresetdone_r[k]    <=   #1 1'b0;
                rxfsmresetdone_r2[k]   <=   #1 1'b0;
            end
            else
            begin
                rxfsmresetdone_r[k]    <=   #1 rxfsmresetdone[k];
                rxfsmresetdone_r2[k]   <=   #1 rxfsmresetdone_r[k];
            end
        end

        always @(posedge tx_clk[k] or negedge txfsmresetdone[k])
        begin
            if (!txfsmresetdone[k])
            begin
                txfsmresetdone_r[k]    <=   #1 1'b0;
                txfsmresetdone_r2[k]   <=   #1 1'b0;
            end
            else
            begin
                txfsmresetdone_r[k]    <=   #1 txfsmresetdone[k];
                txfsmresetdone_r2[k]   <=   #1 txfsmresetdone_r[k];
            end
        end
    end
    endgenerate

endmodule