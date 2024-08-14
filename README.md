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
3. Launch Julia with `julia -p 6` (generally should be the number of cores)
4. Activate the pressure boxes from the GUI
5. Turn on the vacuum line
