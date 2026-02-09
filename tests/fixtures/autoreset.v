module test_autoreset (
    input wire clk,
    input wire rst_n,
    output reg q
);
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    /*AUTORESET*/
  end else begin
    q <= 1'b1;
  end
end
endmodule
