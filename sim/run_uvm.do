transcript on

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

set UVM_HOME "D:/Questasim/verilog_src/uvm-1.2"

vlog -sv +cover=bcesft +define+UVM_NO_DPI +incdir+$UVM_HOME/src +incdir+UVM \
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

set seed 1
if {[info exists ::env(SEED)]} {
    set seed $::env(SEED)
}

set num_txns 200
if {[info exists ::env(NUM_TXNS)]} {
    set num_txns $::env(NUM_TXNS)
}

file mkdir results
vsim -c -nodpiexports -coverage -onfinish stop -sv_seed $seed top_tb \
    +UVM_TESTNAME=$testname +NUM_TXNS=$num_txns +UVM_NO_RELNOTES
run -all
coverage save "results/${testname}_seed_${seed}.ucdb"
coverage report -details -file "results/${testname}_seed_${seed}_coverage.txt"
quit -f

