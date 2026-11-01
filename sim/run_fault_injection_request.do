transcript on
onerror {quit -code 1 -f}
vlib work_request_fault
vmap work_request_fault work_request_fault
vlog -work work_request_fault -sv rtl/axi_lite_slave_regs.v UVM/assertions.sv UVM/learning/fault_injection_request_stability.sv
vsim -c -onfinish stop work_request_fault.fault_injection_request_stability
run 1 us
quit -f
