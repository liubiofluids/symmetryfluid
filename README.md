# mpmodular

Control suite for driving symmetry based microfluidics device.

## Features
- Control pressure boxes in realtime from port level configuration to symmetry based microfluidic modes
- Record pressure and images from cameras
- (Rudimentary) Particle tracking and pressure pump response
- GUI configuration

## Hardware supported
- Elveflow OB1 Mk3+
- Pointgrey cameras
- Prior stage

## Getting started
1. Clone this repo.
2. Clone the Elveflow and Prior Scientific repos.
3. Update the hardcoded locations for those two package locations at the top of the mpmodular script.

## Experimental setup
1. Turn on equipment if to be used
- Prior stage box
- Plug in all cameras (May require computer restart)
- Elveflow boxes
- Light for microscope
2. Turn on positive pressure line to Elveflow boxes
3. Launch Julia with `julia -p 12` (or more if more processes need to be launched)
4. Run `include("C:/path/to/gitrepo/mpmodular.jl")`
5. Run `mpmodularstart()`
6. Activate the pressure boxes from the GUI
- If loading previous calibration data, select `Pump On`, then open vacuum line
- If calibrating, select `Calib On`, then `Pump On`, then cap all ports, open vacuum line, then after the prompt hit `Calib ready`

## Usage
### Stokes wind tunnel mode generation
1. Turn crunch on.
2. Add mode amounts under `Mode controls`.
3. Use `Mode scaling` to adjust the relative strengths of the modes.
### Custom mode path generation
1. Paste in the custom mode command. Example:
```
0;1;1;0
1;linear;cart;diff;-2;0;0
1;linear;cart;diff;0;-2;0
1;linear;cart;diff;2;0;0
1;linear;cart;diff;0;2;0
```
- First line specifies time and space origin. Subsequent lines specify time of step, followed by time dependence, and coordinate system dependent information. The example above executes a square trajectory. See code for full set of options.
2. Toggle `Crunch custom` on.
3. Adjust scaling of generated pressures if needed.

### Custom port generation
1. Paste in the custom port command. Example:
```
0;1;-1;0;0;0;0
1;block;cart;point;1;0;0;0;0;-1
1;block;cart;point;0;0;0;0;-1;1
1;block;cart;point;0;0;0;-1;1;0
1;block;cart;point;0;0;-1;1;0;0
1;block;cart;point;0;-1;1;0;0;0
1;block;cart;point;-1;1;0;0;0;0
```
- First line specifies time and initial port configuration. Subsequent lines specify time of step, followed by pressure wave shape, then port activations.
2. Toggle `Crunch custom port` on.
3. Adjust scaling of generated pressures if needed.

### Camera activation
1. Toggle `Camera` on.
2. For display viewing, toggle `Display` on.
3. For time lapse image viewing, toggle `Squish display` on.
4. To change the number of images used in time lapse, adjust `Stack size`.
5. To change the wait between squishing rounds, adjust `Delay`.

### Recording data
1. Edit experimental notes section for noting current experimental configuration.
2. Toggle `Record` on.
3. After the experiment is finished, run `slztopgm("C:/path/to/images")` to convert the images (if any) to actual image files.

### Track particles
1. Toggle `Track` on.
2. To have the program guess the particle location in the whole frame, toggle `Track best guess` on then off.
3. To translate the pixel coordinate to pressure velocity correction scaling, adjust `Track plane` scale.
4. To change the size of the region being clipped out to analyze, adjust `Clip size`.
5. To adjust the analyzing of the region, adjust `Threshold` and `Kernel smoothing`.
6. To flip the coordinate analysis, adjust `Track coords`.

## Warnings

- Calling commands that involve hardware moving, should only be executed after ensuring there is sufficient physical clearance for the hardware to move.
- Per the manual for the Elveflow pressure boxes, the vacuum line if in use should never be open prior to the initialization of the boxes. Hence, when programming the steps, the initialization should be followed by a pause to open the vacuum line if starting a new calibration, or opened only after a prior calibration has been loaded.

## Future work
- Add licensing
- Converting this repo into a proper Julia project: https://julialang.org/contribute/developing_package/
- Switch out the Elveflow and Prior Scientific paths to proper package imports
- Remove the path generation code and make it into a standalone package
- Add support for Andor cameras: https://github.com/emmt/AndorCameras.jl
- Add support for Fluigent pressure pumps
- Add darkness measurement for z tracking
- Sync up with Dr. Liu's calibration algorithm
- Add support for conformal mapping
- Add support for NI equipment: https://github.com/JaneliaSciComp/NIDAQ.jl
- Add support for PI equipment: https://www.physikinstrumente.com/en/products/software-suite/programming-interfaces-integration
- Add proper documentation
- Add storage and recall of custom pressure modes
- Add support for multiple cameras being used simultaneously
