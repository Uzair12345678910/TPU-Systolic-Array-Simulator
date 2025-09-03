`timescale 1ns/1ps
module tb_perf_only;
  localparam integer N=4, W=8, ACC_W=20, K=4;

  reg  clk=0, rst=1, start=0, in_valid=0;
  reg  [N*W-1:0] a_vec_flat, b_vec_flat;
  wire in_ready, busy, done;
  wire [N*N*ACC_W-1:0] C_flat;

  // DUT
  tpu_core #(.N(N), .W(W), .ACC_W(ACC_W)) dut (
    .clk(clk), .rst(rst),
    .start(start), .cfg_k(16'd4),
    .in_valid(in_valid), .in_ready(in_ready),
    .a_vec_flat(a_vec_flat), .b_vec_flat(b_vec_flat),
    .busy(busy), .done(done), .C_flat(C_flat)
  );

  // 10 ns clock
  always #5 clk = ~clk;

  // Matrices
  integer k;
  reg signed [W-1:0] A [0:N-1][0:K-1];
  reg signed [W-1:0] B [0:K-1][0:N-1];

  task set_Acol4; input signed [W-1:0] a0,a1,a2,a3; begin
    a_vec_flat = {a3[W-1:0],a2[W-1:0],a1[W-1:0],a0[W-1:0]};
  end endtask
  task set_Brow4; input signed [W-1:0] b0,b1,b2,b3; begin
    b_vec_flat = {b3[W-1:0],b2[W-1:0],b1[W-1:0],b0[W-1:0]};
  end endtask

  integer t_start, t_done, cycles_feed, cycles_total, total_macs, eff_x100;

  initial begin
    $display("tb_perf_only: start @ %0t", $time);
    $dumpfile("perf_only.vcd");
    $dumpvars(0, tb_perf_only);

    // A
    A[0][0]=1; A[0][1]=2; A[0][2]=3; A[0][3]=4;
    A[1][0]=-1;A[1][1]=0; A[1][2]=1; A[1][3]=2;
    A[2][0]=5; A[2][1]=6; A[2][2]=7; A[2][3]=8;
    A[3][0]=0; A[3][1]=1; A[3][2]=0; A[3][3]=1;
    // B
    B[0][0]=1; B[0][1]=0; B[0][2]=1; B[0][3]=0;
    B[1][0]=2; B[1][1]=-1;B[1][2]=0; B[1][3]=1;
    B[2][0]=3; B[2][1]=1; B[2][2]=2; B[2][3]=1;
    B[3][0]=4; B[3][1]=0; B[3][2]=-1;B[3][3]=2;

    // Reset
    a_vec_flat=0; b_vec_flat=0; in_valid=0;
    repeat(2) @(posedge clk); rst=0;

    // Start + timestamp
    @(posedge clk); start=1; t_start=$time; @(posedge clk); start=0;

    // Feed K beats
    cycles_feed = 0;
    for (k=0;k<K;k=k+1) begin
      wait(in_ready==1);
      in_valid=1;
      set_Acol4(A[0][k],A[1][k],A[2][k],A[3][k]);
      set_Brow4(B[k][0],B[k][1],B[k][2],B[k][3]);
      @(posedge clk);
      cycles_feed = cycles_feed + 1;
    end
    in_valid=0; a_vec_flat=0; b_vec_flat=0;

    // Finish when done or timeout
    fork
      begin
        @(posedge done);
        t_done = $time;
        cycles_total = (t_done - t_start)/10;   // 10ns period
        total_macs   = N*N*K;                   // 64
        eff_x100     = (total_macs*100)/cycles_total;
        $display("DONE @ %0t", t_done);
        $display("Feed cycles   = %0d", cycles_feed);
        $display("Total cycles  = %0d", cycles_total);
        $display("Peak MACs/cyc = %0d | Effective MACs/cyc ≈ %0d.%02d",
                 N*N, eff_x100/100, eff_x100%100);
        $finish;
      end
      begin
        repeat(300) @(posedge clk);
        $display("TIMEOUT: busy=%0b in_ready=%0b done=%0b", busy,in_ready,done);
        $finish;
      end
    join
  end
endmodule
