module test_autosense (
    input wire a,
    input wire b,
    output reg y
);
/*AUTOSENSE*/
always @(*) begin
    y = a & b;
end
endmodule
