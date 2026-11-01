`ifndef AXI_LITE_MONITOR_SV
`define AXI_LITE_MONITOR_SV
class axi_lite_monitor extends uvm_component;
    `uvm_component_utils(axi_lite_monitor)
    virtual axi_lite_if #(AXI_DATA_WIDTH, AXI_ADDR_WIDTH) vif;
    uvm_analysis_port #(axi_lite_item) ap;
    axi_lite_item aw_hold, w_hold, pending_b[$], pending_r[$];
    longint unsigned cycle, aw_cycle, w_cycle;
    int unsigned aw_wait, w_wait, ar_wait, b_wait, r_wait;
    int unsigned aw_stalls, w_stalls, ar_stalls, b_stalls, r_stalls;
    int unsigned aw_recovered, w_recovered, ar_recovered;
    int unsigned aw_first, w_first, together, overlap, same_addr, different_addr;
    int unsigned bblocked_read, rblocked_write, aw_continuous, w_continuous, ar_continuous;
    bit prev_aw_hs, prev_w_hs, prev_ar_hs;
    bit cov_commit, cov_overlap, cov_same, cov_diff, cov_br, cov_rw;
    bit cov_aw_cont, cov_w_cont, cov_ar_cont;
    int cov_order;
    covergroup timing_cg;
        option.per_instance=1;
        cp_order: coverpoint cov_order iff(cov_commit) { bins aw_first={0}; bins w_first={1}; bins together={2}; }
        cp_aw_wait: coverpoint aw_wait iff(prev_aw_hs) { bins none={0}; bins short_wait={[1:3]}; bins long_wait={[4:10000]}; }
        cp_w_wait: coverpoint w_wait iff(prev_w_hs) { bins none={0}; bins short_wait={[1:3]}; bins long_wait={[4:10000]}; }
        cp_ar_wait: coverpoint ar_wait iff(prev_ar_hs) { bins none={0}; bins short_wait={[1:3]}; bins long_wait={[4:10000]}; }
        cp_b_wait: coverpoint b_wait iff(vif.mon_cb.bvalid && vif.mon_cb.bready) { bins short_wait={[1:3]}; bins long_wait={[4:10000]}; }
        cp_r_wait: coverpoint r_wait iff(vif.mon_cb.rvalid && vif.mon_cb.rready) { bins short_wait={[1:3]}; bins long_wait={[4:10000]}; }
        cp_overlap: coverpoint cov_overlap { bins hit={1}; ignore_bins idle={0}; }
        cp_same: coverpoint cov_same { bins hit={1}; ignore_bins idle={0}; }
        cp_different: coverpoint cov_diff { bins hit={1}; ignore_bins idle={0}; }
        cp_bblocked_read: coverpoint cov_br { bins hit={1}; ignore_bins idle={0}; }
        cp_rblocked_write: coverpoint cov_rw { bins hit={1}; ignore_bins idle={0}; }
        cp_aw_continuous: coverpoint cov_aw_cont { bins hit={1}; ignore_bins idle={0}; }
        cp_w_continuous: coverpoint cov_w_cont { bins hit={1}; ignore_bins idle={0}; }
        cp_ar_continuous: coverpoint cov_ar_cont { bins hit={1}; ignore_bins idle={0}; }
    endgroup
    function new(string name, uvm_component parent);
        super.new(name,parent); ap=new("ap",this); timing_cg=new();
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_lite_if #(AXI_DATA_WIDTH, AXI_ADDR_WIDTH))::get(this,"","vif",vif))
            `uvm_fatal("NOVIF","monitor requires vif")
    endfunction
    task run_phase(uvm_phase phase);
        axi_lite_item tr;
        bit ah, wh, bh, arh, rh;
        forever begin
            @(vif.mon_cb);
            if (!vif.aresetn) continue;
            cycle++;
            ah=vif.mon_cb.awvalid && vif.mon_cb.awready;
            wh=vif.mon_cb.wvalid && vif.mon_cb.wready;
            bh=vif.mon_cb.bvalid && vif.mon_cb.bready;
            arh=vif.mon_cb.arvalid && vif.mon_cb.arready;
            rh=vif.mon_cb.rvalid && vif.mon_cb.rready;
            cov_commit=0; cov_same=0; cov_diff=0; cov_br=0; cov_rw=0;
            cov_aw_cont=prev_aw_hs && vif.mon_cb.awvalid;
            cov_w_cont=prev_w_hs && vif.mon_cb.wvalid;
            cov_ar_cont=prev_ar_hs && vif.mon_cb.arvalid;
            aw_continuous+=cov_aw_cont; w_continuous+=cov_w_cont; ar_continuous+=cov_ar_cont;
            if(vif.mon_cb.awvalid && !vif.mon_cb.awready) begin aw_wait++; aw_stalls++; end
            if(vif.mon_cb.wvalid && !vif.mon_cb.wready) begin w_wait++; w_stalls++; end
            if(vif.mon_cb.arvalid && !vif.mon_cb.arready) begin ar_wait++; ar_stalls++; end
            if(vif.mon_cb.bvalid && !vif.mon_cb.bready) begin b_wait++; b_stalls++; end
            if(vif.mon_cb.rvalid && !vif.mon_cb.rready) begin r_wait++; r_stalls++; end
            // Responses retire before new request events on the same edge.
            if(bh) begin
                if(!pending_b.size()) `uvm_fatal("MON","B without a write")
                tr=pending_b.pop_front(); tr.resp=vif.mon_cb.bresp;
                tr.observed_event=axi_lite_item::COMPLETED; ap.write(tr);
            end
            if(rh) begin
                if(!pending_r.size()) `uvm_fatal("MON","R without a read")
                tr=pending_r.pop_front(); tr.resp=vif.mon_cb.rresp; tr.rdata=vif.mon_cb.rdata;
                tr.observed_event=axi_lite_item::COMPLETED; ap.write(tr);
            end
            // AR is published BEFORE write commit: simultaneous accesses read old data.
            if(arh) begin
                tr=axi_lite_item::type_id::create("read_accepted",this);
                tr.cmd=AXI_READ; tr.addr=vif.mon_cb.araddr;
                tr.observed_event=axi_lite_item::READ_ACCEPTED; ap.write(tr); pending_r.push_back(tr);
                if(vif.mon_cb.bvalid && !vif.mon_cb.bready) begin bblocked_read++; cov_br=1; end
            end
            if(ah) begin
                if(aw_hold!=null) `uvm_fatal("MON","second unmatched AW")
                aw_hold=axi_lite_item::type_id::create("aw",this); aw_hold.addr=vif.mon_cb.awaddr; aw_cycle=cycle;
            end
            if(wh) begin
                if(w_hold!=null) `uvm_fatal("MON","second unmatched W")
                w_hold=axi_lite_item::type_id::create("w",this);
                w_hold.data=vif.mon_cb.wdata; w_hold.wstrb=vif.mon_cb.wstrb; w_cycle=cycle;
            end
            if(aw_hold!=null && w_hold!=null) begin
                tr=aw_hold; tr.cmd=AXI_WRITE; tr.data=w_hold.data; tr.wstrb=w_hold.wstrb;
                tr.observed_event=axi_lite_item::WRITE_COMMITTED; ap.write(tr); pending_b.push_back(tr);
                cov_commit=1;
                if(aw_cycle<w_cycle) begin cov_order=0; aw_first++; end
                else if(w_cycle<aw_cycle) begin cov_order=1; w_first++; end
                else begin cov_order=2; together++; end
                if(arh) begin
                    if(tr.addr==vif.mon_cb.araddr) begin same_addr++; cov_same=1; end
                    else begin different_addr++; cov_diff=1; end
                end
                if(vif.mon_cb.rvalid && !vif.mon_cb.rready) begin rblocked_write++; cov_rw=1; end
                aw_hold=null; w_hold=null;
            end
            cov_overlap=(pending_b.size()!=0 || aw_hold!=null || w_hold!=null) && pending_r.size()!=0;
            overlap+=cov_overlap;
            prev_aw_hs=ah; prev_w_hs=wh; prev_ar_hs=arh;
            timing_cg.sample();
            if(ah) begin if(aw_wait) aw_recovered++; aw_wait=0; end
            if(wh) begin if(w_wait) w_recovered++; w_wait=0; end
            if(arh) begin if(ar_wait) ar_recovered++; ar_wait=0; end
            if(bh) b_wait=0;
            if(rh) r_wait=0;
        end
    endtask
    function void require_scenarios(int profile);
        if(profile==1 && !(aw_recovered && w_recovered && ar_recovered && b_stalls && r_stalls))
            `uvm_error("SCENARIO","slave backpressure/recovery not all exercised")
        if(profile==2 && !(overlap && same_addr && different_addr && bblocked_read && rblocked_write))
            `uvm_error("SCENARIO","concurrency scenarios not all exercised")
        if(profile==3 && !(aw_continuous && w_continuous && ar_continuous && aw_first && w_first && together))
            `uvm_error("SCENARIO","continuous requests / AW-W orders not all exercised")
        `uvm_info("SCENARIO_DONE",$sformatf("profile=%0d",profile),UVM_LOW)
    endfunction
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if(aw_hold!=null || w_hold!=null || pending_b.size() || pending_r.size())
            `uvm_error("MON_DRAIN","unfinished monitor transactions")
    endfunction
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("TIMING",$sformatf("AXI-Lite timing coverage: %.2f%%",timing_cg.get_inst_coverage()),UVM_LOW)
        `uvm_info("TIMING_COUNTS",$sformatf("AW_WAIT=%0d W_WAIT=%0d AR_WAIT=%0d AW_RECOVER=%0d W_RECOVER=%0d AR_RECOVER=%0d B_WAIT=%0d R_WAIT=%0d AW_FIRST=%0d W_FIRST=%0d TOGETHER=%0d OVERLAP=%0d SAME=%0d DIFFERENT=%0d B_BLOCK_READ=%0d R_BLOCK_WRITE=%0d AW_CONT=%0d W_CONT=%0d AR_CONT=%0d",aw_stalls,w_stalls,ar_stalls,aw_recovered,w_recovered,ar_recovered,b_stalls,r_stalls,aw_first,w_first,together,overlap,same_addr,different_addr,bblocked_read,rblocked_write,aw_continuous,w_continuous,ar_continuous),UVM_LOW)
    endfunction
endclass
`endif
