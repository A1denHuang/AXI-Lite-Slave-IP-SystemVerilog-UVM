transcript on

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -sv rtl/axi_lite_slave_regs.v rtl/axi_lite_slave_project_regs.v UVM/assertions.sv sim/tb_axi_lite_slave_regs.v
vsim -c tb_axi_lite_slave_regs -do "run -all; quit -f"
