# Mandelbrot-Zoom-FPGA
Animated Mandelbrot Set fractal zoom using only BRAM on an FPGA

I wrote this for an iCE40HX4k devboard that I designed as a testbench. The project uses almost all of the FPGA resources avalible to do something interesting. It uses only the on-bard BRAMs to work, as it is a standard 640x480 image scaled down to 320x240 pixels. Division is mostly done using bit-shifting, and the same hard multiplier module is re-used for itrations and checking against the escape radius. A 23-bit fixed-point system is used to fit on the FPGA.

## Demo
[Watch this video](https://www.youtube.com/watch?v=BqdT2onGgkM) for a small demo of the project. You can also use `simulation.cpp` with Verlator to get a good idea of what's happening.
