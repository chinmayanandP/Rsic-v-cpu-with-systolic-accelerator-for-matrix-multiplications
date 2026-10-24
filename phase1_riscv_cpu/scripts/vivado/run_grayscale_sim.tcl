set project_dir [file dirname [file normalize [info script]]]
set project_file [file join $project_dir "Project Final riscv.xpr"]
set testbench_file [file join $project_dir "tb_cpu_grayscale_batch.sv"]

if {![file exists $project_file]} {
    puts stderr "Project not found: $project_file"
    exit 1
}

if {![file exists $testbench_file]} {
    puts stderr "Testbench not found: $testbench_file"
    exit 1
}

if {[catch {
    open_project $project_file

    # Construct a Tcl list so paths containing spaces stay together.
    set testbench_list [list $testbench_file]

    if {[llength [get_files -quiet $testbench_list]] == 0} {
        add_files -fileset sim_1 -norecurse $testbench_list
    }

    set_property SOURCE_SET sources_1 [get_filesets sim_1]
    set_property top tb_cpu_grayscale_batch [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]

    update_compile_order -fileset sim_1

    set_property xsim.simulate.runtime {0ns} [get_filesets sim_1]

    launch_simulation -mode behavioral
    run all

} error_message]} {
    puts stderr "Grayscale simulation failed: $error_message"
    puts stderr $::errorInfo
    catch {close_sim}
    catch {close_project}
    exit 1
}

catch {close_sim}
close_project
exit 0