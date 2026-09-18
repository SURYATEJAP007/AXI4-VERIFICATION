class axi4_driver;

    axi4_transaction txn;
    mailbox #(axi4_transaction) m1;
    virtual axi4_if.driver vif;
    int count = 1;

    function new(mailbox #(axi4_transaction) m1, virtual axi4_if.driver vif);
        this.vif = vif;
        this.m1  = m1;
    endfunction

    task run();
        forever begin
            m1.get(txn);
            $display("[DRIVER] Starting transaction %0d (is_write=%0d)", count, txn.is_write);
            if (txn.is_write)
                drive_write(txn);
            else
                drive_read(txn);
            count++;
        end
    endtask

    //==================================================
    // WRITE
    //==================================================
    task drive_write(axi4_transaction txn);
        drive_aw(txn);
        drive_w(txn);
        drive_b(txn);
    endtask

    task drive_aw(axi4_transaction txn);
        vif.driver_cb.awid    <= txn.id;
        vif.driver_cb.awaddr  <= txn.addr;
        vif.driver_cb.awlen   <= txn.len;
        vif.driver_cb.awsize  <= txn.size;
        vif.driver_cb.awburst <= txn.burst_type;
        vif.driver_cb.awvalid <= 1'b1;

        do begin
            @(vif.driver_cb);
        end while (!vif.driver_cb.awready);

        vif.driver_cb.awvalid <= 1'b0;
    endtask

    task drive_w(axi4_transaction txn);
        if (txn.wstrb.size() != txn.len + 1)
            txn.wstrb = new[txn.len + 1];

        for (int i = 0; i <= txn.len; i++) begin
            vif.driver_cb.wdata  <= txn.data[i];
            vif.driver_cb.wstrb  <= txn.wstrb[i];
            vif.driver_cb.wlast  <= (i == txn.len);
            vif.driver_cb.wvalid <= 1'b1;

            do begin
                @(vif.driver_cb);
            end while (!vif.driver_cb.wready);

            vif.driver_cb.wvalid <= 1'b0;
            vif.driver_cb.wlast  <= 1'b0;
        end
    endtask

    task drive_b(axi4_transaction txn);
        vif.driver_cb.bready <= 1'b1;

        do begin
            @(vif.driver_cb);
        end while (!vif.driver_cb.bvalid);

        txn.bresp = vif.driver_cb.bresp;
        $display("[DRIVER] Write response captured: bresp=%0d", txn.bresp);

        vif.driver_cb.bready <= 1'b0;
        @(vif.driver_cb); // Ensure bready deassertion is clocked out
    endtask

    //==================================================
    // READ
    //==================================================
    task drive_read(axi4_transaction txn);
        drive_ar(txn);
        drive_r(txn);
    endtask

    task drive_ar(axi4_transaction txn);
        vif.driver_cb.arid    <= txn.id;
        vif.driver_cb.araddr  <= txn.addr;
        vif.driver_cb.arlen   <= txn.len;
        vif.driver_cb.arsize  <= txn.size;
        vif.driver_cb.arburst <= txn.burst_type;
        vif.driver_cb.arvalid <= 1'b1;

        do begin
            @(vif.driver_cb);
        end while (!vif.driver_cb.arready);

        vif.driver_cb.arvalid <= 1'b0;
    endtask

    task drive_r(axi4_transaction txn);
        // Ensure array sizing matches length
        if (txn.data.size() != txn.len + 1)   txn.data  = new[txn.len + 1];
        if (txn.rresp.size() != txn.len + 1)  txn.rresp = new[txn.len + 1];

        // Drive RREADY high before starting sampling loop
        vif.driver_cb.rready <= 1'b1;

        for (int i = 0; i <= txn.len; i++) begin
            do begin
                @(vif.driver_cb);
            end while (!vif.driver_cb.rvalid);

            // Sample data on active clock edge where (RVALID && RREADY) is true
            txn.data[i]  = vif.driver_cb.rdata;
            txn.rresp[i] = vif.driver_cb.rresp;
            txn.rid_seen = vif.driver_cb.rid;

            $display("[DRIVER] Read beat %0d: data=0x%h rresp=%0d rid=%0d",
                     i, txn.data[i], txn.rresp[i], txn.rid_seen);
        end

        // Deassert RREADY after all beats complete
        vif.driver_cb.rready <= 1'b0;
        @(vif.driver_cb); // Ensure rready deassertion is clocked out
    endtask

endclass
