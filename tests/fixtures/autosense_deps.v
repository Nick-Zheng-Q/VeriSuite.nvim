module test_autosense_deps (
    input wire a,
    input wire b,
    input wire c,
    output reg y
);
reg t;
/*AUTOSENSE*/
always @(*) begin
    t = a & b;
    y = t | c;
end
endmodule
