# Get the folder containing this Tcl script
set script_dir [file dirname [file normalize [info script]]]

# Search for the Vivado project in the same folder
set project_files [glob -nocomplain -types f \
    -directory $script_dir *.xpr]

# If not found, search one folder below
if {[llength $project_files] == 0} {
    foreach subdir [glob -nocomplain -types d \
        -directory $script_dir *] {

        set found [glob -nocomplain -types f \
            -directory $subdir *.xpr]

        set project_files [concat $project_files $found]
    }
}

# Stop if no project was found
if {[llength $project_files] == 0} {
    puts "ERROR: No Vivado .xpr project found."
    puts "Searched inside: $script_dir"
    exit 1
}

# Use the discovered project
set project_file [lindex $project_files 0]

puts "Vivado project found:"
puts $project_file

open_project $project_file

set_property top tb_cpu_matrix_manual [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation -mode behavioral
run all

catch {close_sim}
close_project
exit