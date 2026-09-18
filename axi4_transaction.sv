class axi4_transaction;

    localparam MEM_DEPTH  = 256;
    localparam DATA_WIDTH = 32;

    // ========================================
    // Randomizable Fields
    // ========================================
    rand logic [7:0]   len;
    rand logic [2:0]   size;
    rand logic [1:0]   burst_type;
    rand logic [31:0]  addr;
    rand logic [3:0]   id;
    rand bit           is_write;

    rand logic [31:0] data[];
    rand logic [DATA_WIDTH/8-1:0] wstrb[];

    // ========================================
    // DUT responses
    // ========================================
    logic [1:0] bresp;
    logic [1:0] rresp[];
    logic [3:0] rid_seen;


    // ========================================
    // Constraints
    // ========================================

    constraint const_len {
        len inside {[1:15]};
    }

    constraint const_size {
        size inside {[0:2]};
    }

    constraint const_burst {
        burst_type inside {0,1};
    }

    constraint const_addr {
        addr < (MEM_DEPTH * 4);
    }

    constraint const_addr_align {
        addr % (1 << size) == 0;
    }

    constraint const_id {
        id inside {[0:15]};
    }

    // Number of data beats
    constraint const_data_size {
        data.size() == (len + 1);
    }

    // Number of strobes must also equal number of beats
    constraint const_wstrb_size {
        wstrb.size() == (len + 1);
    }

    constraint valid_strobes {
        foreach (wstrb[i])
            wstrb[i] != 0;
    }

function new();
    addr       = 32'h0;
    len        = 1;          // AXI requires at least 1 beat
    size       = 0;          // 1 byte per beat
    burst_type = 1;          // INCR burst
    id         = 0;
    is_write   = 1'b0;
    data       = new[1];
    wstrb      = new[1];
endfunction

    // ========================================
    // PRE RANDOMIZE
    // ========================================
    function void pre_randomize();

        if (data.size() == 0)
            data = new[16];

        if (wstrb.size() == 0)
            wstrb = new[16];

    endfunction


    // ========================================
    // POST RANDOMIZE
    // ========================================
    function void post_randomize();
    data  = new[len+1];
    wstrb = new[len+1];

    if (is_write) begin
        foreach (data[i]) begin
            data[i]  = $random;
            wstrb[i] = $urandom_range(1, (1 << (DATA_WIDTH/8)) - 1);
        end
    end else begin
        rresp = new[len+1];
    end
endfunction



    // ========================================
    // DISPLAY
    // ========================================

    function void display(string tag="TX");
    int bytes_per_beat = 1 << size;
    $display("[%s] id=%0d addr=0x%h len=%0d size=%0d (%0d bytes/beat) burst=%0d is_write=%0d",
             tag, id, addr, len, size, bytes_per_beat, burst_type, is_write);

        if (is_write) begin
            foreach (data[i])
                $display(
                    "  data[%0d]=0x%h wstrb=%b",
                    i,
                    data[i],
                    wstrb[i]
                );
        end

    endfunction

endclass
