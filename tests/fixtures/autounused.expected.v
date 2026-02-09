module test_autounused (
    input wire clk,
    input wire rst_n,
    input wire a,
    input wire b,
    output reg y
);
  localparam _unused_ok = &{clk, rst_n};
always @(*) begin
    y = a & b;
end
endmodule
