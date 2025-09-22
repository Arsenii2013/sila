add_files -fileset utils_1 -norecurse ../../../src/script/get_git_version.tcl
set_property STEPS.SYNTH_DESIGN.TCL.PRE [ get_files ../../../src/script/get_git_version.tcl -of [get_fileset utils_1] ] [get_runs synth_1]
set_msg_config -suppress -id {HDL 9-3952} -regexp -string {{CRITICAL WARNING: .* use of undefined macro 'GIT_.*' .*} }
set_property verilog_define SYNTHESIS [current_fileset]