`timescale 1ns/1ps

// Deliberately failing, standalone learning bench.  It is compiled only by
// sim/run_fault_injection_rdata.do and is never part of the normal regression.
module fault_injection_rdata_stability;
    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 8;
    localparam int REG_COUNT  = 4;

    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    logic [ADDR_WIDTH-1:0] awaddr = '0;
    logic awvalid = 1'b0;
    wire  awready;
    logic [DATA_WIDTH-1:0] wdata = '0;
    logic [DATA_WIDTH/8-1:0] wstrb = '0;
    logic wvalid = 1'b0;
    wire  wready;
    wire [1:0] bresp;
    wire bvalid;
    logic bready = 1'b0;
    logic [ADDR_WIDTH-1:0] araddr = '0;
    logic arvalid = 1'b0;
    wire arready;
    wire [DATA_WIDTH-1:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    logic rready = 1'b0;
    wire [REG_COUNT*DATA_WIDTH-1:0] regs_flat;

    always #5 aclk = ~aclk;

    axi_lite_slave_regs #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_COUNT(REG_COUNT)
    ) dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .regs_flat(regs_flat)
    );

    axi_lite_slave_assertions #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .REG_COUNT(REG_COUNT)
    ) checker_i (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
    );

    initial begin
        repeat (5) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        araddr  <= 8'h00;
        arvalid <= 1'b1;
        do @(posedge aclk); while (!(arvalid && arready));
        arvalid <= 1'b0;

        wait (rvalid === 1'b1);
        // Let the assertion sample one stalled response before changing it.
        @(posedge aclk);
        @(negedge aclk);
        $display("EXPECTED_FAILURE_INJECTION: changing RDATA while RVALID=1 and RREADY=0");
        force dut.s_axi_rdata = 32'hDEAD_BEEF;
        @(negedge aclk);
        release dut.s_axi_rdata;

        rready <= 1'b1;
        do @(posedge aclk); while (!(rvalid && rready));
        rready <= 1'b0;
        repeat (2) @(posedge aclk);
        $display("EXPECTED_FAILURE_COMPLETE: a_rdata_stable_until_handshake should have fired");
        $finish;
    end
endmodule
