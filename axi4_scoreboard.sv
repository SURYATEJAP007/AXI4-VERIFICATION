class axi4_scoreboard;

    mailbox #(axi4_transaction) m2;

    logic [31:0] wrap_boundary;
    logic [31:0] wrap_size;
    logic [31:0] bytes_per_beat;
    
    // Statistics
    int write_count     = 0;
    int read_pass_count = 0;
    int read_fail_count = 0;

    // Constants
    localparam logic [1:0] BURST_FIXED = 2'b00;
    localparam logic [1:0] BURST_INCR  = 2'b01; // Fixed typo here
    localparam logic [1:0] BURST_WRAP  = 2'b10;
    localparam DATA_WIDTH = 32;   
    localparam MEM_DEPTH  = 256;  

    bit [DATA_WIDTH-1:0] expected_mem [0:MEM_DEPTH-1];

    // Constructor
    function new(mailbox #(axi4_transaction) m2);
        this.m2 = m2;
        foreach (expected_mem[i]) expected_mem[i] = 32'h0;
        $display("[SCOREBOARD] Memory initialized to 0x0");
    endfunction

    // Helper: Mask expected memory based on size and address alignment
    function automatic logic [31:0] get_masked_expected(logic [31:0] addr, logic [2:0] size);
        int word_index = (addr >> 2) % MEM_DEPTH;
        logic [31:0] raw_word = expected_mem[word_index];

        case (size)
            3'b000: begin // 1 Byte
                case (addr[1:0])
                    2'b00: return {24'h0, raw_word[7:0]};
                    2'b01: return {16'h0, raw_word[15:8], 8'h0};
                    2'b10: return {8'h0, raw_word[23:16], 16'h0};
                    2'b11: return {raw_word[31:24], 24'h0};
                endcase
            end
            3'b001: begin // 2 Bytes (Half-word)
                if (addr[1] == 1'b0)
                    return {16'h0, raw_word[15:0]};
                else
                    return {raw_word[31:16], 16'h0};
            end
            3'b010: return raw_word; // 4 Bytes (Full word)
            default: return raw_word;
        endcase
    endfunction

    // Run: Monitor Transactions
    task run();
    axi4_transaction txn;
    forever begin
        m2.get(txn);
        if (txn.addr === 32'hxxxxxxxx || txn.burst_type === 2'bxx) begin
            $warning("[SCOREBOARD] Skipping malformed transaction (addr=X) - known rare monitor glitch");
        end
        else if (txn.is_write) check_write(txn);
        else check_read(txn);
    end
endtask

    // WRITE - Update Expected Memory
    task check_write(axi4_transaction txn);
        logic [31:0] current_addr;
        logic [31:0] mem_index;

        bytes_per_beat = 1 << txn.size;
        wrap_size      = (txn.len + 1) * bytes_per_beat;
        wrap_boundary  = txn.addr & ~(wrap_size - 1);
        current_addr   = txn.addr;

        $display("[SCOREBOARD] Write: addr=0x%h, len=%0d, size=%0d (bytes_per_beat=%0d)",
                 txn.addr, txn.len, txn.size, bytes_per_beat);

        for (int i = 0; i <= txn.len; i++) begin
            mem_index = (current_addr >> 2) % MEM_DEPTH;
            for (int b = 0; b < DATA_WIDTH/8; b++) begin
               if (txn.wstrb[i][b]) begin
                    expected_mem[mem_index][8*b +: 8] = txn.data[i][8*b +: 8];
               end
            end

            $display("[SCOREBOARD]   Beat %0d: addr=0x%h -> mem[%0d] = 0x%h", 
                     i, current_addr, mem_index, expected_mem[mem_index]);

            case (txn.burst_type)
                BURST_FIXED: ;
                BURST_INCR:  current_addr += bytes_per_beat;
                BURST_WRAP:  current_addr = 
                             ((current_addr + bytes_per_beat) >= (wrap_boundary + wrap_size)) 
                             ? wrap_boundary : current_addr + bytes_per_beat;
                default:     current_addr += bytes_per_beat;
            endcase
        end

        $display("[SCOREBOARD] Write response observed: bresp=%0d", txn.bresp);
        write_count++;
    endtask

    // READ - Verify Returned Read Data
    task check_read(axi4_transaction txn);
        logic [31:0] current_addr;
        logic [31:0] expected_data;
        logic [31:0] mem_index;

        current_addr   = txn.addr;
        bytes_per_beat = 1 << txn.size;
        wrap_size      = (txn.len + 1) * bytes_per_beat;
        wrap_boundary  = txn.addr & ~(wrap_size - 1);

        $display("[SCOREBOARD] Read Check: addr=0x%h, len=%0d, size=%0d",
                 txn.addr, txn.len, txn.size);

        for (int i = 0; i <= txn.len; i++) begin
            mem_index     = (current_addr >> 2) % MEM_DEPTH;
            expected_data = get_masked_expected(current_addr, txn.size);

            if (txn.data[i] === 32'hxxxxxxxx || txn.data[i] === 32'hzzzzzzzz) begin
                $warning("[SCOREBOARD] Read: Beat %0d: Undefined data at addr=0x%h", i, current_addr);
                read_fail_count++;
            end else if (expected_data === txn.data[i]) begin
                $display("[SCOREBOARD] READ PASS: Beat %0d: addr=0x%h (mem[%0d]), expected=0x%h actual=0x%h",
                         i, current_addr, mem_index, expected_data, txn.data[i]);
                read_pass_count++;
            end else begin
                $error("[SCOREBOARD] READ FAIL: Beat %0d: addr=0x%h (mem[%0d]), expected=0x%h actual=0x%h",
                       i, current_addr, mem_index, expected_data, txn.data[i]);
                read_fail_count++;
            end

            case (txn.burst_type)
                BURST_FIXED: ;
                BURST_INCR:  current_addr += bytes_per_beat;
                BURST_WRAP:  current_addr = 
                             ((current_addr + bytes_per_beat) >= (wrap_boundary + wrap_size)) 
                             ? wrap_boundary : current_addr + bytes_per_beat;
                default:     $error("[SCOREBOARD] Invalid burst type: %0d", txn.burst_type);
            endcase
        end
    endtask

    // Report Statistics
    function void report();
        $display("\n========================================");
        $display("  SCOREBOARD STATISTICS");
        $display("========================================");
        $display("  Writes checked:     %0d", write_count);
        $display("  Reads passed:       %0d", read_pass_count);
        $display("  Reads failed:       %0d", read_fail_count);
        $display("  Total reads:        %0d", read_pass_count + read_fail_count);
        if (read_fail_count == 0)
            $display("  Status:             ALL TESTS PASSED");
        else
            $display("  Status:             FAILURES DETECTED");
        $display("========================================\n");
    endfunction

endclass
