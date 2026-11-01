# AXI4-Lite Slave Register Verification

Release **v1.0**. SystemVerilog/UVM verification of an AXI4-Lite register slave.

## Design

- Five independent AXI channels with separately captured write address and data.
- Byte-qualified writes through WSTRB.
- Misaligned and unmapped accesses return SLVERR; invalid reads return zero.
- Verification configuration: 32-bit data, 8-bit addresses and four registers.
- One accepted outstanding transaction per direction; read and write paths operate independently.

## Layout

| Directory | Contents |
| --- | --- |
| `rtl/` | Generic register slave and project-register example |
| `UVM/` | Interface, agent, scoreboard, coverage, sequences and assertions |
| `sim/` | Testbenches and simulation scripts |

## Run

The scripts use QuestaSim 10.7c and UVM 1.2. The simulator installation path is configured in the scripts.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_regression.ps1 -SeedsPerTest 10 -RandomTransactions 500
```

Generated logs and coverage databases are written to `results/` and are excluded from source control.

## Versions

See [CHANGELOG.md](CHANGELOG.md). Version tags preserve each release snapshot.
