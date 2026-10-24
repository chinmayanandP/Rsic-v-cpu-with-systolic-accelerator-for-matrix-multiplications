# Portable Vivado project generator for the Phase 1 RV32I CPU repository.
#
# Usage from a Vivado command prompt:
#   vivado -mode batch -source create_project.tcl

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir .. .. ..]]
set phase1_dir [file join $repo_root phase1_riscv_cpu]
set project_dir [file join $repo_root build vivado]
set project_name phase1_riscv_cpu
set fpga_part xc7a200tfbg676-2

puts "Repository root: $repo_root"
puts "Phase 1 source: $phase1_dir"
puts "Vivado project output: $project_dir"

if {![file isdirectory $phase1_dir]} {
    puts stderr "ERROR: Phase 1 directory was not found:"
    puts stderr $phase1_dir
    exit 1
}

file mkdir $project_dir

create_project -force $project_name $project_dir -part $fpga_part
set_property source_mgmt_mode All [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_files [lsort [glob -nocomplain -types f \
    [file join $phase1_dir rtl * *.sv]]]

set testbench_files [lsort [glob -nocomplain -types f \
    [file join $phase1_dir testbenches * *.sv]]]

set constraint_files [lsort [glob -nocomplain -types f \
    [file join $phase1_dir constraints *.xdc]]]

set memory_files [lsort [glob -nocomplain -types f \
    [file join $phase1_dir software machine_code *.hex]]]

if {[llength $rtl_files] != 33} {
    puts stderr "ERROR: Expected 33 RTL files, found [llength $rtl_files]."
    close_project
    exit 1
}

if {[llength $testbench_files] != 40} {
    puts stderr "ERROR: Expected 40 testbench files, found [llength $testbench_files]."
    close_project
    exit 1
}

if {[llength $constraint_files] != 2} {
    puts stderr "ERROR: Expected 2 constraint files, found [llength $constraint_files]."
    close_project
    exit 1
}

if {[llength $memory_files] != 5} {
    puts stderr "ERROR: Expected 5 machine-code files, found [llength $memory_files]."
    close_project
    exit 1
}

add_files -fileset sources_1 -norecurse $rtl_files
add_files -fileset sources_1 -norecurse $memory_files
add_files -fileset sim_1 -norecurse $testbench_files
add_files -fileset constrs_1 -norecurse $constraint_files

foreach memory_file $memory_files {
    set memory_object [get_files -quiet $memory_file]
    if {[llength $memory_object] > 0} {
        set_property file_type {Memory Initialization Files} $memory_object
    }
}

set_property top basic_soc_top [get_filesets sources_1]
set_property top tb_riscv_cpu [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property SOURCE_SET sources_1 [get_filesets sim_1]
set_property xsim.simulate.runtime {0ns} [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set project_file [file join $project_dir ${project_name}.xpr]

puts ""
puts "PORTABLE PHASE 1 VIVADO PROJECT CREATED"
puts "RTL files: [llength $rtl_files]"
puts "Testbench files: [llength $testbench_files]"
puts "Constraint files: [llength $constraint_files]"
puts "Machine-code files: [llength $memory_files]"
puts "Project: $project_file"

close_project
exit 0

