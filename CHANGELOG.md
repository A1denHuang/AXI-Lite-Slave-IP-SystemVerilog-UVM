# Changelog

## v1.2

- Standalone project-register testbench for RW, RO and RW1C semantics.
- Hardware set takes priority over a simultaneous software clear.
- All 16 write-strobe masks, read-response stability and invalid-address checks.
- Directed test: 10 scenarios, 251 transfers and 458 comparisons.
- Isolated mutation test rejects software-clear-priority behavior.

## v1.1

- Independent AW/W/B/AR/R driver tasks with clocking blocks and bounded queues.
- Slave request backpressure, concurrent reads/writes and continuous request tests.
- Read expectations captured at AR acceptance; write mirror updated at write commit.
- Timing coverage, required scenario checks and request-stability fault injection.
- Regression: 91 passing runs and 11,693 checked transfers; 94/94 transaction bins and 24/24 timing bins.

## v1.0

- Parameterized AXI4-Lite register slave with independent AW/W acceptance.
- Six UVM tests, byte-strobe checks, address error checks and interface assertions.
- Serial transactions with randomized request timing and master response backpressure.
- Regression: 61 passing runs and 10,993 checked transfers.
