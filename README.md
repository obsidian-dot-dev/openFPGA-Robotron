# Robotron

Robotron for the Analogue Pocket.

* Based on the FPGA Robotron code by [Sharebrained]( https://github.com/sharebrained/robotron-fpga)
* Ported from the [MiSTer port by Sorgelig and oldgit](https://github.com/MiSTer-devel/Arcade-Robotron_MiSTer)

## Compatibility

This core supports multiple arcade games running on the "later" Rev 1 Williams 6809 arcade board. The full list includes:

* Robotron
* Joust
* Sinistar
* Stargate
* Splat
* Bubbles
* Alien Arena

Note that arcade games supported on the earlier Rev 1 board (i.e. Defender), or Rev 2 (Joust 2, etc.) 6809 board are *not* supported by this core.

## Service Mode Controls

Buttons for service-mode controls (for the high-score-reset and in-game service menu) are mapped as follows:

* Advance -- Select + L
* Auto-up -- R
* Reset High Scores -- Select + R

## Stargate - "Original Control" Mode

There is an additional control added to the UI when running Stargate, allowing the user to select "Original Control Mode".  When selected, the "Reverse" and "Thrust" buttons are mapped to the L and R triggers respectively.

When "Original Control" mode is disabled, the dpad controls both direction and thrust (as in most home-console ports of Defender/Stargate).

## Sinistar - Analog Controls

Sinistar originally used a 49-way joystick.  On Pocket, 8-way dpad controls are used, with some in-between states added to make hitting other angles possible.

When played on the Analogue Dock using a compatible controller with analog stcks, the left stick provides emulation of the 49-way joystick controller for a more authentic experience.

## Robotron - Twin-stick Controls

On Analogue Pocket, Robotron supports the dpad and face buttons for movement and firing direction, respectively.  

When playing in-dock using a controller with dual analog sticks, the left stick additionally controls movement, while the right analog stick is used for firing.

## Usage

*No ROM files are included with this release.*  

Install the contents of the release to the root of the SD card.

Place the necessary `.rom` files for the supported games onto the SD card under `Assets/robotron/common`.

To generate the `.rom` format binaries used by this core, you must use the MRA files included in this repo, along with the corresponding ROMs from the most recent MAME release.

## Known issues and limitations

* High-score saving is not supported.
* "Play Ball!" is supported by the core, but currently doesn't work in this port.

## Notes

Note:  Some of these games make excessive use of strobe effects, which may be problematic for individuals with photosensitivity, epilepsy, or other similar conditions.

## History

v0.9.0
* Initial Release

## Attribution

```
---------------------------------------------------------------------------------
-- MiSTer port by oldgit(davewoo999) and Sorgelig  
---------------------------------------------------------------------------------
-- gen_ram.vhd
-------------------------------- 
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
---------------------------------------------------------------------------------
-- cpu09l - Version : 0128
-- Synthesizable 6809 instruction compatible VHDL CPU core
-- Copyright (C) 2003 - 2010 John Kent
---------------------------------------------------------------------------------
-- cpu68 - Version 9th Jan 2004 0.8
-- 6800/01 compatible CPU core 
-- GNU public license - December 2002 : John E. Kent
---------------------------------------------------------------------------------
```

See individual modules for details.