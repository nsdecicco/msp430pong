
# MSP430 NTSC Pong Game

Copyright (c) 2016 Nicholas DeCicco. See `LICENSE.md` for licensing details.

This project contains code and design files for a MSP430 Pong game, playable
by two people on an NTSC television.

Disclaimer: Video signals are generated using one big loop without using a
timer to ensure that scan line lengths stay constant. Further, for lack of
time, I have not ensured that alternate paths through the code are timed
exactly equally. As a result, there is no small amount of tearing visible.
Some televisions handle this better than others.

I have also noticed that while the video looks fine on some models of
televisions, there is a considerable amount of tearing visible with, for
example, the Hauppauge WinTV PVR-150 PCI capture card. It would appear that
the Hauppauge card does not like how I am differentiating even and odd frames.

## Hardware requirements

A schematic is available in pcb/schematic.pdf. This project requires the
MSP-EXP430G2 Launchpad development board. I built the circuit on perfboard
as a module with male headers that would plug directly into the Launchpad,
though it should be trivial to place the MSP430G2231 on the same board.

## Building

This code has only been tested with TI's version of GCC and Peter A. Bigot's
MSP430 GCC toolchain (now obsoleted by TI's toolchain; this is the version
available in the Ubuntu package repositories).

Note that there are three subdirectories of `src/`: `bars`, `bitmap`, and
`pong`. `pong` contains the Pong game source code; `bars` contains code which
generates black and white vertical bars on the screen; and `bitmap` will
produce a low-resolution bitmap on the screen.

### Ubuntu

These instructions should work for other Debian-derived distributions. First,
install the MSP430 GCC toolchain:

    sudo apt-get install gcc-msp430 msp430-libc mspdebug

Then, `cd` into the source directory and run `make`:

    make

With the target device (Launchpad) connected, run

    make upload

### Windows

The easiest way to obtain the GCC toolchain is to install TI's Code Composer
Studio, then install the MSP430 GCC add-on; see the [Code Composer
documentation](http://processors.wiki.ti.com/index.php/Using_MSP430-GCC_with_CCSv6)
for more information.

The Makefile is written to use MSP430Flasher to flash the device; download and
install MSP430Flasher from <http://www.ti.com/tool/msp430-flasher>.

You either must put `C:\TI\gcc\bin\` and `C:\TI\MSP430Flasher_x.y.z` on your
`%PATH%`, or edit the `Makefile`(s) to point directly to the locations of the
needed binaries.

Then, `cd` into the source directory and run `make`:

    make

With the target device (Launchpad) connected, run

    make upload
