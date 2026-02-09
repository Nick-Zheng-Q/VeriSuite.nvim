module test_autounused (
    input wire clk,
    input wire rst_n,
    input wire a,
    input wire b,
    output reg y
);
/*AUTOUNUSED*/
always @(*) begin
    y = a & b;
end
endmodule
