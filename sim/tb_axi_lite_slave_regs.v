`timescale 1ns/1ps

module tb_axi_lite_slave_regs;
    localparam integer DATA_WIDTH = 32;
    localparam integer ADDR_WIDTH = 8;
    localparam integer REG_COUNT  = 4;

    reg                      aclk;
    reg                      aresetn;
    reg  [ADDR_WIDTH-1:0]    s_axi_awaddr;
    reg                      s_axi_awvalid;
    wire                     s_axi_awready;
    reg  [DATA_WIDTH-1:0]    s_axi_wdata;
    reg  [DATA_WIDTH/8-1:0]  s_axi_wstrb;
    reg                      s_axi_wvalid;
    wire                     s_axi_wready;
    wire [1:0]               s_axi_bresp;
    wire                     s_axi_bvalid;
    reg                      s_axi_bready;
    reg  [ADDR_WIDTH-1:0]    s_axi_araddr;
    reg                      s_axi_arvalid;
    wire                     s_axi_arready;
    wire [DATA_WIDTH-1:0]    s_axi_rdata;
    wire [1:0]               s_axi_rresp;
    wire                     s_axi_rvalid;
    reg                      s_axi_rready;
    wire [REG_COUNT*DATA_WIDTH-1:0] regs_flat;

    axi_lite_slave_regs #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_COUNT(REG_COUNT)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .regs_flat(regs_flat)
    );

    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk;
    end

    initial begin
        aresetn       = 1'b0;
        s_axi_awaddr  = {ADDR_WIDTH{1'b0}};
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = {DATA_WIDTH{1'b0}};
        s_axi_wstrb   = {DATA_WIDTH/8{1'b0}};
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = {ADDR_WIDTH{1'b0}};
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        repeat (2) @(posedge aclk);

        axi_write(8'h00, 32'h1234_5678, 4'hF, 2'b00);
        axi_read(8'h00, 32'h1234_5678, 2'b00);

        axi_write(8'h00, 32'hABCD_EF00, 4'b1100, 2'b00);
        axi_read(8'h00, 32'hABCD_5678, 2'b00);

        axi_write(8'h04, 32'hAAAA_5555, 4'hF, 2'b00);
        axi_read(8'h04, 32'hAAAA_5555, 2'b00);

        axi_write(8'h08, 32'hFFFF_0000, 4'hF, 2'b00);
        axi_read(8'h08, 32'hFFFF_0000, 2'b00);

        axi_write(8'h20, 32'hDEAD_BEEF, 4'hF, 2'b10);
        axi_read(8'h20, 32'h0000_0000, 2'b10);
        axi_read(8'h24, 32'h0000_0000, 2'b10);

        axi_write(8'h01, 32'hCAFE_BABE, 4'hF, 2'b10);
        axi_read(8'h01, 32'h0000_0000, 2'b10);

        $display("PASS");
        $finish;
    end

    task axi_write;
        input [ADDR_WIDTH-1:0]   addr;
        input [DATA_WIDTH-1:0]   data;
        input [DATA_WIDTH/8-1:0] strb;
        input [1:0]              exp_resp;
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= strb;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            fork
                begin
                    wait (s_axi_awready);
                    @(posedge aclk);
                    s_axi_awvalid <= 1'b0;
                end
                begin
                    wait (s_axi_wready);
                    @(posedge aclk);
                    s_axi_wvalid <= 1'b0;
                end
            join

            wait (s_axi_bvalid);
            if (s_axi_bresp !== exp_resp) begin
                $display("WRITE RESP ERROR: addr=%h resp=%b expected=%b", addr, s_axi_bresp, exp_resp);
                $fatal;
            end
            @(posedge aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    task axi_read;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] exp_data;
        input [1:0]            exp_resp;
        begin
            @(posedge aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            wait (s_axi_arready);
            @(posedge aclk);
            s_axi_arvalid <= 1'b0;

            wait (s_axi_rvalid);
            if (s_axi_rresp !== exp_resp || s_axi_rdata !== exp_data) begin
                $display("READ ERROR: addr=%h data=%h resp=%b expected_data=%h expected_resp=%b",
                         addr, s_axi_rdata, s_axi_rresp, exp_data, exp_resp);
                $fatal;
            end
            @(posedge aclk);
            s_axi_rready <= 1'b0;
        end
    endtask

endmodule
