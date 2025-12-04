
module axi4_slave_tb;

    reg clk;
    reg resetn;
    
    reg [31:0]  axi_awaddr;
    reg [7:0]   axi_awlen;
    reg [2:0]   axi_awsize;
    reg [1:0]   axi_awburst;
    reg         axi_awvalid;
    wire        axi_awready;
    
    reg [31:0]  axi_wdata;
    reg [3:0]   axi_wstrb;
    reg         axi_wlast;
    reg         axi_wvalid;
    wire        axi_wready;
    
    wire [1:0]  axi_bresp;
    wire        axi_bvalid;
    reg         axi_bready;
    
    reg [31:0]  axi_araddr;
    reg [7:0]   axi_arlen;
    reg [2:0]   axi_arsize;
    reg [1:0]   axi_arburst;
    reg         axi_arvalid;
    wire        axi_arready;
    
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;
    wire        axi_rlast;
    wire        axi_rvalid;
    reg         axi_rready;
    
    localparam [1:0] OKAY   = 2'b00;
    localparam [1:0] EXOKAY = 2'b01;
    localparam [1:0] SLVERR = 2'b10;
    localparam [1:0] DECERR = 2'b11;
    
    localparam [1:0] FIXED = 2'b00;
    localparam [1:0] INCR  = 2'b01;
    localparam [1:0] WRAP  = 2'b10;
    
    axi4_slave dut (
        .clk(clk),
        .resetn(resetn),
        .axi_awaddr(axi_awaddr),
        .axi_awlen(axi_awlen),
        .axi_awsize(axi_awsize),
        .axi_awburst(axi_awburst),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wlast(axi_wlast),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        .axi_araddr(axi_araddr),
        .axi_arlen(axi_arlen),
        .axi_arsize(axi_arsize),
        .axi_arburst(axi_arburst),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rlast(axi_rlast),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        resetn = 0;
        axi_awaddr = 32'h0;
        axi_awlen = 8'h0;
        axi_awsize = 3'h0;
        axi_awburst = 2'h0;
        axi_awvalid = 1'b0;
        axi_wdata = 32'h0;
        axi_wstrb = 4'h0;
        axi_wlast = 1'b0;
        axi_wvalid = 1'b0;
        axi_bready = 1'b0;
        axi_araddr = 32'h0;
        axi_arlen = 8'h0;
        axi_arsize = 3'h0;
        axi_arburst = 2'h0;
        axi_arvalid = 1'b0;
        axi_rready = 1'b0;
        
        #20;
        resetn = 1;
        #10;
        
        $display("Test 1: Single-beat INCR write");
        axi_awaddr = 32'h0000_0000;
        axi_awlen = 8'h0;
        axi_awsize = 3'h2;
        axi_awburst = INCR;
        axi_awvalid = 1'b1;
        
        @(posedge clk);
        wait(axi_awready);
        @(posedge clk);
        axi_awvalid = 1'b0;
        
        axi_wdata = 32'hDEAD_BEEF;
        axi_wstrb = 4'hF;
        axi_wlast = 1'b1;
        axi_wvalid = 1'b1;
        
        @(posedge clk);
        wait(axi_wready);
        @(posedge clk);
        axi_wvalid = 1'b0;
        axi_wlast = 1'b0;
        
        axi_bready = 1'b1;
        @(posedge clk);
        wait(axi_bvalid);
        $display("  Response: %b (expected OKAY=00)", axi_bresp);
        @(posedge clk);
        axi_bready = 1'b0;
        #20;
        
        $display("Test 2: 4-beat INCR burst");
        axi_awaddr = 32'h0000_0010;
        axi_awlen = 8'h3;
        axi_awsize = 3'h2;
        axi_awburst = INCR;
        axi_awvalid = 1'b1;
        
        @(posedge clk);
        wait(axi_awready);
        @(posedge clk);
        axi_awvalid = 1'b0;
        
        for (int i = 0; i < 4; i++) begin
            axi_wdata = 32'h1111_1111 + i;
            axi_wstrb = 4'hF;
            axi_wlast = (i == 3);
            axi_wvalid = 1'b1;
            
            @(posedge clk);
            wait(axi_wready);
            @(posedge clk);
        end
        axi_wvalid = 1'b0;
        axi_wlast = 1'b0;
        
        axi_bready = 1'b1;
        @(posedge clk);
        wait(axi_bvalid);
        $display("  Response: %b (expected OKAY=00)", axi_bresp);
        @(posedge clk);
        axi_bready = 1'b0;
        #20;
        
        $display("Test 3: 4-beat FIXED burst");
        axi_awaddr = 32'h0000_0020;
        axi_awlen = 8'h3;
        axi_awsize = 3'h2;
        axi_awburst = FIXED;
        axi_awvalid = 1'b1;
        
        @(posedge clk);
        wait(axi_awready);
        @(posedge clk);
        axi_awvalid = 1'b0;
        
        for (int i = 0; i < 4; i++) begin
            axi_wdata = 32'hAAAA_AAAA;
            axi_wstrb = 4'hF;
            axi_wlast = (i == 3);
            axi_wvalid = 1'b1;
            
            @(posedge clk);
            wait(axi_wready);
            @(posedge clk);
        end
        axi_wvalid = 1'b0;
        axi_wlast = 1'b0;
        
        axi_bready = 1'b1;
        @(posedge clk);
        wait(axi_bvalid);
        $display("  Response: %b (expected OKAY=00)", axi_bresp);
        @(posedge clk);
        axi_bready = 1'b0;
        #20;
        
        $display("Test 4: Out-of-range address");
        axi_awaddr = 32'h0000_1000;
        axi_awlen = 8'h0;
        axi_awsize = 3'h2;
        axi_awburst = INCR;
        axi_awvalid = 1'b1;
        
        @(posedge clk);
        wait(axi_awready);
        @(posedge clk);
        axi_awvalid = 1'b0;
        
        axi_wdata = 32'h1234_5678;
        axi_wstrb = 4'hF;
        axi_wlast = 1'b1;
        axi_wvalid = 1'b1;
        
        @(posedge clk);
        wait(axi_wready);
        @(posedge clk);
        axi_wvalid = 1'b0;
        axi_wlast = 1'b0;
        
        axi_bready = 1'b1;
        @(posedge clk);
        wait(axi_bvalid);
        $display("  Response: %b (expected DECERR=11)", axi_bresp);
        @(posedge clk);
        axi_bready = 1'b0;
        #20;
        
        $display("All tests completed");
        #100;
        $finish;
    end
    

    initial begin
        $dumpfile("axi4_slave_tb.vcd");
        $dumpvars(0, axi4_slave_tb);
    end

endmodule
