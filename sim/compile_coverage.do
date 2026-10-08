transcript on

set UVM_HOME "D:/Questasim/verilog_src/uvm-1.2"

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -sv +cover=bcesft +define+UVM_NO_DPI +incdir+$UVM_HOME/src +incdir+UVM \
    $UVM_HOME/src/uvm_pkg.sv \
    UVM/axi_lite_if.sv \
    UVM/axi_lite_pkg.sv \
    rtl/axi_lite_slave_regs.v \
    rtl/axi_lite_slave_project_regs.v \
    UVM/assertions.sv \
    UVM/top_tb_uvm.sv

quit -f
