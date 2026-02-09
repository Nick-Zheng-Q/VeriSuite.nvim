module test_autosense (
    input wire a,
    input wire b,
    output reg y
);
  a or b
always @(*) begin
    y = a & b;
end
endmodule
