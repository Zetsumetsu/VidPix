# VidPix

8 Bit visual synthesizer based on the Pixelmusic3000.

Original by Sound Study Modular (via Synthrotek). This fork adds Nick's
custom firmware — see below.

## VIDPIX-NICK custom firmware (v1.0)

Full-replacement firmware: the 44 stock routines are gone, and the box boots
into 4 original visual routines.

| # | Name | Vibe |
|---|------|------|
| 0 | Shredder | Aggressive. Shards scale with the right channel, snap-rotate on alternate frames, explode outward on transients. |
| 1 | Pressure Bloom | Hypnotic. Concentric rings breathe with the overall level, slow stepped rotation. |
| 2 | Toybox Pervert | Weird. Blobs get yanked around by the stereo difference, googly wobble. |
| 3 | Signal Bleed | Glyphs. Morphing ASCII characters drift with the audio and smear on peaks. |

Controls are unchanged from stock: pattern button/gate advances routines,
color button/gate cycles palettes, glitch mode still re-tiles on audio level.
In auto mode the box picks randomly among the 4, each with a locked palette.

### Files

- `firmware/VIDPIX-NICK-v1.0-NTSC.spin` — flash this (NTSC unit)
- `firmware/VIDPIX-NICK-v1.0-PAL.spin` — PAL variant, same routines
- `build_firmware.py` — regenerates both variants from `VidPix v1.2.2.zip`,
  so every version stays reproducible. Run: `python3 build_firmware.py`
- `VidPix v1.2.2.zip` — pristine stock source. **This is the restore image.**
  To get the factory firmware back, flash the stock file from this zip.

### Flashing (Windows or Mac)

1. Install the Propeller IDE (Propeller Tool on Windows, PropellerIDE on Mac).
2. Connect the Prop Plug to the computer via USB, then to the VID PIX 4-pin
   header with the VSS pin closest to the J2 marking. Power the VID PIX on.
3. Open the NTSC file in the IDE (all six `.spin` files must sit in one
   folder — the IDE pulls them from the extracted stock zip).
4. Compile, then **load to RAM first** to test. When happy, load to EEPROM
   so it survives power-off.

Use the NTSC file. The PAL file on an NTSC unit gives a rolling picture.

### Build check

Both variants are compile-verified with OpenSpin (open-source Spin compiler).
Binary is ~16.4KB of the Propeller's 32KB hub RAM.

## Stock info

VidPix zip file contains

- VID PIX NTSC v1.2.2.spin

- VID PIX PAL v1.2.2.spin

- Graphics.spin

- display.tv.text.spin

- tv.spin

- MSP3208.spin

[1.2.1] 8.4.2021

New pack of patterns added

[1.2.1] 11.24.2021

New pack of patterns added

## License

GPL v3. Original (c) 2021 Synthrotek Sound Study Modular.
Modifications (c) 2026 Nick Dye.
