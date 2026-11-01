`ifndef AXI_LITE_DRIVER_SV
`define AXI_LITE_DRIVER_SV
class axi_lite_driver extends uvm_driver #(axi_lite_item);
    `uvm_component_utils(axi_lite_driver)
    virtual axi_lite_if #(AXI_DATA_WIDTH, AXI_ADDR_WIDTH) vif;
    int unsigned max_ready_delay = 3;
    bit pipeline_mode;
    int unsigned submitted, completed;
    mailbox #(axi_lite_item) aw_q = new(16), w_q = new(16), b_q = new(16);
    mailbox #(axi_lite_item) ar_q = new(16), r_q = new(16);
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_lite_if #(AXI_DATA_WIDTH, AXI_ADDR_WIDTH))::get(this,"","vif",vif))
            `uvm_fatal("NOVIF", "driver requires vif")
        void'(uvm_config_db#(int unsigned)::get(this,"","max_ready_delay",max_ready_delay));
        void'(uvm_config_db#(bit)::get(this,"","pipeline_mode",pipeline_mode));
    endfunction
    task wait_for_idle();
        for (int cycles=0; cycles<10000; cycles++) begin
            if (completed == submitted && aw_q.num()==0 && w_q.num()==0 &&
                b_q.num()==0 && ar_q.num()==0 && r_q.num()==0) return;
            @(vif.drv_cb);
        end
        `uvm_fatal("DRAIN", $sformatf("timeout submitted=%0d completed=%0d",submitted,completed))
    endtask
    task run_phase(uvm_phase phase);
        @(vif.drv_cb);
        vif.drv_cb.awaddr <= '0; vif.drv_cb.awvalid <= 0;
        vif.drv_cb.wdata <= '0; vif.drv_cb.wstrb <= '0; vif.drv_cb.wvalid <= 0;
        vif.drv_cb.araddr <= '0; vif.drv_cb.arvalid <= 0;
        vif.drv_cb.bready <= 0; vif.drv_cb.rready <= 0;
        wait(vif.aresetn === 1'b1);
        @(vif.drv_cb);
        fork
            dispatch(); drive_aw(); drive_w(); drive_b(); drive_ar(); drive_r();
        join
    endtask
    task dispatch();
        axi_lite_item req, tr;
        forever begin
            seq_item_port.get_next_item(req);
            if (req.barrier) wait_for_idle();
            else begin
                if (!$cast(tr, req.clone())) `uvm_fatal("CLONE", "item clone failed")
                if (!tr.use_explicit_delays) begin
                    tr.aw_delay=$urandom_range(0,max_ready_delay);
                    tr.w_delay=$urandom_range(0,max_ready_delay);
                    tr.bready_delay=$urandom_range(0,max_ready_delay);
                    tr.ar_delay=$urandom_range(0,max_ready_delay);
                    tr.rready_delay=$urandom_range(0,max_ready_delay);
                end
                submitted++;
                if (tr.cmd==AXI_WRITE) begin aw_q.put(tr); w_q.put(tr); b_q.put(tr); end
                else begin ar_q.put(tr); r_q.put(tr); end
                if (!pipeline_mode) begin
                    wait_for_idle();
                    req.resp=tr.resp; req.rdata=tr.rdata;
                end
            end
            seq_item_port.item_done();
        end
    endtask
    task drive_aw();
        axi_lite_item tr;
        forever begin
            aw_q.get(tr);
            repeat(tr.aw_delay) @(vif.drv_cb);
            vif.drv_cb.awaddr <= tr.addr; vif.drv_cb.awvalid <= 1;
            do @(vif.drv_cb); while (!vif.drv_cb.awready);
            vif.drv_cb.awvalid <= 0;
        end
    endtask
    task drive_w();
        axi_lite_item tr;
        forever begin
            w_q.get(tr);
            repeat(tr.w_delay) @(vif.drv_cb);
            vif.drv_cb.wdata <= tr.data; vif.drv_cb.wstrb <= tr.wstrb; vif.drv_cb.wvalid <= 1;
            do @(vif.drv_cb); while (!vif.drv_cb.wready);
            vif.drv_cb.wvalid <= 0;
        end
    endtask
    task drive_ar();
        axi_lite_item tr;
        forever begin
            ar_q.get(tr);
            repeat(tr.ar_delay) @(vif.drv_cb);
            vif.drv_cb.araddr <= tr.addr; vif.drv_cb.arvalid <= 1;
            do @(vif.drv_cb); while (!vif.drv_cb.arready);
            vif.drv_cb.arvalid <= 0;
        end
    endtask
    task drive_b();
        axi_lite_item tr;
        forever begin
            b_q.get(tr);
            do @(vif.drv_cb); while (!vif.drv_cb.bvalid);
            repeat(tr.bready_delay) @(vif.drv_cb);
            vif.drv_cb.bready <= 1;
            @(vif.drv_cb);
            if (!vif.drv_cb.bvalid) `uvm_fatal("BVALID", "response disappeared")
            tr.resp=vif.drv_cb.bresp;
            vif.drv_cb.bready <= 0;
            completed++;
        end
    endtask
    task drive_r();
        axi_lite_item tr;
        forever begin
            r_q.get(tr);
            do @(vif.drv_cb); while (!vif.drv_cb.rvalid);
            repeat(tr.rready_delay) @(vif.drv_cb);
            vif.drv_cb.rready <= 1;
            @(vif.drv_cb);
            if (!vif.drv_cb.rvalid) `uvm_fatal("RVALID", "response disappeared")
            tr.resp=vif.drv_cb.rresp; tr.rdata=vif.drv_cb.rdata;
            vif.drv_cb.rready <= 0;
            completed++;
        end
    endtask
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (submitted!=completed || aw_q.num() || w_q.num() || b_q.num() || ar_q.num() || r_q.num())
            `uvm_error("DRAIN", "driver has unfinished transactions")
    endfunction
endclass
`endif
