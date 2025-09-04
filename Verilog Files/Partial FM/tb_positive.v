module tb_ProducePartialFM;

  // Parameters (must match DUT)
  localparam ip_size     = 6;   // changed
  localparam kernel_size = 3;   // changed
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

    // Reset active
    #20;
    rst = 0;

    // Fill ipf with Q1.15 values (choose 0.25 -> raw = 8192)
    // ip is 6x6
    ipf = 0;
    for (i = 0; i < ip_size*ip_size; i = i+1) begin
      ipf[16*(i+1)-1 -: 16] = 16'd8192;  // all inputs = 0.25
    end

    // Kernels: choose different simple constants for each kernel (Q1.15 raw)
    // K1 entries = 0.5  -> 16384
    // K2 entries = 0.25 -> 8192
    // K3 entries = 0.125-> 4096
    for (i = 0; i < kernel_size*kernel_size; i = i+1) begin
      K1f[16*(i+1)-1 -: 16] = 16'd16384;
      K2f[16*(i+1)-1 -: 16] = 16'd8192;
      K3f[16*(i+1)-1 -: 16] = 16'd4096;
    end

    // Run long enough to observe outputs
    #4000;
    $stop;
  end

  // Display only when resting goes high (posedge resting)
  integer row, col;
  always @(posedge resting) begin
    $display("T=%0t | resting=1, Final Matrices:", $time);

    $display("IK1 matrix:");
    for (row = 0; row < op_size; row = row+1) begin
      for (col = 0; col < op_size; col = col+1) begin
        $write("%0d ", IK1[16*(row*op_size+col+1)-1 -: 16]);
      end
      $write("\n");
    end

    $display("IK2 matrix:");
    for (row = 0; row < op_size; row = row+1) begin
      for (col = 0; col < op_size; col = col+1) begin
        $write("%0d ", IK2[16*(row*op_size+col+1)-1 -: 16]);
      end
      $write("\n");
    end

    $display("IK3 matrix:");
    for (row = 0; row < op_size; row = row+1) begin
      for (col = 0; col < op_size; col = col+1) begin
        $write("%0d ", IK3[16*(row*op_size+col+1)-1 -: 16]);
      end
      $write("\n");
    end

    $display("--------------------------------------------------");
  end

endmodule
