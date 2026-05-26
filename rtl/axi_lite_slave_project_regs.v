`timescale 1ns/1ps

module axi_lite_slave_project_regs #(
    parameter [31:0] VERSION_VALUE = 32'h0001_0000
) (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [7:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [7:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    output wire [31:0] ctrl_o,
    input  wire [31:0] status_i,
    output wire [31:0] intr_en_o,
    input  wire [31:0] intr_status_set_i,
    output wire [31:0] intr_status_o
);

    localparam [7:0] ADDR_CTRL        = 8'h00;
    localparam [7:0] ADDR_STATUS      = 8'h04;
    localparam [7:0] ADDR_INTR_EN     = 8'h08;
    localparam [7:0] ADDR_INTR_STATUS = 8'h0C;
    localparam [7:0] ADDR_VERSION     = 8'h10;

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    reg [7:0]  awaddr_hold;
    reg        awaddr_valid;
    reg [31:0] wdata_hold;
    reg [3:0]  wstrb_hold;
    reg        wdata_valid;

    reg [31:0] ctrl_reg;
    reg [31:0] intr_en_reg;
    reg [31:0] intr_status_reg;

    wire aw_accept  = s_axi_awready && s_axi_awvalid;
    wire w_accept   = s_axi_wready && s_axi_wvalid;
    wire write_fire = !s_axi_bvalid &&
                      (awaddr_valid || aw_accept) &&
                      (wdata_valid  || w_accept);
    wire read_fire  = s_axi_arready && s_axi_arvalid;

    wire [7:0]  write_addr = awaddr_valid ? awaddr_hold : s_axi_awaddr;
    wire [31:0] write_data = wdata_valid ? wdata_hold : s_axi_wdata;
    wire [3:0]  write_strb = wdata_valid ? wstrb_hold : s_axi_wstrb;

    wire write_addr_aligned = write_addr[1:0] == 2'b00;
    wire read_addr_aligned  = s_axi_araddr[1:0] == 2'b00;
    wire write_addr_valid   = write_addr_aligned && is_valid_addr(write_addr);
    wire read_addr_valid    = read_addr_aligned  && is_valid_addr(s_axi_araddr);

    assign s_axi_awready = !awaddr_valid && !s_axi_bvalid;
    assign s_axi_wready  = !wdata_valid  && !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    assign ctrl_o        = ctrl_reg;
    assign intr_en_o     = intr_en_reg;
    assign intr_status_o = intr_status_reg;

    integer b;

    always @(posedge aclk) begin
        if (!aresetn) begin
            awaddr_hold     <= 8'h00;
            awaddr_valid    <= 1'b0;
            wdata_hold      <= 32'h0000_0000;
            wstrb_hold      <= 4'h0;
            wdata_valid     <= 1'b0;
            ctrl_reg        <= 32'h0000_0000;
            intr_en_reg     <= 32'h0000_0000;
            intr_status_reg <= 32'h0000_0000;
            s_axi_bresp     <= RESP_OKAY;
            s_axi_bvalid    <= 1'b0;
        end else begin
            intr_status_reg <= intr_status_reg | intr_status_set_i;

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
                    case (write_addr)
                        ADDR_CTRL: begin
                            for (b = 0; b < 4; b = b + 1) begin
                                if (write_strb[b]) begin
                                    ctrl_reg[b*8 +: 8] <= write_data[b*8 +: 8];
                                end
                            end
                        end
                        ADDR_INTR_EN: begin
                            for (b = 0; b < 4; b = b + 1) begin
                                if (write_strb[b]) begin
                                    intr_en_reg[b*8 +: 8] <= write_data[b*8 +: 8];
                                end
                            end
                        end
                        ADDR_INTR_STATUS: begin
                            for (b = 0; b < 4; b = b + 1) begin
                                if (write_strb[b]) begin
                                    intr_status_reg[b*8 +: 8] <=
                                        (intr_status_reg[b*8 +: 8] | intr_status_set_i[b*8 +: 8]) &
                                        ~write_data[b*8 +: 8];
                                end
                            end
                        end
                        default: begin
                        end
                    endcase
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
            s_axi_rdata  <= 32'h0000_0000;
            s_axi_rresp  <= RESP_OKAY;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (read_fire) begin
                if (read_addr_valid) begin
                    case (s_axi_araddr)
                        ADDR_CTRL:        s_axi_rdata <= ctrl_reg;
                        ADDR_STATUS:      s_axi_rdata <= status_i;
                        ADDR_INTR_EN:     s_axi_rdata <= intr_en_reg;
                        ADDR_INTR_STATUS: s_axi_rdata <= intr_status_reg;
                        ADDR_VERSION:     s_axi_rdata <= VERSION_VALUE;
                        default:          s_axi_rdata <= 32'h0000_0000;
                    endcase
                    s_axi_rresp <= RESP_OKAY;
                end else begin
                    s_axi_rdata <= 32'h0000_0000;
                    s_axi_rresp <= RESP_SLVERR;
                end
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    function is_valid_addr;
        input [7:0] addr;
        begin
            case (addr)
                ADDR_CTRL,
                ADDR_STATUS,
                ADDR_INTR_EN,
                ADDR_INTR_STATUS,
                ADDR_VERSION: is_valid_addr = 1'b1;
                default:      is_valid_addr = 1'b0;
            endcase
        end
    endfunction

endmodule
