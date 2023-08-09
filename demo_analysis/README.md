The files in this folder demonstrate performing fixation classification on the data recorded with the readme scripts using I2MC (https://github.com/royhessels/I2MC). First follow the instructions in `demo_analysis/function_library/I2MC/get_I2MC.txt`, then place the `.mat`-file or -files recorded with any of the [`demo_experiments/readme*.m`](../demo_experiments) files in the folder [`demo_analysis/data/mat`](data/mat), and finally run the scripts in the following order:

1. `a_ophakker.m`
2. `b_detFix.m`
3. `c_showFix.m`

When viewing fixation detection with `c_showFix.m`, press any key to go to the next trial. Close the figure window and press any key to stop scrolling through the trials.

The file `a_validationAccuracy.m` can be run in parallel to these scripts and will report the accuracy of the calibration for each recording, as established by the validation procedure run as part of the recording.

## AOI Analysis
After fixation classification has been performed using the above steps, AOI analysis can be performed using the script `d_AOIfix.m`. Your AOI masks can be drawn on top of the stimulus using `d_drawAOIs.m`. If such stimuli with AOI masks are available, `c_showFix.m` will use these instead of the original stimuli to draw your data on.

How to make AOIs:
- For each stimulus, create a folder with the same name as the stimulus file, so e.g. rabbits.jpg. In that folder, you will store the AOIs for that stimulus
- Make them as follows:
   1. Open the image file in a graphics program, such as Photoshop, GIMP, or even Paint.
   2. Make all the areas on the image that are inside the AOI fully white, everything else fully black. That means the AOI can have any shape and also consist of multiple separate areas. It is advisable that you ensure that areas in different AOIs do not overlap. A simple way to create AOIs is to draw and export them as separate layers (Photoshop, GIMP).
   3. Save this file as `.png` (important, not jpg).
   4. The name of the file is the name of the AOI. So, e.g., the folder `rabbits.jpg` may contain the files `tail.png` and `ears.png` that denote the tail and ear AOIs for the rabbits.jpg stimulus.

The example AOIs in the folder `AOIs` were drawn on the two images used in the `readme_*.m` demos.
