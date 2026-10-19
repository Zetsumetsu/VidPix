#!/usr/bin/env python3
"""Build VIDPIX-NICK firmware from the stock v1.2.2 source in this repo.

Reads "VidPix v1.2.2.zip" (stock Sound Study source, also the restore image),
applies Nick's full-replacement transformation, and writes both variants to
firmware/. Run:  python3 build_firmware.py

Every replacement asserts exactly once, so silent drift is impossible.
"""
import re, sys, pathlib, zipfile, tempfile, shutil

ROOT = pathlib.Path(__file__).resolve().parent
OUT = ROOT / "firmware"
OUT.mkdir(exist_ok=True)

HEADER = """''***************************************************************************
''*     VIDPIX-NICK v1.0                                                      *
''*     Custom firmware for Nick - full replacement build                     *
''*     4 original visual routines: Shredder / Pressure Bloom /               *
''*     Toybox Pervert / Signal Bleed                                         *
''*     Built from Sound Study Modular VID PIX v1.2.2 source.                 *
''*     Original (c) 2021 Synthrotek Sound Study Modular, GPL v3.             *
''*     Modifications (c) 2026 Nick Dye.                                      *
''*                                                                           *
''*     This program is free software: you can redistribute it and/or modify   *
''*     it under the terms of the GNU General Public License as published by  *
''*     the Free Software Foundation, either version 3 of the License, or     *
''*     (at your option) any later version.                                   *
''*                                                                           *
''*     This program is distributed in the hope that it will be useful,       *
''*     but WITHOUT ANY WARRANTY; without even the implied warranty of      *
''*     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
''*     GNU General Public License for more details.                          *
''***************************************************************************
"""

BRANCHES = """
        0:  ' SHREDDER - the aggressive one. Shards scale violently with the
            ' right channel, snap-rotate on alternate frames, and explode
            ' outward when the room gets loud.
          if j//2 == 0
            changebit := !changebit

          gr.width(scalar_r+16)
          if changebit == 0
            gr.pix(0, 0, 0, @pixdefshard1)
          else
            gr.pix(0, 0, 1, @pixdefshard1)   ' 90-degree snap

          gr.width(scalar_l+16)
          gr.pix(-45, 0, 2, @pixdefshard1)
          gr.pix(45, 0, 3, @pixdefshard1)

          if totalavg > 10   ' transient burst
            gr.width((totalavg)/2+16)
            gr.pix(-40, -40, 1, @pixdefshard1)
            gr.pix(40, -40, 3, @pixdefshard1)
            gr.pix(-40, 40, 3, @pixdefshard1)
            gr.pix(40, 40, 1, @pixdefshard1)


        1:  ' PRESSURE BLOOM - the hypnotic one. Concentric rings breathe with
            ' the overall level; slow stepped rotation.
          gr.width((totalavg)/2+16)
          gr.pix(0, 0, 0, @pixdefbloom1)

          gr.width(scalar_l+16)
          gr.pix(0, 0, 1, @pixdefbloom1)

          gr.width(scalar_r+16)
          gr.pix(0, 0, 2, @pixdefbloom1)

          if j//8 == 0
            changebit := !changebit
          if changebit == 0
            gr.width(16)
            gr.pix(0, 0, 3, @pixdefbloom1)


        2:  ' TOYBOX PERVERT - the weird one. Blobs get yanked around the
            ' screen by the stereo difference; googly wobble on frames.
          if j//2 == 0
            changebit := !changebit

          gr.width(scalar_l+16)
          if changebit == 0
            gr.pix((scalar_l - scalar_r)*3, (scalar_r - scalar_l)*2, 0, @pixdefblob1)
          else
            gr.pix((scalar_l - scalar_r)*3, (scalar_r - scalar_l)*2, 1, @pixdefblob1)

          gr.width(scalar_r+16)
          gr.pix((scalar_r - scalar_l)*3, 20 + totalavg, 2, @pixdefblob1)

          gr.width((totalavg)/2+16)
          gr.pix(30 - totalavg*2, -20, 0, @pixdefblob1)


        3:  ' SIGNAL BLEED - glyph mode. Morphing characters drift with the
            ' audio; they smear on peaks. (str1/2/3 cycle through ASCII in the
            ' main loop, so the glyphs never sit still.)
          gr.width(0)
          repeat q from -4 to 4
            gr.textmode(scalar_l/2+1, scalar_r/2+1, 6, %0101)
            gr.color(1)
            gr.text(q*18, 0, @str1)
            gr.color(2)
            gr.text(q*22, 12*scalar_l - 24, @str2)
            gr.color(3)
            gr.text(q*22, -12*scalar_l + 24, @str3)
          if totalavg > 10   ' smear on peaks
            gr.color(1)
            repeat q from -4 to 4
              gr.text(q*18 + 6, 4, @str1)


"""

SPRITES = """' Nick's sprites - 16px wide, 12 tall, %% quaternary (0=transparent)
pixdefshard1            word
                        byte    2,12,8,6
                        word    %%11111111, %%11111111
                        word    %%01111111, %%11111110
                        word    %%00111111, %%11111100
                        word    %%00022222, %%11111000
                        word    %%00002222, %%21110000
                        word    %%00000222, %%22110000
                        word    %%00000022, %%22210000
                        word    %%00000002, %%22220000
                        word    %%00000000, %%22222000
                        word    %%00000000, %%02222000
                        word    %%00000000, %%00222000
                        word    %%00000000, %%00022000

pixdefbloom1            word
                        byte    2,12,8,6
                        word    %%00000011, %%11000000
                        word    %%00001122, %%22110000
                        word    %%00012200, %%00221000
                        word    %%00122000, %%00022100
                        word    %%01220000, %%00002210
                        word    %%01200000, %%00000210
                        word    %%01200000, %%00000210
                        word    %%01220000, %%00002210
                        word    %%00122000, %%00022100
                        word    %%00012200, %%00221000
                        word    %%00001122, %%22110000
                        word    %%00000011, %%11000000

pixdefblob1             word
                        byte    2,12,8,6
                        word    %%00000111, %%11100000
                        word    %%00011111, %%11110000
                        word    %%00111111, %%11111000
                        word    %%01111111, %%11111100
                        word    %%01112211, %%11221100
                        word    %%11112211, %%11221110
                        word    %%11111111, %%11111110
                        word    %%01111111, %%11111100
                        word    %%01111111, %%11111100
                        word    %%00111111, %%11111000
                        word    %%00011111, %%11110000
                        word    %%00000111, %%11100000

"""

def sub_once(src, old, new, label):
    n = src.count(old)
    if n != 1:
        sys.exit(f"FATAL: anchor '{label}' found {n}x (expected 1)")
    return src.replace(old, new)

def build(stock_dir, src_name, out_name):
    src = (stock_dir / src_name).read_text()

    # 1. header
    idx = src.index("\n\nCON")
    src = HEADER + src[idx+2:]

    # 2. manual pattern advance wraps over 4 routines
    src = sub_once(src,
        "if pattern == 43   'rotate through routines in order",
        "if pattern == 3   'rotate through Nick's 4 routines in order",
        "pattern wrap")

    # 3. delete the stock pack-remap block (p == 1 .. p == 6)
    start = src.index("                if p == 1   'if pack 1 is selected only show routines 0-7")
    end = src.index("                        pattern := pattern + 4\n") + len("                        pattern := pattern + 4\n")
    src = src[:start] + src[end:]

    # 4. fixed frame averaging (no arcade slowdown special-case)
    src = sub_once(src,
        """                if pattern > 15 and pattern < 24    'if the arcade classics pattern is selected decrease the frame rate for clearer animation
                    ADC_AVG := 105
                else
                    ADC_AVG := 35
""",
        """                ADC_AVG := 35
""",
        "adc avg")

    # 5. auto mode: pick 1 of 4, locked palette per routine
    src = sub_once(src,
        """                    if p == 1   'change the pattern randomly depending on the pack chosen
                        displayroutine:=randomgen(8)-1
                    elseif p == 2
                        displayroutine:=randomgen(8)+7
                    elseif p == 3
                        displayroutine:=randomgen(8)+15
                    elseif p == 4
                        displayroutine:=randomgen(8)+23
                    elseif p == 5
                        displayroutine:=randomgen(8) +31
                    elseif p == 6
                        displayroutine:=randomgen(4) +39
                    elseif p == 7
                        displayroutine:=randomgen(4) + randomgen(8) + randomgen(32) -1
                    

                    if displayroutine > 15 and displayroutine < 24  'if the arcade classics pack is selected
                        i := displayroutine +  14   'display the correct colors
                        ADC_AVG := 105  'slow down the frame rate for clearer animation
                    elseif displayroutine > 38
                        i := displayroutine - 2   'display the correct colors
                        
                    else
                        i:=randomgen(32) 'choose a random color
                        ADC_AVG := 105   'speed up the frame rate
                    SetAreaColor(0,0,TV_HC-1,TV_VC-1,i) 'change the color
""",
        """                    displayroutine:=randomgen(4)-1   'pick one of Nick's 4 routines

                    ' locked palette per routine (tune these indices by eye)
                    i := lookupz(displayroutine: 32, 18, 12, 39)
                    ADC_AVG := 35
                    SetAreaColor(0,0,TV_HC-1,TV_VC-1,i) 'change the color
""",
        "auto select")

    # 6. secret combo lands on routine 0 instead of nonexistent 44
    src = sub_once(src, "displayroutine := 44", "displayroutine := 0", "easter egg")

    # 7. replace the whole case body with the 4 new branches
    start = src.index("    case displayroutine\n") + len("    case displayroutine\n")
    end = src.index("    'update screen bitmap")
    src = src[:start] + BRANCHES + src[end:]

    # 8. stale comments
    src = sub_once(src,
        "''  VidPix has 33 total screen patterns sorted in to 4 packs",
        "''  VIDPIX-NICK has 4 original routines (0-3), full-replacement build",
        "pattern count comment")
    src = sub_once(src,
        "''  To see what a particular screen pattern looks like just hardcode the displayroutine var to a number between 0 and 33",
        "''  To see a particular routine just hardcode the displayroutine var to a number between 0 and 3",
        "hardcode comment")

    # 9. new sprites at the top of DAT
    src = sub_once(src, "DAT\n", "DAT\n" + SPRITES, "dat insert")

    (OUT / out_name).write_text(src)
    print(f"wrote {out_name} ({len(src)} chars)")

tmp = pathlib.Path(tempfile.mkdtemp())
try:
    with zipfile.ZipFile(ROOT / "VidPix v1.2.2.zip") as z:
        z.extractall(tmp)
    stock_dir = tmp / "VidPix v1.2.2"
    build(stock_dir, "VID PIX NTSC v1.2.2.spin", "VIDPIX-NICK-v1.0-NTSC.spin")
    build(stock_dir, "VID PIX PAL v1.2.2.spin", "VIDPIX-NICK-v1.0-PAL.spin")
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("done")
