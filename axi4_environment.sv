
`include "axi4_agent.sv"
`include "axi4_scoreboard.sv"
`include "axi4_coverages.sv"

class axi4_environment;

    // ========================================
    // Component Classes
    // ========================================
    axi4_agent      agent;      // Generator + Driver + Monitor
    axi4_scoreboard sb;         // Verification/checking
    axi4_coverages  cov;        // Coverage collection

    // ========================================
    // Interface
    // ========================================
    virtual axi4_if vif;

    // ========================================
    // Constructor
    // ========================================
    function new(virtual axi4_if vif);
        this.vif = vif;
        $display("[ENV] Environment created");
    endfunction

    // ========================================
    // Build: Create All Components
    // ========================================
    function void build();
        $display("[ENV] Building environment...");
        
        // ? Create agent
        agent = new(vif);
        if (agent == null) begin
            $error("[ENV] Failed to create agent");
            return;
        end
        agent.build();
        $display("[ENV]   Agent created and built");
        
        // ? Create scoreboard (connects to agent's m2 mailbox)
        sb = new(agent.m2);
        if (sb == null) begin
            $error("[ENV] Failed to create scoreboard");
            return;
        end
        $display("[ENV]   Scoreboard created");
        
        // ? Create coverage (connects to agent's m3 mailbox)
        cov = new(agent.m3);
        if (cov == null) begin
            $error("[ENV] Failed to create coverage");
            return;
        end
        $display("[ENV]   Coverage created");
        
        $display("[ENV] Build complete\n");
    endfunction

    // ========================================
    // Run: Start All Components
    // ========================================
    task run();
        $display("[ENV] Starting all components...\n");
        
        fork
            agent.run();
            sb.run();
            cov.run();
        join_none
        
        $display("[ENV] All components running in background\n");
    endtask

    // ========================================
    // Stop: Graceful Shutdown
    // ========================================

task stop();
    $display("\n[ENV] Stopping environment...");
    
    // Wait until generator finishes or transactions drain
    wait (agent.gen.transaction_count == agent.gen.num_txns);
    
    $display("[ENV] All transactions processed");
    report();
endtask

// Report: Show Final Results
function void report();
    $display("\n========================================");
    $display("     VERIFICATION ENVIRONMENT REPORT     ");
    $display("========================================");
    $display("  Report generated at time %0t", $time);

    if (sb != null) sb.report();
    else $display("  Scoreboard: NOT CREATED");

    if (cov != null) cov.report();
    else $display("  Coverage: NOT CREATED");

    $display("========================================\n");
endfunction


endclass
