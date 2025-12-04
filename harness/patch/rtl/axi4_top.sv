// AXI4 Top Module - Golden/Reference RTL
// This is the top-level module that instantiates master and slave

module axi4_top (
    input logic clk,
    input logic resetn
);

    // AXI4 signals between master and slave
    // Write Address Channel
    logic [31:0]  axi_awaddr;
    logic [7:0]   axi_awlen;
    logic [2:0]   axi_awsize;
    logic [1:0]   axi_awburst;
    logic         axi_awvalid;
    logic         axi_awready;
    
    // Write Data Channel
    logic [31:0]  axi_wdata;
    logic [3:0]   axi_wstrb;
    logic         axi_wlast;
    logic         axi_wvalid;
    logic         axi_wready;
    
    // Write Response Channel
    logic [1:0]   axi_bresp;
    logic         axi_bvalid;
    logic         axi_bready;
    
    // Read Address Channel
    logic [31:0]  axi_araddr;
    logic [7:0]   axi_arlen;
    logic [2:0]   axi_arsize;
    logic [1:0]   axi_arburst;
    logic         axi_arvalid;
    logic         axi_arready;
    
    // Read Data Channel
    logic [31:0]  axi_rdata;
    logic [1:0]   axi_rresp;
    logic         axi_rlast;
    logic         axi_rvalid;
    logic         axi_rready;
    
    // Interrupt signals
    logic         interrupt_req;
    logic         interrupt_ack;

    // AXI4 Master
    axi4_master master (
        .clk(clk),
        .resetn(resetn),
        // Write Address Channel
        .axi_awaddr(axi_awaddr),
        .axi_awlen(axi_awlen),
        .axi_awsize(axi_awsize),
        .axi_awburst(axi_awburst),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        // Write Data Channel
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wlast(axi_wlast),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        // Write Response Channel
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        // Read Address Channel
        .axi_araddr(axi_araddr),
        .axi_arlen(axi_arlen),
        .axi_arsize(axi_arsize),
        .axi_arburst(axi_arburst),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        // Read Data Channel
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rlast(axi_rlast),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready)
    );
    
    // AXI4 Slave
    axi4_slave slave (
        .clk(clk),
        .resetn(resetn),
        // Write Address Channel
        .axi_awaddr(axi_awaddr),
        .axi_awlen(axi_awlen),
        .axi_awsize(axi_awsize),
        .axi_awburst(axi_awburst),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        // Write Data Channel
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wlast(axi_wlast),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        // Write Response Channel
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        // Read Address Channel
        .axi_araddr(axi_araddr),
        .axi_arlen(axi_arlen),
        .axi_arsize(axi_arsize),
        .axi_arburst(axi_arburst),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        // Read Data Channel
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rlast(axi_rlast),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready)
    );
    
    // Interrupt controller
    axi4_interrupt interrupt_ctrl (
        .clk(clk),
        .resetn(resetn),
        .interrupt_req(interrupt_req),
        .interrupt_ack(interrupt_ack)
    );

endmodule
