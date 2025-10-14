module tb_dense;

    // Parameters from DUT
    localparam m = 10;
    localparam n = 100;
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
    wire resting;

    // Instantiate DUT
    dense #(
        .m(m),
        .n(n),
        .sets(sets),
        .total_number_of_iterations(total_number_of_iterations)
    ) dut (
        .clk(clk),
        .rst(rst),
        .weightsf(weightsf),
        .biasesf(biasesf),
        .x(x),
        .y(y),
        .resting(resting) // connect it
    );

    // clock gen
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
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

        // simple input vector: set all to 1.0 in Q1.15 (32767)
        for (i = 0; i < m; i = i + 1) begin
            x[16*(i+1)-1 -: 16] = 16'sd32767;
        end

        // weights = 1.0 (Q1.15), biases = 0
        for (i = 0; i < m*n; i = i + 1) begin
            weightsf[16*(i+1)-1 -: 16] = 16'sd32767;
            biasesf[16*(i+1)-1 -: 16]  = 16'sd0;
        end

        // let simulation run
        #20000;
        $finish;
    end

    // monitor when outputs are ready
    integer j;
    always @(posedge resting) begin
        $display("---- Outputs Ready at time %0t ----", $time);
        for (j = 0; j < n; j = j + 1) begin
            $display("y[%0d] = %0d", j, y[16*(j+1)-1 -: 16]);
        end
    end

endmodule
