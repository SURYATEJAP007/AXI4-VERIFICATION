module axi4_slave_wrapper #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter MEM_DEPTH  = 256
) (
    axi4_if.slave bus
);

    // Shared memory
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

  
    axi4_write_slave_burst #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .MEM_DEPTH(MEM_DEPTH)
    ) write_slave (
        .bus(bus),
        .mem(mem)   
    );

   
    axi4_read_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .MEM_DEPTH(MEM_DEPTH)
    ) read_slave (
        .bus(bus),
        .mem(mem)   
    );

endmodule
