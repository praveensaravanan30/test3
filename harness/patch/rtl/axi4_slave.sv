// AXI4 Slave Module - Golden RTL (same as patch/rtl/)
// This is the golden/reference RTL used for validation

module axi4_slave (
    input logic clk,
    input logic resetn,
    
    // Write Address Channel
    input logic [31:0]  axi_awaddr,
    input logic [7:0]   axi_awlen,
    input logic [2:0]   axi_awsize,
    input logic [1:0]   axi_awburst,
    input logic         axi_awvalid,
    output logic        axi_awready,
    
    // Write Data Channel
    input logic [31:0]  axi_wdata,
    input logic [3:0]   axi_wstrb,
    input logic         axi_wlast,
    input logic         axi_wvalid,
    output logic        axi_wready,
    
    // Write Response Channel
    output logic [1:0]  axi_bresp,
    output logic        axi_bvalid,
    input logic         axi_bready,
    
    // Read Address Channel (for completeness, minimal support)
    input logic [31:0]  axi_araddr,
    input logic [7:0]   axi_arlen,
    input logic [2:0]   axi_arsize,
    input logic [1:0]   axi_arburst,
    input logic         axi_arvalid,
    output logic        axi_arready,
    
    // Read Data Channel (for completeness, minimal support)
    output logic [31:0] axi_rdata,
    output logic [1:0]  axi_rresp,
    output logic        axi_rlast,
    output logic        axi_rvalid,
    input logic         axi_rready
);

    // Internal memory storage (256 words = 1KB)
    localparam MEM_SIZE = 256;
    logic [31:0] memory [0:MEM_SIZE-1];
    
    // Write Address Channel State
    logic [31:0] write_addr;
    logic [7:0]  write_len;
    logic [2:0]  write_size;
    logic [1:0]  write_burst;
    logic        write_addr_accepted;
    logic [7:0]  write_count;
    logic        write_in_progress;
    
    // Write Data Channel State
    logic        write_data_accepted;
    
    // Write Response Channel State
    logic        write_response_pending;
    logic        write_response_ready;
    
    // Response codes
    localparam [1:0] OKAY   = 2'b00;
    localparam [1:0] EXOKAY = 2'b01;
    localparam [1:0] SLVERR = 2'b10;
    localparam [1:0] DECERR = 2'b11;
    
    // Burst types
    localparam [1:0] FIXED = 2'b00;
    localparam [1:0] INCR  = 2'b01;
    localparam [1:0] WRAP  = 2'b10;
    
    // Initialize memory
    initial begin
        for (int i = 0; i < MEM_SIZE; i++) begin
            memory[i] = 32'h0;
        end
    end
    
    // ============================================
    // Write Address Channel
    // ============================================
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            axi_awready <= 1'b0;
            write_addr_accepted <= 1'b0;
            write_addr <= 32'h0;
            write_len <= 8'h0;
            write_size <= 3'h0;
            write_burst <= 2'h0;
            write_count <= 8'h0;
            write_in_progress <= 1'b0;
        end else begin
            // Accept write address if valid and ready
            if (axi_awvalid && axi_awready && !write_in_progress) begin
                write_addr <= axi_awaddr;
                write_len <= axi_awlen;
                write_size <= axi_awsize;
                write_burst <= axi_awburst;
                write_addr_accepted <= 1'b1;
                write_count <= 8'h0;
                write_in_progress <= 1'b1;
            end
            
            // Control AWREADY - can accept new address when not busy
            if (!write_in_progress && !write_response_pending) begin
                axi_awready <= 1'b1;
            end else if (axi_awvalid && axi_awready) begin
                axi_awready <= 1'b0;
            end
            
            // Reset address accepted flag when write completes
            if (write_response_ready && axi_bvalid && axi_bready) begin
                write_addr_accepted <= 1'b0;
                write_in_progress <= 1'b0;
            end
        end
    end
    
    // ============================================
    // Write Data Channel
    // ============================================
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            axi_wready <= 1'b0;
            write_data_accepted <= 1'b0;
            write_response_pending <= 1'b0;
        end else begin
            // Accept write data if valid and ready
            if (axi_wvalid && axi_wready && write_in_progress) begin
                // Calculate address based on burst type
                logic [31:0] current_addr;
                logic [31:0] addr_offset;
                logic [31:0] byte_size;
                
                byte_size = (1 << write_size); // 2^size bytes
                addr_offset = write_count * byte_size;
                
                case (write_burst)
                    FIXED: current_addr = write_addr;
                    INCR:  current_addr = write_addr + addr_offset;
                    WRAP:  begin
                        // For WRAP, calculate wrap boundary
                        logic [31:0] wrap_boundary;
                        logic [31:0] aligned_addr;
                        aligned_addr = (write_addr >> write_size) << write_size;
                        wrap_boundary = aligned_addr + ((write_len + 1) << write_size);
                        current_addr = aligned_addr + ((write_addr + addr_offset - aligned_addr) % wrap_boundary);
                    end
                    default: current_addr = write_addr;
                endcase
                
                // Write to memory (only if address is within range)
                if (current_addr < (MEM_SIZE * 4)) begin
                    logic [31:0] mem_addr;
                    mem_addr = current_addr >> 2; // Convert byte address to word address
                    
                    // Apply write strobes
                    if (axi_wstrb[0]) memory[mem_addr][7:0]   <= axi_wdata[7:0];
                    if (axi_wstrb[1]) memory[mem_addr][15:8]  <= axi_wdata[15:8];
                    if (axi_wstrb[2]) memory[mem_addr][23:16] <= axi_wdata[23:16];
                    if (axi_wstrb[3]) memory[mem_addr][31:24] <= axi_wdata[31:24];
                end
                
                // Increment write count
                if (axi_wlast) begin
                    write_count <= 8'h0;
                    write_data_accepted <= 1'b1;
                    write_response_pending <= 1'b1;
                end else begin
                    write_count <= write_count + 1;
                end
            end
            
            // Control WREADY - ready when write is in progress and not waiting for response
            if (write_in_progress && !write_response_pending) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
            
            // Reset data accepted flag
            if (write_response_ready && axi_bvalid && axi_bready) begin
                write_data_accepted <= 1'b0;
                write_response_pending <= 1'b0;
            end
        end
    end
    
    // ============================================
    // Write Response Channel
    // ============================================
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp <= OKAY;
            write_response_ready <= 1'b0;
        end else begin
            // Assert BVALID when write data is complete and response is ready
            if (write_response_pending && write_data_accepted && !axi_bvalid) begin
                // Check if address is within range
                if (write_addr < (MEM_SIZE * 4)) begin
                    axi_bresp <= OKAY;
                end else begin
                    axi_bresp <= DECERR; // Address decode error
                end
                axi_bvalid <= 1'b1;
                write_response_ready <= 1'b1;
            end
            
            // Clear BVALID when response is accepted
            if (axi_bvalid && axi_bready) begin
                axi_bvalid <= 1'b0;
                write_response_ready <= 1'b0;
            end
        end
    end
    
    // ============================================
    // Read Address Channel (Basic Support)
    // ============================================
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            axi_arready <= 1'b1;
        end else begin
            // Simple ready signal - can always accept read address
            axi_arready <= 1'b1;
        end
    end
    
    // ============================================
    // Read Data Channel (Basic Support)
    // ============================================
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            axi_rvalid <= 1'b0;
            axi_rdata <= 32'h0;
            axi_rresp <= OKAY;
            axi_rlast <= 1'b0;
        end else begin
            // Basic read support - respond with OKAY and data from memory
            if (axi_arvalid && axi_arready && !axi_rvalid) begin
                logic [31:0] read_addr;
                read_addr = axi_araddr >> 2; // Convert byte address to word address
                if (read_addr < MEM_SIZE) begin
                    axi_rdata <= memory[read_addr];
                    axi_rresp <= OKAY;
                end else begin
                    axi_rdata <= 32'h0;
                    axi_rresp <= DECERR;
                end
                axi_rlast <= 1'b1; // Single beat for now
                axi_rvalid <= 1'b1;
            end
            
            // Clear RVALID when data is accepted
            if (axi_rvalid && axi_rready) begin
                axi_rvalid <= 1'b0;
                axi_rlast <= 1'b0;
            end
        end
    end

endmodule

