module tb_ProducePartialFM;

  // Parameters (must match DUT)
  localparam ip_size     = 6;
  localparam kernel_size = 3;
  localparam op_size     = ip_size - kernel_size + 1;

  // Clock + Reset
  reg clk, rst;

  // Inputs to DUT (flattened)
  reg [16*ip_size*ip_size-1:0] ipf;
  reg [16*kernel_size*kernel_size-1:0] K1f;
  reg [16*kernel_size*kernel_size-1:0] K2f;
  reg [16*kernel_size*kernel_size-1:0] K3f;

  // Outputs from DUT (flattened)
  wire [16*op_size*op_size-1:0] IK1;
  wire [16*op_size*op_size-1:0] IK2;
  wire [16*op_size*op_size-1:0] IK3;
  wire resting;

  // Instantiate DUT
  ProducePartialFM dut (
    .clk(clk),
    .rst(rst),
    .ipf(ipf),
    .K1f(K1f),
    .K2f(K2f),
    .K3f(K3f),
    .IK1(IK1),
    .IK2(IK2),
    .IK3(IK3),
    .resting(resting)
  );

  // Clock generation (10 time unit period)
  always #5 clk = ~clk;

  // Stimulus
  integer i;
  initial begin
    clk = 0;
    rst = 1;

    #20;
    rst = 0;

    // Fill ipf with Q1.15 value 0.25 (8192 raw)
    for (i = 0; i < ip_size*ip_size; i = i+1)
      ipf[16*(i+1)-1 -: 16] = 8192;

    // Kernels
    for (i = 0; i < kernel_size*kernel_size; i = i+1) begin
      K1f[16*(i+1)-1 -: 16] = 16384;   // +0.5
      K2f[16*(i+1)-1 -: 16] = -8192;   // -0.25
      K3f[16*(i+1)-1 -: 16] = -4096;   // -0.125
    end

    #4000;
    $stop;
  end

  // Debugging monitors
  integer row, col;
  always @(posedge clk) begin
    $display("T=%0t | State=%0d | IK_index=%0d | resting=%b",
             $time, dut.state, dut.IK_index, resting);

    $display("  partial_result1=%0d | partial_result2=%0d | partial_result3=%0d",
             dut.partial_result1, dut.partial_result2, dut.partial_result3);

    $display("  ip_subset[0][0]=%0d, K1[0][0]=%0d, op1[0][0]=%0d (after shift=%0d)",
             dut.ip_subset[0][0], dut.K1[0][0],
             dut.op1[0][0], dut.op1[0][0]>>>15);

    $display("IK1 matrix so far:");
    for (row = 0; row < op_size; row = row+1) begin
      for (col = 0; col < op_size; col = col+1)
        $write("%0d ", IK1[16*(row*op_size+col+1)-1 -: 16]);
      $write("\n");
    end

    $display("IK2 matrix so far:");
    for (row = 0; row < op_size; row = row+1) begin
      for (col = 0; col < op_size; col = col+1)
        $write("%0d ", IK2[16*(row*op_size+col+1)-1 -: 16]);
      $write("\n");
    end

    $display("IK3 matrix so far:");
    for (row = 0; row < op_size; row = row+1) begin
      for (col = 0; col < op_size; col = col+1)
        $write("%0d ", IK3[16*(row*op_size+col+1)-1 -: 16]);
      $write("\n");
    end

    $display("--------------------------------------------------");
  end

endmodule
