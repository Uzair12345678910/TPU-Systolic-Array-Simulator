// mac_cell.v
// One systolic cell: passes A→right, B↓, accumulates A*B each enabled beat.
module mac_cell #(
    parameter W = 8,                  // operand width (int8)
    parameter ACC_W = 2*W + 4         // accumulator width (headroom)
)(
    input  wire                   clk,
    input  wire                   rst,   // sync reset, active-high
    input  wire                   en,    // advance one "beat" when 1
    input  wire signed [W-1:0]    a_in,  // from left
    input  wire signed [W-1:0]    b_in,  // from top
    output reg  signed [W-1:0]    a_out, // to right
    output reg  signed [W-1:0]    b_out, // down
    output reg  signed [ACC_W-1:0] acc   // running sum for this C(i,j)
);
    always @(posedge clk) begin
        if (rst) begin
            a_out <= '0; b_out <= '0; acc <= '0;
        end else if (en) begin
            a_out <= a_in;
            b_out <= b_in;
            acc   <= acc + a_in * b_in;
        end
    end
endmodule
