// inputs: A input matrix and it's corresponding row of kernels
// outpts: partial feature maps

// Works for square matrices, rectangular matrices should be padded
// Fixed layer depth of 3
// Q1.15 format is used  
// log
// opIK are widened to 32 bits -> shifting is done when flattening is carried out -> partial results also 32 bits
// temporary registers are required to hold values

module ProducePartialFM(clk, rst, ipf, K1f, K2f, K3f, IK1, IK2, IK3, resting);
    input clk,
          rst; // active high rst  
    // parameters for size
    parameter IK_index_bit_width = 5;
    parameter ip_size = 6; // ip dimension
    parameter kernel_size = 3; // kernel dimension
    parameter op_size = ip_size - kernel_size + 1; // op dimension
    // inputs
    input signed [16*ip_size*ip_size - 1 : 0] ipf;
    input signed [16*kernel_size*kernel_size - 1 : 0] K1f;
    input signed [16*kernel_size*kernel_size - 1 : 0] K2f;
    input signed [16*kernel_size*kernel_size - 1 : 0] K3f;
    // matrix inputs
    wire signed [15 : 0] ip [0 : ip_size - 1][0 : ip_size - 1];
    wire signed [15 : 0] K1 [0 : kernel_size - 1][0 : kernel_size - 1];
    wire signed [15 : 0] K2 [0 : kernel_size - 1][0 : kernel_size - 1];
    wire signed [15 : 0] K3 [0 : kernel_size - 1][0 : kernel_size - 1];
    // unpack
    genvar i;
    genvar j;
    generate
        for(j = 0; j<ip_size; j = j+1)
            for(i = 0; i<ip_size; i = i+1)
                assign ip[i][j] = ipf [16*(i+j*ip_size+1)-1 : 16*(i+j*ip_size)];
        for(j = 0; j<kernel_size; j = j+1)
            for(i = 0; i<kernel_size; i = i+1)
                begin
                    assign K1[i][j] = K1f[16*(i+j*kernel_size+1)-1 : 16*(i+j*kernel_size)];
                    assign K2[i][j] = K2f[16*(i+j*kernel_size+1)-1 : 16*(i+j*kernel_size)];
                    assign K3[i][j] = K3f[16*(i+j*kernel_size+1)-1 : 16*(i+j*kernel_size)];
                end
    endgenerate
   
    // outputs
    output reg resting;
    output signed [16*op_size*op_size - 1 : 0] IK1;
    output signed [16*op_size*op_size - 1 : 0] IK2;
    output signed [16*op_size*op_size - 1 : 0] IK3;
    // outputs bitwise separated
    reg signed [15 : 0] opIK1 [0 : op_size*op_size-1];
    reg signed [15 : 0] opIK2 [0 : op_size*op_size-1];
    reg signed [15 : 0] opIK3 [0 : op_size*op_size-1];
    // flatten outputs
    genvar k;
    generate
        for(k = 0; k < op_size*op_size; k = k + 1)
        begin
            assign IK1[16*(k+1)-1 : 16*k] = opIK1[k];
            assign IK2[16*(k+1)-1 : 16*k] = opIK2[k];
            assign IK3[16*(k+1)-1 : 16*k] = opIK3[k];
        end
    endgenerate

    // parameters for FSM
    parameter INIT = 3'b000,
              IDLE = 3'b001,
              MULTIPLY = 3'b010,
              SHIFT = 3'b011,
              ADD = 3'b100,
              REST = 3'b101;

    reg [2:0] state;
   
    // ip subset
    reg signed [15 : 0] ip_subset [0 : kernel_size - 1][0 : kernel_size - 1];

    // element calculation buffers
    reg signed [31 : 0] op1 [0 : kernel_size - 1][0 : kernel_size - 1];
    reg signed [31 : 0] op2 [0 : kernel_size - 1][0 : kernel_size - 1];
    reg signed [31 : 0] op3 [0 : kernel_size - 1][0 : kernel_size - 1];

    // 20 bits long for safe additions
    reg signed [19 : 0] partial_result1;
    reg signed [19 : 0] partial_result2;
    reg signed [19 : 0] partial_result3;
    reg [IK_index_bit_width - 1 : 0] IK_index;
   
    // x, y are variables that take care of row shifting once the right edge of ip is reached
    reg [5 : 0] x, // giving 5 bits so theres sufficient space for increments
                y;
    integer m, n, r, c, p, q, a, b, d, e;
    always @ (posedge clk or posedge rst)
    begin
        if (rst)
        begin
            state <= INIT;
            IK_index <= 0;
            x <= 0;
            y <= 0;
            partial_result1 <= 0;
            partial_result2 <= 0;
            partial_result3 <= 0;
            resting <= 1'b0;
        end
        else
        begin
            case(state)
                INIT:
                begin
                    for(m = 0; m < kernel_size; m = m+1)
                    begin
                        for(n = 0; n < kernel_size; n = n+1)
                        begin
                            ip_subset[m][n] <= ip[m][n];
                        end
                    end
                    // state updation
                    state <= MULTIPLY;
                end

                IDLE:
                begin
                    for(r = 0; r < kernel_size; r = r+1)
                    begin
                        for(c = 0; c < kernel_size-1; c = c+1)
                        begin
                            ip_subset[r][c] <= ip_subset[r][c+1];
                        end
                    end
                    for(r = 0; r < kernel_size; r=r+1)
                    begin
                        ip_subset[r][kernel_size-1] <= ip[r+x][y + kernel_size];
                    end
                    if(y < op_size-2)
                    begin
                        y <= y + 1;
                    end
                    else
                    begin
                        y <= 0;
                        if(x < op_size-1) x <= x + 1;
                        else x <= 0;
                    end
                    // clamping
                    if (partial_result1 > 20'sh07FFF)
                        opIK1[IK_index] <= 16'sh7FFF;
                    else if (partial_result1 < 20'shFF8000)
                        opIK1[IK_index] <= 16'sh8000;
                    else
                        opIK1[IK_index] <= partial_result1[15:0];
                    if (partial_result2 > 20'sh07FFF)
                        opIK2[IK_index] <= 16'sh7FFF;
                    else if (partial_result2 < 20'shFF8000)
                        opIK2[IK_index] <= 16'sh8000;
                    else
                        opIK2[IK_index] <= partial_result2[15:0];
                    if (partial_result3 > 20'sh07FFF)
                        opIK3[IK_index] <= 16'sh7FFF;
                    else if (partial_result3 < 20'shFF8000)
                        opIK3[IK_index] <= 16'sh8000;
                    else
                        opIK3[IK_index] <= partial_result3[15:0];
                    // ik index increments
                    IK_index <= IK_index + 1;
                    // state updation
                    state <= MULTIPLY;
                end

                MULTIPLY:
                begin
                    for(p = 0; p < kernel_size; p = p+1)
                    begin
                        for(q = 0; q < kernel_size; q = q+1)
                        begin
                            op1[p][q] <= ip_subset[p][q] * K1[p][q];
                            op2[p][q] <= ip_subset[p][q] * K2[p][q];
                            op3[p][q] <= ip_subset[p][q] * K3[p][q];
                        end
                    end
                    partial_result1 <= 0;
                    partial_result2 <= 0;
                    partial_result3 <= 0;
                    state <= SHIFT;
                end

                SHIFT:
                begin
                    for(d = 0; d < kernel_size; d = d+1)
                    begin
                        for(e = 0; e < kernel_size; e = e+1)
                        begin
                            op1[d][e] <= op1[d][e] >>> 15;
                            op2[d][e] <= op2[d][e] >>> 15;
                            op3[d][e] <= op3[d][e] >>> 15;
                        end
                    end
                    state <= ADD;
                end

                ADD:
                begin
                    if(IK_index == op_size * op_size)
                    begin
                        resting <= 1'b1;
                        state <= REST;
                    end
                    else
                    begin
                        resting <= 1'b0;
                        state <= IDLE;
                    end
                end

                REST:
                begin
                    state <= REST;
                end

                default: state <= INIT;
            endcase
        end
    end
    always @ (state)
    begin
        case (state)
            ADD:
            begin
                for(a = 0; a < kernel_size; a = a+1)
                begin
                    for(b = 0; b < kernel_size; b = b+1)
                    begin
                        partial_result1 = partial_result1 + op1[a][b];
                        partial_result2 = partial_result2 + op2[a][b];
                        partial_result3 = partial_result3 + op3[a][b];
                    end
                end
            end
        endcase
    end
endmodule