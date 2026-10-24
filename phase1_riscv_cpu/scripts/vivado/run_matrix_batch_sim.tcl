set project_file {E:/project/Project Final riscv/Project Final riscv.xpr}

if {![file exists $project_file]} {
    puts "ERROR: Vivado project does not exist:"
    puts $project_file
    exit 1
}

open_project $project_file

puts "Vivado project found:"
puts $project_file

set_property top tb_cpu_matrix_batch [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

update_compile_order -fileset sim_1

launch_simulation -mode behavioral

run all

catch {close_sim}

close_project
exit