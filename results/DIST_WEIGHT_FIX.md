# AXI-Lite 地址 `dist` 权重修正验证

验证日期：2026-10-31（Asia/Shanghai）

## 修正内容

`UVM/axi_lite_agent/axi_lite_item.sv` 的地址约束由 `:=` 改为 `:/`，使三个地址范围的整体目标权重为 70/15/15。

旧写法 `:=` 会把权重赋给范围内每个值。其理论分布为：

| 地址范围 | 总权重 | 理论比例 |
| --- | ---: | ---: |
| `0x00-0x0F` | `16×70=1120` | 23.73% |
| `0x10-0x1F` | `16×15=240` | 5.08% |
| `0x20-0xFF` | `224×15=3360` | 71.19% |

四个合法地址 `0x00/0x04/0x08/0x0C` 在旧写法下的理论占比为 `4×70/4720=5.93%`。改为 `:/` 后，`0x00-0x0F` 整段占 70%，因此四个合法地址的理论总占比为 `70%×4/16=17.5%`。

## 定向回归证据

执行配置：

- test：`axi_lite_random_test`
- seed：`20261031`
- transactions：`1000`
- simulator：QuestaSim 10.7c

结果：

- 编译 errors/warnings：`0/0`
- UVM errors/fatals：`0/0`
- assertion failures：`0`
- `cp_addr`：17/17 bins covered，100%
- `cp_addr_kind`：3/3 bins covered，100%
- 地址类别命中：legal 187、unaligned 758、out-of-range 55
- legal 实测比例：18.7%，与 17.5% 的理论目标相符（有限样本允许随机波动）
- 单次运行总 functional coverage：98.81%；缺口位于 `cx_write_addr_wstrb` 的 4 个交叉 bin，不是地址 coverpoint

这次结果同时说明：coverpoint 的 bin 全部命中只证明覆盖目标出现过，不能证明激励概率写法正确。
