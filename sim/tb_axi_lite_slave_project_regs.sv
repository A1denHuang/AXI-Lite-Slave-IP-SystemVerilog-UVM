`timescale 1ns/1ps
// Standalone, self-checking project register tests. No UVM dependency.
// Stimulus changes only at falling edges; DUT and SVA sample rising edges.
module tb_axi_lite_slave_project_regs;
    localparam [31:0] VERSION = 32'hcafe_0102;
    logic aclk=0, aresetn=0;
    logic [31:0] status_i=0, intr_status_set_i=0;
    wire [31:0] ctrl_o, intr_en_o, intr_status_o;
    int checks=0, writes=0, reads=0, cases=0;
    axi_lite_if #(32,8) bus(aclk,aresetn);
    always #5 aclk=~aclk;

    axi_lite_slave_project_regs #(.VERSION_VALUE(VERSION)) dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(bus.awaddr),
        .s_axi_awvalid(bus.awvalid),
        .s_axi_awready(bus.awready),
        .s_axi_wdata(bus.wdata),
        .s_axi_wstrb(bus.wstrb),
        .s_axi_wvalid(bus.wvalid),
        .s_axi_wready(bus.wready),
        .s_axi_bresp(bus.bresp),
        .s_axi_bvalid(bus.bvalid),
        .s_axi_bready(bus.bready),
        .s_axi_araddr(bus.araddr),
        .s_axi_arvalid(bus.arvalid),
        .s_axi_arready(bus.arready),
        .s_axi_rdata(bus.rdata),
        .s_axi_rresp(bus.rresp),
        .s_axi_rvalid(bus.rvalid),
        .s_axi_rready(bus.rready),
        .ctrl_o(ctrl_o), .status_i(status_i), .intr_en_o(intr_en_o),
        .intr_status_set_i(intr_status_set_i), .intr_status_o(intr_status_o)
    );
    // Five contiguous register offsets 0x00..0x10 match the checker's address contract.
    axi_lite_slave_assertions #(.DATA_WIDTH(32), .ADDR_WIDTH(8), .REG_COUNT(5)) axi_assert_i (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(bus.awaddr),
        .s_axi_awvalid(bus.awvalid),
        .s_axi_awready(bus.awready),
        .s_axi_wdata(bus.wdata),
        .s_axi_wstrb(bus.wstrb),
        .s_axi_wvalid(bus.wvalid),
        .s_axi_wready(bus.wready),
        .s_axi_bresp(bus.bresp),
        .s_axi_bvalid(bus.bvalid),
        .s_axi_bready(bus.bready),
        .s_axi_araddr(bus.araddr),
        .s_axi_arvalid(bus.arvalid),
        .s_axi_arready(bus.arready),
        .s_axi_rdata(bus.rdata),
        .s_axi_rresp(bus.rresp),
        .s_axi_rvalid(bus.rvalid),
        .s_axi_rready(bus.rready)
    );

    task automatic check32(input logic [31:0] actual, expected, input string label);
        checks++;
        if(actual !== expected)
            $fatal(1,"%s actual=%08h expected=%08h",label,actual,expected);
    endtask
    task automatic outputs(input logic [31:0] ctrl, en, pending);
        check32(ctrl_o,ctrl,"CTRL output");
        check32(intr_en_o,en,"INTR_EN output");
        check32(intr_status_o,pending,"INTR_STATUS output");
    endtask
    task automatic start_case(input string label);
        cases++;
        $display("CASE %0d: %s",cases,label);
    endtask
    task automatic reset_dut();
        @(negedge aclk);
        aresetn=0; intr_status_set_i=0;
        bus.awvalid=0; bus.wvalid=0; bus.arvalid=0; bus.bready=0; bus.rready=0;
        repeat(3) @(posedge aclk);
        @(negedge aclk); aresetn=1;
        outputs(0,0,0);
    endtask
    task automatic event_pulse(input logic [31:0] bits_to_set);
        @(negedge aclk); intr_status_set_i=bits_to_set;
        @(negedge aclk); intr_status_set_i=0;
    endtask
    task automatic write_reg(
        input logic [7:0] addr,
        input logic [31:0] data,
        input logic [3:0] strb=15,
        input int aw_delay=0, w_delay=0,
        input logic [31:0] same_cycle_set=0,
        input logic [1:0] expected_resp=0,
        input int b_delay=0
    );
        int last_request;
        last_request=(aw_delay>w_delay)?aw_delay:w_delay;
        @(negedge aclk);
        fork
            begin
                repeat(aw_delay) @(negedge aclk);
                bus.awaddr=addr; bus.awvalid=1;
                do @(posedge aclk); while(!bus.awready);
                @(negedge aclk); bus.awvalid=0;
            end
            begin
                repeat(w_delay) @(negedge aclk);
                bus.wdata=data; bus.wstrb=strb; bus.wvalid=1;
                do @(posedge aclk); while(!bus.wready);
                @(negedge aclk); bus.wvalid=0;
            end
            begin
                // Pulse exactly when the later AW/W is accepted, not throughout the write.
                repeat(last_request) @(negedge aclk);
                intr_status_set_i=same_cycle_set;
                @(negedge aclk); intr_status_set_i=0;
            end
        join
        while(!bus.bvalid) @(negedge aclk);
        repeat(b_delay) @(negedge aclk);
        bus.bready=1;
        @(posedge aclk);
        check32({30'b0,bus.bresp},{30'b0,expected_resp},"BRESP");
        @(negedge aclk); bus.bready=0;
        writes++;
    endtask
    task automatic read_reg(
        input logic [7:0] addr,
        input logic [31:0] expected,
        input logic [1:0] expected_resp=0,
        input int r_delay=0,
        input bit change_status=0,
        input logic [31:0] new_status=0
    );
        @(negedge aclk); bus.araddr=addr; bus.arvalid=1;
        do @(posedge aclk); while(!bus.arready);
        @(negedge aclk); bus.arvalid=0;
        while(!bus.rvalid) @(negedge aclk);
        if(change_status) status_i=new_status;
        repeat(r_delay) begin
            @(posedge aclk);
            check32(bus.rdata,expected,"RDATA while blocked");
            check32({30'b0,bus.rresp},{30'b0,expected_resp},"RRESP while blocked");
            @(negedge aclk);
        end
        bus.rready=1;
        @(posedge aclk);
        check32(bus.rdata,expected,"RDATA");
        check32({30'b0,bus.rresp},{30'b0,expected_resp},"RRESP");
        @(negedge aclk); bus.rready=0;
        reads++;
    endtask

    initial begin
        bus.awaddr=0; bus.awvalid=0; bus.wdata=0; bus.wstrb=0; bus.wvalid=0;
        bus.bready=0; bus.araddr=0; bus.arvalid=0; bus.rready=0;
        start_case("reset and custom VERSION");
        reset_dut();
        read_reg(0,0); read_reg(8,0); read_reg(12,0); read_reg(16,VERSION);

        start_case("RW byte strobes, AW-first, W-first, simultaneous and delayed B");
        write_reg(0,32'h11223344,15,0,3,0,0,5);
        write_reg(0,32'haabbccdd,5,3,0);
        read_reg(0,32'h11bb33dd);
        write_reg(0,32'hffffffff,0);
        write_reg(8,32'h12345678);
        write_reg(8,32'haabbccdd,10);
        read_reg(8,32'haa34cc78);
        outputs(32'h11bb33dd,32'haa34cc78,0);

        start_case("all sixteen WSTRB combinations on CTRL and INTR_EN");
        for(int mask=0;mask<16;mask++) begin
            logic [31:0] expected;
            expected=0;
            for(int lane=0;lane<4;lane++)
                if((mask>>lane)&1) expected[lane*8+:8]=8'hff;
            write_reg(0,0); write_reg(0,32'hffffffff,mask);
            read_reg(0,expected);
            write_reg(8,0); write_reg(8,32'hffffffff,mask);
            read_reg(8,expected);
            outputs(expected,expected,0);
        end

        start_case("RO writes ignored; STATUS follows hardware; R snapshot stable");
        status_i=32'h87654321;
        write_reg(4,32'hffffffff);
        write_reg(16,0);
        read_reg(4,32'h87654321,0,6,1,32'h10203040);
        read_reg(4,32'h10203040);
        read_reg(16,VERSION);

        start_case("hardware set, write-zero retention, masked RW1C clearing");
        event_pulse(32'hffffffff);
        read_reg(12,32'hffffffff);
        write_reg(12,0);
        read_reg(12,32'hffffffff);
        write_reg(12,32'hffffffff,0);
        read_reg(12,32'hffffffff);
        write_reg(12,32'hffffffff,5);
        read_reg(12,32'hff00ff00);
        write_reg(12,32'hff00ff00);
        read_reg(12,0);

        start_case("set wins same-bit conflict from zero and one, all byte lanes");
        for(int lane=0;lane<4;lane++) begin
            logic [31:0] bit_mask;
            bit_mask=32'h1 << (lane*8);
            // First conflict starts from zero; second starts from one.
            write_reg(12,bit_mask,1<<lane,0,0,bit_mask);
            read_reg(12,bit_mask);
            write_reg(12,bit_mask,1<<lane,0,2,bit_mask);
            read_reg(12,bit_mask);
            write_reg(12,bit_mask,1<<lane,2,0,bit_mask);
            read_reg(12,bit_mask);
            write_reg(12,bit_mask,1<<lane);
            read_reg(12,0);
        end

        start_case("all sixteen RW1C strobe combinations and hardware in unselected lanes");
        for(int mask=0;mask<16;mask++) begin
            logic [31:0] expected, clear_mask;
            clear_mask=0;
            for(int lane=0;lane<4;lane++)
                if((mask>>lane)&1) clear_mask[lane*8+:8]=8'hff;
            event_pulse(32'hffffffff);
            expected=~clear_mask | 32'h01010101;
            write_reg(12,32'hffffffff,mask,0,0,32'h01010101);
            read_reg(12,expected);
            write_reg(12,32'hffffffff);
            read_reg(12,0);
        end

        start_case("different-bit clear/set preserves the new event");
        event_pulse(32'h00000003);
        write_reg(12,1,15,0,0,32'h00000004);
        read_reg(12,6);
        write_reg(12,32'hffffffff);
        read_reg(12,0);

        // Hardware can set a previously zero bit outside the strobed byte.
        write_reg(12,32'hffffffff,1,0,0,32'h80000000);
        read_reg(12,32'h80000000);
        write_reg(12,32'hffffffff);
        read_reg(12,0);

        start_case("unaligned and unmapped access; no legal register corruption");
        write_reg(0,32'h13579bdf);
        write_reg(8,32'h2468ace0);
        event_pulse(32'h00000055);
        for(int i=0;i<8;i++) begin
            logic [7:0] bad_addr;
            case(i)
                0: bad_addr=1; 1: bad_addr=5; 2: bad_addr=9; 3: bad_addr=13;
                4: bad_addr=17; 5: bad_addr=20; 6: bad_addr=32; 7: bad_addr=255;
            endcase
            write_reg(bad_addr,32'hffffffff,15,0,0,0,2);
            read_reg(bad_addr,0,2);
            outputs(32'h13579bdf,32'h2468ace0,32'h55);
        end
        read_reg(0,32'h13579bdf); read_reg(8,32'h2468ace0); read_reg(12,32'h55);

        start_case("reset restores written state; external STATUS and VERSION remain external/constant");
        reset_dut();
        read_reg(0,0); read_reg(8,0); read_reg(12,0);
        read_reg(4,32'h10203040); read_reg(16,VERSION);
        if(cases!=10) $fatal(1,"missing directed test cases");
        $display("PROJECT_REGS_PASS cases=%0d checks=%0d writes=%0d reads=%0d transfers=%0d",
                 cases,checks,writes,reads,writes+reads);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"PROJECT_REGS_TIMEOUT");
    end
endmodule

