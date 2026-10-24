# Portable manual-matrix simulation runner.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir .. .. ..]]
set project_file [file join $repo_root build vivado phase1_riscv_cpu.xpr]

if {[llength $argv] != 2} {
    puts stderr "ERROR: Expected input and output file paths."
    puts stderr "Usage: vivado -mode batch -source run_matrix_sim.tcl -tclargs INPUT OUTPUT"
    exit 1
}

set input_file [file normalize [lindex $argv 0]]
set output_file [file normalize [lindex $argv 1]]

if {![file exists $project_file]} {
    puts stderr "ERROR: Generated Vivado project not found:"
    puts stderr $project_file
    puts stderr "Run create_vivado_project.bat first."
    exit 1
}

if {![file exists $input_file]} {
    puts stderr "ERROR: Matrix input file not found:"
    puts stderr $input_file
    exit 1
}

file mkdir [file dirname $output_file]
if {[file exists $output_file]} {
    file delete -force $output_file
}

if {[catch {
    open_project $project_file

    set_property top tb_cpu_matrix_manual [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]
    set_property SOURCE_SET sources_1 [get_filesets sim_1]
    set_property xsim.simulate.runtime {0ns} [get_filesets sim_1]

    set simulation_options [format         {-testplusarg MATRIX_INPUT=%s -testplusarg MATRIX_OUTPUT=%s}         $input_file $output_file]

    set_property -name {xsim.simulate.xsim.more_options} -value $simulation_options -objects [get_filesets sim_1]

    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    puts "Vivado project: $project_file"
    puts "Matrix input: $input_file"
    puts "Matrix output: $output_file"

    launch_simulation -mode behavioral
    run all
} error_message]} {
    puts stderr "Matrix simulation failed: $error_message"
    puts stderr $::errorInfo
    catch {close_sim}
    catch {close_project}
    exit 1
}

catch {close_sim}
close_project

if {![file exists $output_file]} {
    puts stderr "ERROR: Simulation completed without creating:"
    puts stderr $output_file
    exit 1
}

exit 0
