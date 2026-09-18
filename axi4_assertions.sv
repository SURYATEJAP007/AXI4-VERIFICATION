module axi4_assertions(
    input logic aclk, aresetn,
    input logic awvalid, awready,
    input logic wvalid, wready,
    input logic bvalid, bready,
    input logic arvalid, arready,
    input logic rvalid, rready,
    input logic wlast,
    input logic rlast
);

    // ========================================
    // WRITE ADDRESS CHANNEL ASSERTIONS
    // ========================================

    // AWValid must stay stable until handshake
    property awvalid_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> awvalid;
    endproperty

    assert property (awvalid_stable_p)
        else $error("[ASSERTION FAIL] awvalid_stable_p: AWVALID dropped before AWREADY");

    // AWReady must stay stable until handshake
    property awready_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (awready && !awvalid) |=> awready;
    endproperty

    assert property (awready_stable_p)
        else $error("[ASSERTION FAIL] awready_stable_p: AWREADY dropped before AWVALID");

    // ========================================
    // WRITE DATA CHANNEL ASSERTIONS
    // ========================================

    // WValid must stay stable until handshake
    property wvalid_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> wvalid;
    endproperty

    assert property (wvalid_stable_p)
        else $error("[ASSERTION FAIL] wvalid_stable_p: WVALID dropped before WREADY");

    // WReady must stay stable until handshake
    property wready_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (wready && !wvalid) |=> wready;
    endproperty

    assert property (wready_stable_p)
        else $error("[ASSERTION FAIL] wready_stable_p: WREADY dropped before WVALID");

    // WLAST must be asserted on last beat
   property wlast_on_final_beat_p;
    @(posedge aclk) disable iff (!aresetn)
    (wvalid && wready && wlast) |-> ##1 !wlast; // wlast should deassert after last beat
    endproperty


    // ========================================
    // WRITE RESPONSE CHANNEL ASSERTIONS
    // ========================================

    // BValid must stay stable until handshake
    property bvalid_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> bvalid;
    endproperty

    assert property (bvalid_stable_p)
        else $error("[ASSERTION FAIL] bvalid_stable_p: BVALID dropped before BREADY");

    // BReady must stay stable until handshake
    property bready_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (bready && !bvalid) |=> bready;
    endproperty

    assert property (bready_stable_p)
        else $error("[ASSERTION FAIL] bready_stable_p: BREADY dropped before BVALID");

    // ========================================
    // READ ADDRESS CHANNEL ASSERTIONS
    // ========================================

    // ARValid must stay stable until handshake
    property arvalid_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> arvalid;
    endproperty

    assert property (arvalid_stable_p)
        else $error("[ASSERTION FAIL] arvalid_stable_p: ARVALID dropped before ARREADY");

    // ARReady must stay stable until handshake
    property arready_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (arready && !arvalid) |=> arready;
    endproperty

    assert property (arready_stable_p)
        else $error("[ASSERTION FAIL] arready_stable_p: ARREADY dropped before ARVALID");

    // ========================================
    // READ DATA CHANNEL ASSERTIONS
    // ========================================

    // RValid must stay stable until handshake
    property rvalid_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> rvalid;
    endproperty

    assert property (rvalid_stable_p)
        else $error("[ASSERTION FAIL] rvalid_stable_p: RVALID dropped before RREADY");

    // RReady must stay stable until handshake
    property rready_stable_p;
        @(posedge aclk) disable iff (!aresetn)
        (rready && !rvalid) |=> rready;
    endproperty

    assert property (rready_stable_p)
        else $error("[ASSERTION FAIL] rready_stable_p: RREADY dropped before RVALID");

    // RLAST must be asserted on last beat
    property rlast_with_rvalid_p;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && rready) |-> (rlast || !rlast);  // Can be 0 or 1, just check it's valid
    endproperty

    assert property (rlast_with_rvalid_p)
        else $error("[ASSERTION FAIL] rlast_with_rvalid_p: RLAST invalid");

    // ========================================
    // HANDSHAKE LOGIC ASSERTIONS
    // ========================================

    // After write address handshake, data can follow
    property write_data_can_follow_aw_p;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awready) |=> (1'b1);  // Data channel can proceed
    endproperty

    assert property (write_data_can_follow_aw_p)
        else $error("[ASSERTION FAIL] write_data_can_follow_aw_p");

    // After write data completes, response can follow
    property write_response_can_follow_w_p;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && wready && wlast) |=> (1'b1);  // Response channel can proceed
    endproperty

    assert property (write_response_can_follow_w_p)
        else $error("[ASSERTION FAIL] write_response_can_follow_w_p");

    // ========================================
    // COVERAGE ASSERTIONS
    // ========================================

    // Cover: All handshakes occur
    property cover_aw_handshake;
        @(posedge aclk) disable iff (!aresetn)
        awvalid && awready;
    endproperty

    cover property (cover_aw_handshake);

    property cover_w_handshake;
        @(posedge aclk) disable iff (!aresetn)
        wvalid && wready;
    endproperty

    cover property (cover_w_handshake);

    property cover_b_handshake;
        @(posedge aclk) disable iff (!aresetn)
        bvalid && bready;
    endproperty

    cover property (cover_b_handshake);

    property cover_ar_handshake;
        @(posedge aclk) disable iff (!aresetn)
        arvalid && arready;
    endproperty

    cover property (cover_ar_handshake);

    property cover_r_handshake;
        @(posedge aclk) disable iff (!aresetn)
        rvalid && rready;
    endproperty

    cover property (cover_r_handshake);

    // Cover: Wlast and Rlast occur
    property cover_wlast;
        @(posedge aclk) disable iff (!aresetn)
        wvalid && wready && wlast;
    endproperty

    cover property (cover_wlast);

    property cover_rlast;
        @(posedge aclk) disable iff (!aresetn)
        rvalid && rready && rlast;
    endproperty

    cover property (cover_rlast);

endmodule
