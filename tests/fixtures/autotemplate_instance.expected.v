module submod_inst (
    input wire clk,
    output wire [3:0] data_bus,
    output wire valid
);
endmodule

module test_autotemplate_instance;
    wire [3:0] my_bus0;
    wire [3:0] my_bus1;
    wire my_valid0;
    wire my_valid1;

    /* u_submod1 AUTO_TEMPLATE (
        .data_bus   (my_bus[@]),
        .valid      (my_valid[@]),
    ); */

    submod_inst u_submod0 (
        .clk(clk),
          .data_bus(data_bus),
          .valid(valid)
    );

    submod_inst u_submod1 (
        .clk(clk),
          .data_bus(my_bus[1]),
          .valid(my_valid[1])
    );
endmodule
