# AXI4-Lite Slave Register IP and Verification

Release **v1.2** combines a parameterized AXI4-Lite register slave, a UVM verification environment and a standalone testbench for project-specific RW/RO/RW1C registers.

## RTL

### Generic register slave

[`axi_lite_slave_regs.v`](rtl/axi_lite_slave_regs.v) provides a register array behind an AXI4-Lite interface.

- Parameterized data width, address width and register count. The verified configuration is 32-bit data, 8-bit addresses and four registers.
- AW and W can arrive in either order or together; each has an independent holding register.
- WSTRB controls byte updates.
- Misaligned and unmapped writes return SLVERR without changing registers; invalid reads return zero with SLVERR.
- Synchronous active-low reset clears the registers.
- `regs_flat` exports the register array as a packed bus.

Each direction accepts at most one outstanding transaction. Read and write paths operate independently. A read accepted on the same edge as a write to the same address returns the pre-write value.

### Project registers

[`axi_lite_slave_project_regs.v`](rtl/axi_lite_slave_project_regs.v) has a fixed register map:

| Offset | Register | Access | Behavior |
| --- | --- | --- | --- |
| `0x00` | CTRL | RW | Byte-qualified software updates |
| `0x04` | STATUS | RO | Samples `status_i` on read acceptance |
| `0x08` | INTR_EN | RW | Byte-qualified software updates |
| `0x0C` | INTR_STATUS | RW1C | Hardware set with software write-one-to-clear |
| `0x10` | VERSION | RO | Constant `VERSION_VALUE` |

Writes to RO registers are ignored and return OKAY. INTR_STATUS uses:

```text
next_status = (old_status & ~software_clear_mask) | hardware_set
```

WSTRB qualifies software clearing, while hardware set remains active in every byte. Hardware set wins a same-bit collision; reset has priority over both. The module exposes `ctrl_o`, `intr_en_o` and `intr_status_o`, with no separate IRQ output.

## Verification architecture

```text
sequence -> sequencer -> five-channel driver -> AXI interface -> DUT
                                            |
                                     cycle-based monitor
                                            |
                                   scoreboard + coverage

project-register testbench -> AXI + hardware-event inputs -> project DUT
                          -> explicit comparisons + AXI assertions
```

The UVM driver has independent AW/W/B/AR/R tasks, bounded queues and clocking-block timing. The six original tests run serially; three additional tests allow queued requests and concurrent reads/writes.

The monitor observes all five channels each cycle. The scoreboard updates its register mirror when AW/W pairing commits a write and captures expected read data at AR acceptance. This keeps predictions correct while B or R responses are blocked.

The interface checker contains 18 assertions and three request-recovery cover properties. End-of-test checks require all submitted transactions to be checked and all pending queues to drain.

## Tests

| UVM test | Focus |
| --- | --- |
| `axi_lite_smoke_test` | Basic register reads and writes |
| `axi_lite_random_test` | Constrained-random transactions |
| `axi_lite_wstrb_test` | All 16 strobes and address/strobe crosses |
| `axi_lite_error_test` | Misaligned and unmapped accesses |
| `axi_lite_backpressure_test` | Master-side BREADY/RREADY delays |
| `axi_lite_learning_test` | Deterministic AW/W ordering and readback |
| `axi_lite_slave_backpressure_test` | AW/W/AR stalls and eventual recovery |
| `axi_lite_concurrent_test` | Same/different-address reads and writes; independent progress |
| `axi_lite_continuous_test` | Continuous read, write and mixed request streams |

Continuous requests can wait for the DUT's READY signals; they do not imply one accepted request per cycle. Each additional test checks that its required scenarios were actually observed.

The standalone [project-register bench](sim/tb_axi_lite_slave_project_regs.sv) checks ten directed scenario groups: reset and VERSION, RW byte writes, all strobe masks, ignored RO writes, STATUS read snapshots under response stalls, RW1C retention/clearing, same-bit collisions in all byte lanes, hardware set outside selected bytes, different-bit collisions and invalid-address isolation. It checks both AXI readback and the three register outputs.

## Run

The scripts use QuestaSim 10.7c and UVM 1.2. Set the simulator installation path in the scripts to match your environment. Run the following commands from the project root.

```powershell
# Generic-DUT UVM regression and directed bench
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_regression.ps1 -SeedsPerTest 10 -RandomTransactions 500

# Project-register directed test
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_project_regs.ps1
```

The generic regression defaults to `results/v1.1/`; the project-register test writes to `results/project-regs/`. These generated logs and coverage databases are excluded from source control.

For a single UVM test in Questa:

```powershell
$env:UVM_TESTNAME='axi_lite_concurrent_test'
vsim -do sim/run_uvm.do
```

## Fault-detection checks

Two separate checks deliberately introduce incorrect behavior:

```powershell
# Change AW/W/AR payloads while requests are stalled
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_request_fault.ps1

# Restore software-clear-priority RW1C in an isolated generated copy
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_project_priority_mutation.ps1
```

The first wrapper requires one expected stability assertion failure on each request channel and reports `EXPECTED_FAILURE_VERIFIED assertions=3`. The second requires the same-bit RW1C collision check to reject the modified copy and reports `PRIORITY_MUTATION_REJECTED`. The real RTL is not modified by either check. Expected failures are excluded from normal regression pass counts.

## Measured results

Measured on 2026-11-01 with QuestaSim 10.7c and UVM 1.2:

| Check | Result |
| --- | ---: |
| Generic-DUT normal regression | 91/91 PASS |
| UVM matrix | 9 tests x 10 seeds |
| Standalone generic directed bench | 1 PASS |
| Generic-DUT checked transfers | 11,693 = 11,680 UVM + 13 directed |
| Transaction coverage | 94/94 bins (100%) |
| Timing coverage | 24/24 bins (100%) |
| Normal-run UVM errors / assertion failures | 0 / 0 |
| Project-register directed scenarios | 10 PASS |
| Project-register transfers | 251 = 137 writes + 114 reads |
| Project-register comparisons | 458 PASS |

Coverage percentages refer to the two implemented generic-DUT coverage models. The project-register test uses explicit directed checks and is reported separately.

## Layout

| Directory | Contents |
| --- | --- |
| `rtl/` | Generic and project-specific register modules |
| `UVM/` | AXI interface, agent, reference model, coverage, sequences and assertions |
| `sim/` | Simulation scripts, standalone benches and fault-detection wrappers |

## Versions

| Version | Changes | Measured verification |
| --- | --- | --- |
| [v1.0](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/v1.0) | Serial UVM baseline, register mirror, transaction coverage and AXI assertions | 61/61 runs; 10,993 transfers |
| [v1.1](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/v1.1) | Slave request backpressure, concurrent reads/writes, continuous requests and timing coverage | 91/91 runs; 11,693 transfers; 94/94 transaction bins; 24/24 timing bins |
| [v1.2](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/v1.2) | Standalone project-register tests and hardware-set-priority RW1C | 10 directed scenarios; 251 transfers; 458 comparisons |

The v1.2 project-register test is separate from the 91-run generic-DUT regression. Version tags preserve the release snapshots.

See [CHANGELOG.md](CHANGELOG.md) for release changes.
