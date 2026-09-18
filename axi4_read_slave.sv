module axi4_read_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter MEM_DEPTH  = 256
) (
    axi4_if.slave bus,
    ref [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1]
);

    typedef enum logic [1:0] {IDLE, SEND_DATA} state_t;
    state_t state;

    localparam BURST_FIXED = 2'b00;
    localparam BURST_INCR  = 2'b01;
    localparam BURST_WRAP  = 2'b10;

    logic [ADDR_WIDTH-1:0] araddr_latched;
    logic [ADDR_WIDTH-1:0] current_addr;
    logic [ID_WIDTH-1:0]   arid_latched;
    logic [1:0]            arburst_latched;
    logic [7:0]             arlen_latched;
    logic [2:0]             arsize_latched;
    logic [7:0]             beat_cnt;

    logic [ADDR_WIDTH-1:0] block_size;
    logic [ADDR_WIDTH-1:0] wrap_boundary_low;
    logic [ADDR_WIDTH-1:0] wrap_boundary_high;

    always_comb begin
        block_size         = (1 << arsize_latched) * (arlen_latched + 1);
        wrap_boundary_low  = araddr_latched & ~(block_size - 1);
        wrap_boundary_high = wrap_boundary_low + block_size;
    end

    logic [ADDR_WIDTH-1:0] next_addr;
    logic [ADDR_WIDTH-1:0] beat_bytes;
    assign beat_bytes = 1 << arsize_latched;

    always_comb begin
        case (arburst_latched)
            BURST_FIXED: next_addr = current_addr;
            BURST_INCR:  next_addr = current_addr + beat_bytes;
            BURST_WRAP:  next_addr = ((current_addr + beat_bytes) >= wrap_boundary_high)
                                        ? wrap_boundary_low
                                        : current_addr + beat_bytes;
            default:     next_addr = current_addr + beat_bytes;
        endcase
    end

    function automatic logic [DATA_WIDTH-1:0] get_read_data(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [2:0] size
    );
        int word_index = (addr >> 2) % MEM_DEPTH;
        logic [DATA_WIDTH-1:0] raw_word = mem[word_index];

        case (size)
            3'b000: begin
                case (addr[1:0])
                    2'b00: return {24'h0, raw_word[7:0]};
                    2'b01: return {16'h0, raw_word[15:8], 8'h0};
                    2'b10: return {8'h0, raw_word[23:16], 16'h0};
                    2'b11: return {raw_word[31:24], 24'h0};
                endcase
            end
            3'b001: begin
                if (addr[1] == 1'b0)
                    return {16'h0, raw_word[15:0]};
                else
                    return {raw_word[31:16], 16'h0};
            end
            3'b010: return raw_word;
            default: return raw_word;
        endcase
    endfunction

    always_ff @(posedge bus.aclk or negedge bus.aresetn) begin
        if (!bus.aresetn) begin
            state           <= IDLE;
            bus.arready     <= 1'b0;
            bus.rvalid      <= 1'b0;
            bus.rlast       <= 1'b0;
            bus.rid         <= '0;
            bus.rdata       <= '0;
            bus.rresp       <= 2'b00;
            araddr_latched  <= '0;
            current_addr    <= '0;
            arid_latched    <= '0;
            arburst_latched <= '0;
            arlen_latched   <= '0;
            arsize_latched  <= '0;
            beat_cnt        <= '0;
        end else begin
            case (state)
                IDLE: begin
                    bus.arready <= 1'b1;
                    bus.rvalid  <= 1'b0;
                    bus.rlast   <= 1'b0;

                    if (bus.arvalid && bus.arready) begin
                        araddr_latched  <= bus.araddr;
                        current_addr    <= bus.araddr;
                        arid_latched    <= bus.arid;
                        arburst_latched <= bus.arburst;
                        arlen_latched   <= bus.arlen;
                        arsize_latched  <= bus.arsize;
                        beat_cnt        <= '0;

                        bus.rid    <= bus.arid;
                        bus.rdata  <= get_read_data(bus.araddr, bus.arsize);
                        bus.rresp  <= 2'b00;
                        bus.rlast  <= (bus.arlen == 0);

                        bus.arready <= 1'b0;
                        bus.rvalid  <= 1'b1;
                        state       <= SEND_DATA;

                        $display("[READ_SLAVE] Read burst accepted: addr=0x%h, len=%0d, size=%0d",
                                 bus.araddr, bus.arlen, bus.arsize);
                    end
                end

                SEND_DATA: begin
                    if (bus.rvalid && bus.rready) begin
                        if (beat_cnt == arlen_latched) begin
                            bus.rvalid  <= 1'b0;
                            bus.rlast   <= 1'b0;
                            bus.arready <= 1'b1;
                            state       <= IDLE;
                            $display("[READ_SLAVE] Read burst complete (beats transferred: %0d)", beat_cnt + 1);
                        end else begin
                            automatic logic [ADDR_WIDTH-1:0] n_addr = next_addr;
                            current_addr <= n_addr;
                            beat_cnt     <= beat_cnt + 1;

                            bus.rdata <= get_read_data(n_addr, arsize_latched);
                            bus.rlast <= ((beat_cnt + 1) == arlen_latched);

                            $display("[READ_SLAVE] Beat %0d: addr=0x%h", beat_cnt + 1, n_addr);
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
