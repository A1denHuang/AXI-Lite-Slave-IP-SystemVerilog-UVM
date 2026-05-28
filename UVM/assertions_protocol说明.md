# AXI-Lite Assertions Protocol 说明

本文档对应 `UVM/assertions.sv` 中的 `axi_lite_slave_assertions`。
该 checker 只观察 AXI4-Lite 接口信号，不依赖 DUT 内部信号，因此可以在 testbench 中例化，也可以用 `bind` 绑定到 RTL。

## 1. 全局与复位协议

- `a_reset_clears_responses`

  复位期间 `BVALID` 和 `RVALID` 必须为 0。这样可以保证复位后不会遗留旧的写响应或读响应。

- `a_no_unknown_control`

  复位释放后，所有 `VALID/READY` 控制信号不能出现 `X/Z`。AXI 握手依赖这些信号，未知态会导致事务是否发生无法判定。

## 2. 写地址通道 AW

- `a_awaddr_stable_until_handshake`

  当 master 拉高 `AWVALID` 但 slave 尚未拉高 `AWREADY` 时，`AWVALID` 必须保持为 1，`AWADDR` 必须保持稳定，直到握手完成。

- `a_no_second_aw_before_write_response`

  当前设计一次只缓存一个写地址。在前一个写地址尚未与写数据组成完整写事务前，不允许 slave 接收第二个 AW。

## 3. 写数据通道 W

- `a_wdata_stable_until_handshake`

  当 `WVALID=1` 且 `WREADY=0` 时，`WDATA`、`WSTRB` 和 `WVALID` 必须保持稳定，直到 W 通道握手完成。

- `a_no_second_w_before_write_response`

  当前设计一次只缓存一个写数据。在前一个写数据尚未与写地址组成完整写事务前，不允许 slave 接收第二个 W。

## 4. 写响应通道 B

- `a_bvalid_only_after_aw_and_w`

  `BVALID` 只能在 AW 和 W 两个通道都完成握手后产生。AXI4-Lite 写事务必须同时拥有地址和数据后才允许返回写响应。

- `a_bresp_stable_until_handshake`

  当 `BVALID=1` 且 `BREADY=0` 时，`BRESP` 和 `BVALID` 必须保持稳定，直到 B 通道握手完成。

- `a_bresp_legal_value`

  当前 RTL 只使用 `OKAY(2'b00)` 和 `SLVERR(2'b10)`。如果出现其他响应编码，说明响应生成逻辑异常。

- `a_write_response_latency`

  当完整写事务形成后，必须在 `MAX_RESP_LATENCY` 个周期内看到 `BVALID`。这是活性检查，用来发现响应丢失或状态机卡死。

- `a_invalid_write_gets_slverr`

  如果写地址越界或未按数据宽度对齐，写响应必须返回 `SLVERR`。

## 5. 读地址通道 AR

- `a_araddr_stable_until_handshake`

  当 `ARVALID=1` 且 `ARREADY=0` 时，`ARVALID` 必须保持为 1，`ARADDR` 必须保持稳定，直到 AR 通道握手完成。

- `a_no_second_ar_before_read_response`

  当前设计一次只处理一个 outstanding read。在上一笔读响应完成前，不允许 slave 接收第二个 AR。

## 6. 读响应通道 R

- `a_rvalid_only_after_ar`

  `RVALID` 只能在 AR 通道完成握手后产生。没有读地址事务时，不应凭空返回读数据。

- `a_rdata_stable_until_handshake`

  当 `RVALID=1` 且 `RREADY=0` 时，`RDATA`、`RRESP` 和 `RVALID` 必须保持稳定，直到 R 通道握手完成。

- `a_rresp_legal_value`

  当前 RTL 只使用 `OKAY(2'b00)` 和 `SLVERR(2'b10)`。如果出现其他响应编码，说明读响应逻辑异常。

- `a_read_response_latency`

  当 AR 握手完成后，必须在 `MAX_RESP_LATENCY` 个周期内看到 `RVALID`。

- `a_invalid_read_gets_slverr`

  如果读地址越界或未按数据宽度对齐，读响应必须返回 `SLVERR`，同时 RTL 返回全 0 数据。

## 7. 例化方式

在普通 testbench 中可以直接例化：

```systemverilog
axi_lite_slave_assertions #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .REG_COUNT(REG_COUNT),
    .MAX_RESP_LATENCY(16)
) axi_assert_i (
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
    .s_axi_rready(s_axi_rready)
);
```

也可以在独立 bind 文件中绑定到 `axi_lite_slave_regs`，但需要确保参数和端口名与 DUT 一致。
