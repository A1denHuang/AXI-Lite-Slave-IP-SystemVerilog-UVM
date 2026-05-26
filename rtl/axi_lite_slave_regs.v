`timescale 1ns/1ps

module axi_lite_slave_regs #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 8,
    parameter integer REG_COUNT  = 8
) (
    input  wire                     aclk,
    input  wire                     aresetn,

    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,

    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,

    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready,

    output wire [REG_COUNT*DATA_WIDTH-1:0] regs_flat
);

    localparam integer STRB_WIDTH = DATA_WIDTH / 8;
    localparam integer ADDR_LSB   = clog2(STRB_WIDTH);
    localparam [1:0]   RESP_OKAY  = 2'b00;
    localparam [1:0]   RESP_SLVERR = 2'b10;

    reg [DATA_WIDTH-1:0] regs [0:REG_COUNT-1];
    reg [ADDR_WIDTH-1:0] awaddr_hold;
    reg                  awaddr_valid;
    reg [DATA_WIDTH-1:0] wdata_hold;
    reg [STRB_WIDTH-1:0] wstrb_hold;
    reg                  wdata_valid;

    wire aw_accept = s_axi_awready && s_axi_awvalid;
    wire w_accept  = s_axi_wready && s_axi_wvalid;
    wire write_fire = !s_axi_bvalid &&
                      (awaddr_valid || aw_accept) &&
                      (wdata_valid  || w_accept);
    wire read_fire  = s_axi_arready && s_axi_arvalid;

    wire [ADDR_WIDTH-1:0] write_addr = awaddr_valid ? awaddr_hold : s_axi_awaddr;
    wire [DATA_WIDTH-1:0] write_data = wdata_valid ? wdata_hold : s_axi_wdata;
    wire [STRB_WIDTH-1:0] write_strb = wdata_valid ? wstrb_hold : s_axi_wstrb;

    wire [ADDR_WIDTH-ADDR_LSB-1:0] write_word_addr = write_addr[ADDR_WIDTH-1:ADDR_LSB];
    wire [ADDR_WIDTH-ADDR_LSB-1:0] read_word_addr =
        s_axi_araddr[ADDR_WIDTH-1:ADDR_LSB];

    wire write_addr_aligned = write_addr[ADDR_LSB-1:0] == {ADDR_LSB{1'b0}};
    wire read_addr_aligned  = s_axi_araddr[ADDR_LSB-1:0] == {ADDR_LSB{1'b0}};
    wire write_addr_valid   = write_addr_aligned && (write_word_addr < REG_COUNT);
    wire read_addr_valid    = read_addr_aligned  && (read_word_addr  < REG_COUNT);

    assign s_axi_awready = !awaddr_valid && !s_axi_bvalid;
    assign s_axi_wready  = !wdata_valid  && !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    genvar g;
    generate
        for (g = 0; g < REG_COUNT; g = g + 1) begin : gen_regs_flat
            assign regs_flat[g*DATA_WIDTH +: DATA_WIDTH] = regs[g];
        end
    endgenerate

    integer i;
    integer b;

    always @(posedge aclk) begin
        if (!aresetn) begin
            for (i = 0; i < REG_COUNT; i = i + 1) begin
                regs[i] <= {DATA_WIDTH{1'b0}};
            end
            awaddr_hold  <= {ADDR_WIDTH{1'b0}};
            awaddr_valid <= 1'b0;
            wdata_hold   <= {DATA_WIDTH{1'b0}};
            wstrb_hold   <= {STRB_WIDTH{1'b0}};
            wdata_valid  <= 1'b0;
            s_axi_bresp  <= RESP_OKAY;
            s_axi_bvalid <= 1'b0;
        end else begin
            if (aw_accept && !write_fire) begin
                awaddr_hold  <= s_axi_awaddr;
                awaddr_valid <= 1'b1;
            end

            if (w_accept && !write_fire) begin
                wdata_hold  <= s_axi_wdata;
                wstrb_hold  <= s_axi_wstrb;
                wdata_valid <= 1'b1;
            end

            if (write_fire) begin
                if (write_addr_valid) begin
                    for (b = 0; b < STRB_WIDTH; b = b + 1) begin
                        if (write_strb[b]) begin
                            regs[write_word_addr][b*8 +: 8] <= write_data[b*8 +: 8];
                        end
                    end
                    s_axi_bresp <= RESP_OKAY;
                end else begin
                    s_axi_bresp <= RESP_SLVERR;
                end
                s_axi_bvalid <= 1'b1;
                awaddr_valid <= 1'b0;
                wdata_valid  <= 1'b0;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_rdata  <= {DATA_WIDTH{1'b0}};
            s_axi_rresp  <= RESP_OKAY;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (read_fire) begin
                if (read_addr_valid) begin
                    s_axi_rdata <= regs[read_word_addr];
                    s_axi_rresp <= RESP_OKAY;
                end else begin
                    s_axi_rdata <= {DATA_WIDTH{1'b0}};
                    s_axi_rresp <= RESP_SLVERR;
                end
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1) begin
                v = v >> 1;
            end
        end
    endfunction

endmodule
