`timescale 1ns/1ps

module top_tb;
    import uvm_pkg::*;
    import axi_lite_pkg::*;

    localparam int DATA_WIDTH = AXI_DATA_WIDTH;
    localparam int ADDR_WIDTH = AXI_ADDR_WIDTH;
    localparam int REG_COUNT  = AXI_REG_COUNT;

    logic aclk;
    logic aresetn;
    wire [REG_COUNT*DATA_WIDTH-1:0] regs_flat;

    axi_lite_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_if (
        .aclk(aclk),
        .aresetn(aresetn)
    );

    axi_lite_slave_regs #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_COUNT(REG_COUNT)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(axi_if.awaddr),
        .s_axi_awvalid(axi_if.awvalid),
        .s_axi_awready(axi_if.awready),
        .s_axi_wdata(axi_if.wdata),
        .s_axi_wstrb(axi_if.wstrb),
        .s_axi_wvalid(axi_if.wvalid),
        .s_axi_wready(axi_if.wready),
        .s_axi_bresp(axi_if.bresp),
        .s_axi_bvalid(axi_if.bvalid),
        .s_axi_bready(axi_if.bready),
        .s_axi_araddr(axi_if.araddr),
        .s_axi_arvalid(axi_if.arvalid),
        .s_axi_arready(axi_if.arready),
        .s_axi_rdata(axi_if.rdata),
        .s_axi_rresp(axi_if.rresp),
        .s_axi_rvalid(axi_if.rvalid),
        .s_axi_rready(axi_if.rready),
        .regs_flat(regs_flat)
    );

    axi_lite_slave_assertions #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_COUNT(REG_COUNT),
        .MAX_RESP_LATENCY(16)
    ) axi_assert_i (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(axi_if.awaddr),
        .s_axi_awvalid(axi_if.awvalid),
        .s_axi_awready(axi_if.awready),
        .s_axi_wdata(axi_if.wdata),
        .s_axi_wstrb(axi_if.wstrb),
        .s_axi_wvalid(axi_if.wvalid),
        .s_axi_wready(axi_if.wready),
        .s_axi_bresp(axi_if.bresp),
        .s_axi_bvalid(axi_if.bvalid),
        .s_axi_bready(axi_if.bready),
        .s_axi_araddr(axi_if.araddr),
        .s_axi_arvalid(axi_if.arvalid),
        .s_axi_arready(axi_if.arready),
        .s_axi_rdata(axi_if.rdata),
        .s_axi_rresp(axi_if.rresp),
        .s_axi_rvalid(axi_if.rvalid),
        .s_axi_rready(axi_if.rready)
    );

    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk;
    end

    initial begin
        aresetn = 1'b0;
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual axi_lite_if #(DATA_WIDTH, ADDR_WIDTH))::set(
            null, "uvm_test_top.env.agent.*", "vif", axi_if);
        run_test();
    end
endmodule
