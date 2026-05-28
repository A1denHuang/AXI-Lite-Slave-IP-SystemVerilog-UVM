`ifndef AXI_LITE_SCOREBOARD_SV
`define AXI_LITE_SCOREBOARD_SV

class axi_lite_scoreboard extends uvm_component;
    `uvm_component_utils(axi_lite_scoreboard)

    uvm_analysis_imp #(axi_lite_item, axi_lite_scoreboard) analysis_export;
    bit [AXI_DATA_WIDTH-1:0] mirror [AXI_REG_COUNT];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
    endfunction

    function void reset_mirror();
        foreach (mirror[i]) begin
            mirror[i] = '0;
        end
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        reset_mirror();
    endfunction

    function void write(axi_lite_item tr);
        int unsigned word_addr;
        bit [AXI_DATA_WIDTH-1:0] expected_data;

        word_addr = tr.addr >> 2;

        if (tr.cmd == AXI_WRITE) begin
            if (tr.is_legal_addr()) begin
                if (tr.resp !== 2'b00) begin
                    `uvm_error("SCB", $sformatf("WRITE addr=0x%0h expected OKAY, got %0b", tr.addr, tr.resp))
                end
                for (int b = 0; b < AXI_DATA_WIDTH/8; b++) begin
                    if (tr.wstrb[b]) begin
                        mirror[word_addr][b*8 +: 8] = tr.data[b*8 +: 8];
                    end
                end
            end else begin
                if (tr.resp !== 2'b10) begin
                    `uvm_error("SCB", $sformatf("WRITE addr=0x%0h expected SLVERR, got %0b", tr.addr, tr.resp))
                end
            end
        end else begin
            if (tr.is_legal_addr()) begin
                expected_data = mirror[word_addr];
                if (tr.resp !== 2'b00) begin
                    `uvm_error("SCB", $sformatf("READ addr=0x%0h expected OKAY, got %0b", tr.addr, tr.resp))
                end
                if (tr.rdata !== expected_data) begin
                    `uvm_error("SCB", $sformatf(
                        "READ addr=0x%0h data mismatch: got 0x%08h expected 0x%08h",
                        tr.addr, tr.rdata, expected_data))
                end
            end else begin
                if (tr.resp !== 2'b10) begin
                    `uvm_error("SCB", $sformatf("READ addr=0x%0h expected SLVERR, got %0b", tr.addr, tr.resp))
                end
                if (tr.rdata !== '0) begin
                    `uvm_error("SCB", $sformatf("READ addr=0x%0h invalid access data expected 0, got 0x%08h",
                        tr.addr, tr.rdata))
                end
            end
        end
    endfunction
endclass

`endif
