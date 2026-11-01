`ifndef AXI_LITE_SCOREBOARD_SV
`define AXI_LITE_SCOREBOARD_SV
class axi_lite_scoreboard extends uvm_component;
    `uvm_component_utils(axi_lite_scoreboard)
    uvm_analysis_imp #(axi_lite_item,axi_lite_scoreboard) analysis_export;
    bit [AXI_DATA_WIDTH-1:0] mirror[AXI_REG_COUNT];
    axi_lite_item expected_b[$], expected_r[$];
    int unsigned checked_transfers;
    function new(string name,uvm_component parent);
        super.new(name,parent); analysis_export=new("analysis_export",this);
    endfunction
    function void write(axi_lite_item tr);
        axi_lite_item exp;
        int unsigned word_addr;
        word_addr=tr.addr >> 2;
        case(tr.observed_event)
            axi_lite_item::READ_ACCEPTED: begin
                exp=axi_lite_item::type_id::create("expected_read");
                exp.addr=tr.addr; exp.resp=tr.is_legal_addr()?2'b00:2'b10;
                exp.rdata=tr.is_legal_addr()?mirror[word_addr]:'0;
                expected_r.push_back(exp);
            end
            axi_lite_item::WRITE_COMMITTED: begin
                exp=axi_lite_item::type_id::create("expected_write");
                exp.addr=tr.addr; exp.resp=tr.is_legal_addr()?2'b00:2'b10;
                if(tr.is_legal_addr())
                    for(int b=0;b<AXI_DATA_WIDTH/8;b++)
                        if(tr.wstrb[b]) mirror[word_addr][b*8+:8]=tr.data[b*8+:8];
                expected_b.push_back(exp);
            end
            axi_lite_item::COMPLETED: begin
                if(tr.cmd==AXI_WRITE) begin
                    if(!expected_b.size()) `uvm_fatal("SCB","unexpected write response")
                    exp=expected_b.pop_front();
                end else begin
                    if(!expected_r.size()) `uvm_fatal("SCB","unexpected read response")
                    exp=expected_r.pop_front();
                    if(tr.rdata !== exp.rdata)
                        `uvm_error("SCB",$sformatf("READ addr=%h got=%h expected=%h",tr.addr,tr.rdata,exp.rdata))
                end
                if(tr.addr !== exp.addr || tr.resp !== exp.resp)
                    `uvm_error("SCB",$sformatf("response mismatch addr=%h expected_addr=%h resp=%b expected_resp=%b",tr.addr,exp.addr,tr.resp,exp.resp))
                checked_transfers++;
            end
        endcase
    endfunction
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if(expected_b.size() || expected_r.size()) `uvm_error("SCB_DRAIN","unmatched expectations")
    endfunction
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB_COUNT",$sformatf("CHECKED_TRANSFERS=%0d",checked_transfers),UVM_LOW)
    endfunction
endclass
`endif
