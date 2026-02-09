// tests/fixtures/autotemplate.v
// Test fixture for AUTO_TEMPLATE expansion

module submod (
    input wire clk,
    output wire [3:0] data_bus,
    output wire valid
);
    assign data_bus = 4'h0;
    assign valid = 1'b0;
endmodule

module test_autotemplate;
    wire [3:0] my_databus;
    wire my_valid;
    
    /* submod AUTO_TEMPLATE (
        .data_bus   (my_databus[]),
        .valid      (my_valid),
        );
    */
    submod u_submod0 (
          .clk(clk),
          .data_bus(my_databus[3:0]),
          .valid(my_valid)
    );
endmodule
