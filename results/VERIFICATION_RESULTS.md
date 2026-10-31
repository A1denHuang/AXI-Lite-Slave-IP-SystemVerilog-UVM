# AXI4-Lite verification results

Date: 2026-10-31 (Asia/Shanghai)

Simulator: QuestaSim-64 10.7c (2018.08), UVM 1.2

## Verified headline

| Item | Result | Evidence / definition |
| --- | ---: | --- |
| Named scenarios | 6 | Five UVM test classes plus one standalone directed bench |
| Formal runs | 51/51 PASS | 50 UVM runs and one directed run |
| Unique UVM seeds | 50 | Decimal seeds 1001-1050; ten seeds assigned to each UVM test |
| Checked AXI-Lite transfers | 6,703 | 6,690 UVM monitor samples plus 13 directed transfers |
| UVM errors / fatals | 0 / 0 | Parsed from every UVM run log |
| Assertion failures | 0 | Merged assertion report |
| Functional coverage | 100.00% | Merged `axi_lite_cg` type coverage |
| Statement coverage | 92.72% | `rtl/axi_lite_slave_regs.v`: 51/55 statements |
| Branch coverage | 100.00% | `rtl/axi_lite_slave_regs.v`: 26/26 branches |
| Condition coverage | 100.00% | `rtl/axi_lite_slave_regs.v`: 8/8 FEC condition terms |
| Expression coverage | 100.00% | `rtl/axi_lite_slave_regs.v`: 22/22 FEC expression terms |
| Toggle coverage | 69.30% | `rtl/axi_lite_slave_regs.v`: 298/430 toggle bins |

## Regression matrix

| Test | Runs | Seeds | Transfers per run | Result | Per-run functional coverage |
| --- | ---: | --- | ---: | ---: | ---: |
| `axi_lite_smoke_test` | 10 | 1001-1010 | 13 | 10/10 PASS | 64.32% |
| `axi_lite_random_test` | 10 | 1011-1020 | 500 | 10/10 PASS | 96.13%-98.51% |
| `axi_lite_wstrb_test` | 10 | 1021-1030 | 36 | 10/10 PASS | 67.16% |
| `axi_lite_error_test` | 10 | 1031-1040 | 20 | 10/10 PASS | 63.97% |
| `axi_lite_backpressure_test` | 10 | 1041-1050 | 100 | 10/10 PASS | 96.13%-97.92% |
| Directed SystemVerilog bench | 1 | N/A | 13 | 1/1 PASS | No covergroup |

Total: 51 runs and 6,703 checked AXI-Lite read/write transfers.

## Coverage scope and interpretation

- Functional coverage is merged across the 50 UVM runs. Every coverpoint and
  both crosses in `axi_lite_cg` reached 100%.
- `c_wstrb` now generates all 16 WSTRB values. The WSTRB directed sequence also
  enumerates every value at a legal address and drives `0`, `8`, `9`, and `A`
  at out-of-range address `0x20`, closing the four reachable cross bins missed
  by the original finite random sample.
- Protocol-violating response combinations are `illegal_bins`: legal accesses
  returning `SLVERR`, and invalid accesses returning `OKAY`. Both illegal bins
  had zero hits in the merged regression.
- A single seed is not required to reach 100%; the headline is the merged
  regression result. Coverage closure demonstrates completion of this
  covergroup model, not completeness of the whole verification plan.
- Code coverage headline numbers apply only to the instantiated reusable DUT,
  `rtl/axi_lite_slave_regs.v`. They intentionally exclude verification code and
  the uninstantiated `axi_lite_slave_project_regs.v` example.
- Toggle coverage is lower because random data does not guarantee both edges on
  every register/data bit.

## Reproduction

From the project root in PowerShell:

```powershell
pwsh -File sim/run_regression.ps1 -SeedsPerTest 10 -RandomTransactions 500
```

The regression script compiles with `+cover=bcesft`, runs the five UVM tests,
saves one UCDB per run, runs the directed bench, writes
`results/regression_results.csv`, and produces both UVM-only and final merged
reports. `final_merged_coverage.ucdb` and
`final_merged_coverage.txt` are the archived 51-run evidence set, including the
directed bench.

## Evidence files

- `results/regression_results.csv`: one row per UVM test/seed, including pass/fail
  and UVM error/fatal counts.
- `results/final_merged_coverage.txt`: detailed merged functional, code and
  assertion coverage report.
- `results/final_merged_coverage.ucdb`: merged Questa coverage database.
- `results/logs/`: compiler, merge and individual UVM run logs.
