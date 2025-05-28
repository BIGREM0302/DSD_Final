sh mkdir -p Netlist
sh mkdir -p Report

read_file -format verilog CHIP.v
read_file -format verilog D_cache.v
read_file -format verilog I_cache.v
read_file -format verilog RISCV_Pipeline.v
#read_file -format verilog cache_dm.v

set DESIGN "CHIP"
current_design [get_designs $DESIGN]

source CHIP_syn.sdc

compile_ultra -no_autoungroup
#compile

#####################################################

report_area         -hierarchy
report_timing       -delay min  -max_path 5
report_timing       -delay max  -max_path 5
report_area         -hierarchy              > ./Report/${DESIGN}_syn.area
report_timing       -delay min  -max_path 5 > ./Report/${DESIGN}_syn.timing_min
report_timing       -delay max  -max_path 5 > ./Report/${DESIGN}_syn.timing_max

write_sdf   -version 2.1                ./Netlist/${DESIGN}_syn.sdf
write   -format verilog -hier -output ./Netlist/${DESIGN}_syn.v
write   -format ddc     -hier -output ./Netlist/${DESIGN}_syn.ddc
