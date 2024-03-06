
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {clk_out0*}]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {clk_out1*}]



set_max_delay -from [get_cells {Inst_cameralink_calibration/r_flag_error_long_reg}] -to [get_cells {Inst_cameralink_calibration/r_flag_error_cdc_reg[0]}]  -datapath_only 5.0