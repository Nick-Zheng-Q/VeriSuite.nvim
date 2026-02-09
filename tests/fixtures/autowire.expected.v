// tests/fixtures/autowire.v
// Fixture for wire generation

module test_autowire (
    input wire clk,
    output wire out
);
      // Beginning of automatic wires
      wire [3:0] internal_wire;
      // End of automatics
    
    // Instantiate a submodule
    submod u_submod (
        .clk(clk),
        .data(internal_wire)
    );
endmodule

module submod (
    input wire clk,
    output wire [3:0] data
);
    assign data = 4'b0000;
endmodule
