class axi4_generator;

    // ========================================
    // Mailbox
    // ========================================
    mailbox #(axi4_transaction) m1;

    int transaction_count;
    int num_txns;


    // ========================================
    // Store previous WRITE transactions
    // ========================================
    static axi4_transaction written_txns[$];


    // ========================================
    // Constructor
    // ========================================
    function new(mailbox #(axi4_transaction) m1);

        this.m1 = m1;

        transaction_count = 0;
        num_txns = 0;

    endfunction


    // ========================================
    // Generator
    // ========================================
    task run_generator();

        axi4_transaction txn;

        int idx;


        $display("[GENERATOR] Starting to generate 50 transactions");


        repeat (50) begin

            txn = new();


            // ==================================================
            // No previous write exists
            // ==================================================
            // Read is not allowed yet.
            // Force WRITE.
            // ==================================================

            if (written_txns.size() == 0) begin

                assert(
                    txn.randomize() with {
                        is_write == 1;
                    }
                )
                else begin
                    $fatal("[GENERATOR] WRITE randomization failed");
                end

            end


            // ==================================================
            // Previous WRITE transactions exist
            // ==================================================

            else begin


                // Randomly choose WRITE or READ
                if ($urandom_range(0,1) == 1) begin


                    // ==========================================
                    // Generate new RANDOM WRITE
                    // ==========================================

                    assert(
                        txn.randomize() with {
                            is_write == 1;
                            len inside {[1:15]};          // no zero-length bursts
                            size inside {[0:2]};          // 1,2,4 bytes per beat (expand if needed)
                            burst_type inside {0,1,2};    // FIXED, INCR, WRAP
                        }
                    )
                    else begin
                        $fatal("[GENERATOR] WRITE randomization failed");
                    end

                end


                else begin


                    // ==========================================
                    // Generate READ from an OLD WRITE
                    // ==========================================

                    idx = $urandom_range(
                        0,
                        written_txns.size()-1
                    );


                    // This is a READ
                    txn.is_write = 0;


                    // ------------------------------------------
                    // Take burst information from previous write
                    // ------------------------------------------

                    txn.addr =
                        written_txns[idx].addr;

                    txn.len =
                        written_txns[idx].len;

                    txn.size =
                        written_txns[idx].size;

                    txn.burst_type =
                        written_txns[idx].burst_type;


                    // ID can be newly selected
                    txn.id =
                        $urandom_range(0,15);


                    // ------------------------------------------
                    // Allocate arrays required for READ
                    // ------------------------------------------

                    txn.data =
                        new[txn.len + 1];

                    txn.rresp =
                        new[txn.len + 1];


                    $display(
                        "[GENERATOR] READ selected from stored WRITE[%0d]",
                        idx
                    );

                    $display(
                        "[GENERATOR] READ: addr=0x%08h len=%0d size=%0d burst=%0d",
                        txn.addr,
                        txn.len,
                        txn.size,
                        txn.burst_type
                    );

                end

            end


            // ==================================================
            // WRITE transaction
            // ==================================================

            if (txn.is_write) begin


                // Data and wstrb have already been generated
                // by post_randomize().


                foreach (txn.data[i]) begin

                    $display(
                        "[GENERATOR] Beat %0d: data=0x%08h wstrb=%b",
                        i,
                        txn.data[i],
                        txn.wstrb[i]
                    );

                end


                // ----------------------------------------------
                // Store this WRITE transaction
                // ----------------------------------------------

                written_txns.push_back(txn);


                $display(
                    "[GENERATOR] Stored WRITE[%0d]: addr=0x%08h len=%0d size=%0d burst=%0d",
                    written_txns.size()-1,
                    txn.addr,
                    txn.len,
                    txn.size,
                    txn.burst_type
                );

            end


            // ==================================================
            // Transaction count
            // ==================================================

            transaction_count++;
            num_txns++;


            // ==================================================
            // Display transaction
            // ==================================================

            $display(
                "[GENERATOR] Transaction [%0d]: len=%0d size=%0d burst=%0d addr=0x%08h is_write=%0d",
                transaction_count,
                txn.len,
                txn.size,
                txn.burst_type,
                txn.addr,
                txn.is_write
            );


            // ==================================================
            // Send to driver
            // ==================================================

            m1.put(txn);

        end


        $display(
            "[GENERATOR] All %0d transactions generated successfully",
            transaction_count
        );

    endtask

endclass
