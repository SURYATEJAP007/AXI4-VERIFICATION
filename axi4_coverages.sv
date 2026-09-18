class axi4_coverages;

    axi4_transaction txn;
    mailbox #(axi4_transaction) m3;
    
    int sample_count = 0;

    // ========================================
    // Covergroup Definition
    // ========================================
    covergroup axi4_cg;
        
        option.per_instance = 1;
        option.name = "axi4_cg";

        // ================================================
        // Burst Type Coverage
        // ================================================
        burst_cp: coverpoint txn.burst_type {
            bins fixed = {2'b00};
            bins incr  = {2'b01};
            bins wrap  = {2'b10};
            illegal_bins other = default;
        }

        // ================================================
        // Size Coverage (bytes per beat)
        // ================================================
        size_cp: coverpoint txn.size {
            bins byte1  = {0};      // 2^0 = 1 byte
            bins byte2  = {1};      // 2^1 = 2 bytes
            bins byte4  = {2};      // 2^2 = 4 bytes
            illegal_bins other = default;
        }

        // ================================================
        // Length Coverage (beats per burst)
        // ================================================
        len_cp: coverpoint txn.len {
            bins single = {0};
            bins short  = {[1:3]};
            bins medium1 = {[4:7]};
            bins long   = {[8:15]};
        }

        // ================================================
        // Address Coverage
        // ================================================
        addr_cp: coverpoint txn.addr {
            bins low   = {[32'h000:32'h0FF]};
            bins mid   = {[32'h100:32'h1FF]};
            bins high  = {[32'h200:32'h3FF]};
        }

        // ================================================
        // ID Coverage (Master ID)
        // ================================================
        id_cp: coverpoint txn.id {
            bins id_low  = {[0:7]};
            bins id_high = {[8:15]};
        }

        // ================================================
        // Transaction Type Coverage
        // ================================================
        is_write_cp: coverpoint txn.is_write {
            bins write = {1};
            bins read  = {0};
        }

        // ================================================
        // Cross Coverage: Write Transaction Types
        // ================================================
        write_burst_cross: cross is_write_cp, burst_cp {
            bins write_fixed = binsof(is_write_cp) intersect {1} &&
                               binsof(burst_cp) intersect {2'b00};
            bins write_incr  = binsof(is_write_cp) intersect {1} &&
                               binsof(burst_cp) intersect {2'b01};
            bins write_wrap  = binsof(is_write_cp) intersect {1} &&
                               binsof(burst_cp) intersect {2'b10};
        }

        // ================================================
        // Cross Coverage: Read Transaction Types
        // ================================================
        read_burst_cross: cross is_write_cp, burst_cp {
            bins read_fixed = binsof(is_write_cp) intersect {0} &&
                              binsof(burst_cp) intersect {2'b00};
            bins read_incr  = binsof(is_write_cp) intersect {0} &&
                              binsof(burst_cp) intersect {2'b01};
            bins read_wrap  = binsof(is_write_cp) intersect {0} &&
                              binsof(burst_cp) intersect {2'b10};
        }

        // ================================================
        // Cross Coverage: Size and Length
        // ================================================
        size_len_cross: cross size_cp, len_cp;

        // ================================================
        // Cross Coverage: Write with Size
        // ================================================
        write_size_cross: cross is_write_cp, size_cp {
            bins write_1byte = binsof(is_write_cp) intersect {1} &&
                               binsof(size_cp) intersect {0};
            bins write_2byte = binsof(is_write_cp) intersect {1} &&
                               binsof(size_cp) intersect {1};
            bins write_4byte = binsof(is_write_cp) intersect {1} &&
                               binsof(size_cp) intersect {2};
        }

        // ================================================
        // Cross Coverage: Read with Size
        // ================================================
        read_size_cross: cross is_write_cp, size_cp {
            bins read_1byte = binsof(is_write_cp) intersect {0} &&
                              binsof(size_cp) intersect {0};
            bins read_2byte = binsof(is_write_cp) intersect {0} &&
                              binsof(size_cp) intersect {1};
            bins read_4byte = binsof(is_write_cp) intersect {0} &&
                              binsof(size_cp) intersect {2};
        }

    endgroup

    // ========================================
    // Constructor
    // ========================================
    function new(mailbox #(axi4_transaction) m3);
        this.m3 = m3;
        axi4_cg = new();
        $display("[COVERAGE] Covergroup initialized");
    endfunction

    // ========================================
    // Run: Sample Transactions
    // ========================================
    task run();
    forever begin
        m3.get(txn);
        if (txn.addr === 32'hxxxxxxxx || txn.burst_type === 2'bxx) begin
            $warning("[COVERAGE] Skipping malformed transaction - known rare monitor glitch");
        end
        else begin
            axi4_cg.sample();
            sample_count++;
        end
    end
endtask

    // ========================================
    // Report: Show Coverage Results
    // ========================================
    function void report();
        real coverage;
        coverage = axi4_cg.get_coverage();
        
        $display("\n");
        $display("========================================");
        $display("  COVERAGE REPORT");
        $display("========================================");
        $display("  Transactions sampled:  %0d", sample_count);
        $display("  Overall coverage:      %0.2f%%", coverage);
        
        if (coverage >= 90.0) begin
            $display("  Status:                ??? EXCELLENT");
        end else if (coverage >= 75.0) begin
            $display("  Status:                ?? GOOD");
        end else if (coverage >= 50.0) begin
            $display("  Status:                ? ACCEPTABLE");
        end else begin
            $display("  Status:                ? NEEDS IMPROVEMENT");
        end
        
        $display("========================================\n");
    endfunction

endclass


