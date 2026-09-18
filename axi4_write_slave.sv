module axi4_write_slave_burst #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter MEM_DEPTH  = 256
) (
    axi4_if.slave bus,
    ref [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1]
);

    // ========================================
    // Types and Constants
    // ========================================
    typedef enum logic [1:0] {IDLE, WAIT_DATA, WAIT_RESP} state_t;
    state_t state;

    localparam BURST_FIXED = 2'b00;
    localparam BURST_INCR  = 2'b01;
    localparam BURST_WRAP  = 2'b10;

    // ========================================
    // Latched Address Channel Signals
    // ========================================
    logic [ADDR_WIDTH-1:0] awaddr_latched;   
    logic [ADDR_WIDTH-1:0] current_addr;     
    logic [ID_WIDTH-1:0]   awid_latched;
    logic [1:0]            awburst_latched;
    logic [7:0]            awlen_latched;
    logic [2:0]            awsize_latched;

    // ========================================
    // Wrap Boundary Calculations
    // ========================================
    logic [ADDR_WIDTH-1:0] block_size;
    logic [ADDR_WIDTH-1:0] wrap_boundary_low;
    logic [ADDR_WIDTH-1:0] wrap_boundary_high;

    always_comb begin
        block_size         = (1 << awsize_latched) * (awlen_latched + 1);
        wrap_boundary_low  = awaddr_latched & ~(block_size - 1);
        wrap_boundary_high = wrap_boundary_low + block_size;
    end

    // ========================================
    // Memory Initialization
    // ========================================
    initial begin
        for (int i = 0; i < MEM_DEPTH; i++) begin
            mem[i] = 32'h0;
        end
        $display("[WRITE_SLAVE] Memory initialized to 0x0");
    end

    // ========================================
    // Main State Machine
    // ========================================
    always @(posedge bus.aclk or negedge bus.aresetn) begin
        if (!bus.aresetn) begin
            // Reset all signals
            state           <= IDLE;
            bus.awready     <= 1'b0;
            bus.wready      <= 1'b0;
            bus.bvalid      <= 1'b0;
            bus.bresp       <= 2'b00;
            bus.bid         <= '0;
            awaddr_latched  <= '0;
            current_addr    <= '0;
            awid_latched    <= '0;
            awburst_latched <= '0;
            awlen_latched   <= '0;
            awsize_latched  <= '0;
        end 
        else begin
            case (state)

                // ================================================
                // IDLE: Wait for Write Address
                // ================================================
                IDLE: begin
                    bus.awready <= 1'b1;
                    bus.wready  <= 1'b0;
                    
                    if (bus.awvalid && bus.awready) begin
                        // Latch address channel signals
                        awaddr_latched  <= bus.awaddr;
                        current_addr    <= bus.awaddr;
                        awid_latched    <= bus.awid;
                        awburst_latched <= bus.awburst;
                        awlen_latched   <= bus.awlen;
                        awsize_latched  <= bus.awsize;
                        
                        // Deassert ready and move to data phase
                        bus.awready <= 1'b0;
                        state       <= WAIT_DATA;
                        
                        $display("[WRITE_SLAVE] Write burst accepted: addr=0x%h, len=%0d, size=%0d", 
                                 bus.awaddr, bus.awlen, bus.awsize);
                    end
                end

                // ================================================
                // WAIT_DATA: Receive Write Data
                // ================================================
                WAIT_DATA: begin
                    bus.wready <= 1'b1;
                    
                    if (bus.wvalid && bus.wready) begin
                        // ? Write only enabled bytes (bytestrobe)
                        for (int b = 0; b < DATA_WIDTH/8; b++) begin
                            if (bus.wstrb[b])
                                mem[(current_addr >> 2) % MEM_DEPTH][8*b +: 8] <= bus.wdata[8*b +: 8];
                        end
                        
                        $display("[WRITE_SLAVE]   Beat: addr=0x%h, data=0x%h, wlast=%0d", 
                                 current_addr, bus.wdata, bus.wlast);
                        
                        if (bus.wlast) begin
                            // ? Last beat received, prepare response
                            bus.wready  <= 1'b0;
                            bus.bvalid  <= 1'b1;
                            bus.bresp   <= 2'b00;  // OKAY response
                            bus.bid     <= awid_latched;
                            state       <= WAIT_RESP;
                            
                            $display("[WRITE_SLAVE] Write burst complete, sending response");
                        end 
                        else begin
                            // ? More beats coming, increment address
                            case (awburst_latched)
                                BURST_FIXED: begin
                                    current_addr <= current_addr;
                                end
                                
                                BURST_INCR: begin
                                    current_addr <= current_addr + (1 << awsize_latched);
                                end
                                
                                BURST_WRAP: begin
                                    if ((current_addr + (1 << awsize_latched)) >= wrap_boundary_high)
                                        current_addr <= wrap_boundary_low;
                                    else
                                        current_addr <= current_addr + (1 << awsize_latched);
                                end
                                
                                default: begin
                                    current_addr <= current_addr + (1 << awsize_latched);
                                end
                            endcase
                            
                            state <= WAIT_DATA;
                        end
                    end
                end

                // ================================================
                // WAIT_RESP: Send Write Response
                // ================================================
                WAIT_RESP: begin
                    if (bus.bvalid && bus.bready) begin
                        // ? Response acknowledged, return to IDLE
                        bus.bvalid <= 1'b0;
                        state      <= IDLE;
                        
                        $display("[WRITE_SLAVE] Response acknowledged, ready for next burst\n");
                    end
                end

                // ================================================
                // Default: Safety
                // ================================================
                default: state <= IDLE;
            endcase
        end
    end

endmodule