module test_autosense_case (
    input wire [1:0] sel,
    input wire a,
    input wire b,
    output reg y
);
/*AUTOSENSE*/
always @(*) begin
  case (sel)
    2'b00: y = a;
    default: y = b;
  endcase
end
endmodule
