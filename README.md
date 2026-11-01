# AXI4-Lite Slave Register IP and Verification

A parameterized AXI4-Lite register slave with SystemVerilog/UVM verification, interface-level assertions and a standalone project-register testbench.

**Latest release: [v1.2](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/v1.2)** · **[Latest source and documentation](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/version1.2)**

This `main` branch retains the earlier source baseline. The features and results below are identified by release; check out `version1.2` to run the latest tests.

## Versions

| Version | Changes | Measured verification |
| --- | --- | --- |
| [v1.0](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/v1.0) | Serial UVM baseline, register mirror, transaction coverage and AXI assertions | 61/61 runs; 10,993 transfers |
| [v1.1](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/v1.1) | Slave request backpressure, concurrent reads/writes, continuous requests and timing coverage | 91/91 runs; 11,693 transfers; 94/94 transaction bins; 24/24 timing bins |
| [v1.2](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/v1.2) | Standalone project-register tests and hardware-set-priority RW1C | 10 directed scenarios; 251 transfers; 458 comparisons |

The v1.2 project-register test is separate from the 91-run generic-DUT regression. Version tags preserve the release snapshots.

## Design and verification

The generic DUT supports independent AW/W arrival, WSTRB byte enables and SLVERR for misaligned or unmapped addresses. The verified configuration uses 32-bit data, 8-bit addresses and four registers. It accepts at most one outstanding transaction per direction; reads and writes can progress independently.

v1.1 adds five independent driver tasks, cycle-based monitoring and request-time reference-model updates. Tests cover both directions of backpressure, AW-first/W-first/simultaneous writes, concurrent accesses and continuous requests. Continuous requests remain subject to READY; they do not imply one accepted request per cycle.

v1.2 adds a separate testbench for CTRL, STATUS, INTR_EN, INTR_STATUS and VERSION. It checks RW/RO/RW1C behavior, all 16 WSTRB masks, hardware/software collisions, invalid addresses and blocked read responses. Hardware set wins a simultaneous software clear in INTR_STATUS.

Source: [generic RTL](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/blob/version1.2/rtl/axi_lite_slave_regs.v), [UVM environment](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/tree/version1.2/UVM), [project-register testbench](https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM/blob/version1.2/sim/tb_axi_lite_slave_project_regs.sv).

## Run the latest version

```sh
git clone --branch version1.2 https://github.com/A1denHuang/AXI-Lite-Slave-IP-SystemVerilog-UVM.git
cd AXI-Lite-Slave-IP-SystemVerilog-UVM
```

The scripts use QuestaSim 10.7c and UVM 1.2. Set the simulator installation path in the scripts to match your environment. Run the following commands from the project root.

```powershell
# Generic-DUT UVM regression and directed bench
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_regression.ps1 -SeedsPerTest 10 -RandomTransactions 500

# Project-register directed test
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_project_regs.ps1
```

The generic regression defaults to `results/v1.1/`; the project-register test writes to `results/project-regs/`. These generated logs and coverage databases are excluded from source control.

## Fault-detection checks

Two separate checks deliberately introduce incorrect behavior:

```powershell
# Change AW/W/AR payloads while requests are stalled
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_request_fault.ps1

# Restore software-clear-priority RW1C in an isolated generated copy
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_project_priority_mutation.ps1
```

The first wrapper requires one expected stability assertion failure on each request channel and reports `EXPECTED_FAILURE_VERIFIED assertions=3`. The second requires the same-bit RW1C collision check to reject the modified copy and reports `PRIORITY_MUTATION_REJECTED`. The real RTL is not modified by either check. Expected failures are excluded from normal regression pass counts.

## Results

Measurements were taken on 2026-11-01 with QuestaSim 10.7c. The v1.1 regression comprises nine UVM tests with ten seeds each plus one standalone directed bench: 11,680 UVM transfers and 13 directed transfers, with no UVM errors or normal-run assertion failures.

Transaction coverage reached 94/94 bins and timing coverage reached 24/24 bins. These percentages describe the implemented coverage models. The v1.2 standalone project-register run completed 137 writes, 114 reads and 458 comparisons without simulator or assertion errors.
