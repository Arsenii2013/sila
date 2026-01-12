`timescale 1ns/1ns

`include "cfg_params.svh"
/*
Wrapper for GTX Wizard IP
*/

module gtwizard_wrapper#(
    parameter DEVICE = "EVG",
    parameter PORT_N = gtx::EVG_PORT_N
)(
    input  logic        refclk_n,
    input  logic        refclk_p,
    input  logic        sysclk,
    input  logic        soft_reset,

    input  logic        sfp_loss[PORT_N],
    input  logic        rx_n[PORT_N],
    input  logic        rx_p[PORT_N],
    output logic        tx_n[PORT_N],
    output logic        tx_p[PORT_N],

    output logic        beacon_clk,  // Временно для Fanout на основе ax7z100b
    input  logic        refclk_rx_n, // Временно для Fanout на основе ax7z100b
    input  logic        refclk_rx_p, // Временно для Fanout на основе ax7z100b

    gtx_if.gtx          gtx_if[PORT_N]
);
    //import gxt::*;
    localparam N = PORT_N;

    logic wa_rst_req[N] = '{default: 0};
    logic wa_rst_req_sync[N];
//Resetdone logic
    logic refclk_rx;

    logic  txfsmresetdone[N];
    logic  rxfsmresetdone[N];
    logic   data_valid_in[N];
    logic rxmcommaalignen[N];
    logic rxpcommaalignen[N];

    logic rxresetdone[N];
    logic txresetdone[N];

    logic rxresetdone_r[N];
    logic rxresetdone_r2[N];
    logic rxresetdone_r3[N];

    logic rxfsmresetdone_r[N];
    logic rxfsmresetdone_r2[N]; 

    logic txfsmresetdone_r[N];
    logic txfsmresetdone_r2[N];

    genvar i;
    generate
    for (i=0; i < N; i++) begin
        assign data_valid_in[i] = rxresetdone[i];
        assign gtx_if[i].tx_reset_done = txfsmresetdone_r2[i] && txresetdone[i];
        assign gtx_if[i].rx_reset_done = rxfsmresetdone_r2[i] && rxresetdone_r3[i];
        assign rxmcommaalignen[i] = rxresetdone[i];
        assign rxpcommaalignen[i] = rxresetdone[i];
    end
    endgenerate

//Alignment logic
    localparam WA_DETECT_INTERVAL = 32;
    localparam WA_RXSLIDE_MAX_CNT = 41;

    localparam WA_WORD_CNT_W      = $clog2(WA_DETECT_INTERVAL);
    localparam WA_SLIDE_CNT_W     = $clog2(WA_RXSLIDE_MAX_CNT);

    typedef enum {
        wafsmPATTERN_SEARCH,
        wafsmCHECK,
        wafsmALIGNED
    } wafsm_state_t;

    typedef logic [ WA_WORD_CNT_W-1:0] word_cnt_t;
    typedef logic [WA_SLIDE_CNT_W-1:0] slide_cnt_t;

    logic         detect[N]   = '{default: '0};
    word_cnt_t    word_cnt[N] = '{default: '0};

    logic         rxslide[N];
    slide_cnt_t   slide_cnt[N]  = '{default: '0};

    wafsm_state_t state[N] = '{default: wafsmPATTERN_SEARCH};
    wafsm_state_t next[N];


    logic test = 'b0;

    genvar j;
    generate
    for (j=0; j < N; j++) begin

    assign rxslide[j] = state[j] == wafsmCHECK && !detect[j];
    assign gtx_if[j].aligned = state[j] == wafsmALIGNED;

    always_ff @(posedge gtx_if[j].rx_clk or negedge gtx_if[j].rx_reset_done) begin // async reset becouse rx_clk loss when rx_reset_done fall
        if (!gtx_if[j].rx_reset_done) begin
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
                    if (gtx::is_alignment(gtx_if[j].rx_data, gtx_if[j].rx_is_k))
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

    xpm_cdc_async_rst reset_req_cdc_i(
        .dest_clk(sysclk),
        .dest_arst(wa_rst_req_sync[j]),
        .src_arst(wa_rst_req[j])
    );

    always_comb begin
        if (!gtx_if[j].rx_reset_done) begin
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
    logic txoutclk [N];
    logic rxoutclk [N];
    logic qplllock, qpllrefclklost, qpllreset, qplloutclk, qplloutrefclk;
    logic gt_qpllreset [N];

    generate 
    if(DEVICE == "EVR") begin
    EVR_gtwizard_port_0 gtwizard_port_0
    (
        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[0] || sfp_loss[0]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[0]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[0]),
        .gt0_data_valid_in              (data_valid_in[0]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[0].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[0]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[0]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[0].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[0].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[0]),
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[0] || sfp_loss[0]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[0]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[0].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[0]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[0].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[0]),
        .gt0_gtxtxp_out                 (tx_p[0]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[0].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[0].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[0]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[0].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[0]),
    //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt0_txpolarity_in              (1),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[0]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );
    end else if(DEVICE == "EVG") begin
    EVG_gtwizard_port_0 gtwizard_port_0
    (
        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[0] || sfp_loss[0]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[0]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[0]),
        .gt0_data_valid_in              (data_valid_in[0]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[0].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[0]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[0]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[0].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[0].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[0]),
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[0] || sfp_loss[0]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[0]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[0].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[0]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[0].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[0]),
        .gt0_gtxtxp_out                 (tx_p[0]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[0].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[0].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[0]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[0].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[0]),
    //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt0_txpolarity_in              (1),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[0]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );

    EVG_gtwizard_port_1 gtwizard_port_1
    (
        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[1] || sfp_loss[1]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[1]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[1]),
        .gt0_data_valid_in              (data_valid_in[1]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[1].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[1]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[1]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[1].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[1].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[1]),
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[1] || sfp_loss[1]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[1]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[1].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[1]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[1].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[1]),
        .gt0_gtxtxp_out                 (tx_p[1]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[1].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[1].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[1]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[1].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[1]),
    //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt0_txpolarity_in              (1),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[1]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );

    EVG_gtwizard_port_2 gtwizard_port_2
    (
        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[2] || sfp_loss[2]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[2]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[2]),
        .gt0_data_valid_in              (data_valid_in[2]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[2].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[2]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[2]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[2].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[2].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[2]),
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[2] || sfp_loss[2]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[2]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[2].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[2]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[2].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[2]),
        .gt0_gtxtxp_out                 (tx_p[2]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[2].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[2].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[2]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[2].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[2]),
    //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt0_txpolarity_in              (1),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[2]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );

    EVG_gtwizard_port_3 gtwizard_port_3
    (
        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[3] || sfp_loss[3]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[3]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[3]),
        .gt0_data_valid_in              (data_valid_in[3]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[3].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[3]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[3]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[3].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[3].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[3]),
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[3] || sfp_loss[3]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[3]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[3].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[3]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[3].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[3]),
        .gt0_gtxtxp_out                 (tx_p[3]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[3].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[3].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[3]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[3].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[3]),
    //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt0_txpolarity_in              (1),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[3]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );
    end else if(DEVICE == "Fanout") begin
    logic outclkfabric;
    BUFG outclkfabric_BUFG (
        .O(beacon_clk),
        .I(outclkfabric)
    );
    Fanout_gtwizard_port_0 gtwizard_port_0
    (
        .gt0_cpllfbclklost_out          (),
        .gt0_cplllock_out               (),
        .gt0_cplllockdetclk_in          (sysclk),
        .gt0_cpllreset_in               (0),
        .gt0_gtrefclk0_in               (0), // QPLL - common logic!
        .gt0_gtrefclk1_in               (refclk_rx), // CPLL

        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[0] || sfp_loss[0]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[0]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[0]),
        .gt0_data_valid_in              (data_valid_in[0]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[0].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[0]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[0]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[0].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[0].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[0]),
        .gt0_rxoutclkfabric_out         (outclkfabric),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[0] || sfp_loss[0]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[0]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[0].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[0]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[0].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[0]),
        .gt0_gtxtxp_out                 (tx_p[0]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[0].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[0].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[0]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[0].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[0]),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[0]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );

    Fanout_gtwizard_port_1 gtwizard_port_1
    (
        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[1] || sfp_loss[1]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[1]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[1]),
        .gt0_data_valid_in              (data_valid_in[1]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[1].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[1]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[1]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[1].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[1].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[1]),
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[1] || sfp_loss[1]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[1]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[1].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[1]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[1].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[1]),
        .gt0_gtxtxp_out                 (tx_p[1]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[1].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[1].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[1]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[1].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[1]),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[1]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );

    Fanout_gtwizard_port_2 gtwizard_port_2
    (
        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[2] || sfp_loss[2]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[2]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[2]),
        .gt0_data_valid_in              (data_valid_in[2]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[2].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[2]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[2]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[2].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[2].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[2]),
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[2] || sfp_loss[2]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[2]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[2].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[2]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[2].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[2]),
        .gt0_gtxtxp_out                 (tx_p[2]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[2].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[2].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[2]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[2].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[2]),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[2]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );

    Fanout_gtwizard_port_3 gtwizard_port_3
    (
        .sysclk_in                      (sysclk),
        .soft_reset_tx_in               (soft_reset),
        .soft_reset_rx_in               (soft_reset || wa_rst_req_sync[3] || sfp_loss[3]),
        .dont_reset_on_data_error_in    ('0),
        .gt0_tx_fsm_reset_done_out      (txfsmresetdone[3]),
        .gt0_rx_fsm_reset_done_out      (rxfsmresetdone[3]),
        .gt0_data_valid_in              (data_valid_in[3]),

        .gt0_drpaddr_in                 ('0),
        .gt0_drpclk_in                  (sysclk),
        .gt0_drpdi_in                   ('0),
        .gt0_drpdo_out                  (),
        .gt0_drpen_in                   ('0),
        .gt0_drprdy_out                 (),
        .gt0_drpwe_in                   ('0),
   
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            ('0),
        .gt0_rxuserrdy_in               ('b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          ('0),
        //---------------- Receive Ports - FPGA RX interface Ports -----------------
        .gt0_rxdata_out                 (gtx_if[3].rx_data),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //------------------------- Receive Ports - RX AFE -------------------------
        .gt0_gtxrxp_in                  (rx_p[3]),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtxrxn_in                  (rx_n[3]),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxusrclk_in                (gtx_if[3].rx_clk),
        .gt0_rxusrclk2_in               (gtx_if[3].rx_clk),
        //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
        // .gt0_rxphmonitor_out            (),
        // .gt0_rxphslipmonitor_out        (),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxdfelpmreset_in           ('0),
        .gt0_rxmonitorout_out           (),
        .gt0_rxmonitorsel_in            ('0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk[3]),
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               ('0),
        .gt0_rxpmareset_in              (wa_rst_req_sync[3] || sfp_loss[3]),
        //-------------------- Receive Ports - RX gearbox ports --------------------
        .gt0_rxslide_in                 (rxslide[3]),
        //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (gtx_if[3].rx_is_k),
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (rxresetdone[3]),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               ('0),
        .gt0_txuserrdy_in               ('b1),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gtx_if[3].tx_data),
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (tx_n[3]),
        .gt0_gtxtxp_out                 (tx_p[3]),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txusrclk_in                (gtx_if[3].tx_clk),
        .gt0_txusrclk2_in               (gtx_if[3].tx_clk),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk[3]),
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gtx_if[3].tx_is_k),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (txresetdone[3]),

   
        .gt0_qplllock_in(qplllock),
        .gt0_qpllrefclklost_in(qpllrefclklost),
        .gt0_qpllreset_out(gt_qpllreset[3]),
        .gt0_qplloutclk_in(qplloutclk),
        .gt0_qplloutrefclk_in(qplloutrefclk)
    );
    end
    endgenerate

    logic commonreset;

    always_comb begin
        qpllreset = 1;
        for(int qpllreset_ind = 0; qpllreset_ind < PORT_N; qpllreset_ind++) begin
            qpllreset = qpllreset && gt_qpllreset[qpllreset_ind];
        end
    end

    //IBUFDS_GTE2
    logic refclk;
    IBUFDS_GTE2 ibufds_instQ0_CLK1  
    (
        .O               (refclk),
        .ODIV2           (),
        .CEB             ('0),
        .I               (refclk_p),
        .IB              (refclk_n)
    );
    IBUFDS_GTE2 ibufds_instQ0_CLK0  
    (
        .O               (refclk_rx),
        .ODIV2           (),
        .CEB             ('0),
        .I               (refclk_rx_p),
        .IB              (refclk_rx_n)
    );
    genvar l;
    generate
    for (l=0; l < N; l++) begin
        gtwizard_0_GT_USRCLK_SOURCE gt_usrclk_source
        (

            .GT0_TXUSRCLK_OUT    (gtx_if[l].tx_clk),
            .GT0_TXUSRCLK2_OUT   (),
            .GT0_TXOUTCLK_IN     (txoutclk[l]),
            .GT0_RXUSRCLK_OUT    (gtx_if[l].rx_clk),
            .GT0_RXUSRCLK2_OUT   (),
            .GT0_RXOUTCLK_IN     (rxoutclk[l])
        );
    end
    endgenerate

    gtwizard_0_common common0_i
    (
        .QPLLREFCLKSEL_IN(3'b010),
        .GTREFCLK0_IN('0),
        .GTREFCLK1_IN(refclk),
        .QPLLLOCK_OUT(qplllock),
        .QPLLLOCKDETCLK_IN(sysclk),
        .QPLLOUTCLK_OUT(qplloutclk),
        .QPLLOUTREFCLK_OUT(qplloutrefclk),
        .QPLLREFCLKLOST_OUT(qpllrefclklost),    
        .QPLLRESET_IN(qpllreset || commonreset)
    );

    gtwizard_0_common_reset # 
    (
        .STABLE_CLOCK_PERIOD (8)        // Period of the stable clock driving this state-machine, unit is [ns]
    )
    common_reset_i
    (    
        .STABLE_CLOCK(sysclk),             //Stable Clock, either a stable clock from the PCB
        .SOFT_RESET(soft_reset),               //User Reset, can be pulled any time
        .COMMON_RESET(commonreset)              //Reset QPLL
    );

//Resetdone logic
    genvar k;
    generate
    for (k=0; k < N; k++) begin
        always @(posedge  gtx_if[k].rx_clk or negedge rxresetdone[k])
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

        always @(posedge gtx_if[k].rx_clk or negedge rxfsmresetdone[k])
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

        always @(posedge gtx_if[k].tx_clk or negedge txfsmresetdone[k])
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

module gtwizard_0_GT_USRCLK_SOURCE 
(
 
    output          GT0_TXUSRCLK_OUT,
    output          GT0_TXUSRCLK2_OUT,
    input           GT0_TXOUTCLK_IN,
    output          GT0_RXUSRCLK_OUT,
    output          GT0_RXUSRCLK2_OUT,
    input           GT0_RXOUTCLK_IN
    );
    `define DLY #1

    //*********************************Wire Declarations**********************************
    wire            tied_to_ground_i;
    wire            tied_to_vcc_i;
 
    wire            gt0_txoutclk_i; 
    wire            gt0_rxoutclk_i;
    wire  q0_clk1_gtrefclk /*synthesis syn_noclockbuf=1*/;

    wire            gt0_txusrclk_i;
    wire            gt0_rxusrclk_i;


    //*********************************** Beginning of Code *******************************

    //  Static signal Assigments    
    assign tied_to_ground_i             = 1'b0;
    assign tied_to_vcc_i                = 1'b1;
    assign gt0_txoutclk_i = GT0_TXOUTCLK_IN;
    assign gt0_rxoutclk_i = GT0_RXOUTCLK_IN;




    // Instantiate a MMCM module to divide the reference clock. Uses internal feedback
    // for improved jitter performance, and to avoid consuming an additional BUFG

    BUFG txoutclk_bufg0_i
    (
        .I                              (gt0_txoutclk_i),
        .O                              (gt0_txusrclk_i)
    );


    BUFG rxoutclk_bufg1_i
    (
        .I                              (gt0_rxoutclk_i),
        .O                              (gt0_rxusrclk_i)
    );



    
    assign GT0_TXUSRCLK_OUT = gt0_txusrclk_i;
    assign GT0_TXUSRCLK2_OUT = gt0_txusrclk_i;
    assign GT0_RXUSRCLK_OUT = gt0_rxusrclk_i;
    assign GT0_RXUSRCLK2_OUT = gt0_rxusrclk_i;

endmodule

`define DLY #1
//***************************** Entity Declaration ****************************
module gtwizard_0_common #
(
    // Simulation attributes
    parameter   WRAPPER_SIM_GTRESET_SPEEDUP    =   "TRUE",     // Set to "true" to speed up sim reset
    parameter   SIM_QPLLREFCLK_SEL             =   3'b010     
)
(
    input   [2:0]   QPLLREFCLKSEL_IN,
    input           GTREFCLK0_IN,
    input           GTREFCLK1_IN,
    output          QPLLLOCK_OUT,
    input           QPLLLOCKDETCLK_IN,
    output          QPLLOUTCLK_OUT,
    output          QPLLOUTREFCLK_OUT,
    output          QPLLREFCLKLOST_OUT,   
    input           QPLLRESET_IN
);



//***************************** Parameter Declarations ************************
    localparam QPLL_FBDIV_TOP =  80;

    localparam QPLL_FBDIV_IN  =  (QPLL_FBDIV_TOP == 16)  ? 10'b0000100000 : 
				(QPLL_FBDIV_TOP == 20)  ? 10'b0000110000 :
				(QPLL_FBDIV_TOP == 32)  ? 10'b0001100000 :
				(QPLL_FBDIV_TOP == 40)  ? 10'b0010000000 :
				(QPLL_FBDIV_TOP == 64)  ? 10'b0011100000 :
				(QPLL_FBDIV_TOP == 66)  ? 10'b0101000000 :
				(QPLL_FBDIV_TOP == 80)  ? 10'b0100100000 :
				(QPLL_FBDIV_TOP == 100) ? 10'b0101110000 : 10'b0000000000;

   localparam QPLL_FBDIV_RATIO = (QPLL_FBDIV_TOP == 16)  ? 1'b1 : 
				(QPLL_FBDIV_TOP == 20)  ? 1'b1 :
				(QPLL_FBDIV_TOP == 32)  ? 1'b1 :
				(QPLL_FBDIV_TOP == 40)  ? 1'b1 :
				(QPLL_FBDIV_TOP == 64)  ? 1'b1 :
				(QPLL_FBDIV_TOP == 66)  ? 1'b0 :
				(QPLL_FBDIV_TOP == 80)  ? 1'b1 :
				(QPLL_FBDIV_TOP == 100) ? 1'b1 : 1'b1;

    // ground and vcc signals
wire            tied_to_ground_i;
wire    [63:0]  tied_to_ground_vec_i;
wire            tied_to_vcc_i;
wire    [63:0]  tied_to_vcc_vec_i;

    assign tied_to_ground_i             = 1'b0;
    assign tied_to_ground_vec_i         = 64'h0000000000000000;
    assign tied_to_vcc_i                = 1'b1;
    assign tied_to_vcc_vec_i            = 64'hffffffffffffffff;

    //_________________________________________________________________________
    //_________________________________________________________________________
    //_________________________GTXE2_COMMON____________________________________

    GTXE2_COMMON #
    (
            // Simulation attributes
            `ifndef SYNTHESIS
            .SIM_RESET_SPEEDUP   ("TRUE"),
            .SIM_QPLLREFCLK_SEL  (3'b010),
            .SIM_VERSION         ("4.0"),
            `else

            `endif


           //----------------COMMON BLOCK Attributes---------------
            .BIAS_CFG                               (64'h0000040000001000),
            .COMMON_CFG                             (32'h00000000),
            .QPLL_CFG                               (27'h0680181),
            .QPLL_CLKOUT_CFG                        (4'b0000),
            .QPLL_COARSE_FREQ_OVRD                  (6'b010000),
            .QPLL_COARSE_FREQ_OVRD_EN               (1'b0),
            .QPLL_CP                                (10'b0000011111),
            .QPLL_CP_MONITOR_EN                     (1'b0),
            .QPLL_DMONITOR_SEL                      (1'b0),
            .QPLL_FBDIV                             (QPLL_FBDIV_IN),
            .QPLL_FBDIV_MONITOR_EN                  (1'b0),
            .QPLL_FBDIV_RATIO                       (QPLL_FBDIV_RATIO),
            .QPLL_INIT_CFG                          (24'h000006),
            .QPLL_LOCK_CFG                          (16'h21E8),
            .QPLL_LPF                               (4'b1111),
            .QPLL_REFCLK_DIV                        (1)

    )
    gtxe2_common_i
    (
        //----------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
        .DRPADDR                        (tied_to_ground_vec_i[7:0]),
        .DRPCLK                         (tied_to_ground_i),
        .DRPDI                          (tied_to_ground_vec_i[15:0]),
        .DRPDO                          (),
        .DRPEN                          (tied_to_ground_i),
        .DRPRDY                         (),
        .DRPWE                          (tied_to_ground_i),
        //-------------------- Common Block  - Ref Clock Ports ---------------------
        .GTGREFCLK                      (tied_to_ground_i),
        .GTNORTHREFCLK0                 (tied_to_ground_i),
        .GTNORTHREFCLK1                 (tied_to_ground_i),
        .GTREFCLK0                      (GTREFCLK0_IN),
        .GTREFCLK1                      (GTREFCLK1_IN),
        .GTSOUTHREFCLK0                 (tied_to_ground_i),
        .GTSOUTHREFCLK1                 (tied_to_ground_i),
        //----------------------- Common Block -  QPLL Ports -----------------------
        .QPLLDMONITOR                   (),
        //--------------------- Common Block - Clocking Ports ----------------------
        .QPLLOUTCLK                     (QPLLOUTCLK_OUT),
        .QPLLOUTREFCLK                  (QPLLOUTREFCLK_OUT),
        .REFCLKOUTMONITOR               (),
        //----------------------- Common Block - QPLL Ports ------------------------
        .QPLLFBCLKLOST                  (),
        .QPLLLOCK                       (QPLLLOCK_OUT),
        .QPLLLOCKDETCLK                 (QPLLLOCKDETCLK_IN),
        .QPLLLOCKEN                     (tied_to_vcc_i),
        .QPLLOUTRESET                   (tied_to_ground_i),
        .QPLLPD                         (tied_to_ground_i),
        .QPLLREFCLKLOST                 (QPLLREFCLKLOST_OUT),
        .QPLLREFCLKSEL                  (QPLLREFCLKSEL_IN),
        .QPLLRESET                      (QPLLRESET_IN),
        .QPLLRSVD1                      (16'b0000000000000000),
        .QPLLRSVD2                      (5'b11111),
        //------------------------------- QPLL Ports -------------------------------
        .BGBYPASSB                      (tied_to_vcc_i),
        .BGMONITORENB                   (tied_to_vcc_i),
        .BGPDB                          (tied_to_vcc_i),
        .BGRCALOVRD                     (5'b11111),
        .PMARSVD                        (8'b00000000),
        .RCALENB                        (tied_to_vcc_i)

    );
endmodule


module gtwizard_0_common_reset  #
   (
      parameter     STABLE_CLOCK_PERIOD      = 8        // Period of the stable clock driving this state-machine, unit is [ns]
   )
   (    
      input  wire      STABLE_CLOCK,             //Stable Clock, either a stable clock from the PCB
      input  wire      SOFT_RESET,               //User Reset, can be pulled any time
      output reg      COMMON_RESET = 1'b0             //Reset QPLL
   );


  localparam integer  STARTUP_DELAY    = 500;//AR43482: Transceiver needs to wait for 500 ns after configuration
  localparam integer WAIT_CYCLES      = STARTUP_DELAY / STABLE_CLOCK_PERIOD; // Number of Clock-Cycles to wait after configuration
  localparam integer WAIT_MAX         = WAIT_CYCLES + 10;                    // 500 ns plus some additional margin

  reg [7:0] init_wait_count = 0;
  reg       init_wait_done = 1'b0;
  wire      common_reset_i;
  reg       common_reset_asserted = 1'b0;

  localparam INIT = 1'b0;
  localparam ASSERT_COMMON_RESET = 1'b1;
    
  reg state = INIT;

  always @(posedge STABLE_CLOCK)
  begin
      // The counter starts running when configuration has finished and 
      // the clock is stable. When its maximum count-value has been reached,
      // the 500 ns from Answer Record 43482 have been passed.
      if (init_wait_count == WAIT_MAX) 
          init_wait_done <= `DLY  1'b1;
      else
        init_wait_count <= `DLY  init_wait_count + 1;
  end


  always @(posedge STABLE_CLOCK)
  begin
      if (SOFT_RESET == 1'b1)
       begin
         state <= INIT;
         COMMON_RESET <= 1'b0;
         common_reset_asserted <= 1'b0;
       end
      else
       begin
        case (state)
         INIT :
          begin
            if (init_wait_done == 1'b1) state <= ASSERT_COMMON_RESET;
          end
         ASSERT_COMMON_RESET :
          begin
            if(common_reset_asserted == 1'b0)
              begin
                COMMON_RESET <= 1'b1;
                common_reset_asserted <= 1'b1;
              end
            else
                COMMON_RESET <= 1'b0;
          end
          default:
              state <=  INIT; 
        endcase
       end
   end 


endmodule 