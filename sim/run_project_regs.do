transcript on
onerror {quit -code 1 -f}
set results_dir "results/project-regs"
if {[info exists ::env(AXI_PROJECT_RESULTS_DIR)]} {set results_dir $::env(AXI_PROJECT_RESULTS_DIR)}
file mkdir $results_dir
vlib work_project_regs
vmap work_project_regs work_project_regs
vlog -work work_project_regs -sv +cover=bcesft UVM/axi_lite_if.sv rtl/axi_lite_slave_project_regs.v UVM/assertions.sv sim/tb_axi_lite_slave_project_regs.sv
vsim -c -coverage -onfinish stop work_project_regs.tb_axi_lite_slave_project_regs
run 200 us
coverage save "$results_dir/project_regs.ucdb"
coverage report -details -file "$results_dir/project_regs_coverage.txt"
quit -f
