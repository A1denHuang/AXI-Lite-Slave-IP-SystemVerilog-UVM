transcript on
onerror {quit -code 1 -f}
set mutation_dir "results/project-regs/mutation"
if {[info exists ::env(AXI_PROJECT_MUTATION_DIR)]} {set mutation_dir $::env(AXI_PROJECT_MUTATION_DIR)}
vlib work_project_mutation
vmap work_project_mutation work_project_mutation
vlog -work work_project_mutation -sv UVM/axi_lite_if.sv "$mutation_dir/software_clear_priority.v" UVM/assertions.sv sim/tb_axi_lite_slave_project_regs.sv
vsim -c -onfinish stop work_project_mutation.tb_axi_lite_slave_project_regs
run 200 us
quit -f
