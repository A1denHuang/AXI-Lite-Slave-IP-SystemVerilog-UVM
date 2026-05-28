`ifndef AXI_LITE_MONITOR_SV
`define AXI_LITE_MONITOR_SV

class axi_lite_monitor extends uvm_component;
    `uvm_component_utils(axi_lite_monitor)

    virtual axi_lite_if #(AXI_DATA_WIDTH, AXI_ADDR_WIDTH) vif;
    uvm_analysis_port #(axi_lite_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_lite_if #(AXI_DATA_WIDTH, AXI_ADDR_WIDTH))::get(
                this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "axi_lite_monitor requires virtual interface")
        end
    endfunction

    task run_phase(uvm_phase phase);
        wait (vif.aresetn === 1'b1);
        fork
            collect_writes();
            collect_reads();
        join
    endtask

    task collect_writes();
        axi_lite_item tr;
        forever begin
            tr = axi_lite_item::type_id::create("mon_write_tr", this);
            tr.cmd = AXI_WRITE;
            fork
                begin
                    do @(posedge vif.aclk); while (!(vif.awvalid && vif.awready));
                    tr.addr = vif.awaddr;
                end
                begin
                    do @(posedge vif.aclk); while (!(vif.wvalid && vif.wready));
                    tr.data  = vif.wdata;
                    tr.wstrb = vif.wstrb;
                end
            join
            do @(posedge vif.aclk); while (!(vif.bvalid && vif.bready));
            tr.resp = vif.bresp;
            ap.write(tr);
        end
    endtask

    task collect_reads();
        axi_lite_item tr;
        forever begin
            tr = axi_lite_item::type_id::create("mon_read_tr", this);
            tr.cmd = AXI_READ;
            do @(posedge vif.aclk); while (!(vif.arvalid && vif.arready));
            tr.addr = vif.araddr;
            do @(posedge vif.aclk); while (!(vif.rvalid && vif.rready));
            tr.rdata = vif.rdata;
            tr.resp  = vif.rresp;
            ap.write(tr);
        end
    endtask
endclass

`endif
