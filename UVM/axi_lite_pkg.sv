`ifndef AXI_LITE_PKG_SV
`define AXI_LITE_PKG_SV

package axi_lite_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int AXI_DATA_WIDTH = 32;
    parameter int AXI_ADDR_WIDTH = 8;
    parameter int AXI_REG_COUNT  = 4;

    typedef enum int {AXI_READ, AXI_WRITE} axi_lite_cmd_e;
    typedef enum int {ADDR_LEGAL, ADDR_UNALIGNED, ADDR_OUT_OF_RANGE} axi_lite_addr_kind_e;

    `include "axi_lite_agent/axi_lite_item.sv"
    `include "axi_lite_agent/axi_lite_sequencer.sv"
    `include "axi_lite_agent/axi_lite_driver.sv"
    `include "axi_lite_agent/axi_lite_monitor.sv"
    `include "axi_lite_agent/axi_lite_agent.sv"
    `include "env/axi_lite_scoreboard.sv"
    `include "env/axi_lite_coverage.sv"
    `include "env/axi_lite_env.sv"
    `include "tests/axi_lite_sequences.sv"
    `include "tests/axi_lite_tests.sv"
endpackage

`endif
