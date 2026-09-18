class axi4_monitor;

    virtual axi4_if.monitor vif;
    mailbox #(axi4_transaction) m2;
    mailbox #(axi4_transaction) m3;

    function new(virtual axi4_if.monitor vif, 
                 mailbox #(axi4_transaction) m2,
                 mailbox #(axi4_transaction) m3);
        this.vif = vif;
        this.m2  = m2;
        this.m3  = m3;
    endfunction

    task run();
    repeat (5) @(vif.monitor_cb);
        fork begin  repeat (5) @(vif.monitor_cb);
            forever watch_write();
            end
            begin  repeat (5) @(vif.monitor_cb);
            forever watch_read();
            end
        join_none
    endtask

    //==================================================
    // WATCH WRITE (AW + W + B)
    //==================================================
   task watch_write();
    static int call_num = 0;
    axi4_transaction txn;
    int burst_len;

    call_num++; 
    $display("[MONITOR] watch_write() CALL #%0d starting, time=%0t", call_num, $time);

    // Wait for AW handshake on a clock edge
    @(vif.monitor_cb);
    while (!(vif.monitor_cb.awvalid && vif.monitor_cb.awready)) @(vif.monitor_cb);

    // Now signals are stable ? create transaction
    txn            = new();
    txn.is_write   = 1'b1;
    txn.id         = vif.monitor_cb.awid;
    txn.addr       = vif.monitor_cb.awaddr;
    txn.size       = vif.monitor_cb.awsize;
    txn.burst_type = vif.monitor_cb.awburst;

    burst_len = vif.monitor_cb.awlen;
    if (burst_len < 0 || burst_len > 255) begin
        $warning("[MONITOR] Write: Invalid awlen=%0d, clamping to 15", burst_len);
        burst_len = 15;
    end
    txn.len = burst_len;

    txn.data  = new[txn.len + 1];
    txn.wstrb = new[txn.len + 1];
    foreach (txn.data[i])  txn.data[i]  = 32'h0;
    foreach (txn.wstrb[i]) txn.wstrb[i] = 'hF;

    $display("[MONITOR] Write: addr=0x%h, len=%0d, size=%0d, burst=%0d", 
             txn.addr, txn.len, txn.size, txn.burst_type);

    // Capture write data beats
    for (int i = 0; i <= txn.len; i++) begin
        @(vif.monitor_cb);
        while (!(vif.monitor_cb.wvalid && vif.monitor_cb.wready)) @(vif.monitor_cb);

        txn.data[i]  = vif.monitor_cb.wdata;
        txn.wstrb[i] = vif.monitor_cb.wstrb;

        if (vif.monitor_cb.wlast) begin
            $display("[MONITOR] Write: Captured WLAST at beat %0d (len=%0d)", i, txn.len);
            break;
        end
    end

    // Wait for Write Response Handshake
    @(vif.monitor_cb);
    while (!(vif.monitor_cb.bvalid && vif.monitor_cb.bready)) @(vif.monitor_cb);

    txn.bresp = vif.monitor_cb.bresp; 
    $display("[MONITOR] About to m2.put() write txn: addr=0x%h, id=%0d, time=%0t", txn.addr, txn.id, $time);  
    m2.put(txn);
    m3.put(txn);
endtask


    //==================================================
    // WATCH READ (AR + R)
    //==================================================
    task watch_read();
        axi4_transaction txn;
        int burst_len;
        
        // Wait for active Address Read Handshake
        @(vif.monitor_cb);
        while (!(vif.monitor_cb.arvalid && vif.monitor_cb.arready)) begin
            @(vif.monitor_cb);
        end
         
        txn            = new();
        txn.is_write   = 1'b0;
        txn.id         = vif.monitor_cb.arid;
        txn.addr       = vif.monitor_cb.araddr;
        txn.size       = vif.monitor_cb.arsize;
        txn.burst_type = vif.monitor_cb.arburst;
        
        burst_len = vif.monitor_cb.arlen;
        if (burst_len < 0 || burst_len > 255) begin
            $warning("[MONITOR] Read: Invalid arlen=%0d, clamping to 15", burst_len);
            burst_len = 15;
        end
        txn.len = burst_len;
        
        txn.data  = new[txn.len + 1];
        txn.rresp = new[txn.len + 1];

        $display("[MONITOR] Read: addr=0x%h, len=%0d, size=%0d, burst=%0d", 
                 txn.addr, txn.len, txn.size, txn.burst_type);

        // Advance past address handshake cycle
        @(vif.monitor_cb);

        // Capture read data beats
        for (int i = 0; i <= txn.len; i++) begin
            while (!(vif.monitor_cb.rvalid && vif.monitor_cb.rready)) begin
                @(vif.monitor_cb);
            end

            txn.data[i]  = vif.monitor_cb.rdata;
            txn.rresp[i] = vif.monitor_cb.rresp;
            
            $display("[MONITOR] Read: Beat %0d: data=0x%h, resp=%0d, rlast=%0d", 
                     i, txn.data[i], txn.rresp[i], vif.monitor_cb.rlast);
            
            if (vif.monitor_cb.rlast) begin
                $display("[MONITOR] Read: Captured RLAST at beat %0d (expected len=%0d)", i, txn.len);
            end

            @(vif.monitor_cb);
        end

        m2.put(txn);
        m3.put(txn);
    endtask
    
endclass
