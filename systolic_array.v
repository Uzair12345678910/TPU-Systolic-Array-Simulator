// systolic_array.v  -- uses unsigned edge ports; casts to signed internally
module systolic_array #(
    parameter integer N      = 2,
    parameter integer W      = 8,
    parameter integer ACC_W  = 2*W + 4
)(
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        en,

    // UNSIGNED edge vectors; cast slices to signed when unpacking
    input  wire [N*W-1:0]              a_vec_flat,  // {a[N-1],...,a[0]}
    input  wire [N*W-1:0]              b_vec_flat,  // {b[N-1],...,b[0]}

    output wire signed [N*N*ACC_W-1:0] C_flat
);

    // Unpack with explicit signed cast
    wire signed [W-1:0] a_vec [0:N-1];
    wire signed [W-1:0] b_vec [0:N-1];
    genvar u;
    generate
        for (u=0; u<N; u=u+1) begin : UNPACK
            assign a_vec[u] = $signed(a_vec_flat[W*u +: W]);
            assign b_vec[u] = $signed(b_vec_flat[W*u +: W]);
        end
    endgenerate

    // Skew pipelines (delay A row i by i cycles, B col j by j cycles)
    wire signed [W-1:0] a_skew [0:N-1];
    wire signed [W-1:0] b_skew [0:N-1];

    genvar i, j;
    generate
        for (i=0; i<N; i=i+1) begin : SKEW_A
            if (i==0) begin
                assign a_skew[i] = a_vec[i];
            end else begin : PIPEA
                reg signed [W-1:0] pipe [0:i-1];
                integer k;
                always @(posedge clk) begin
                    if (rst) begin
                        for (k=0;k<i;k=k+1) pipe[k] <= {W{1'b0}};
                    end else if (en) begin
                        pipe[0] <= a_vec[i];
                        for (k=1;k<i;k=k+1) pipe[k] <= pipe[k-1];
                    end
                end
                assign a_skew[i] = pipe[i-1];
            end
        end
        for (j=0; j<N; j=j+1) begin : SKEW_B
            if (j==0) begin
                assign b_skew[j] = b_vec[j];
            end else begin : PIPEB
                reg signed [W-1:0] pipe [0:j-1];
                integer k2;
                always @(posedge clk) begin
                    if (rst) begin
                        for (k2=0;k2<j;k2=k2+1) pipe[k2] <= {W{1'b0}};
                    end else if (en) begin
                        pipe[0] <= b_vec[j];
                        for (k2=1;k2<j;k2=k2+1) pipe[k2] <= pipe[k2-1];
                    end
                end
                assign b_skew[j] = pipe[j-1];
            end
        end
    endgenerate

    // Pass-through buses and accumulators
    wire signed [W-1:0]       a_bus [0:N-1][0:N-1];
    wire signed [W-1:0]       b_bus [0:N-1][0:N-1];
    wire signed [ACC_W-1:0]   C     [0:N-1][0:N-1];

    // MAC grid
    generate
        for (i=0; i<N; i=i+1) begin : ROW
            for (j=0; j<N; j=j+1) begin : COL
                if (i==0 && j==0) begin : CELL00
                    mac_cell #(.W(W), .ACC_W(ACC_W)) u (
                        .clk(clk), .rst(rst), .en(en),
                        .a_in(a_skew[i]), .b_in(b_skew[j]),
                        .a_out(a_bus[i][j]), .b_out(b_bus[i][j]), .acc(C[i][j])
                    );
                end else if (i==0) begin : CELL0J
                    mac_cell #(.W(W), .ACC_W(ACC_W)) u (
                        .clk(clk), .rst(rst), .en(en),
                        .a_in(a_bus[i][j-1]), .b_in(b_skew[j]),
                        .a_out(a_bus[i][j]),  .b_out(b_bus[i][j]), .acc(C[i][j])
                    );
                end else if (j==0) begin : CELLI0
                    mac_cell #(.W(W), .ACC_W(ACC_W)) u (
                        .clk(clk), .rst(rst), .en(en),
                        .a_in(a_skew[i]), .b_in(b_bus[i-1][j]),
                        .a_out(a_bus[i][j]), .b_out(b_bus[i][j]), .acc(C[i][j])
                    );
                end else begin : CELLIJ
                    mac_cell #(.W(W), .ACC_W(ACC_W)) u (
                        .clk(clk), .rst(rst), .en(en),
                        .a_in(a_bus[i][j-1]), .b_in(b_bus[i-1][j]),
                        .a_out(a_bus[i][j]),  .b_out(b_bus[i][j]), .acc(C[i][j])
                    );
                end
            end
        end
    endgenerate

    // Pack C row-major
    generate
        for (i=0; i<N; i=i+1) begin : PACK_R
            for (j=0; j<N; j=j+1) begin : PACK_C
                localparam integer L = ACC_W*(i*N + j);
                assign C_flat[L +: ACC_W] = C[i][j];
            end
        end
    endgenerate
endmodule
