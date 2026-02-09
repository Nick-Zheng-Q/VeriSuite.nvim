module test_autoreset_targets (
    input wire clk,
    input wire rst_n,
    output reg q,
    output reg r
);
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    /*AUTORESET*/
  end else begin
    q <= 1'b1;
    r <= q;
  end
end
endmodule
