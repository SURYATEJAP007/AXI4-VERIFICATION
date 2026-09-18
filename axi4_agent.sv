`include "axi4_transaction.sv"
`include "axi4_generator.sv"
`include "axi4_driver.sv"
`include "axi4_monitor.sv"
class axi4_agent;

    // Components
    axi4_generator gen;
    axi4_driver    drv;
    axi4_monitor   mon;

    // Mailboxes
    mailbox #(axi4_transaction) m1;  // Generator -> Driver
    mailbox #(axi4_transaction) m2;  // Monitor -> Scoreboard
    mailbox #(axi4_transaction) m3;  // Monitor -> Coverage

    // Interface
    virtual axi4_if vif;

    // Config flag
    bit is_active = 1;

    // Constructor
    function new(virtual axi4_if vif);
        this.vif = vif;
    endfunction

    // Build
    function void build();
        m1 = new();
        m2 = new();
        m3 = new();
        if (is_active) begin
            gen = new(m1);
            drv = new(m1, vif);
        end
        mon = new(vif, m2, m3);
    endfunction

    // Run
    task run();
        $display("[AGENT] Agent started");
        fork
            if (is_active) begin
                gen.run_generator();
                drv.run();
            end
            mon.run();
        join_none
    endtask

endclass

