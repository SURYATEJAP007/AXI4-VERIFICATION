interface axi4_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
) (
    input logic aclk,
    input logic aresetn
);

    // ---- Write Address Channel ----
    logic [ID_WIDTH-1:0]   awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;    
    logic [2:0]            awsize; 
    logic [1:0]            awburst; 
    logic                  awvalid;
    logic                  awready;

    // ---- Write Data Channel ----
    logic [DATA_WIDTH-1:0]     wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;
    logic                      wlast;
    logic                      wvalid;
    logic                      wready;

    // ---- Write Response Channel ----
    logic [ID_WIDTH-1:0] bid;
    logic [1:0]          bresp;  
    logic                bvalid;
    logic                bready;

    // ---- Read Address Channel ----
    logic [ID_WIDTH-1:0]   arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arvalid;
    logic                  arready;

    // ---- Read Data Channel ----
    logic [ID_WIDTH-1:0]   rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic                  rvalid;
    logic                  rready;

    // ========================================
    // Driver Clocking Block
    // ========================================
    clocking driver_cb @(posedge aclk);
        default input #1step output #1step;

        // Write Address Channel
        output awid, awaddr, awlen, awsize, awburst, awvalid;
        input awready;

        // Write Data Channel
        output wdata, wstrb, wlast, wvalid;
        input wready;

        // Write Response Channel
        input bid, bresp, bvalid;
        output bready;

        // Read Address Channel
        output arid, araddr, arlen, arsize, arburst, arvalid;
        input arready;

        // Read Data Channel
        input rid, rdata, rresp, rlast, rvalid;
        output rready;
    endclocking

    // ========================================
    // Monitor Clocking Block
    // ========================================
    clocking monitor_cb @(posedge aclk);
        default input #1step output #1step;
        input aclk,aresetn;

        // Write Address Channel
        input awid, awaddr, awlen, awsize, awburst, awvalid, awready;

        // Write Data Channel
        input wdata, wstrb, wlast, wvalid, wready;

        // Write Response Channel
        input bid, bresp, bvalid, bready;

        // Read Address Channel
        input arid, araddr, arlen, arsize, arburst, arvalid, arready;

        // Read Data Channel
        input rid, rdata, rresp, rlast, rvalid, rready;
    endclocking

    // ========================================
    // Modports
    // ========================================
    
    // Master: drives outputs, reads inputs
    modport master (
        input  aclk, aresetn,
        output awid, awaddr, awlen, awsize, awburst, awvalid,
        input  awready,
        output wdata, wstrb, wlast, wvalid,
        input  wready,
        input  bid, bresp, bvalid,
        output bready,
        output arid, araddr, arlen, arsize, arburst, arvalid,
        input  arready,
        input  rid, rdata, rresp, rlast, rvalid,
        output rready
    );

    // Slave: receives inputs, drives outputs
    modport slave (
        input  aclk, aresetn,
        input  awid, awaddr, awlen, awsize, awburst, awvalid,
        output awready,
        input  wdata, wstrb, wlast, wvalid,
        output wready,
        output bid, bresp, bvalid,
        input  bready,
        input  arid, araddr, arlen, arsize, arburst, arvalid,
        output arready,
        output rid, rdata, rresp, rlast, rvalid,
        input  rready
    );

    // Monitor: reads everything (no driving)
    modport monitor (
        input aclk, aresetn,
        clocking monitor_cb
    );

    // Driver: drives with clocking block
    modport driver (
        input aclk, aresetn,
        clocking driver_cb
    );

endinterface
