transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# Paths relative to this script (simulation/modelsim/)
set RTL_DIR [file normalize [file join [file dirname [info script]] ../..]]

vlog -vlog01compat -work work +incdir+$RTL_DIR [file join $RTL_DIR assignment.v]

vlog -vlog01compat -work work +incdir+$RTL_DIR [file join $RTL_DIR tb_assignment.v]

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneii_ver -L rtl_work -L work -voptargs="+acc"  tb_assignment

add wave *
view structure
view signals
run -all
