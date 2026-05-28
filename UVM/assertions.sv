`ifndef AXI_LITE_ASSERTIONS_SV
`define AXI_LITE_ASSERTIONS_SV

// AXI4-Lite interface assertions for axi_lite_slave_regs.
//
// The checker is intentionally interface-level: it observes only AXI signals,
// so it can be instantiated in a testbench or bound to the DUT without using
// internal implementation signals.

module axi_lite_slave_assertions #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 8,
    parameter int REG_COUNT  = 8,
    parameter int MAX_RESP_LATENCY = 16
) (
    input  logic                     aclk,
    input  logic                     aresetn,

    input  logic [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  logic                     s_axi_awvalid,
    input  logic                     s_axi_awready,

    input  logic [DATA_WIDTH-1:0]    s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  logic                     s_axi_wvalid,
    input  logic                     s_axi_wready,

    input  logic [1:0]               s_axi_bresp,
    input  logic                     s_axi_bvalid,
    input  logic                     s_axi_bready,

    input  logic [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  logic                     s_axi_arvalid,
    input  logic                     s_axi_arready,

    input  logic [DATA_WIDTH-1:0]    s_axi_rdata,
    input  logic [1:0]               s_axi_rresp,
    input  logic                     s_axi_rvalid,
    input  logic                     s_axi_rready
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int ADDR_LSB   = $clog2(STRB_WIDTH);
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    logic [ADDR_WIDTH-1:0] awaddr_q;
    logic                  aw_seen_q;
    logic                  w_seen_q;
    logic                  write_pending_q;
    logic                  read_pending_q;

    wire aw_hs = s_axi_awvalid && s_axi_awready;
    wire w_hs  = s_axi_wvalid  && s_axi_wready;
    wire b_hs  = s_axi_bvalid  && s_axi_bready;
    wire ar_hs = s_axi_arvalid && s_axi_arready;
    wire r_hs  = s_axi_rvalid  && s_axi_rready;

    wire [ADDR_WIDTH-1:0] write_addr = aw_seen_q ? awaddr_q : s_axi_awaddr;
    wire write_addr_aligned = write_addr[ADDR_LSB-1:0] == '0;
    wire read_addr_aligned  = s_axi_araddr[ADDR_LSB-1:0] == '0;
    wire [ADDR_WIDTH-ADDR_LSB-1:0] write_word_addr = write_addr[ADDR_WIDTH-1:ADDR_LSB];
    wire [ADDR_WIDTH-ADDR_LSB-1:0] read_word_addr  = s_axi_araddr[ADDR_WIDTH-1:ADDR_LSB];
    wire write_addr_valid = write_addr_aligned && (write_word_addr < REG_COUNT);
    wire read_addr_valid  = read_addr_aligned  && (read_word_addr  < REG_COUNT);

    wire write_complete = (aw_seen_q || aw_hs) && (w_seen_q || w_hs);

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            awaddr_q        <= '0;
            aw_seen_q       <= 1'b0;
            w_seen_q        <= 1'b0;
            write_pending_q <= 1'b0;
            read_pending_q  <= 1'b0;
        end else begin
            if (aw_hs && !write_complete) begin
                awaddr_q  <= s_axi_awaddr;
                aw_seen_q <= 1'b1;
            end

            if (w_hs && !write_complete) begin
                w_seen_q <= 1'b1;
            end

            if (write_complete) begin
                aw_seen_q       <= 1'b0;
                w_seen_q        <= 1'b0;
                write_pending_q <= 1'b1;
            end else if (b_hs) begin
                write_pending_q <= 1'b0;
            end

            if (ar_hs) begin
                read_pending_q <= 1'b1;
            end else if (r_hs) begin
                read_pending_q <= 1'b0;
            end
        end
    end

    default clocking cb @(posedge aclk);
    endclocking

    // -------------------------
    // Global/reset/X checking
    // -------------------------

    a_reset_clears_responses:
        assert property (!aresetn |=> (!s_axi_bvalid && !s_axi_rvalid))
        else $error("AXI-Lite reset protocol violation: BVALID/RVALID must be low in reset");

    a_no_unknown_control:
        assert property (disable iff (!aresetn)
            !$isunknown({
                s_axi_awvalid, s_axi_awready,
                s_axi_wvalid,  s_axi_wready,
                s_axi_bvalid,  s_axi_bready,
                s_axi_arvalid, s_axi_arready,
                s_axi_rvalid,  s_axi_rready
            }))
        else $error("AXI-Lite protocol violation: VALID/READY contains X/Z");

    // -------------------------
    // Write address channel
    // -------------------------

    a_awaddr_stable_until_handshake:
        assert property (disable iff (!aresetn)
            s_axi_awvalid && !s_axi_awready |=> s_axi_awvalid && $stable(s_axi_awaddr))
        else $error("AXI-Lite AW protocol violation: AWADDR/AWVALID changed before AW handshake");

    a_no_second_aw_before_write_response:
        assert property (disable iff (!aresetn)
            aw_seen_q |-> !aw_hs)
        else $error("AXI-Lite AW protocol violation: second AW accepted before previous write address was consumed");

    // -------------------------
    // Write data channel
    // -------------------------

    a_wdata_stable_until_handshake:
        assert property (disable iff (!aresetn)
            s_axi_wvalid && !s_axi_wready |=>
                s_axi_wvalid && $stable(s_axi_wdata) && $stable(s_axi_wstrb))
        else $error("AXI-Lite W protocol violation: WDATA/WSTRB/WVALID changed before W handshake");

    a_no_second_w_before_write_response:
        assert property (disable iff (!aresetn)
            w_seen_q |-> !w_hs)
        else $error("AXI-Lite W protocol violation: second W accepted before previous write data was consumed");

    // -------------------------
    // Write response channel
    // -------------------------

    a_bvalid_only_after_aw_and_w:
        assert property (disable iff (!aresetn)
            $rose(s_axi_bvalid) |-> $past(write_pending_q || write_complete))
        else $error("AXI-Lite B protocol violation: BVALID rose before both AW and W handshakes completed");

    a_bresp_stable_until_handshake:
        assert property (disable iff (!aresetn)
            s_axi_bvalid && !s_axi_bready |=> s_axi_bvalid && $stable(s_axi_bresp))
        else $error("AXI-Lite B protocol violation: BRESP/BVALID changed before B handshake");

    a_bresp_legal_value:
        assert property (disable iff (!aresetn)
            s_axi_bvalid |-> (s_axi_bresp inside {RESP_OKAY, RESP_SLVERR}))
        else $error("AXI-Lite B protocol violation: BRESP must be OKAY or SLVERR");

    a_write_response_latency:
        assert property (disable iff (!aresetn)
            write_complete |-> ##[0:MAX_RESP_LATENCY] s_axi_bvalid)
        else $error("AXI-Lite B protocol violation: write response latency exceeded MAX_RESP_LATENCY");

    a_invalid_write_gets_slverr:
        assert property (disable iff (!aresetn)
            write_complete && !write_addr_valid |-> ##[0:MAX_RESP_LATENCY]
                (s_axi_bvalid && s_axi_bresp == RESP_SLVERR))
        else $error("AXI-Lite address protocol violation: invalid write did not return SLVERR");

    // -------------------------
    // Read address channel
    // -------------------------

    a_araddr_stable_until_handshake:
        assert property (disable iff (!aresetn)
            s_axi_arvalid && !s_axi_arready |=> s_axi_arvalid && $stable(s_axi_araddr))
        else $error("AXI-Lite AR protocol violation: ARADDR/ARVALID changed before AR handshake");

    a_no_second_ar_before_read_response:
        assert property (disable iff (!aresetn)
            read_pending_q |-> !ar_hs)
        else $error("AXI-Lite AR protocol violation: second AR accepted before previous read response completed");

    // -------------------------
    // Read response channel
    // -------------------------

    a_rvalid_only_after_ar:
        assert property (disable iff (!aresetn)
            $rose(s_axi_rvalid) |-> $past(read_pending_q || ar_hs))
        else $error("AXI-Lite R protocol violation: RVALID rose before AR handshake completed");

    a_rdata_stable_until_handshake:
        assert property (disable iff (!aresetn)
            s_axi_rvalid && !s_axi_rready |=>
                s_axi_rvalid && $stable(s_axi_rdata) && $stable(s_axi_rresp))
        else $error("AXI-Lite R protocol violation: RDATA/RRESP/RVALID changed before R handshake");

    a_rresp_legal_value:
        assert property (disable iff (!aresetn)
            s_axi_rvalid |-> (s_axi_rresp inside {RESP_OKAY, RESP_SLVERR}))
        else $error("AXI-Lite R protocol violation: RRESP must be OKAY or SLVERR");

    a_read_response_latency:
        assert property (disable iff (!aresetn)
            ar_hs |-> ##[0:MAX_RESP_LATENCY] s_axi_rvalid)
        else $error("AXI-Lite R protocol violation: read response latency exceeded MAX_RESP_LATENCY");

    a_invalid_read_gets_slverr:
        assert property (disable iff (!aresetn)
            ar_hs && !read_addr_valid |-> ##[0:MAX_RESP_LATENCY]
                (s_axi_rvalid && s_axi_rresp == RESP_SLVERR))
        else $error("AXI-Lite address protocol violation: invalid read did not return SLVERR");

endmodule

`endif
