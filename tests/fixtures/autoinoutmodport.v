interface bus_if;
  logic req;
  logic gnt;
  modport master (output req, input gnt);
endinterface

module test_modport;
  /*AUTOINOUTMODPORT(master)*/
endmodule
