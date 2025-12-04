AXI4 Documentation

Overview

AXI4 (Advanced eXtensible Interface 4) is an industry-standard bus protocol developed by ARM as part of the AMBA (Advanced Microcontroller Bus Architecture) specification. AXI4 defines high-performance, high-frequency communication between master and slave components in system-on-chip (SoC) designs. It provides point-to-point interconnect and supports multiple outstanding transactions, separate read and write channels, and robust data transfer for quick response times. It is widely adopted in the design of modern FPGAs, ASICs, and processors to interface memory, peripherals, and custom logic.

AXI4 transactions are burst-based, allowing the transfer of multiple data items in a single transaction and improving throughput while minimizing bus overhead. Each AXI4 interface consists of independent read and write data channels with their associated address, control, and response signals.

Functionality

AXI4 Protocol Channels

AXI4 works through five independent unidirectional channels, each responsible for transmitting different types of information:

1. Write Address Channel (AW): Carries the address and control information for write transactions.
2. Write Data Channel (W): Transports the actual write data.
3. Write Response Channel (B): Carries the response signal from slave to master for write operations.
4. Read Address Channel (AR): Carries the address and control information for read transactions.
5. Read Data Channel (R): Carries the read data and response information.

Each channel uses a valid-ready handshake (VALID and READY signals) to synchronize data transfer, ensuring reliable communication regardless of clock frequency or variation in slave/master response times.

AXI4 Write Transaction

A typical AXI4 write transaction proceeds as follows:

1. The master asserts AWVALID and provides the write address and control information on the AW channel.
2. When the slave is ready, it asserts AWREADY. Once both AWVALID and AWREADY are high, the address is accepted.
3. The master asserts WVALID and provides the write data on the W channel.
4. When the slave is ready, it asserts WREADY. On both WVALID and WREADY high, data is accepted.
5. After the last data item in the burst, WLAST is asserted.
6. The slave provides a write response on the B channel, asserting BVALID along with a response code.
7. The master asserts BREADY to acknowledge receipt of the response, completing the write transaction.

AXI4 Read Transaction

A typical AXI4 read transaction follows these steps:

1. The master asserts ARVALID and provides the read address and control information on the AR channel.
2. When the slave is ready, it asserts ARREADY. Both ARVALID and ARREADY high indicate that the address is accepted.
3. The slave transmits the read data on the R channel, asserting RVALID and providing data and response codes.
4. The master asserts RREADY when it is able to receive data.
5. For burst transfers, the slave asserts RLAST with the last data item.

Burst Type and Length

AXI4 supports burst transfers, allowing the master to specify a sequence of data transfers with a single address phase. Each burst can be:

- FIXED: Address remains constant for every data transfer.
- INCR: Address increments after each data transfer.
- WRAP: Address wraps around at the boundary of a defined length.

The burst length field specifies how many data transfers are in the burst (up to 256 beats).

AXI4 Signal Summary

For each channel, key signals include:

- AWADDR/ARADDR: Address of the first data transfer in a burst.
- AWLEN/ARLEN: Number of transfers in a burst.
- AWSIZE/ARSIZE: Size of each data transfer (bytes per beat).
- AWBURST/ARBURST: Burst type (fixed, incrementing, or wrapping).
- WDATA/RDATA: Write and read data.
- WSTRB: Write strobes to indicate valid data bytes.
- WLAST/RLAST: Signal last transfer in the burst.
- BRESP/RRESP: Response codes indicating success or errors.

AXI4 ensures high throughput due to the use of independent channels and pipelined handshakes. It allows for multiple transactions to be outstanding simultaneously (out-of-order completion is supported when IDs are used). The protocol also supports quality-of-service (QoS) signaling, cache and protection options, and user-defined signals for custom extensions.

Working Example

Write Transaction Example

Let us consider a write transaction where an AXI4 master writes four 32-bit words starting at address 0x1000_0000 using an INCR burst:

- AWADDR = 0x1000_0000
- AWLEN = 3 (for 4 transfers; length is zero-based)
- AWSIZE = 2 (indicating 4 bytes per transfer)
- AWBURST = INCR

Step-by-step waveform:

1. Master presents AWADDR, AWLEN, AWSIZE, AWBURST with AWVALID.
2. Slave asserts AWREADY. Address transfer completes (AWVALID & AWREADY high).
3. For each of the four data words:
    - Master presents WDATA, sets WVALID.
    - After each transfer, slave asserts WREADY.
    - On the last transfer (fourth word), master sets WLAST high.
4. Slave provides write response on B channel with BVALID and a response code (e.g., OKAY).
5. Master acknowledges with BREADY. Write completed.

Read Transaction Example

Now, consider a single 32-bit word read at address 0x2000_0000:

- ARADDR = 0x2000_0000
- ARLEN = 0 (single transfer)
- ARSIZE = 2

Procedure:

1. Master asserts ARVALID, ARADDR with appropriate control signals.
2. Slave asserts ARREADY. Address handshake completes.
3. Slave presents read data on RDATA, asserts RVALID.
4. Master asserts RREADY, receives the data.
5. As this is a single-beat read, RLAST is high with this data.
6. Read completes with a normal response (RRESP = OKAY).

Summary

AXI4 is a powerful, flexible, and robust protocol for use in high-throughput, low-latency SoC components. By supporting burst transactions, pipelined operations, and multiple outstanding transfers, it is highly suited for modern SoC communication and memory interfaces. Careful attention should be paid to the handshake signaling and burst configuration to ensure interoperability and performance in AXI4-based designs.

