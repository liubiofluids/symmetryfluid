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

## Experimental setup
1. Turn on equipment if to be used
- Prior stage box
- Plug in all cameras (May require computer restart)
- Elveflow boxes
- Light for microscope
2. Turn on positive pressure line to Elveflow boxes
3. Launch Julia with `julia -p 12` (generally should be the number of cores)
4. Run `include("C:/path/to/gitrepo/mpmodular.jl")`
5. Run `mpmodularstart()`
6. Activate the pressure boxes from the GUI
- If loading previous calibration data, select `Pump On`, then open vacuum line
- If calibrating, select `Calib On`, then `Pump On`, then cap all ports, open vacuum line, then after the prompt hit `Calib ready`

## Warnings

- Calling commands that involve hardware moving, in the example above one such command being `controller.stage.goto-position`, should only be executed after ensuring there is sufficient physical clearance for the hardware to move.
- Per the manual for the Elveflow pressure boxes, the vacuum line if in use should never be open prior to the initialization of the boxes. Hence, when programming the steps, the initialization should be followed by a pause to open the vacuum line if starting a new calibration, or opened only after a prior calibration has been loaded.

## Future work
- Converting this repo into a proper Julia project: https://julialang.org/contribute/developing_package/
