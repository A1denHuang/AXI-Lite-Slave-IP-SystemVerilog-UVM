`ifndef AXI_LITE_IF_SV
`define AXI_LITE_IF_SV

interface axi_lite_if #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 8
) (
    input logic aclk,
    input logic aresetn
);

    logic [ADDR_WIDTH-1:0]   awaddr;
    logic                    awvalid;
    logic                    awready;
    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                    wvalid;
    logic                    wready;
    logic [1:0]              bresp;
    logic                    bvalid;
    logic                    bready;
    logic [ADDR_WIDTH-1:0]   araddr;
    logic                    arvalid;
    logic                    arready;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;
    logic                    rvalid;
    logic                    rready;

    clocking drv_cb @(posedge aclk);
        output awaddr, awvalid, wdata, wstrb, wvalid, bready;
        output araddr, arvalid, rready;
        input  awready, wready, bresp, bvalid;
        input  arready, rdata, rresp, rvalid;
    endclocking

    clocking mon_cb @(posedge aclk);
        input awaddr, awvalid, awready;
        input wdata, wstrb, wvalid, wready;
        input bresp, bvalid, bready;
        input araddr, arvalid, arready;
        input rdata, rresp, rvalid, rready;
    endclocking

endinterface

`endif
