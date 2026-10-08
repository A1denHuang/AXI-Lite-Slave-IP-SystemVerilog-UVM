transcript on

set UVM_HOME "D:/Questasim/verilog_src/uvm-1.2"
set testname "axi_lite_smoke_test"
set seed 1
set num_txns 200

if {[info exists ::env(UVM_TESTNAME)]} {
    set testname $::env(UVM_TESTNAME)
}
if {[info exists ::env(SEED)]} {
    set seed $::env(SEED)
}
if {[info exists ::env(NUM_TXNS)]} {
    set num_txns $::env(NUM_TXNS)
}

file mkdir results

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

vsim -c -nodpiexports -coverage -onfinish stop -sv_seed $seed top_tb \
    +UVM_TESTNAME=$testname +NUM_TXNS=$num_txns +UVM_NO_RELNOTES
run -all
coverage save "results/${testname}_seed_${seed}.ucdb"
coverage report -details -file "results/${testname}_seed_${seed}_coverage.txt"
quit -f
