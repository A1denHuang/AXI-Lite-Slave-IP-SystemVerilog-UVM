# AXI4-Lite Slave Register IP + UVM Verification

A parameterized AXI4-Lite slave register block in Verilog, with a UVM
testbench, interface-level SVA checkers, and a seed-swept coverage regression
run on QuestaSim 10.7c.

## RTL

### `rtl/axi_lite_slave_regs.v` (verified DUT)

Generic register file behind an AXI4-Lite slave port.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `DATA_WIDTH` | 32 | Register / data bus width |
| `ADDR_WIDTH` | 8 | Byte address width |
| `REG_COUNT` | 8 | Number of registers |

Behavior:

- AW and W may arrive in either order or in the same cycle. Each channel has a
  one-entry hold register; the write executes once both are present and no
  write response is pending.
- One outstanding write and one outstanding read at a time (`AWREADY`/`WREADY`
  drop while a beat is held or `BVALID` is high, `ARREADY` drops while `RVALID`
  is high).
- `WSTRB` byte enables are honored.
- Unaligned or out-of-range addresses return `SLVERR`. Writes to them change
  nothing; reads return all zeros.
- Synchronous active-low reset clears all registers.
- All registers are also exported on `regs_flat` for the surrounding logic.

### `rtl/axi_lite_slave_project_regs.v` (example, not verified)

A fixed register map showing how the generic block can be specialized:

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| 0x00 | CTRL | RW | Control |
| 0x04 | STATUS | RO | Reflects `status_i` |
| 0x08 | INTR_EN | RW | Interrupt enable |
| 0x0C | INTR_STATUS | RW1C | Set by `intr_status_set_i`, cleared by writing 1 |
| 0x10 | VERSION | RO | `VERSION_VALUE` parameter |

## Verification

```
UVM/
  axi_lite_if.sv, axi_lite_pkg.sv
  axi_lite_agent/   item, sequencer, driver, monitor, agent
  env/              env, scoreboard (register mirror), coverage
  tests/            sequences and tests
  assertions.sv     SVA checker module
  top_tb_uvm.sv     UVM top
sim/
  tb_axi_lite_slave_regs.v   standalone directed bench
  *.do, run_regression.ps1   Questa scripts
results/                     archived regression output
```

- **Driver** inserts random `BREADY`/`RREADY` delays (up to `max_ready_delay`).
- **Scoreboard** keeps a mirror of the registers, applies `WSTRB` on writes,
  and checks read data and the expected `OKAY`/`SLVERR` response.
- **Coverage** (`axi_lite_cg`): command, address (each register, unaligned,
  out of range), response, `WSTRB` pattern, and crosses of
  command x address kind x response and address kind x `WSTRB`.
- **Assertions** (`UVM/assertions.sv`) watch only the AXI ports: signal
  stability while `VALID` is waiting for `READY`, no response without a
  request, legal response codes, response latency bound, and `SLVERR` on
  invalid addresses. They are instantiated in both the directed and UVM tops.
  `UVM/assertions_protocol说明.md` explains each property (in Chinese).

| Test | Focus |
| --- | --- |
| `axi_lite_smoke_test` | Basic write/read to each register |
| `axi_lite_random_test` | Constrained-random mix of reads and writes |
| `axi_lite_wstrb_test` | Partial writes with different byte enables |
| `axi_lite_error_test` | Unaligned and out-of-range accesses |
| `axi_lite_backpressure_test` | Random traffic with longer `BREADY`/`RREADY` stalls |

## Results

Regression on 2026-10-08: 5 UVM tests x 10 seeds (1001-1050) plus the directed
bench, 51/51 passing, 10,543 transfers checked, no UVM errors and no assertion
failures.

| Metric | Result |
| --- | ---: |
| Functional coverage (merged `axi_lite_cg`) | 82.14% |
| Statement | 92.72% |
| Branch | 100% |
| Condition | 100% |
| Expression | 100% |
| Toggle | 69.30% |

Code coverage is for `rtl/axi_lite_slave_regs.v` only. Per-test numbers, the
seed matrix and logs are in `results/VERIFICATION_RESULTS.md` and
`results/logs/`.

## Running

Paths assume QuestaSim installed under `D:\Questasim`; adjust as needed.

```sh
# one UVM test (default test set in run_uvm.do)
vsim -do sim/run_uvm.do

# pick a test and transaction count
vsim -c -coverage top_tb +UVM_TESTNAME=axi_lite_random_test +NUM_TXNS=1000 -do "run -all; quit -f"

# directed bench
vsim -do sim/run_directed.do
```

Full regression with coverage merge (PowerShell):

```powershell
pwsh -File sim/run_regression.ps1 -SeedsPerTest 10 -RandomTransactions 500
```

Intel FPGA ModelSim ASE can compile the environment but cannot run the
randomization and covergroups; a full QuestaSim license is needed.

## Known gaps

- Functional coverage stops at 82% for two reasons: the `WSTRB` constraint never
  generates `6`, `7`, `9`, `B`, `D`, `E`, and the command x address kind x
  response cross still contains impossible bins (for example an invalid
  address returning `OKAY`) that should be marked `illegal_bins`.
- Toggle coverage is low because random data does not drive both edges on every
  register bit.
- `axi_lite_slave_project_regs.v` has no testbench yet.
