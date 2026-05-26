# AXI-Lite-Slave-IP-SystemVerilog-UVM
A parameterized AXI4-Lite Slave Register IP along with a complete verification environment built using SystemVerilog/UVM

## 1. 项目整体架构

该项目提供了一套**参数化、可复用的 AXI4-Lite Slave Register IP**，用于快速为 SoC/ASIC 项目生成寄存器映射接口。主要包含两个核心模块：

- **axi_lite_slave_regs.v**：**通用参数化寄存器 IP**（推荐在大多数项目中使用）
- **axi_lite_slave_project_regs.v**：**项目特定（硬编码）寄存器 IP**（针对特定寄存器定义的示例实现）

配套提供了一个**基础验证环境**（Testbench），用于验证 AXI4-Lite 寄存器访问的正确性，包括对齐检查、部分字节写（STRB）、错误响应（SLVERR）等功能。

## 2.文件概览

#### **(1) axi_lite_slave_regs.v** —— 通用参数化 AXI4-Lite Slave Register IP

这是项目的**核心可复用组件**。

**主要特性：**

- **参数化设计**：
  - DATA_WIDTH：默认 32bit，可扩展
  - ADDR_WIDTH：地址宽度，默认 8bit（支持 256 字节空间）
  - REG_COUNT：寄存器数量（每个寄存器占 DATA_WIDTH）
- **接口**：
  - 标准 AXI4-Lite Slave 接口（AW、W、B、AR、R）
  - 输出 regs_flat：所有寄存器平铺输出，便于连接到上层模块
- **关键功能**：
  - 支持**字节使能**（WSTRB）部分写入
  - 地址对齐检查（必须 4 字节对齐）
  - 非法地址返回 SLVERR
  - 握手机制（支持 AW/W 分离到达）
  - 复位后所有寄存器清零
- **实现亮点**：
  - 使用 write_fire 信号统一处理写事务
  - 地址映射采用 word_addr（自动除以 4）
  - 使用 generate 块生成 regs_flat 输出

#### **(2) axi_lite_slave_project_regs.v** —— 项目专用寄存器 IP

这是一个**具体项目**的寄存器映射示例，展示了如何基于通用模板定制特殊寄存器行为。

**寄存器映射（偏移地址）：**

| 地址 | 名称        | 类型 | 功能描述                                             |
| ---- | ----------- | ---- | ---------------------------------------------------- |
| 0x00 | CTRL        | RW   | 控制寄存器                                           |
| 0x04 | STATUS      | RO   | 状态输入（来自外部 status_i）                        |
| 0x08 | INTR_EN     | RW   | 中断使能                                             |
| 0x0C | INTR_STATUS | RW1C | 中断状态（支持外部 intr_status_set_i 置位，写1清零） |
| 0x10 | VERSION     | RO   | 只读版本号（parameter VERSION_VALUE）                |

**特色功能**：

- 中断状态寄存器实现 **RW1C + 外部置位** 逻辑（常见中断控制器设计）
- 固定地址映射 + is_valid_addr 函数
- 同样支持字节写和错误响应

#### **(3) tb_axi_lite_slave_regs.v** —— 验证环境（Testbench）

针对**通用寄存器 IP** 的基础定向测试。

**测试内容覆盖：**

- 正常单字写读
- **部分字节写入**（WSTRB = 4'b1100）
- **非法地址**访问（返回 SLVERR）
- **非对齐地址**访问（返回 SLVERR）
- 基本握手时序验证

**测试流程**：

1. 复位
2. 正常写读 0x00、0x04、0x08
3. 部分字节写测试
4. 错误响应测试（地址 0x20、0x01）
