`ifndef AXI_LITE_COVERAGE_SV
`define AXI_LITE_COVERAGE_SV

class axi_lite_coverage extends uvm_component;
    `uvm_component_utils(axi_lite_coverage)

    uvm_analysis_imp #(axi_lite_item, axi_lite_coverage) analysis_export;

    axi_lite_cmd_e       cov_cmd;
    axi_lite_addr_kind_e cov_addr_kind;
    bit [AXI_ADDR_WIDTH-1:0] cov_addr;
    bit [AXI_DATA_WIDTH/8-1:0] cov_wstrb;
    bit [1:0] cov_resp;

    covergroup axi_lite_cg;
        option.per_instance = 1;

        cp_cmd: coverpoint cov_cmd {
            bins read  = {AXI_READ};
            bins write = {AXI_WRITE};
        }

        cp_addr: coverpoint cov_addr {
            bins reg0 = {8'h00};
            bins reg1 = {8'h04};
            bins reg2 = {8'h08};
            bins reg3 = {8'h0C};
            bins unaligned[] = {[8'h01:8'h03], [8'h05:8'h07], [8'h09:8'h0B], [8'h0D:8'h0F]};
            bins out_of_range = {[8'h10:8'hFF]};
        }

        cp_addr_kind: coverpoint cov_addr_kind {
            bins legal       = {ADDR_LEGAL};
            bins unaligned   = {ADDR_UNALIGNED};
            bins out_of_rng  = {ADDR_OUT_OF_RANGE};
        }

        cp_resp: coverpoint cov_resp {
            bins okay   = {2'b00};
            bins slverr = {2'b10};
        }

        cp_wstrb: coverpoint cov_wstrb iff (cov_cmd == AXI_WRITE) {
            bins zero       = {4'h0};
            bins single[]   = {4'h1, 4'h2, 4'h4, 4'h8};
            bins multi[]    = {4'h3, 4'h5, 4'h6, 4'h9, 4'hA, 4'hC, 4'hE, 4'h7, 4'hB, 4'hD};
            bins full       = {4'hF};
        }

        cx_cmd_addr_resp: cross cp_cmd, cp_addr_kind, cp_resp;
        cx_write_addr_wstrb: cross cp_addr_kind, cp_wstrb iff (cov_cmd == AXI_WRITE);
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        axi_lite_cg = new();
    endfunction

    function void write(axi_lite_item tr);
        cov_cmd       = tr.cmd;
        cov_addr      = tr.addr;
        cov_addr_kind = tr.addr_kind();
        cov_wstrb     = tr.wstrb;
        cov_resp      = tr.resp;
        axi_lite_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("AXI-Lite functional coverage: %.2f%%", axi_lite_cg.get_coverage()), UVM_LOW)
    endfunction
endclass

`endif
