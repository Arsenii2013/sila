`ifndef __MULT_SV__
`define __MULT_SV__

//------------------------------------------------
//
//      64x64 karatsuba multiplier module
//
//
module mult64x64_m
(
    input  logic         clk,
    input  logic         rst,

    input  logic         start,
    output logic         ready,

    input  logic [ 63:0] a,
    input  logic [ 63:0] b,
    output logic [127:0] p
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Types
//
typedef logic [ 63:0] data_t;
typedef logic [ 64:0] z1_data_t;
typedef logic [127:0] odata_t;

typedef struct {
    logic        start;
    logic        ready;
    logic [31:0] a;
    logic [31:0] b;
    logic [63:0] p;
} mult32x32_port_t;

typedef enum {
    IDLE,
    WAIT,
    STORE_Z,
    ADD_Z0,
    ADD_Z1,
    ADD_Z2
} state_t;

//------------------------------------------------
//
//      Objects
//
mult32x32_port_t mult[3];
logic            mult32x32_ready;
data_t           z0, z2;
z1_data_t        z1;

state_t          state = IDLE;

logic            neg_a;
logic            neg_b;
logic            neg_a_r;
logic            neg_b_r;

//------------------------------------------------
//
//      Logic
//
//always_comb begin
//    // z0 computation
//    mult[0].a = a[31:0];
//    mult[0].b = b[31:0];
//    
//    // z1 computation
//    neg_a = a[ 31:0] < a[63:32];
//    neg_b = b[63:32] < b[ 31:0];
//    
//    mult[1].a = neg_a ? a[63:32] - a[31:0] : a[31:0] - a[63:32];
//    mult[1].b = neg_b ? b[31:0] - b[63:32] : b[63:32] - b[31:0];
//    
//    // z2 computation
//    mult[2].a = a[63:32];
//    mult[2].b = b[63:32];
//end

//------------------------------------------------
assign mult[0].start   = state == WAIT;
assign mult[1].start   = state == WAIT;
assign mult[2].start   = state == WAIT;
assign mult32x32_ready = mult[0].ready & mult[1].ready & mult[2].ready;

//------------------------------------------------
assign ready = state == IDLE;

assign neg_a = a[ 31:0] < a[63:32];
assign neg_b = b[63:32] < b[ 31:0];

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE: begin
                if (start) begin
                    p         <= '0;
                    neg_a_r   <= neg_a;
                    neg_b_r   <= neg_b;
                    mult[0].a <= a[31:0];
                    mult[0].b <= b[31:0];
                    mult[1].a <= neg_a ? a[63:32] - a[31:0] : a[31:0] - a[63:32];
                    mult[1].b <= neg_b ? b[31:0] - b[63:32] : b[63:32] - b[31:0];
                    mult[2].a <= a[63:32];
                    mult[2].b <= b[63:32];                               
                    state     <= WAIT;
                end
            end
            WAIT: state <= STORE_Z;
            STORE_Z: begin
                if (mult32x32_ready) begin
                    automatic logic neg = neg_a_r ^ neg_b_r;
                    z0 <= mult[0].p;
                    z2 <= mult[2].p; 
                    z1 <= neg ? mult[0].p + mult[2].p - mult[1].p : mult[0].p + mult[2].p + mult[1].p;
                    state <= ADD_Z0;
                end
            end
            ADD_Z0: begin p <= p + (odata_t'(z0) <<  0); state <= ADD_Z1; end
            ADD_Z1: begin p <= p + (odata_t'(z1) << 32); state <= ADD_Z2; end
            ADD_Z2: begin p <= p + (odata_t'(z2) << 64); state <= IDLE;   end
        endcase
    end
end

//------------------------------------------------
//
//      Instances
//
genvar i;
generate
    for (i=0; i<3; i++) begin : mult32x32_inst
        mult32x32_m mult32x32
        (
            .clk   ( clk           ),
            .start ( mult[i].start ),
            .ready ( mult[i].ready ),
            .a     ( mult[i].a     ),
            .b     ( mult[i].b     ),
            .p     ( mult[i].p     )
        );
    end
endgenerate

//------------------------------------------------
endmodule : mult64x64_m

//------------------------------------------------
//
//      32x32 karatsuba multiplier module
//
//
module mult32x32_m
(
    input  logic        clk,
    input  logic        rst,

    input  logic        start,
    output logic        ready,

    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [63:0] p
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Types
//
typedef logic [31:0] data_t;
typedef logic [32:0] z1_data_t;
typedef logic [63:0] odata_t;

typedef struct {
    logic [15:0] a;
    logic [15:0] b;
    logic [31:0] p;
} mult16x16_data_t;

typedef enum {
    IDLE,
    WAIT,
    STORE_Z,
    ADD_Z0,
    ADD_Z1,
    ADD_Z2
} state_t;

//------------------------------------------------
//
//      Objects
//
mult16x16_data_t mult[3];
data_t           z0, z2;
z1_data_t        z1;

state_t          state = IDLE;

logic            neg_a;
logic            neg_b;
logic            neg_a_r;
logic            neg_b_r;

//------------------------------------------------
//
//      Logic
//
//always_comb begin
//    // z0 computation
//    mult[0].a = a[15:0];
//    mult[0].b = b[15:0];
//    
//    // z1 computation
//    neg_a = a[ 15:0] < a[31:16];
//    neg_b = b[31:16] < b[ 15:0];
//    
//    mult[1].a = neg_a ? a[31:16] - a[15:0] : a[15:0] - a[31:16];
//    mult[1].b = neg_b ? b[15:0] - b[31:16] : b[31:16] - b[15:0];
//    
//    // z2 computation
//    mult[2].a = a[31:16];
//    mult[2].b = b[31:16];
//end

//------------------------------------------------
assign ready = state == IDLE;

assign neg_a = a[ 15:0] < a[31:16];
assign neg_b = b[31:16] < b[ 15:0];

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE: begin
                if (start) begin
                    p         <= '0;
                    neg_a_r   <= neg_a;
                    neg_b_r   <= neg_b;
                    mult[0].a <= a[15:0];
                    mult[0].b <= b[15:0];                
                    mult[1].a <= neg_a ? a[31:16] - a[15:0] : a[15:0] - a[31:16];
                    mult[1].b <= neg_b ? b[15:0] - b[31:16] : b[31:16] - b[15:0];
                    mult[2].a <= a[31:16];
                    mult[2].b <= b[31:16];                
                    state     <= WAIT;
                end
            end
            WAIT: state <= STORE_Z;
            STORE_Z: begin
                automatic logic neg = neg_a_r ^ neg_b_r;
                z0 <= mult[0].p;
                z2 <= mult[2].p; 
                z1 <= neg ? mult[0].p + mult[2].p - mult[1].p : mult[0].p + mult[2].p + mult[1].p;
                state <= ADD_Z0;
            end
            ADD_Z0: begin p <= p + (odata_t'(z0) <<  0); state <= ADD_Z1; end
            ADD_Z1: begin p <= p + (odata_t'(z1) << 16); state <= ADD_Z2; end
            ADD_Z2: begin p <= p + (odata_t'(z2) << 32); state <= IDLE;   end
        endcase
    end
end

//------------------------------------------------
//
//      Instances
//
genvar i;
generate
    for (i=0; i<3; i++) begin : mult16x16_inst
        mult16x16_m mult16x16
        (
            .clk ( clk       ),
            .a   ( mult[i].a ),
            .b   ( mult[i].b ),
            .p   ( mult[i].p )
        );
    end
endgenerate

//------------------------------------------------
endmodule : mult32x32_m

//------------------------------------------------
//
//      16x16 multiplier module
//      with dedicated DSP block inside
//
module mult16x16_m
(
    input  logic        clk,

    input  logic [15:0] a,
    input  logic [15:0] b,
    output logic [31:0] p
);

//------------------------------------------------
`timescale 1ns / 1ps

//------------------------------------------------
//
//      Instances
//
    /*lpm_mult
    #(
    .lpm_hint           ( "INPUT_A_IS_CONSTANT=NO,INPUT_B_IS_CONSTANT=NO,DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5" ),
    .lpm_widtha         ( 16                                                                                                  ),
    .lpm_widthb         ( 16                                                                                                  ),
    .lpm_widthp         ( 32                                                                                                  ),
    .lpm_type           ( "LPM_MULT"                                                                                          ),
    .lpm_representation ( "UNSIGNED"                                                                                          ),
    .lpm_pipeline       ( 1                                                                                                   )
    )
    lpm_mult
    (
    .dataa  ( a    ),
    .datab  ( b    ),
    .clken  ( 1'b1 ),
    .clock  ( clk  ),
    .result ( p    ),
    .aclr   ( 1'b0 ),
    .sclr   ( 1'b0 ),
    .sum    ( 1'b0 )
    );*/

    MULT_MACRO #(
    .DEVICE("7SERIES"), // Target Device: "7SERIES"
    .LATENCY(1),        // Desired clock cycle latency, 0-4
    .WIDTH_A(16),       // Multiplier A-input bus width, 1-25
    .WIDTH_B(16)        // Multiplier B-input bus width, 1-18
    ) MULT_MACRO_inst (
    .P(p),     // Multiplier output bus, width determined by WIDTH_P parameter
    .A(a),     // Multiplier input A bus, width determined by WIDTH_A parameter
    .B(b),     // Multiplier input B bus, width determined by WIDTH_B parameter
    .CE('1),   // 1-bit active high input clock enable
    .CLK(clk), // 1-bit positive edge clock input
    .RST('1)  // 1-bit input active high reset
    );

//------------------------------------------------
endmodule : mult16x16_m

`endif//__MULT_SV__