transcript on
onerror {quit -code 1 -f}

if {[file exists work_fault]} {
    vdel -lib work_fault -all
}
vlib work_fault
vmap work_fault work_fault

vlog -work work_fault -sv rtl/axi_lite_slave_regs.v UVM/assertions.sv UVM/learning/fault_injection_rdata_stability.sv
vsim -c -voptargs=+acc -onfinish stop work_fault.fault_injection_rdata_stability
run 10 us
quit -f
