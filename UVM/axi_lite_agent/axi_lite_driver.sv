`ifndef AXI_LITE_DRIVER_SV
`define AXI_LITE_DRIVER_SV

class axi_lite_driver extends uvm_driver #(axi_lite_item);
    `uvm_component_utils(axi_lite_driver)

    virtual axi_lite_if #(AXI_DATA_WIDTH, AXI_ADDR_WIDTH) vif;
    int unsigned max_ready_delay = 3;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_lite_if #(AXI_DATA_WIDTH, AXI_ADDR_WIDTH))::get(
                this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "axi_lite_driver requires virtual interface")
        end
        void'(uvm_config_db#(int unsigned)::get(this, "", "max_ready_delay", max_ready_delay));
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_item req;
        drive_idle();
        wait (vif.aresetn === 1'b1);
        forever begin
            seq_item_port.get_next_item(req);
            if (req.cmd == AXI_WRITE) begin
                drive_write(req);
            end else begin
                drive_read(req);
            end
            seq_item_port.item_done();
        end
    endtask

    task drive_idle();
        vif.awaddr  <= '0;
        vif.awvalid <= 1'b0;
        vif.wdata   <= '0;
        vif.wstrb   <= '0;
        vif.wvalid  <= 1'b0;
        vif.bready  <= 1'b0;
        vif.araddr  <= '0;
        vif.arvalid <= 1'b0;
        vif.rready  <= 1'b0;
    endtask

    task drive_write(axi_lite_item tr);
        int unsigned aw_delay;
        int unsigned w_delay;
        int unsigned b_delay;

        aw_delay = $urandom_range(0, max_ready_delay);
        w_delay  = $urandom_range(0, max_ready_delay);
        b_delay  = $urandom_range(0, max_ready_delay);

        fork
            begin
                repeat (aw_delay) @(posedge vif.aclk);
                vif.awaddr  <= tr.addr;
                vif.awvalid <= 1'b1;
                do @(posedge vif.aclk); while (!(vif.awvalid && vif.awready));
                vif.awvalid <= 1'b0;
            end
            begin
                repeat (w_delay) @(posedge vif.aclk);
                vif.wdata  <= tr.data;
                vif.wstrb  <= tr.wstrb;
                vif.wvalid <= 1'b1;
                do @(posedge vif.aclk); while (!(vif.wvalid && vif.wready));
                vif.wvalid <= 1'b0;
            end
        join

        vif.bready <= 1'b0;
        repeat (b_delay) @(posedge vif.aclk);
        vif.bready <= 1'b1;
        do @(posedge vif.aclk); while (!(vif.bvalid && vif.bready));
        tr.resp = vif.bresp;
        vif.bready <= 1'b0;
    endtask

    task drive_read(axi_lite_item tr);
        int unsigned ar_delay;
        int unsigned r_delay;

        ar_delay = $urandom_range(0, max_ready_delay);
        r_delay  = $urandom_range(0, max_ready_delay);

        repeat (ar_delay) @(posedge vif.aclk);
        vif.araddr  <= tr.addr;
        vif.arvalid <= 1'b1;
        do @(posedge vif.aclk); while (!(vif.arvalid && vif.arready));
        vif.arvalid <= 1'b0;

        vif.rready <= 1'b0;
        repeat (r_delay) @(posedge vif.aclk);
        vif.rready <= 1'b1;
        do @(posedge vif.aclk); while (!(vif.rvalid && vif.rready));
        tr.rdata = vif.rdata;
        tr.resp  = vif.rresp;
        vif.rready <= 1'b0;
    endtask
endclass

`endif
