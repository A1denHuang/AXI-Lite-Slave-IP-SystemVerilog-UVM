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
        bit [3:0] patterns[$] = '{4'h0, 4'h1, 4'h2, 4'h4, 4'h8, 4'h3, 4'h5, 4'hA, 4'hC, 4'hF};
        foreach (patterns[i]) begin
            send_write(8'h00, 32'h1111_0000 + i, patterns[i]);
            send_read(8'h00);
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

`endif
