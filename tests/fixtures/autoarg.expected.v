// tests/fixtures/autoarg.v
// Fixture for argument expansion

module test_autoarg(
  // Outputs
  data_out,
  valid,
  // Inputs
  clk,
  rst_n,
  data_in
);
    input wire clk;
    input wire rst_n;
    output reg [7:0] data_out;
    input wire [7:0] data_in;
    output wire valid;
endmodule
