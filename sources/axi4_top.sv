// AXI4 Top Module - Baseline RTL (incomplete)
// This is the top-level module that instantiates master and slave

module axi4_top (
    input logic clk,
    input logic resetn
);

    // AXI4 Master
    axi4_master master (
        .clk(clk),
        .resetn(resetn),
        // ... AXI4 signals connected to slave
    );
    
    // AXI4 Slave
    axi4_slave slave (
        .clk(clk),
        .resetn(resetn),
        // ... AXI4 signals connected to master
    );
    
    // Interrupt controller
    axi4_interrupt interrupt_ctrl (
        .clk(clk),
        .resetn(resetn),
        // ... signals
    );

endmodule

