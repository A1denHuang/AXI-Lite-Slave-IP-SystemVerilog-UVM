transcript on
file mkdir results

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
run -all
coverage save "results/directed_smoke.ucdb"
coverage report -details -file "results/directed_smoke_coverage.txt"
quit -f
