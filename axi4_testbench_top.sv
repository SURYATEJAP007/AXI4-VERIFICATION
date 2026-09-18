`include "axi4_environment.sv"


module axi4_tb;

    // ========================================
    // Clock and Reset
    // ========================================
    logic aclk;
    logic aresetn;

    // Interface instance
    axi4_if vif(aclk, aresetn);

    // Environment instance
    axi4_environment env;

    // Slave models
   axi4_slave_wrapper dut (
    .bus(vif.slave)
);


    // ========================================
    // Assertions Binding
    // ========================================
    bind axi4_if axi4_assertions u_assertions (
    .aclk    (aclk),
    .aresetn (aresetn),
    .awvalid (vif.awvalid), .awready (vif.awready),
    .wvalid  (vif.wvalid),  .wready  (vif.wready), .wlast(vif.wlast),
    .bvalid  (vif.bvalid),  .bready  (vif.bready),
    .arvalid (vif.arvalid), .arready (vif.arready),
    .rvalid  (vif.rvalid),  .rready  (vif.rready), .rlast(vif.rlast)
   );


    // ========================================
    // Clock Generation
    // ========================================
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk; // 100 MHz
    end

    // ========================================
    // Reset Sequence
    // ========================================
    initial begin
        aresetn = 0;
        repeat(10) @(posedge aclk);
        aresetn = 1;
    end

    // ========================================
    // Testbench Control
    // ========================================
    initial begin
        // Build and run environment
        env = new(vif);
        env.build();
        env.run();

        // Let simulation run for a while
        repeat(10000) @(posedge aclk);

        // Graceful shutdown and reporting
        env.stop();
        $finish;
    end

endmodule

