#!/bin/bash
# Script to set up HUD format branches and push to GitHub
# Run this in WSL Ubuntu

set -e  # Exit on error

REPO_URL="https://github.com/praveensaravanan30/test3"
PROBLEM_ID="axi4_testbench"

echo "=== Setting up HUD branches for $PROBLEM_ID ==="

# Check if git is initialized
if [ ! -d .git ]; then
    echo "Initializing git repository..."
    git init
    git config user.email "praveensaravanan30@users.noreply.github.com"
    git config user.name "praveensaravanan30"
fi

# Check if remote is set
if ! git remote get-url origin &>/dev/null; then
    echo "Adding remote origin..."
    git remote add origin "$REPO_URL"
fi

# Create complete branch with everything (for development)
echo "Creating complete branch with all files..."
git checkout -b complete 2>/dev/null || git checkout complete
git add -A
git commit -m "Complete solution with tests and golden RTL" || true

# Create baseline branch (incomplete RTL, NO tests)
echo "Creating baseline branch..."
git checkout -b "${PROBLEM_ID}_baseline" 2>/dev/null || git checkout "${PROBLEM_ID}_baseline"
git reset --hard complete

# Remove tests directory completely
rm -rf tests/
git add -A
git commit -m "Baseline: Incomplete RTL, no tests directory" || true

# Create test branch (baseline + tests)
echo "Creating test branch..."
git checkout -b "${PROBLEM_ID}_test" 2>/dev/null || git checkout "${PROBLEM_ID}_test"
git reset --hard "${PROBLEM_ID}_baseline"

# Restore tests from complete branch
git checkout complete -- tests/
git add tests/
git commit -m "Add hidden tests for grading" || true

# Create golden branch (baseline + golden RTL, NO tests)
echo "Creating golden branch..."
git checkout -b "${PROBLEM_ID}_golden" 2>/dev/null || git checkout "${PROBLEM_ID}_golden"
git reset --hard "${PROBLEM_ID}_baseline"

# Copy golden RTL files
cat > sources/axi4_slave.sv << 'GOLDEN_EOF'
// AXI4 Slave Module - Golden RTL
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
GOLDEN_EOF

# Update axi4_top.sv with complete implementation
cat > sources/axi4_top.sv << 'GOLDEN_TOP_EOF'
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
GOLDEN_TOP_EOF

# Verify no tests directory exists
if [ -d tests/ ]; then
    echo "ERROR: Golden branch should not have tests directory!"
    rm -rf tests/
fi

git add sources/
git commit -m "Golden solution - complete RTL implementation, no tests" || true

# Verify all branches
echo ""
echo "=== Verifying branches ==="
for branch in "${PROBLEM_ID}_baseline" "${PROBLEM_ID}_test" "${PROBLEM_ID}_golden"; do
    echo "Checking $branch..."
    git checkout "$branch" &>/dev/null
    echo "  Sources: $(ls sources/*.sv 2>/dev/null | wc -l) files"
    if [ -d tests/ ]; then
        echo "  Tests: $(find tests/ -name '*.py' 2>/dev/null | wc -l) files"
    else
        echo "  Tests: No tests directory (correct)"
    fi
done

# Push all branches to GitHub
echo ""
echo "=== Pushing branches to GitHub ==="
echo "Note: You may need to authenticate with GitHub"
echo ""

# Push each branch
for branch in "${PROBLEM_ID}_baseline" "${PROBLEM_ID}_test" "${PROBLEM_ID}_golden"; do
    echo "Pushing $branch..."
    git push -u origin "$branch" || echo "  Warning: Failed to push $branch (may need authentication)"
done

echo ""
echo "=== Done! ==="
echo "Branches created:"
echo "  - ${PROBLEM_ID}_baseline (incomplete RTL, no tests)"
echo "  - ${PROBLEM_ID}_test (incomplete RTL + tests)"
echo "  - ${PROBLEM_ID}_golden (complete RTL, no tests)"
echo ""
echo "Next steps:"
echo "1. Verify branches on GitHub: $REPO_URL"
echo "2. Test the setup with HUD framework"
echo "3. Register problem in basic.py"

