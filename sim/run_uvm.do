transcript on

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

set UVM_HOME "C:/intelFPGA/20.1/modelsim_ase/verilog_src/uvm-1.2"

vlog -sv +define+UVM_NO_DPI +incdir+$UVM_HOME/src +incdir+UVM \
    $UVM_HOME/src/uvm_pkg.sv \
    UVM/axi_lite_if.sv \
    UVM/axi_lite_pkg.sv \
    rtl/axi_lite_slave_regs.v \
    rtl/axi_lite_slave_project_regs.v \
    UVM/assertions.sv \
    UVM/top_tb_uvm.sv

set testname "axi_lite_smoke_test"
if {[info exists ::env(UVM_TESTNAME)]} {
    set testname $::env(UVM_TESTNAME)
}

vsim -c -nodpiexports -coverage top_tb +UVM_TESTNAME=$testname +UVM_NO_RELNOTES
run -all
coverage report -details -file coverage_$testname.txt

