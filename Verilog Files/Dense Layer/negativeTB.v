`timescale 1ns/1ps

module tb_dense;

    // Parameters from DUT
    localparam m = 10;
    localparam n = 100;
    localparam alpha = 328;
    localparam sets = 10;
    localparam total_number_of_iterations = 10;

    // DUT inputs
    reg clk;
    reg rst;
    reg [16*m*n-1 : 0] weightsf;
    reg [16*m*n-1 : 0] biasesf;
    reg [16*m-1 : 0]   x;

    // DUT outputs
    wire [16*n-1 : 0] y;

    // Instantiate DUT
    dense #(
        .m(m),
        .n(n),
        .alpha(alpha),
        .sets(sets),
        .total_number_of_iterations(total_number_of_iterations)
    ) dut (
        .clk(clk),
        .rst(rst),
        .weightsf(weightsf),
        .biasesf(biasesf),
        .x(x),
        .y(y)
    );

    // clock gen
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // stimulus
    integer i;
    initial begin
        // init
        rst = 1;
        weightsf = {16*m*n{1'b0}};
        biasesf  = {16*m*n{1'b0}};
        x        = {16*m{1'b0}};
        #20;

        rst = 0;

        // input vector: simple positive values
        // in Q1.15 form (just small integers for clarity)
        x = {16'sd1, 16'sd2, 16'sd3, 16'sd4, 16'sd5, 
             16'sd6, 16'sd7, 16'sd8, 16'sd9, 16'sd10};

        // weights = -1, biases = -1
        // (easy to check: output will clearly go negative before LeakyReLU)
        // Case 1: diagonal weights = 1
        for (i = 0; i < m*n; i = i + 1) 
        begin
            if (i % m == i / m) // crude diagonal check
                weightsf[16*(i+1)-1 -: 16] = 16'sd1;
            else
                weightsf[16*(i+1)-1 -: 16] = 16'sd0;
            biasesf[16*(i+1)-1 -: 16]  = 16'sd0;
        end


        // let simulation run
        #2000;
        $finish;
    end

    // monitor only at posedge resting
    integer j;
    always @(posedge dut.resting) begin
        $write("Outputs at %t ns: ", $time);
        for (j = 0; j < n; j = j + 1) begin
            $write("%0d ", $signed(y[16*(j+1)-1 -: 16]));
        end
        $write("\n");
    end

endmodule
