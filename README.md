# AXI4-Lite Slave Register Verification

Release **v1.2**. SystemVerilog/UVM verification of an AXI4-Lite register slave.

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

## Protocol scenarios

The UVM tests exercise master response backpressure, slave request backpressure,
AW-first/W-first/simultaneous arrival, concurrent reads and writes, and continuous requests.
Continuous requests remain subject to the slave's READY behavior; they do not imply one accepted request every cycle.
Same-cycle reads and writes to one address return the pre-write value.

The transaction model contains 94 bins; the timing model contains 24 bins. The measured regression reaches all bins in both models.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_request_fault.ps1
```

## Project registers

| Offset | Register | Access |
| --- | --- | --- |
| `0x00` | CTRL | RW |
| `0x04` | STATUS | RO, sampled from status_i |
| `0x08` | INTR_EN | RW |
| `0x0C` | INTR_STATUS | RW1C with hardware set |
| `0x10` | VERSION | RO constant |

RO writes are ignored and return OKAY. For INTR_STATUS,
`next = (old & ~software_clear_mask) | hardware_set`; WSTRB qualifies only the software clear.
Reset clears writable state. The module exposes enable and status registers, with no separate IRQ output.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_project_regs.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File sim/check_project_priority_mutation.ps1
```

## Versions

See [CHANGELOG.md](CHANGELOG.md). Version tags preserve each release snapshot.
