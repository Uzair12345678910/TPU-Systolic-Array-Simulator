// tpu_core.v  -- Verilog-2005 wrapper for the systolic array
module tpu_core
#(
  parameter integer N     = 2,
  parameter integer W     = 8,
  parameter integer ACC_W = 2*W + 4
)(
  input  wire                        clk,
  input  wire                        rst,

  // Control
  input  wire                        start,      // pulse to start
  input  wire [15:0]                 cfg_k,      // inner dimension K (#beats)

  // Streaming inputs (one beat per cycle while in_valid=1 during FEED)
  input  wire                        in_valid,
  output wire                        in_ready,
  input  wire [N*W-1:0]              a_vec_flat, // {a[N-1],...,a[0]}
  input  wire [N*W-1:0]              b_vec_flat, // {b[N-1],...,b[0]}

  // Status
  output wire                        busy,
  output wire                        done,       // 1-cycle pulse when C valid

  // Results
  output wire signed [N*N*ACC_W-1:0] C_flat
);

  // ---------------- FSM ----------------
  localparam [2:0] IDLE   = 3'd0,
                   CLEAR  = 3'd1,
                   FEED   = 3'd2,
                   DRAIN  = 3'd3,
                   DONE_S = 3'd4;

  // Safe drain for skew + registered passes (works for N>=2)
  localparam integer DRAIN_CONST = 2*(N-1) + 1;

  reg  [2:0]  state, nstate;
  reg  [15:0] feed_cnt, drain_cnt;

  assign in_ready = (state == FEED);                 // we "always ready" in FEED
  assign busy     = (state != IDLE) && (state != DONE_S);

  // Done pulse
  reg done_r;
  assign done = done_r;
  always @(posedge clk) begin
    if (rst) done_r <= 1'b0;
    else     done_r <= (state == DONE_S);
  end

  // Counters
  always @(posedge clk) begin
    if (rst) begin
      feed_cnt  <= 16'd0;
      drain_cnt <= 16'd0;
    end else begin
      if (state == CLEAR) begin
        feed_cnt  <= 16'd0;
        drain_cnt <= 16'd0;
      end else if (state == FEED && in_valid) begin
        feed_cnt <= feed_cnt + 16'd1;
      end else if (state == DRAIN) begin
        drain_cnt <= drain_cnt + 16'd1;
      end
    end
  end

  // Next-state logic
  always @* begin
    nstate = state;
    case (state)
      IDLE:   nstate = start ? CLEAR : IDLE;
      CLEAR:  nstate = FEED;  // one cycle to clear accumulators
      FEED:   nstate = ((feed_cnt == (cfg_k-1)) && in_valid) ? DRAIN : FEED;
      DRAIN:  nstate = (drain_cnt == (DRAIN_CONST-1)) ? DONE_S : DRAIN;
      DONE_S: nstate = IDLE;
      default:nstate = IDLE;
    endcase
  end

  // State register
  always @(posedge clk) begin
    if (rst) state <= IDLE;
    else     state <= nstate;
  end

  // ---------------- Drive the systolic array ----------------
  // Enable the array when we accept a feed beat, and during every drain beat.
  wire        arr_en  = (state==FEED) ? in_valid : (state==DRAIN);
  wire        arr_rst = (state==CLEAR);

  // Pass the vectors through combinationally during FEED; zeros otherwise.
  wire [N*W-1:0] arr_a_flat_u = (state==FEED && in_valid) ? a_vec_flat : {N*W{1'b0}};
  wire [N*W-1:0] arr_b_flat_u = (state==FEED && in_valid) ? b_vec_flat : {N*W{1'b0}};

  systolic_array
  #(.N(N), .W(W), .ACC_W(ACC_W))
  u_array (
    .clk(clk),
    .rst(arr_rst),
    .en(arr_en),
    .a_vec_flat(arr_a_flat_u),
    .b_vec_flat(arr_b_flat_u),
    .C_flat(C_flat)
  );

endmodule
