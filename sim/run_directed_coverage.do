transcript on
set results_dir "results"
if {[info exists ::env(AXI_RESULTS_DIR)]} {set results_dir $::env(AXI_RESULTS_DIR)}
file mkdir $results_dir

if {[file exists work_directed]} {
    vdel -lib work_directed -all
}
vlib work_directed
vmap work work_directed

vlog -work work_directed -sv +cover=bcesft \
    rtl/axi_lite_slave_regs.v \
    rtl/axi_lite_slave_project_regs.v \
    UVM/assertions.sv \
    sim/tb_axi_lite_slave_regs.v

vsim -c -lib work_directed -coverage -onfinish stop tb_axi_lite_slave_regs
set timeout_us 10000
if {[info exists ::env(AXI_SIM_TIMEOUT_US)]} {
    set timeout_us $::env(AXI_SIM_TIMEOUT_US)
}
run $timeout_us us
coverage save "$results_dir/directed_smoke.ucdb"
coverage report -details -file "$results_dir/directed_smoke_coverage.txt"
quit -f
