The files in this folder demonstrate performing fixation classification on the data recorded with the readme scripts using I2MC (https://github.com/royhessels/I2MC). First follow the instructions in `readme_analysis_example/function_library/I2MC/get_I2MC.txt`, then place the `.mat`-file or -files recorded with any of the `readme.m` files in the folder `readme_analysis_example/data/mat`, and finally run the scripts in the following order:

1. `a_ophakker.m`
2. `b_detFix.m`
3. `c_showFix.m`

When viewing fixation detection with `c_showFix.m`, press any key to go to the next trial. Close the figure window and press any key to stop scrolling through the trials.

The file `a_validationAccuracy.m` can be run in parallel to these scripts
