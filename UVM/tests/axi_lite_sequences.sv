`ifndef AXI_LITE_SEQUENCES_SV
`define AXI_LITE_SEQUENCES_SV

class axi_lite_base_sequence extends uvm_sequence #(axi_lite_item);
    `uvm_object_utils(axi_lite_base_sequence)

    int unsigned num_txns = 200;

    function new(string name = "axi_lite_base_sequence");
        super.new(name);
    endfunction

    task send_write(bit [7:0] addr, bit [31:0] data, bit [3:0] wstrb);
        axi_lite_item tr;
        tr = axi_lite_item::type_id::create("write_tr");
        start_item(tr);
        tr.cmd   = AXI_WRITE;
        tr.addr  = addr;
        tr.data  = data;
        tr.wstrb = wstrb;
        finish_item(tr);
    endtask

    task send_read(bit [7:0] addr);
        axi_lite_item tr;
        tr = axi_lite_item::type_id::create("read_tr");
        start_item(tr);
        tr.cmd   = AXI_READ;
        tr.addr  = addr;
        tr.data  = '0;
        tr.wstrb = '0;
        finish_item(tr);
    endtask

    task send_write_timed(
        bit [7:0] addr,
        bit [31:0] data,
        bit [3:0] wstrb,
        int unsigned aw_delay,
        int unsigned w_delay,
        int unsigned bready_delay
    );
        axi_lite_item tr;
        tr = axi_lite_item::type_id::create("timed_write_tr");
        start_item(tr);
        tr.cmd                 = AXI_WRITE;
        tr.addr                = addr;
        tr.data                = data;
        tr.wstrb               = wstrb;
        tr.use_explicit_delays = 1'b1;
        tr.aw_delay            = aw_delay;
        tr.w_delay             = w_delay;
        tr.bready_delay        = bready_delay;
        finish_item(tr);
    endtask

    task send_read_timed(
        bit [7:0] addr,
        int unsigned ar_delay,
        int unsigned rready_delay
    );
        axi_lite_item tr;
        tr = axi_lite_item::type_id::create("timed_read_tr");
        start_item(tr);
        tr.cmd                 = AXI_READ;
        tr.addr                = addr;
        tr.data                = '0;
        tr.wstrb               = '0;
        tr.use_explicit_delays = 1'b1;
        tr.ar_delay            = ar_delay;
        tr.rready_delay        = rready_delay;
        finish_item(tr);
    endtask
endclass

class axi_lite_smoke_sequence extends axi_lite_base_sequence;
    `uvm_object_utils(axi_lite_smoke_sequence)

    function new(string name = "axi_lite_smoke_sequence");
        super.new(name);
    endfunction

    task body();
        send_write(8'h00, 32'h1234_5678, 4'hF);
        send_read (8'h00);
        send_write(8'h00, 32'hABCD_EF00, 4'b1100);
        send_read (8'h00);
        send_write(8'h04, 32'hAAAA_5555, 4'hF);
        send_read (8'h04);
        send_write(8'h08, 32'hFFFF_0000, 4'hF);
        send_read (8'h08);
        send_write(8'h20, 32'hDEAD_BEEF, 4'hF);
        send_read (8'h20);
        send_read (8'h24);
        send_write(8'h01, 32'hCAFE_BABE, 4'hF);
        send_read (8'h01);
    endtask
endclass

class axi_lite_random_sequence extends axi_lite_base_sequence;
    `uvm_object_utils(axi_lite_random_sequence)

    function new(string name = "axi_lite_random_sequence");
        super.new(name);
    endfunction

    task body();
        axi_lite_item tr;
        void'($value$plusargs("NUM_TXNS=%0d", num_txns));
        repeat (num_txns) begin
            tr = axi_lite_item::type_id::create("random_tr");
            start_item(tr);
            if (!tr.randomize()) begin
                `uvm_fatal("RAND", "Failed to randomize AXI-Lite item")
            end
            finish_item(tr);
        end
    endtask
endclass

class axi_lite_wstrb_sequence extends axi_lite_base_sequence;
    `uvm_object_utils(axi_lite_wstrb_sequence)

    function new(string name = "axi_lite_wstrb_sequence");
        super.new(name);
    endfunction

    task body();
        bit [3:0] patterns[$] = '{4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7,
                                  4'h8, 4'h9, 4'hA, 4'hB, 4'hC, 4'hD, 4'hE, 4'hF};
        bit [3:0] out_of_range_patterns[$] = '{4'h0, 4'h8, 4'h9, 4'hA};

        foreach (patterns[i]) begin
            send_write(8'h00, 32'h1111_0000 + i, patterns[i]);
            send_read(8'h00);
        end

        // Deterministically close the four reachable out-of-range x WSTRB
        // cross bins that a finite random run can miss.
        foreach (out_of_range_patterns[i]) begin
            send_write(8'h20, 32'hBAD0_1000 + i, out_of_range_patterns[i]);
        end
    endtask
endclass

class axi_lite_error_sequence extends axi_lite_base_sequence;
    `uvm_object_utils(axi_lite_error_sequence)

    function new(string name = "axi_lite_error_sequence");
        super.new(name);
    endfunction

    task body();
        bit [7:0] bad_addrs[$] = '{8'h01, 8'h02, 8'h03, 8'h05, 8'h10, 8'h14, 8'h20, 8'h24, 8'hFF};
        foreach (bad_addrs[i]) begin
            send_write(bad_addrs[i], 32'hBAD0_0000 + i, 4'hF);
            send_read(bad_addrs[i]);
        end
        send_write(8'h00, 32'h55AA_AA55, 4'hF);
        send_read(8'h00);
    endtask
endclass

class axi_lite_backpressure_sequence extends axi_lite_random_sequence;
    `uvm_object_utils(axi_lite_backpressure_sequence)

    function new(string name = "axi_lite_backpressure_sequence");
        super.new(name);
        num_txns = 100;
    endfunction
endclass

// A deterministic end-to-end learning scenario.  The first three writes make
// AW-first, W-first and simultaneous AW/W arrival visible in the waveform.
class axi_lite_learning_sequence extends axi_lite_base_sequence;
    `uvm_object_utils(axi_lite_learning_sequence)

    function new(string name = "axi_lite_learning_sequence");
        super.new(name);
    endfunction

    task body();
        bit [3:0] missing_wstrb[$] = '{4'h6, 4'h7, 4'h9, 4'hB, 4'hD, 4'hE};

        // AW first, with delayed BREADY.
        send_write_timed(8'h00, 32'h1122_3344, 4'hF, 0, 3, 3);
        send_read_timed (8'h00, 0, 2);

        // W first.
        send_write_timed(8'h04, 32'hAABB_CCDD, 4'h3, 3, 0, 1);
        send_read_timed (8'h04, 1, 0);

        // AW and W arrive together.
        send_write_timed(8'h08, 32'h5566_7788, 4'hC, 0, 0, 0);
        send_read_timed (8'h08, 0, 3);

        // Fourth register uses another byte-enable pattern.
        send_write_timed(8'h0C, 32'hDEAD_BEEF, 4'h5, 1, 1, 2);
        send_read_timed (8'h0C, 2, 1);

        // An unaligned address aliases word index zero internally.  Reading
        // 0x00 afterwards proves that the rejected write did not corrupt it.
        send_write_timed(8'h01, 32'hFFFF_FFFF, 4'hF, 0, 2, 2);
        send_read_timed (8'h01, 0, 1);
        send_read_timed (8'h00, 0, 0);

        // Out-of-range traffic must also return SLVERR without mirror updates.
        send_write_timed(8'h20, 32'hCAFE_BABE, 4'hF, 2, 0, 2);
        send_read_timed (8'h20, 1, 2);

        // Explicitly exercise the WSTRB values that were absent from the
        // original random constraint.
        foreach (missing_wstrb[i]) begin
            send_write_timed(8'h0C, 32'h1020_3040 + i, missing_wstrb[i], 0, 0, 0);
            send_read_timed (8'h0C, 0, 0);
        end

        // Final legal reads let the scoreboard verify the complete mirror.
        send_read(8'h00);
        send_read(8'h04);
        send_read(8'h08);
        send_read(8'h0C);
    endtask
endclass

`endif
