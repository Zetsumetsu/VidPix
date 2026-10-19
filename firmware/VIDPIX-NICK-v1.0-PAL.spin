''***************************************************************************
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
CON


  _clkmode = xtal1 + pll16x     'set clock speed to 80 MHz  (16 x external crytsal 5_000_000Hz)
  _xinfreq = 5_000_000
  _stack = ($C00 + $C00 + 100) >> 2   'accomodate display memory and stack

  x_tiles = 8   'number of tiles that make up the screen
  y_tiles = 6

  paramcount = 14
  bitmap_base = $6800
  display_base = $7400


  'can increase or decrease this number to make more or less time between color or shape changes
  DELAYUNIT = 10_000_000 '1/8 of a sec

  'set up the Analog to Digital Converter (ADC) Pins on the Propeller
  ADC_CLK       = 0 'Clock to ADC
  ADC_DIN       = 1 'Data to/from ADC
  ADC_CS        = 2 'CS to ADC

  ' can increase or decrease this number to make more or less time both buttons must be held to bring up menu
  increment_menu = 80_000_000


VAR

  'set the tv object variables...
  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset16                     write-only
  long  tv_vo         'vertical offset16                       write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only


  word  screen[x_tiles * y_tiles]
  long  colors[64]


  long delayStack[32]           'a stack of longs used by delay routine
  byte lastrand
  byte delayflag

OBJ
  'we use the propeller's included tv, graphics and mcp3208/adc objects
  tv            : "tv"
  gr            : "graphics"
  adc           : "MCP3208"
  text          : "display.tv.text"

PUB start | i, j, k, l, h, g, q, r, pin1, pin2, ep, ec, ee, scalar_r, scalar_bigd, scalar_l, rightADCavg, leftADCavg, totalavg, rotateflag, changebit, changedisplay, displayroutine, xs, ys, tmp, p, pattern, ADC_AVG, str1, str2, str3, gate1, gate2

  'turn on the LED
  dira[16]~~
  outa[16]~~

  'set switch and gates to inputs
  dira[5]~
  dira[8]~
  dira[9]~

  'start the adc object
  adc.start(ADC_DIN,  ADC_CLK, ADC_CS, $FF)

  'start tv object
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'start and setup graphics object
  gr.start
  gr.setup(8, 6, 64, 48, bitmap_base)

''*******************************************************************************
''  COLOR PALETTES
''  These are the colors that the VidPix will cycle through
''  We only use 4 colors onscreen at a time and one color is always black
''  To get more color variety, we create different palettes and combos of colors
''  Each palette group has a slight variation in the order or hue of the colors
''  This is exploited by the shapes which also arrange the color bits with variation
''  You can use 'Graphics_Palette.spin' in the Example Library or Fig. 3 in the
''  read me file if you would like to pick different color values
''*******************************************************************************


  'browns and yellows
  SetColorPalette(0,$02,$ac,$18,$ab)
  SetColorPalette(1,$02,$18,$9e,$ab)
  SetColorPalette(2,$02,$bb,$18,$9b)
  SetColorPalette(3,$02,$18,$ac,$ab)
  SetColorPalette(4,$02,$ab,$ac,$18)
  SetColorPalette(5,$02,$ac,$18,$9b)

  'blues and purples
  SetColorPalette(6,$02,$3c,$b8,$eb)
  SetColorPalette(7,$02,$0c,$5e,$fb)
  SetColorPalette(8,$02,$b8,$3c,$eb)
  SetColorPalette(9,$02,$b8,$5d,$88)
  SetColorPalette(10,$02,$eb,$3c,$5d)
  SetColorPalette(11,$02,$b8,$eb,$88)

  'purple pink white
  SetColorPalette(12,$02,$58,$88,$3e)
  SetColorPalette(13,$02,$ed,$dd,$3e)
  SetColorPalette(14,$02,$cc,$ed,$b8)
  SetColorPalette(15,$02,$58,$88,$3e)
  SetColorPalette(16,$02,$68,$cc,$4d)
  SetColorPalette(17,$02,$3e,$b8,$58)

  'light blues and greens
  SetColorPalette(18,$02,$5e,$3d,$f8)
  SetColorPalette(19,$02,$3d,$5e,$f8)
  SetColorPalette(20,$02,$6d,$3e,$6e)
  SetColorPalette(21,$02,$5e,$4e,$f8)
  SetColorPalette(22,$02,$6e,$3d,$4e)
  SetColorPalette(23,$02,$f8,$6e,$3e)

  'orange and greens
  SetColorPalette(24,$02,$8d,$8e,$38)
  SetColorPalette(25,$02,$8e,$8d,$28)
  SetColorPalette(26,$02,$5c,$8e,$ad)
  SetColorPalette(27,$02,$7c,$7e,$5c)
  SetColorPalette(28,$02,$5c,$8d,$38)
  SetColorPalette(29,$02,$28,$8e,$5c)

  'link
  SetColorPalette(30,$02,$6c,$ab,$ae)

  'Mario
  SetColorPalette(31,$02,$38,$ce,$7a)

 'pacman
  SetColorPalette(32,$02,$9d,$07,$3d)

 'Space Invaders
  SetColorPalette(33,$02,$6c,$07,$3d)

  'Galaga
  SetColorPalette(34,$02,$07,$38,$a8)

  'Digdug
  SetColorPalette(35,$02,$07,$38,$b8)

  'Bubble Bobble
  SetColorPalette(36,$02,$e8,$18,$07)

  'final fantasy
  SetColorPalette(37,$02,$9d,$3e,$9c)
  
  'fire
  SetColorPalette(38,$02,$9b,$1f,$ae)
  
  'leglamp
  SetColorPalette(39,$ba,$02,$ae,$9e)
  
  'fire2
  SetColorPalette(40,$03,$9b,$1f,$ae)
  
  'gnome
  SetColorPalette(41,$02,$07,$1f,$ae)

  'start a new delay counter in its own cog
  delayflag:=0
  cognew(delay(@delayflag, 8), @delayStack)


  'the screen is made of 8 horizontal x 6 vertical tiles (groups of pixels)
  'while each tile can have its own color palette, we set a color palette to apply globally across all screen tiles
  SetAreaColor(0,0,TV_HC-1,TV_VC-1,41)

  'selects menu option as all on startup
  p := 7

  'set parameters for startup
  ADC_AVG := 35

  pin1 := 0
  pin2 := 0

  ee := 0

  repeat  'main loop

''*******************************************************************************
''  retrieve ADC L and R values, build pixel scalar values

    rightADCavg := adc.average(0,ADC_AVG) 'right channel volume/voltage
    leftADCavg := adc.average (1,ADC_AVG) 'left channel volume/voltage

    scalar_r := (rightADCavg*16/4096) 'we're massaging the number into something applicable to the shapes
    scalar_l := (leftADCavg*16/4096)
    scalar_bigd :=((scalar_r)*2/5) +16

    totalavg:=(scalar_r+scalar_l)/2 'we will use totalavg to help make sure not to change anything if no input


    if ina[5] == 0  'if in manual mode
        if ina[8] == 1  'and pattern gate is high
            waitcnt(clkfreq/1000 + cnt)   'Wait the requested amount of settle time.
            if ina[8] == 1 'if pattern gate is still high
                if pin1 == 0    'if the gate has gone low since the last pattern change
                    gate1 := 1  'set gatechange parameter to high
                    ep++
                    ec := 0
                    pin1 :=1    'mark gate as high
        else
            pin1 := 0   'mark gate as low

        if ina[9] == 1  'If color gate is high
            waitcnt(clkfreq/1000 + cnt)   'Wait the requested amount of settle time.
            if ina[9] == 1  'if color gate is still high
                if pin2 == 0    'if the gate has gone low since the last color change
                    gate2 := 1  'set gatechange parameter to high
                    ec++
                    ep := 0
                    pin2 := 1   'mark gate as high
        else
            pin2 := 0   'mark gate as low

    tmp := cnt  'note where the internal counter is currently
    repeat while ina[8] <> 0 and ina[9] <> 0    'When both gate pins are high
        if cnt - tmp > increment_menu   'and have been held for > 2 seconds
            tv.stop     'stop current graphics
            p := menu   'bring up menu and set pack selector
            g := glitch 'bring up glitch menu and choose mode
            gr.start    'restart graphics
            gr.setup(8, 6, 64, 48, bitmap_base)
            delayflag := 1      'Set parameters to immediatly change routine
            totalavg := 3
            gate1 := 1
            gate2 := 1



''*******************************************************************************
    if ina[5] == 0      'if in manual mode
            if gate1 == 1   'if the gatechange parameter is high
                if pattern == 3   'rotate through Nick's 4 routines in order
                    pattern := 0
                else
                    pattern++
                ADC_AVG := 35

                displayroutine:= pattern    'change the pattern
                gate1 := 0  'reset gatechange parameter

            if gate2 == 1   'if the gatechange parameter is high
               i++  'rotate through color selection
               if i>41
                i:=0
               SetAreaColor(0,0,TV_HC-1,TV_VC-1,i)  'change the color
'               i:=39
'               SetAreaColor(0,0,TV_HC-1,TV_VC-1,i)  'change the color
               gate2 := 0  'reset gatechange parameter
               

    if ina[5] <> 0      'if in automatic mode
        if totalavg > 2     'if we are getting an input
            if delayflag==1 'and the random time delay has passed
                    displayroutine:=randomgen(4)-1   'pick one of Nick's 4 routines

                    ' locked palette per routine (tune these indices by eye)
                    i := lookupz(displayroutine: 32, 18, 12, 39)
                    ADC_AVG := 35
                    SetAreaColor(0,0,TV_HC-1,TV_VC-1,i) 'change the color
                    delayflag:=0    'reset ramdom delay

                    cognew(delay(@delayflag, 0), @delayStack)   'start random delay counter on new cog




    if ee == 0 and ec == 1
        ee++
    elseif ee == 1 and ec > 1
        ee := 0
    elseif ee == 1 and ep == 2
        ee++
    elseif ee == 2 and ep > 2
        ee := 0
    elseif ee == 2 and ec == 3
        ee++
    elseif ee == 3 and ec > 3
        ee := 0
    elseif ee == 3 and ep == 3
        ee++
    elseif ee == 4 and ep > 3
        ee := 0
    elseif ee == 4 and ec == 1
        ee++
    elseif ee == 5 and ec > 1
        ee := 0
    elseif ee == 5 and ep == 1
        ee++
    elseif ee == 6 and ep > 1
        ee := 0
    elseif ee == 6 and ec == 1
        displayroutine := 0
        SetAreaColor(0,0,TV_HC-1,TV_VC-1,33)
        ee := 0
''*******************************************************************************
''  change the orientation? some of the screen patterns have alternating rotations

    if j//9== 0
      rotateflag := !rotateflag

''*******************************************************************************
''  Translate L+R inputs to simple shapes and colors
''  VIDPIX-NICK has 4 original routines (0-3), full-replacement build
''  The shapes in the layout are grown or shrunk based in the ADC values
''  To see a particular routine just hardcode the displayroutine var to a number between 0 and 3

'   displayroutine:= 0
    
    gr.clear

    if g == 1   'if glitch mode is on
        gr.setup(4+scalar_l, 2+scalar_r, 64, 48, bitmap_base)   'change the amount of screen tiles to relate to the ADC values


    case displayroutine

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


    'update screen bitmap
    gr.copy(display_base)


    if j == 32  'each pattern has 32 frames it can use
      j:=1
    else
      j++

    if h == 8   'this counter is used by patterns that change images every 4 frames
        h:=0
    elseif (j+1)//4== 0
        h++

    if str1 == 127  'used by the character assassination pack to cycle through characters
        str1 := 33
    else
        str1++

    if str1 < 63    'used by the character assassination pack to show semi random characters
        str2 := str1 + randomgen(32)
        str3 := str1 + randomgen(32)
    else
        str2 := str1 - randomgen(32)
        str3 := str1 - randomgen(32)
    
    if k ==$1FFF
      k:=0
    else
      k++

''*******************************************************************************
'thanks to Jim Fouch in the parallax forums for these 3 screen color pubs
Pub SetAreaColor(X1,Y1,X2,Y2,ColorIndex)|DX,DY
  Repeat DX from X1 to X2
    Repeat DY from Y1 to Y2
      SetTileColor(DX,DY,ColorIndex)

Pub SetTileColor( x, y, ColorIndex)
   screen[y * tv_hc + x] := display_base >> 6 + y + x * tv_vc + ((ColorIndex & $3F) << 10)

Pub SetColorPalette(ColorIndex,Color1,Color2,Color3,Color4)
  colors[ColorIndex] := (Color1) + (Color2 << 8) +  (Color3 << 16) + (Color4 << 24)

pub delay (delayflagAddr, mult)
    if mult==0   '0 = choose a random number b/w 0 and 31
      mult:=randomgen(32)
      waitcnt(DELAYUNIT*mult + cnt)
    else         'multiply by a multiplier
      waitcnt(DELAYUNIT*mult + cnt)

    byte[delayflagAddr]:=1


''*******************************************************************************
pub randomgen (sigdigs):output | mask, var1
      if sigdigs==32
        mask:= %0000000000011111
      elseif sigdigs==16
        mask:= %0000000000001111
      elseif sigdigs==8
        mask:= %0000000000000111
      elseif sigdigs==4
        mask:= %0000000000000011
      else
        mask:= %0000000000000001

      var1:=(((cnt?) &  mask) + 1)

      if var1==lastrand
        var1:=(((cnt?) &  mask) + 1)

      lastrand:=var1
      output:=var1


PUB menu | f

  f:=1  'set cursor to row one
  text.start(12)    'start the menu graphics
  option    'show the meu options on screem
  waitpeq(0, |< 9, 0) 'wait until color gate is low
  waitcnt(clkfreq/100 + cnt)   'wait a debounce time



  repeat until ina[9] <> 0  'repeats menu loop until the color gate is high
    if ina[8] == 1  'if the pattern gate is high
        text.out ($00)  'clear screen
        f++  'move cursor position down a row
        option  'reprint menu options
        waitpeq(0,|<8,0)    'wait until the pattern gate is low
        waitcnt(clkfreq/100 + cnt)   'wait a debounce time

    if f > 7    'if the cursor is at the bottom of the list, put it at the top
        f :=1

    'print cursor
    text.out ($0A)
    text.out (3)
    text.out ($0b)
    text.out (f)
    text.out ($bb)
    
    
    
    

  result := f   'when the method ends send the cursor position to the main loop as pack selection



pub option

  'print list of options
  text.setcolors (@palette)
  text.str(string($0A, 5, $0B, 1," Digital Diamonds 1 "))
  text.str(string($0A, 5, $0B, 2," Digital Diamonds 2 "))
  text.str(string($0A, 5, $0B, 3," 8-bit Nostalgia "))
  text.str(string($0A, 5, $0B, 4," Character Assassination "))
  text.str(string($0A, 5, $0B, 5," Dream Ranger "))
  text.str(string($0A, 5, $0B, 6," Holidays "))
  text.str(string($0A, 5, $0B, 7," All "))

pub glitch | g


  g:=1  'set cursor to row one
  text.start(12)    'start the menu graphics
  text.setcolors (@palette)
  text.str(string($0A, 5, $0B, 1," glitch mode on "))
  text.str(string($0A, 5, $0B, 2," glitch mode off "))
  waitpeq(0, |< 9, 0) 'wait until color gate is low
  waitcnt(clkfreq/100 + cnt)   'wait a debounce time


  repeat until ina[9] <> 0  'repeats menu loop until the color gate is high
    if ina[8] == 1  'if the pattern gate is high
        text.out ($00)  'clear screen
        g++  'move cursor position down a row
        text.str(string($0A, 5, $0B, 1," glitch mode on ")) 'show menu options
        text.str(string($0A, 5, $0B, 2," glitch mode off "))
        waitpeq(0,|<8,0)    'wait until the pattern gate is low
        waitcnt(clkfreq/100 + cnt)   'wait a debounce time

    if g > 2   'if the cursor is at the bottom of the list, put it at the top
        g := 1

    'print curor
    text.out ($0A)
    text.out (3)
    text.out ($0b)
    text.out (g)
    text.out ($bb)


  result := g  'when the method ends send the cursor position to the main loop as mode selection


  text.stop 'stop menu graphics
  tv.start(@tv_status)  'start tv graphics

DAT
' Nick's sprites - 16px wide, 12 tall, %% quaternary (0=transparent)
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


tvparams                long    0               'status
                        long    1               'enable
                        long    %001_0101       'pins
                        long    %0001          'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    20              'hx
                        long    2               'vx
                        long    0               'ho
                        long    0               'vo
                        long    0               'broadcast
                        long    0               'auralcog

pixdeftriclear1         word
                        byte    2,16,8,8
                        word    %%00000001, %%10000000
                        word    %%00000011, %%11000000
                        word    %%00000111, %%11100000
                        word    %%00001111, %%11110000
                        word    %%00011111, %%11111000
                        word    %%00111111, %%11111100
                        word    %%01111111, %%11111110
                        word    %%11111111, %%11111111
                        word    %%01111111, %%11111110
                        word    %%00111111, %%11111100
                        word    %%00011111, %%11111000
                        word    %%00001111, %%11110000
                        word    %%00000111, %%11100000
                        word    %%00000011, %%11000000
                        word    %%00000001, %%10000000
                        word    %%00000000, %%00000000

pixdeftriclear2         word
                        byte    2,16,8,8
                        word    %%00000002, %%20000000
                        word    %%00000022, %%22000000
                        word    %%00000222, %%22200000
                        word    %%00002222, %%22220000
                        word    %%00022222, %%22222000
                        word    %%00222222, %%22222200
                        word    %%02222222, %%22222220
                        word    %%22222222, %%22222222
                        word    %%02222222, %%22222220
                        word    %%00222222, %%22222200
                        word    %%00022222, %%22222000
                        word    %%00002222, %%22220000
                        word    %%00000222, %%22200000
                        word    %%00000022, %%22000000
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000


pixdeftriclear3         word
                        byte    2,16,8,8
                        word    %%00000003, %%30000000
                        word    %%00000033, %%33000000
                        word    %%00000333, %%33300000
                        word    %%00003333, %%33330000
                        word    %%00033333, %%33333000
                        word    %%00333333, %%33333300
                        word    %%03333333, %%33333330
                        word    %%33333333, %%33333333
                        word    %%03333333, %%33333330
                        word    %%00333333, %%33333300
                        word    %%00033333, %%33333000
                        word    %%00003333, %%33330000
                        word    %%00000333, %%33300000
                        word    %%00000033, %%33000000
                        word    %%00000003, %%30000000
                        word    %%00000000, %%00000000


pixdeftriclear2a        word
                        byte    2,14,8,7
                        word    %%00000022, %%22000000
                        word    %%00000000, %%00000000
                        word    %%00002222, %%22220000
                        word    %%00000000, %%00000000
                        word    %%00222222, %%22222200
                        word    %%00000000, %%00000000
                        word    %%22222222, %%22222222
                        word    %%00000000, %%00000000
                        word    %%00222222, %%22222200
                        word    %%00000000, %%00000000
                        word    %%00002222, %%22220000
                        word    %%00000000, %%00000000
                        word    %%00000022, %%22000000
                        word    %%00000000, %%0000000

pixdeftriclear2b        word
                        byte    2,16,8,8
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000
                        word    %%00000222, %%22200000
                        word    %%00000000, %%00000000
                        word    %%00022222, %%22222000
                        word    %%00000000, %%00000000
                        word    %%02222222, %%22222220
                        word    %%00000000, %%00000000
                        word    %%02222222, %%22222220
                        word    %%00000000, %%00000000
                        word    %%00022222, %%22222000
                        word    %%00000000, %%00000000
                        word    %%00000222, %%22200000
                        word    %%00000000, %%00000000
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000

pixdefsmall1            word
                        byte    2,10,8,5
                        word    %%00000001, %%10000000
                        word    %%00000011, %%11000000
                        word    %%00000111, %%11100000
                        word    %%00011111, %%11111000
                        word    %%11111111, %%11111111
                        word    %%00011111, %%11111000
                        word    %%00000111, %%11100000
                        word    %%00000011, %%11000000
                        word    %%00000001, %%10000000
                        word    %%00000000, %%00000000

pixdefsmall2            word
                        byte    2,10,8,5
                        word    %%00000002, %%20000000
                        word    %%00000022, %%22000000
                        word    %%00000222, %%22200000
                        word    %%00022222, %%22222000
                        word    %%22222222, %%22222222
                        word    %%00022222, %%22222000
                        word    %%00000222, %%22200000
                        word    %%00000022, %%22000000
                        word    %%00000002, %%20000000
                        word    %%00000000, %%0000000

pixdefhollow1           word
                        byte    2,16,8,8
                        word    %%00000001, %%10000000
                        word    %%00000011, %%11000000
                        word    %%00000110, %%01100000
                        word    %%00001100, %%00110000
                        word    %%00011000, %%00011000
                        word    %%00110000, %%00001100
                        word    %%01100000, %%00000110
                        word    %%11000000, %%00000011
                        word    %%01100000, %%00000110
                        word    %%00110000, %%00001100
                        word    %%00011000, %%00011000
                        word    %%00001100, %%00110000
                        word    %%00000110, %%01100000
                        word    %%00000011, %%11000000
                        word    %%00000001, %%10000000
                        word    %%00000000, %%00000000


pixdefhollow2           word
                        byte    2,16,8,8
                        word    %%00000002, %%20000000
                        word    %%00000022, %%22000000
                        word    %%00000220, %%02200000
                        word    %%00002200, %%00220000
                        word    %%00022000, %%00022000
                        word    %%00220000, %%00002200
                        word    %%02200000, %%00000220
                        word    %%22000000, %%00000022
                        word    %%02200000, %%00000220
                        word    %%00220000, %%00002200
                        word    %%00022000, %%00022000
                        word    %%00002200, %%00220000
                        word    %%00000220, %%02200000
                        word    %%00000022, %%22000000
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000


pixdefhollow3           word
                        byte    2,16,8,8
                        word    %%00000003, %%30000000
                        word    %%00000033, %%33000000
                        word    %%00000330, %%03300000
                        word    %%00003300, %%00330000
                        word    %%00033000, %%00033000
                        word    %%00330000, %%00003300
                        word    %%03300000, %%00000330
                        word    %%33000000, %%00000033
                        word    %%03300000, %%00000330
                        word    %%00330000, %%00003300
                        word    %%00033000, %%00033000
                        word    %%00003300, %%00330000
                        word    %%00000330, %%03300000
                        word    %%00000033, %%33000000
                        word    %%00000003, %%30000000
                        word    %%00000000, %%00000000


link1                   word
                        byte    2,16,8,8
                        word    %%00000011, %%11000000
                        word    %%00001111, %%12222000
                        word    %%00111311, %%22222200
                        word    %%01111332, %%22222000
                        word    %%01011333, %%23313000
                        word    %%00012233, %%23323332
                        word    %%00002223, %%33333002
                        word    %%00000111, %%13333002
                        word    %%00021111, %%11122232
                        word    %%00222133, %%31112232
                        word    %%00222233, %%31112202
                        word    %%00222233, %%11120002
                        word    %%00012211, %%22220002
                        word    %%00111111, %%11110000
                        word    %%00000222, %%20000000
                        word    %%00000222, %%22000000

link2                   word
                        byte    3,15,12,8
                        word    %%00000011, %%11000000, %%00000000
                        word    %%00001111, %%12222000, %%00000000
                        word    %%00011311, %%22222200, %%00000000
                        word    %%00011332, %%22222000, %%00000000
                        word    %%00111333, %%23313000, %%00000000
                        word    %%01112233, %%23323331, %%00000000
                        word    %%01002223, %%33333001, %%00000000
                        word    %%00001111, %%13333331, %%22222220
                        word    %%00011222, %%22233331, %%22222222
                        word    %%00012222, %%22233131, %%22222220
                        word    %%00112222, %%22210001, %%00000000
                        word    %%01111222, %%11122011, %%00000000
                        word    %%22111111, %%22222000, %%00000000
                        word    %%22211111, %%11112200, %%00000000
                        word    %%02220000, %%00022220, %%00000000


mario                   word
                        byte    2,15,8,8
                        word    %%00000111, %%11000000
                        word    %%00001111, %%11111000
                        word    %%00003332, %%23200000
                        word    %%00032322, %%23222000
                        word    %%00032332, %%22322200
                        word    %%00033222, %%23333000
                        word    %%00000222, %%22220000
                        word    %%00003313, %%33000000
                        word    %%00033313, %%31333000
                        word    %%00333311, %%11333300
                        word    %%00223121, %%12132200
                        word    %%00222111, %%11122200
                        word    %%00221111, %%11112200
                        word    %%00001110, %%01110000
                        word    %%00033300, %%00333000

mariojump               word
                        byte 2,16,8,8
                        word %%00000000, %%00000222
                        word %%00000011, %%11100222
                        word %%00000111, %%11111122
                        word %%00000333, %%22320333
                        word %%00003232, %%22322233
                        word %%00003233, %%22232223
                        word %%00003322, %%22333330
                        word %%00000022, %%22222300
                        word %%00333331, %%33313000
                        word %%03333333, %%13331003
                        word %%22333333, %%11111003
                        word %%22200131, %%11212133
                        word %%02030111, %%11111133
                        word %%00333111, %%11111133
                        word %%03331111, %%11100000
                        word %%03001111, %%00000000

mushroom                word
                        byte 2,16,8,8
                        word %%00000333, %%33300000
                        word %%00033000, %%01133000
                        word %%00311000, %%01111300
                        word %%03110000, %%00111130
                        word %%03100111, %%10011130
                        word %%30001111, %%11000003
                        word %%30001111, %%11001103
                        word %%31001111, %%11011113
                        word %%31100111, %%10011113
                        word %%31100000, %%00001103
                        word %%31003333, %%33330003
                        word %%03332232, %%23223330
                        word %%00322232, %%23222300
                        word %%00322222, %%22222300
                        word %%00032222, %%22223000
                        word %%00003333, %%33330000

pacmanghost1a           word
                        byte 2,14,8,8
                        word %%00000033, %%33000000
                        word %%00003333, %%33330000
                        word %%00033333, %%33333000
                        word %%00322333, %%32233300
                        word %%00222233, %%22223300
                        word %%00002233, %%00223300
                        word %%03002233, %%00223330
                        word %%03322333, %%32233330
                        word %%03333333, %%33333330
                        word %%03333333, %%33333330
                        word %%03333333, %%33333330
                        word %%03333333, %%33333330
                        word %%03303330, %%03330330
                        word %%03000330, %%03300030


pacmanghost1b           word
                        byte 2,14,8,8
                        word %%00000033, %%33000000
                        word %%00003333, %%33330000
                        word %%00033333, %%33333000
                        word %%00322333, %%32233300
                        word %%00222233, %%22223300
                        word %%00002233, %%00223300
                        word %%03002233, %%00223330
                        word %%03322333, %%32233330
                        word %%03333333, %%33333330
                        word %%03333333, %%33333330
                        word %%03333333, %%33333330
                        word %%03333333, %%33333330
                        word %%03333033, %%33033330
                        word %%00330003, %%30003300

pacmandead1a            word
                        byte 2,14,8,8
                        word %%00000022, %%22000000
                        word %%00002222, %%22220000
                        word %%00022222, %%22222000
                        word %%00222222, %%22222200
                        word %%00222332, %%23322200
                        word %%00222332, %%23322200
                        word %%02222222, %%22222220
                        word %%02222222, %%22222220
                        word %%02233223, %%32233220
                        word %%02322332, %%23322020
                        word %%02222222, %%22222220
                        word %%02222222, %%22222220
                        word %%02202220, %%02220220
                        word %%02000220, %%02200020

pacmandead1b            word
                        byte 2,14,8,8
                        word %%00000022, %%22000000
                        word %%00002222, %%22220000
                        word %%00022222, %%22222000
                        word %%00222222, %%22222200
                        word %%00222332, %%23322200
                        word %%00222332, %%23322200
                        word %%02222222, %%22222220
                        word %%02222222, %%22222220
                        word %%02233223, %%32233220
                        word %%02322332, %%23322320
                        word %%02222222, %%22222220
                        word %%02222222, %%22222220
                        word %%02222022, %%22022220
                        word %%00220002, %%20002200

pacman1                 word
                        byte 2,16,8,8
                        word %%00000000, %%00000000
                        word %%00000011, %%11100000
                        word %%00001111, %%11111000
                        word %%00011111, %%11111100
                        word %%00011111, %%11111100
                        word %%00111111, %%11111110
                        word %%00111111, %%11111110
                        word %%00111111, %%11111110
                        word %%00111111, %%11111110
                        word %%00111111, %%11111110
                        word %%00011111, %%11111100
                        word %%00011111, %%11111100
                        word %%00001111, %%11111000
                        word %%00000011, %%11100000
                        word %%00000000, %%00000000
                        word %%00000000, %%00000000

pacman2                 word
                        byte 2,16,8,8
                        word %%00000000, %%00000000
                        word %%00000011, %%11100000
                        word %%00001111, %%11111000
                        word %%00011111, %%11111100
                        word %%00011111, %%11111100
                        word %%00000111, %%11111110
                        word %%00000000, %%11111110
                        word %%00000000, %%00011110
                        word %%00000000, %%11111110
                        word %%00000111, %%11111110
                        word %%00011111, %%11111100
                        word %%00011111, %%11111100
                        word %%00001111, %%11111000
                        word %%00000011, %%11100000
                        word %%00000000, %%00000000
                        word %%00000000, %%00000000

pacman3                 word
                        byte 2,16,8,8
                        word %%00000000, %%00000000
                        word %%00000011, %%11100000
                        word %%00000011, %%11111000
                        word %%00000001, %%11111100
                        word %%00000000, %%11111100
                        word %%00000000, %%01111110
                        word %%00000000, %%00111110
                        word %%00000000, %%00011110
                        word %%00000000, %%00111110
                        word %%00000000, %%01111110
                        word %%00000000, %%11111100
                        word %%00000001, %%11111100
                        word %%00000011, %%11111000
                        word %%00000011, %%11100000
                        word %%00000000, %%00000000
                        word %%00000000, %%00000000

pacmanfood              word
                        byte 2,8,4,4
                        word %%00222200, %%00000000
                        word %%02222220, %%00000000
                        word %%22222222, %%00000000
                        word %%22222222, %%00000000
                        word %%22222222, %%00000000
                        word %%22222222, %%00000000
                        word %%02222220, %%00000000
                        word %%00222200, %%00000000

SpaceInvaders1          word
                        byte 2,8,7,4
                        word %%00001000, %%00100000
                        word %%00000100, %%01000000
                        word %%00001111, %%11100000
                        word %%00011011, %%10110000
                        word %%00111111, %%11111000
                        word %%00101111, %%11101000
                        word %%00101000, %%00101000
                        word %%00000110, %%11000000

SpaceInvaders2          word
                        byte 2,8,7,4
                        word %%00001000, %%00100000
                        word %%00100100, %%01001000
                        word %%00101111, %%11101000
                        word %%00111011, %%10111000
                        word %%00111111, %%11111000
                        word %%00011111, %%11110000
                        word %%00001000, %%00100000
                        word %%00010000, %%00010000

SpaceInvaders3          word
                        byte 2,8,7,4
                        word %%00002000, %%00200000
                        word %%00000200, %%02000000
                        word %%00002222, %%22200000
                        word %%00022022, %%20220000
                        word %%00222222, %%22222000
                        word %%00202222, %%22202000
                        word %%00202000, %%00202000
                        word %%00000220, %%22000000

SpaceInvaders4          word
                        byte 2,8,7,4
                        word %%00002000, %%00200000
                        word %%00200200, %%02002000
                        word %%00202222, %%22202000
                        word %%00222022, %%20222000
                        word %%00222222, %%22222000
                        word %%00022222, %%22220000
                        word %%00002000, %%00200000
                        word %%00020000, %%00020000

galaga                  word
                        byte 2,16,8,8
                        word %%00000001, %%00000000
                        word %%00000001, %%00000000
                        word %%00000001, %%00000000
                        word %%00000011, %%10000000
                        word %%00000011, %%10000000
                        word %%00020011, %%10020000
                        word %%00020011, %%10020000
                        word %%00010111, %%11010000
                        word %%20013112, %%11310020
                        word %%20031122, %%21130020
                        word %%10011121, %%21110010
                        word %%10111111, %%11111010
                        word %%11111211, %%12111110
                        word %%11102211, %%12201110
                        word %%11002201, %%02200110
                        word %%10000001, %%00000010

galagamoth1             word
                        byte 2,10,8,5
                        word %%00020030, %%30020000
                        word %%02220030, %%30022200
                        word %%02220121, %%21022200
                        word %%02220111, %%11022200
                        word %%00222211, %%12222000
                        word %%00022233, %%32220000
                        word %%00222233, %%32222000
                        word %%02222211, %%12222200
                        word %%00222033, %%30222000
                        word %%00002000, %%00200000

galagamoth2             word
                        byte 2,10,8,5
                        word %%00020000, %%00020000
                        word %%00020030, %%30020000
                        word %%00020121, %%21020000
                        word %%00020111, %%11020000
                        word %%00022211, %%12220000
                        word %%00000233, %%32000000
                        word %%00022233, %%32220000
                        word %%00022211, %%12220000
                        word %%00022033, %%30220000
                        word %%00002003, %%00200000

galagapew               word
                        byte 1,6,4,3
                        word %%00030000
                        word %%00333000
                        word %%00313000
                        word %%00020000
                        word %%00020000
                        word %%00020000

digdug1                 word
                        byte 2,14,8,7
                        word %%00000000, %%11100000
                        word %%00000000, %%11111000
                        word %%00000011, %%11111100
                        word %%00001111, %%11111110
                        word %%00003030, %%33331110
                        word %%00003030, %%33331110
                        word %%00000333, %%33311110
                        word %%00020011, %%11133000
                        word %%00220111, %%11133100
                        word %%02222222, %%33332220
                        word %%00220111, %%33311000
                        word %%00020011, %%11111100
                        word %%00000001, %%10001100
                        word %%00000111, %%10111100

digdug2                 word
                        byte 2,14,8,7
                        word %%00000000, %%11100000
                        word %%00000000, %%11111000
                        word %%00000011, %%11111100
                        word %%00001111, %%11111110
                        word %%00003030, %%33331110
                        word %%00003030, %%33331110
                        word %%00000333, %%33311110
                        word %%00020011, %%11133000
                        word %%00220001, %%11133100
                        word %%02222222, %%33332220
                        word %%00220001, %%33311100
                        word %%00020000, %%11111000
                        word %%00000000, %%01100000
                        word %%00000001, %%11100000

digdug3                 word
                        byte 2,14,8,7
                        word %%00000000, %%01110000
                        word %%00000000, %%01111100
                        word %%00000001, %%11111110
                        word %%00000111, %%11111111
                        word %%00000303, %%03333111
                        word %%00000303, %%03333111
                        word %%00000033, %%33331111
                        word %%00333111, %%11113310
                        word %%00332222, %%33333311
                        word %%20000211, %%33311111
                        word %%22000211, %%11311110
                        word %%02202221, %%11111110
                        word %%00222220, %%00011100
                        word %%00022222, %%00111110

digdug4                 word
                        byte 2,14,8,7
                        word %%00000000, %%00000000
                        word %%00000000, %%11100000
                        word %%00000000, %%11111000
                        word %%00000011, %%11111100
                        word %%00001111, %%11111110
                        word %%00003030, %%33331110
                        word %%00003030, %%33331110
                        word %%00000333, %%33311110
                        word %%00033111, %%11111331
                        word %%02033222, %%23333331
                        word %%02211121, %%13331111
                        word %%00221222, %%11111111
                        word %%00022222, %%10001110
                        word %%00002222, %%20111100

digdug5                 word
                        byte 2,14,8,7
                        word %%00000000, %%01110000
                        word %%00000000, %%01111100
                        word %%00000001, %%11111110
                        word %%00000111, %%11111111
                        word %%00000303, %%03333111
                        word %%00000303, %%03333111
                        word %%00000033, %%33331111
                        word %%00033001, %%11113330
                        word %%00033311, %%11111333
                        word %%00003311, %%11111133
                        word %%00000011, %%11113331
                        word %%00000001, %%11113311
                        word %%00000011, %%10001111
                        word %%00000111, %%00000001
                        
{digdugc1                 word
                        byte 2,14,8,7
                        word %%00000000, %%12220011
                        word %%00000000, %%11222211
                        word %%00000011, %%11122200
                        word %%00001111, %%11112200
                        word %%00003030, %%33331200
                        word %%00003030, %%33331100
                        word %%00000333, %%33311100
                        word %%00020011, %%11133000
                        word %%00220111, %%11133100
                        word %%02222222, %%33332220
                        word %%00220111, %%33311000
                        word %%00020011, %%11111100
                        word %%00000001, %%10001100
                        word %%00000111, %%10111100

digdugc2                 word
                        byte 2,14,8,7
                        word %%00000000, %%12220011
                        word %%00000000, %%11222211
                        word %%00000011, %%11122200
                        word %%00001111, %%11112200
                        word %%00003030, %%33331200
                        word %%00003030, %%33331100
                        word %%00000333, %%33311100
                        word %%00020011, %%11133000
                        word %%00220001, %%11133100
                        word %%02222222, %%33332220
                        word %%00220001, %%33311100
                        word %%00020000, %%11111000
                        word %%00000000, %%01100000
                        word %%00000001, %%11100000

digdugc3                 word
                        byte 2,14,8,7
                        word %%00000000, %%02222011
                        word %%00000000, %%01222211
                        word %%00000001, %%11112200
                        word %%00000111, %%11111200
                        word %%00000303, %%03333100
                        word %%00000303, %%03333110
                        word %%00000033, %%33331111
                        word %%00333111, %%11113310
                        word %%00332222, %%33333311
                        word %%20000211, %%33311111
                        word %%22000211, %%11311110
                        word %%02202221, %%11111110
                        word %%00222220, %%00011100
                        word %%00022222, %%00111110

digdugc4                 word
                        byte 2,14,8,7
                        word %%00000000, %%00000000
                        word %%00000000, %%22200011
                        word %%00000000, %%12222011
                        word %%00000011, %%11222200
                        word %%00001111, %%11122220
                        word %%00003030, %%33332220
                        word %%00003030, %%33331220
                        word %%00000333, %%33311120
                        word %%00033111, %%11111331
                        word %%02033222, %%23333331
                        word %%02211121, %%13331111
                        word %%00221222, %%11111111
                        word %%00022222, %%10001110
                        word %%00002222, %%20111100

digdugc5                 word
                        byte 2,14,8,7
                        word %%00000000, %%02222011
                        word %%00000000, %%01222211
                        word %%00000001, %%11122220
                        word %%00000111, %%11112220
                        word %%00000303, %%03333220
                        word %%00000303, %%03333120
                        word %%00000033, %%33331110
                        word %%00033001, %%11113330
                        word %%00033311, %%11111333
                        word %%00003311, %%11111133
                        word %%00000011, %%11113331
                        word %%00000001, %%11113311
                        word %%00000011, %%10001111
                        word %%00000111, %%00000001}


digdugharpoon           word
                        byte 2, 5, 8, 3
                        word %%00200000, %%00000111
                        word %%02200000, %%00011000
                        word %%22210000, %%00100000
                        word %%02201000, %%11000000
                        word %%00200111, %%00000000

fygar1                  word
                        byte 2,14,8,7
                        word %%00003333, %%33000000
                        word %%00333333, %%33110000
                        word %%00010133, %%31111000
                        word %%00000000, %%01100100
                        word %%00000000, %%03100100
                        word %%00101013, %%33311100
                        word %%00333333, %%33300000
                        word %%00033333, %%32222000
                        word %%00000333, %%30222220
                        word %%00003223, %%33222220
                        word %%00023322, %%33320200
                        word %%00022332, %%23333300
                        word %%00222000, %%22033330
                        word %%00000000, %%20000000

fygar2                  word
                        byte 2,14,8,7
                        word %%00003333, %%33000000
                        word %%00333333, %%33110000
                        word %%00010133, %%31001000
                        word %%00101010, %%31000100
                        word %%00333330, %%03101100
                        word %%00033333, %%33311100
                        word %%00000333, %%33322200
                        word %%00000003, %%32222220
                        word %%00000033, %%33202020
                        word %%00203333, %%33000000
                        word %%00203333, %%23300030
                        word %%00023333, %%23333330
                        word %%00020022, %%22033300
                        word %%00000000, %%00000000

fygar3                  word
                        byte 2,14,8,7
                        word %%00000333, %%33300000
                        word %%00033333, %%33333000
                        word %%00010033, %%33311100
                        word %%00000103, %%33100100
                        word %%00333301, %%33100000
                        word %%00003330, %%00311100
                        word %%00000033, %%33333000
                        word %%00000003, %%32222200
                        word %%22000233, %%20202000
                        word %%02223233, %%33200000
                        word %%00203222, %%33300000
                        word %%00000023, %%33033300
                        word %%00000020, %%03330000
                        word %%00000000, %%00000000

fygar4                  word
                        byte    3,19,12,9
                        word    %%00000000, %%03333333, %%00000000
                        word    %%00000003, %%33333333, %%33000000
                        word    %%00000333, %%33333333, %%33300000
                        word    %%00000100, %%01333333, %%11100000
                        word    %%00000001, %%00003331, %%00010000
                        word    %%00003333, %%33100331, %%00010000
                        word    %%00000033, %%33330033, %%11120000
                        word    %%00000000, %%33333333, %%33300000
                        word    %%00000003, %%33333333, %%33000000
                        word    %%00000331, %%11333333, %%33300000
                        word    %%00000311, %%11133333, %%32222000
                        word    %%00220111, %%11113333, %%23222000
                        word    %%00020111, %%11113333, %%33232000
                        word    %%00022211, %%11111333, %%33330000
                        word    %%00002111, %%11111333, %%33330000
                        word    %%00000311, %%22211333, %%33300300
                        word    %%00000033, %%32222333, %%33003300
                        word    %%00000003, %%33322233, %%33333000
                        word    %%00000000, %%00002003, %%33300000

fygar5                  word
                        byte    3,23,12,8
                        word    %%00000000, %%00000000, %%00000000
                        word    %%00000000, %%00000000, %%00000000
                        word    %%00000000, %%33333333, %%30000000
                        word    %%00000333, %%33333333, %%33300000
                        word    %%00033333, %%33333333, %%33330000
                        word    %%00010001, %%03333333, %%33111000
                        word    %%00000100, %%00033333, %%31000100
                        word    %%00333333, %%31003333, %%31000100
                        word    %%00003333, %%33300333, %%33111000
                        word    %%00000033, %%33333333, %%33333000
                        word    %%00000333, %%33333333, %%33333000
                        word    %%00003111, %%11333333, %%33330000
                        word    %%00031111, %%11133333, %%33300000
                        word    %%00031111, %%11113333, %%33330000
                        word    %%00311111, %%11113333, %%32223000
                        word    %%00311111, %%11111333, %%23222200
                        word    %%00311111, %%11111333, %%33232200
                        word    %%00311111, %%11111333, %%33333200
                        word    %%00311111, %%11111333, %%33333000
                        word    %%00031111, %%11111333, %%33330000
                        word    %%00031111, %%11113333, %%33300300
                        word    %%00003232, %%21132223, %%33333000
                        word    %%00000022, %%23302200, %%33300000

fygar6                  word
                        byte    3,23,12,8
                        word    %%00000000, %%00333000, %%00000000
                        word    %%00000000, %%00033333, %%00000000
                        word    %%00000000, %%00003333, %%33000000
                        word    %%10000000, %%00003333, %%33330000
                        word    %%00000000, %%00001333, %%33333000
                        word    %%00000000, %%31000033, %%33111100
                        word    %%00000010, %%33300003, %%31000010
                        word    %%10000000, %%33331033, %%31000010
                        word    %%00010000, %%03333333, %%31100113
                        word    %%00001103, %%31333333, %%33311133
                        word    %%00000111, %%31333333, %%33333333
                        word    %%01011100, %%11333333, %%33333330
                        word    %%00110000, %%01331333, %%33333000
                        word    %%00110000, %%00113333, %%33222220
                        word    %%11100000, %%00013333, %%33323202
                        word    %%01100001, %%10133333, %%33333000
                        word    %%00100000, %%11133333, %%33333000
                        word    %%00010000, %%11113333, %%33333000
                        word    %%01111000, %%01333333, %%33333000
                        word    %%22011000, %%11333333, %%33330000
                        word    %%02221131, %%33223333, %%33300033
                        word    %%00221333, %%33222323, %%33333330
                        word    %%00000000, %%33332223, %%33333000

{fygarc1                  word
                        byte 2,14,8,7
                        word %%02003333, %%33000000
                        word %%00333333, %%33110000
                        word %%00010133, %%31111000
                        word %%00000000, %%01100100
                        word %%00000000, %%03100100
                        word %%00101013, %%33311100
                        word %%00333333, %%33300000
                        word %%00033333, %%32222000
                        word %%00000333, %%30222220
                        word %%00003223, %%33222220
                        word %%00023322, %%33320200
                        word %%00022332, %%23333300
                        word %%00222000, %%22033330
                        word %%00000000, %%20000000

fygarc2                  word
                        byte 2,14,8,7
                        word %%02003333, %%33000000
                        word %%00333333, %%33110000
                        word %%00010133, %%31001000
                        word %%00101010, %%31000100
                        word %%00333330, %%03101100
                        word %%00033333, %%33311100
                        word %%00000333, %%33322200
                        word %%00000003, %%32222220
                        word %%00000033, %%33202020
                        word %%00203333, %%33000000
                        word %%00203333, %%23300030
                        word %%00023333, %%23333330
                        word %%00020022, %%22033300
                        word %%00000000, %%00000000

fygarc3                  word
                        byte 2,14,8,7
                        word %%00200333, %%33300000
                        word %%00033333, %%33333000
                        word %%00010033, %%33311100
                        word %%00000103, %%33100100
                        word %%00333301, %%33100000
                        word %%00003330, %%00311100
                        word %%00000033, %%33333000
                        word %%00000003, %%32222200
                        word %%22000233, %%20202000
                        word %%02223233, %%33200000
                        word %%00203222, %%33300000
                        word %%00000023, %%33033300
                        word %%00000020, %%03330000
                        word %%00000000, %%00000000

fygarc4                  word
                        byte    3,19,12,9
                        word    %%00022000, %%03333333, %%00000000
                        word    %%00022003, %%33333333, %%33000000
                        word    %%00000333, %%33333333, %%33300000
                        word    %%00000100, %%01333333, %%11100000
                        word    %%00000001, %%00003331, %%00010000
                        word    %%00003333, %%33100331, %%00010000
                        word    %%00000033, %%33330033, %%11120000
                        word    %%00000000, %%33333333, %%33300000
                        word    %%00000003, %%33333333, %%33000000
                        word    %%00000331, %%11333333, %%33300000
                        word    %%00000311, %%11133333, %%32222000
                        word    %%00220111, %%11113333, %%23222000
                        word    %%00020111, %%11113333, %%33232000
                        word    %%00022211, %%11111333, %%33330000
                        word    %%00002111, %%11111333, %%33330000
                        word    %%00000311, %%22211333, %%33300300
                        word    %%00000033, %%32222333, %%33003300
                        word    %%00000003, %%33322233, %%33333000
                        word    %%00000000, %%00002003, %%33300000

fygarc5                  word
                        byte    3,23,12,8
                        word    %%00000000, %%00000000, %%00000000
                        word    %%00000000, %%00000000, %%00000000
                        word    %%02200000, %%33333333, %%30000000
                        word    %%02200333, %%33333333, %%33300000
                        word    %%00033333, %%33333333, %%33330000
                        word    %%00010001, %%03333333, %%33111000
                        word    %%00000100, %%00033333, %%31000100
                        word    %%00333333, %%31003333, %%31000100
                        word    %%00003333, %%33300333, %%33111000
                        word    %%00000033, %%33333333, %%33333000
                        word    %%00000333, %%33333333, %%33333000
                        word    %%00003111, %%11333333, %%33330000
                        word    %%00031111, %%11133333, %%33300000
                        word    %%00031111, %%11113333, %%33330000
                        word    %%00311111, %%11113333, %%32223000
                        word    %%00311111, %%11111333, %%23222200
                        word    %%00311111, %%11111333, %%33232200
                        word    %%00311111, %%11111333, %%33333200
                        word    %%00311111, %%11111333, %%33333000
                        word    %%00031111, %%11111333, %%33330000
                        word    %%00031111, %%11113333, %%33300300
                        word    %%00003232, %%21132223, %%33333000
                        word    %%00000022, %%23302200, %%33300000

fygarc6                  word
                        byte    3,23,12,8
                        word    %%00000000, %%02233000, %%00000000
                        word    %%00000000, %%00033333, %%00000000
                        word    %%00000000, %%00003333, %%33000000
                        word    %%10000000, %%00003333, %%33330000
                        word    %%00000000, %%00001333, %%33333000
                        word    %%00000000, %%31000033, %%33111100
                        word    %%00000010, %%33300003, %%31000010
                        word    %%10000000, %%33331033, %%31000010
                        word    %%00010000, %%03333333, %%31100113
                        word    %%00001103, %%31333333, %%33311133
                        word    %%00000111, %%31333333, %%33333333
                        word    %%01011100, %%11333333, %%33333330
                        word    %%00110000, %%01331333, %%33333000
                        word    %%00110000, %%00113333, %%33222220
                        word    %%11100000, %%00013333, %%33323202
                        word    %%01100001, %%10133333, %%33333000
                        word    %%00100000, %%11133333, %%33333000
                        word    %%00010000, %%11113333, %%33333000
                        word    %%01111000, %%01333333, %%33333000
                        word    %%22011000, %%11333333, %%33330000
                        word    %%02221131, %%33223333, %%33300033
                        word    %%00221333, %%33222323, %%33333330
                        word    %%00000000, %%33332223, %%33333000}


bubblebobble1           word
                        byte 2,16,8,8
                        word %%00000000, %%20000000
                        word %%00000002, %%22000000
                        word %%00022221, %%11110000
                        word %%00002211, %%11111000
                        word %%00000111, %%13313100
                        word %%00222111, %%33010300
                        word %%00021111, %%33010300
                        word %%00001111, %%33010310
                        word %%00221111, %%33010310
                        word %%00021111, %%13313110
                        word %%00001211, %%00030000
                        word %%00012221, %%11111100
                        word %%00012221, %%13333000
                        word %%00212211, %%33333300
                        word %%02111112, %%23333300
                        word %%11111122, %%22333222

bubblebobble2           word
                        byte 2,16,8,8
                        word %%00000002, %%00000000
                        word %%00000022, %%23300000
                        word %%00022221, %%10331000
                        word %%00002213, %%01033100
                        word %%00000133, %%00131100
                        word %%00222133, %%30311000
                        word %%00021113, %%33313000
                        word %%00001111, %%33100000
                        word %%00221111, %%11000000
                        word %%00000111, %%10000000
                        word %%00022211, %%00000000
                        word %%00022221, %%11111100
                        word %%10002211, %%13333000
                        word %%12211111, %%33333300
                        word %%01111112, %%22333300
                        word %%00111122, %%22233222

bubblebobble3           word
                        byte 2,16,8,8
                        word %%00000000, %%20000000
                        word %%00000002, %%22000000
                        word %%00022221, %%11110000
                        word %%00002211, %%11111000
                        word %%00000111, %%13313100
                        word %%00222111, %%33010300
                        word %%00021111, %%33010300
                        word %%00001111, %%33010310
                        word %%00221111, %%33010310
                        word %%00021111, %%13313110
                        word %%00001211, %%00030000
                        word %%00012221, %%11111100
                        word %%10012221, %%13333000
                        word %%12212211, %%33333300
                        word %%01111112, %%23333300
                        word %%00111122, %%22333222

bubble1                 word
                        byte 1,8,4,4
                        word %%00011000
                        word %%00111100
                        word %%01331110
                        word %%01311110
                        word %%01111310
                        word %%01113310
                        word %%00111100
                        word %%00011000

bubble2                 word
                        byte 1,10,4,5
                        word %%00111100
                        word %%01131110
                        word %%11311111
                        word %%13111111
                        word %%11111111
                        word %%11111111
                        word %%11111131
                        word %%11111311
                        word %%01113110
                        word %%00111100

bubble3                 word
                        byte 2,14,8,7
                        word %%00000001, %%10000000
                        word %%00000111, %%11100000
                        word %%00001331, %%11110000
                        word %%00013311, %%11111000
                        word %%00013111, %%11111000
                        word %%00111111, %%11111100
                        word %%00111111, %%11111100
                        word %%00111111, %%11111100
                        word %%00111111, %%11111100
                        word %%00011111, %%11131000
                        word %%00011111, %%11331000
                        word %%00001111, %%13310000
                        word %%00000111, %%11100000
                        word %%00000001, %%1000000

bubble4                 word
                        byte 2,16,8,8
                        word %%00000011, %%11000000
                        word %%00001100, %%00110000
                        word %%00010300, %%00001000
                        word %%00013330, %%00001000
                        word %%00103330, %%00000100
                        word %%00103330, %%00000100
                        word %%01000300, %%00000010
                        word %%01000000, %%00000010
                        word %%01000000, %%00000010
                        word %%01000000, %%00000010
                        word %%00100000, %%00000100
                        word %%00100000, %%00300100
                        word %%00010000, %%03001000
                        word %%00010000, %%00001000
                        word %%00001100, %%00110000
                        word %%00000011, %%11000000

finalfantasy1           word
                        byte 2,24,8,12
                        word %%00000000, %%00000110
                        word %%00000000, %%00011130
                        word %%00000000, %%00111300
                        word %%00000000, %%11113300
                        word %%00000011, %%11333000
                        word %%11111111, %%33333000
                        word %%03333111, %%13333000
                        word %%00003333, %%11130000
                        word %%00000003, %%33333000
                        word %%00001000, %%00333300
                        word %%00001001, %%00003330
                        word %%00200001, %%00002033
                        word %%02000000, %%00000000
                        word %%02220001, %%11020111
                        word %%00222201, %%10101011
                        word %%02222220, %%01020100
                        word %%02222222, %%00222000
                        word %%02222222, %%02222200
                        word %%00222222, %%02202200
                        word %%00002200, %%22220000
                        word %%00020022, %%22222000
                        word %%00022222, %%22222000
                        word %%01102222, %%22220110
                        word %%11110222, %%22201111

finalfantasy2           word
                        byte 2,24,8,12
                        word %%00000000, %%00000000
                        word %%00000000, %%00000110
                        word %%00000000, %%00011130
                        word %%00000000, %%00111300
                        word %%00000000, %%11113300
                        word %%00000011, %%11333000
                        word %%11111111, %%33333000
                        word %%03333111, %%13333000
                        word %%00003333, %%11130000
                        word %%00000003, %%33333000
                        word %%00001000, %%00333300
                        word %%00001001, %%00003330
                        word %%02000001, %%00002033
                        word %%02011100, %%01110200
                        word %%00011010, %%10110000
                        word %%00200102, %%01002000
                        word %%00222002, %%00222000
                        word %%00222202, %%02222000
                        word %%00022202, %%02220000
                        word %%00202022, %%20202200
                        word %%00220222, %%22022200
                        word %%00222222, %%22222200
                        word %%01022222, %%22222010
                        word %%11102222, %%22200111

finalfantasy3           word
                        byte 2,24,8,12
                        word %%01100000, %%00000000
                        word %%03111000, %%00000000
                        word %%00311100, %%00000000
                        word %%00331111, %%00000000
                        word %%00033311, %%11000000
                        word %%00033333, %%11111111
                        word %%00033331, %%11133330
                        word %%00003111, %%33330000
                        word %%00033333, %%30000000
                        word %%00333300, %%00010000
                        word %%03330000, %%10010000
                        word %%33020000, %%10000200
                        word %%00000000, %%00000020
                        word %%11102011, %%10002220
                        word %%11010101, %%10222200
                        word %%00102010, %%02222220
                        word %%00022200, %%22222220
                        word %%00222220, %%22222220
                        word %%00220220, %%22222200
                        word %%00002222, %%00220000
                        word %%00022222, %%22002200
                        word %%00022222, %%22222200
                        word %%01102222, %%22220110
                        word %%11110222, %%22201111

finalfantasy4           word
                        byte 2,24,8,12
                        word %%00000000, %%00000000
                        word %%01100000, %%00000000
                        word %%03111000, %%00000000
                        word %%00311100, %%00000000
                        word %%00331111, %%00000000
                        word %%00033311, %%11000000
                        word %%00033333, %%11111111
                        word %%00033331, %%11133330
                        word %%00003111, %%33330000
                        word %%00033333, %%30000000
                        word %%00333300, %%00010000
                        word %%03330000, %%10010000
                        word %%33020000, %%10000020
                        word %%00200000, %%00000020
                        word %%00022011, %%01102200
                        word %%00222011, %%01102220
                        word %%00222200, %%20022220
                        word %%00222202, %%22022220
                        word %%00002202, %%22022000
                        word %%00202202, %%22022020
                        word %%00220022, %%22200220
                        word %%00022222, %%22222200
                        word %%01102222, %%22220110
                        word %%11110222, %%22201111

easteregg1              word
                        byte 10,28,40,14
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00000000, %%00000000, %%00000000, %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011111, %%11111100, %%00000000, %%00000000, %%00000011, %%11111000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%01111111, %%11111111, %%11000000, %%00000000, %%11111111, %%11111100
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%01111111, %%11111111, %%11111001, %%11110011, %%11111111, %%11111100
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00110011, %%11111111, %%11111011, %%11111011, %%11111111, %%11111100
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00110011, %%11111111, %%11111011, %%11111011, %%11111111, %%11111100
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00110001, %%11111111, %%11111011, %%11111011, %%11111111, %%11111000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011000, %%11111111, %%11111011, %%11111011, %%11111111, %%11111000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011000, %%01111111, %%11111011, %%11111011, %%11111111, %%11110000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011000, %%01111111, %%11111011, %%11111011, %%11111111, %%11110000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00001100, %%01111111, %%11111011, %%11111011, %%11111111, %%11110000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00001100, %%00111111, %%11111011, %%11111011, %%11111111, %%11100000
                        word %%00000000, %%01100000, %%00000000, %%00000000, %%00001110, %%00111111, %%11111011, %%11111011, %%11111111, %%11100000
                        word %%00011100, %%00110000, %%00000000, %%00000000, %%00000110, %%00111111, %%11111011, %%11111011, %%11111111, %%11000000
                        word %%00000110, %%11100010, %%10000000, %%00000000, %%00000110, %%00111111, %%11111011, %%11111011, %%11111111, %%11000000
                        word %%00000011, %%11101010, %%11111111, %%11110000, %%00000110, %%00111111, %%11111011, %%11111011, %%11111111, %%11000000
                        word %%00000111, %%11101010, %%11111111, %%11111000, %%00000000, %%00111111, %%11111011, %%11111011, %%11111111, %%11000000
                        word %%00011111, %%11101011, %%11111111, %%11111100, %%00000100, %%00000000, %%00000000, %%00000000, %%00000000, %%00000000
                        word %%00011111, %%11101111, %%11111111, %%11111100, %%00000101, %%01010001, %%11100101, %%01010101, %%00011110, %%01000000
                        word %%00000001, %%10011111, %%11111111, %%11111101, %%01010101, %%01000110, %%11011001, %%01010100, %%01101101, %%10000000
                        word %%00000000, %%01111111, %%11111111, %%11111100, %%00000001, %%01001100, %%11001101, %%01010100, %%11001100, %%11000000
                        word %%00000000, %%01111111, %%11111111, %%11111000, %%00000101, %%00010000, %%11000110, %%01010001, %%10001100, %%00100000
                        word %%00000000, %%00011111, %%11111111, %%11110000, %%00000101, %%00011111, %%11000010, %%01010001, %%00001111, %%11100000
                        word %%00000000, %%00011111, %%11100011, %%11110000, %%00000001, %%00010000, %%11111110, %%01010001, %%11111100, %%00100000
                        word %%00000000, %%00011111, %%00000011, %%11110000, %%00000000, %%00011000, %%11000010, %%00000001, %%00001100, %%01100000
                        word %%00000000, %%00011011, %%10000111, %%01100000, %%00000000, %%00001100, %%11001100, %%00000000, %%11001100, %%11000000
                        word %%00000000, %%00111001, %%10000111, %%01100000, %%00000000, %%00000110, %%11011000, %%00000000, %%01101101, %%10000000
                        word %%00000000, %%01110001, %%10000001, %%11100000, %%00000000, %%00000011, %%11110000, %%00000000, %%00111111, %%00000000

easteregg2              word
                        byte 10,28,40,14
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011111, %%11111100, %%00000000, %%00000000, %%00000011, %%11111000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%01111111, %%11111111, %%11000000, %%00000000, %%11111111, %%11111100
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%01111111, %%11111111, %%11111001, %%11110011, %%11111111, %%11111100
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00110011, %%11111111, %%11111011, %%11111011, %%11111111, %%11111100
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00110011, %%11111111, %%11111011, %%11111011, %%11111111, %%11111100
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00110001, %%11111111, %%11111011, %%11111011, %%11111111, %%11111000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011000, %%11111111, %%11111011, %%11111011, %%11111111, %%11111000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011000, %%11111111, %%11111011, %%11111011, %%11111111, %%11111000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011000, %%01111111, %%11111011, %%11111011, %%11111111, %%11110000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00011000, %%01111111, %%11111011, %%11111011, %%11111111, %%11110000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00001100, %%01111111, %%11111011, %%11111011, %%11111111, %%11110000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00001100, %%00111111, %%11111011, %%11111011, %%11111111, %%11100000
                        word %%00000000, %%00000000, %%00000000, %%00000000, %%00001110, %%00111111, %%11111011, %%11111011, %%11111111, %%11100000
                        word %%00000000, %%01100000, %%00000000, %%00000000, %%00000110, %%00111111, %%11111011, %%11111011, %%11111111, %%11000000
                        word %%00011100, %%00110010, %%10000000, %%00000000, %%00000110, %%00111111, %%11111011, %%11111011, %%11111111, %%11000000
                        word %%00000110, %%11101010, %%11110001, %%11100000, %%00000110, %%00111111, %%11111011, %%11111011, %%11111111, %%11000000
                        word %%00000011, %%11101010, %%11111111, %%11111000, %%00000000, %%00111111, %%11111011, %%11111011, %%11111111, %%11000000
                        word %%00000111, %%11101011, %%11111111, %%11111100, %%00000100, %%00000000, %%00000000, %%00000000, %%00000000, %%00000000
                        word %%00011111, %%11101111, %%11111111, %%11111100, %%00000101, %%01010001, %%11100101, %%01010101, %%00011110, %%01000000
                        word %%00011111, %%10011111, %%11111111, %%11111101, %%01010101, %%01000110, %%00011001, %%01010100, %%01100001, %%10000000
                        word %%00000001, %%01111111, %%11111111, %%11111100, %%00000001, %%01001100, %%00001101, %%01010100, %%11000000, %%11000000
                        word %%00000000, %%01111111, %%11111111, %%11111000, %%00000101, %%00010111, %%00110110, %%01010001, %%10110011, %%00100000
                        word %%00000000, %%00011111, %%11111111, %%11110000, %%00000101, %%00010000, %%11000010, %%01010001, %%00001100, %%00100000
                        word %%00000000, %%00001111, %%11100011, %%11110000, %%00000001, %%00010000, %%11000010, %%01010001, %%00001100, %%00100000
                        word %%00000000, %%00001111, %%00000011, %%11110000, %%00000000, %%00011011, %%00111010, %%00000001, %%00110011, %%01100000
                        word %%00000000, %%00001111, %%00000011, %%00111000, %%00000000, %%00001100, %%00001100, %%00000000, %%11000000, %%11000000
                        word %%00000000, %%00011011, %%00000110, %%00111000, %%00000000, %%00000110, %%00011000, %%00000000, %%01100001, %%10000000
                        word %%00000000, %%00110001, %%10001100, %%00111110, %%00000000, %%00000011, %%11110000, %%00000000, %%00111111, %%00000000

yhdod                   word
                        byte 16,8,64,4
                        word %%10001000, %%00000000, %%00010000, %%00000000, %%00000000, %%00000000, %%10100000, %%00000010, %%00000000, %%11000000, %%10000000, %%00000000, %%00000000, %%00010000, %%00000000, %%00000000
                        word %%10001000, %%00000000, %%00010000, %%00000000, %%00000000, %%00000000, %%10000000, %%00000010, %%00000001, %%00000000, %%10000000, %%00000000, %%00000000, %%00010000, %%00000000, %%00000000
                        word %%01010001, %%11001000, %%10010000, %%00111101, %%00010011, %%10000000, %%10100111, %%00000010, %%00111001, %%00000000, %%10100010, %%01110001, %%11001111, %%00111100, %%01110010, %%11010001
                        word %%01010010, %%00101000, %%10011110, %%01000101, %%00010100, %%01000111, %%10101000, %%10011110, %%01000101, %%11000111, %%10100010, %%10001010, %%00101000, %%10010000, %%10001011, %%00010001
                        word %%00100010, %%00101000, %%10010001, %%01000101, %%00010111, %%11001000, %%10101111, %%10100010, %%01000101, %%00001000, %%10100010, %%01100011, %%11101000, %%10010000, %%11111010, %%00010001
                        word %%00100010, %%00101000, %%10010001, %%01000101, %%00010100, %%00001000, %%10101000, %%00100010, %%01000101, %%00001000, %%10011100, %%00010010, %%00001000, %%10010000, %%10000010, %%00001110
                        word %%00100010, %%00101000, %%10010001, %%01000100, %%10100100, %%01001000, %%10101000, %%10100010, %%01000101, %%00001000, %%10000100, %%10001010, %%00101000, %%10010010, %%10001010, %%00000010
                        word %%00100001, %%11000111, %%00010001, %%00111100, %%01000011, %%10000111, %%10100111, %%00011110, %%00111001, %%00000111, %%10011000, %%01110001, %%11001000, %%10001100, %%01110010, %%00001100

palette                 byte    $07,   $02    '    white / black


vecdef                  word    $4000+$1FFF*0/360         
                        word    5
                        word    $8000+$1FFF*90/360 
                        word    3
                        word    $8000+$1FFF*180/360 
                        word    5
                        word    $8000+$1FFF*270/360 
                        word    3
                        word    $8000+$1FFF*360/360 
                        word    5
                        word    0

vecdef2                 word    $4000+$1FFF*0/360         
                        word    5
                        word    $8000+$1FFF*90/360 
                        word    5
                        word    $8000+$1FFF*180/360 
                        word    5
                        word    $8000+$1FFF*270/360 
                        word    5
                        word    $8000+$1FFF*360/360 
                        word    5
                        word    0
                        
vecdef3                 word    $4000+$1FFF*90/360         
                        word    3
                        word    $8000+$1FFF*210/360 
                        word    3
                        word    $8000+$1FFF*330/360 
                        word    3
                        word    $8000+$1FFF*90/360 
                        word    3
                        word    0    
                        
vecdef4                 word    $4000+$1FFF*0/360         
                        word    3
                        word    $8000+$1FFF*90/360 
                        word    15
                        word    $8000+$1FFF*180/360 
                        word    3
                        word    $8000+$1FFF*270/360 
                        word    15
                        word    $8000+$1FFF*0/360 
                        word    3
                        word    0   
                        
vecdef5                 word    $4000+$1FFF*0/360         
                        word    1
                        word    $8000+$1FFF*180/360 
                        word    1
                        word    0   
                        
                        
vecdef6                 word    $4000+$1FFF*0/360         
                        word    5
                        word    $8000+$1FFF*180/360 
                        word    3
                        word    0 
    
vecdef7                 word    $4000+$1FFF*180/360         
                        word    65
                        word    $8000+$1FFF*150/360 
                        word    35
                        word    $8000+$1FFF*30/360 
                        word    36
                        word    $8000+$1FFF*0/360 
                        word    65
                        word    $4000+$1FFF*150/360 
                        word    35
                        word    $8000+$1FFF*135/360 
                        word    43
                        word    $4000+$1FFF*30/360 
                        word    36
                        word    $8000+$1FFF*45/360 
                        word    44
                        word    $4000+$1FFF*62/360 
                        word    20
                        word    $8000+$1FFF*73/360 
                        word    29
                        word    $4000+$1FFF*118/360 
                        word    20
                        word    $8000+$1FFF*108/360 
                        word    29
                        word    $4000+$1FFF*10/360 
                        word    50
                        word    $8000+$1FFF*21/360 
                        word    53
                        word    $4000+$1FFF*170/360 
                        word    50
                        word    $8000+$1FFF*159/360 
                        word    52
                        word    0 
                        
vecdef8                 word    $4000+$1FFF*180/360         
                        word    65
                        word    $8000+$1FFF*150/360 
                        word    35
                        word    $8000+$1FFF*30/360 
                        word    36
                        word    $8000+$1FFF*0/360 
                        word    65
                        word    $4000+$1FFF*150/360 
                        word    35
                        word    $8000+$1FFF*135/360 
                        word    43
                        word    $4000+$1FFF*30/360 
                        word    36
                        word    $8000+$1FFF*45/360 
                        word    44
                        word    $4000+$1FFF*90/360 
                        word    18
                        word    $8000+$1FFF*90/360 
                        word    28
                        word    $4000+$1FFF*48/360 
                        word    25
                        word    $8000+$1FFF*59/360 
                        word    33
                        word    $4000+$1FFF*132/360 
                        word    25
                        word    $8000+$1FFF*121/360 
                        word    33
                        word    $4000+$1FFF*161/360 
                        word    42
                        word    $8000+$1FFF*151/360 
                        word    46
                        word    $4000+$1FFF*19/360 
                        word    42
                        word    $8000+$1FFF*29/360 
                        word    46
                        word    $4000+$1FFF*174/360 
                        word    54
                        word    $8000+$1FFF*165/360 
                        word    56
                        word    $4000+$1FFF*6/360 
                        word    54
                        word    $8000+$1FFF*17/360 
                        word    56
                        word    0 
                        
fire1                   word
                        byte 3,32,12,0
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%20000000, %%00000000
                        word %%00000000, %%20000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000002, %%00020000, %%00000000
                        word %%00000002, %%00000000, %%00000000
                        word %%00000002, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00200000, %%00000000
                        word %%00000002, %%02200000, %%00000000
                        word %%00000002, %%02200000, %%00000000
                        word %%00000002, %%22220000, %%00000000
                        word %%00000002, %%23222200, %%00000000
                        word %%00000002, %%22223200, %%00000000
                        word %%00000000, %%22223220, %%00000000
                        word %%00000000, %%22222320, %%00000000
                        word %%00000000, %%22322320, %%00000000
                        word %%00000000, %%22322220, %%00000000
                        word %%00000000, %%22322220, %%00000000
                        word %%00000000, %%22222220, %%00000000
                        word %%00000002, %%22223220, %%00000000
                        word %%00000002, %%22222222, %%00000000
                        word %%00000022, %%22222322, %%20000000
                        word %%00000022, %%22322233, %%22000000
                        word %%00000223, %%32222233, %%22200000
                        word %%00000233, %%32222233, %%32200000
                        word %%00000233, %%22222232, %%32220000
                        word %%00000233, %%33322233, %%33220000
                        word %%00000233, %%33332333, %%33320000
                        word %%00000223, %%33333333, %%33320000
                        word %%00000222, %%33333333, %%32220000
                        word %%00000222, %%23333332, %%22200000
                        

                        
fire2                   word
                        byte 3,32,12,0
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00020000, %%00000000
                        word %%00000000, %%02000000, %%00000000
                        word %%00000000, %%02000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%02220000, %%00000000
                        word %%00000000, %%02322000, %%00000000
                        word %%00000000, %%02232000, %%00000000
                        word %%00000000, %%00220000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000002, %%00000000, %%00000000
                        word %%00000000, %%00220000, %%00000000
                        word %%00000000, %%00222000, %%00000000
                        word %%00000000, %%00232000, %%00000000
                        word %%00000000, %%00232200, %%00000000
                        word %%00000000, %%00023200, %%00000000
                        word %%00000200, %%00022200, %%00000000
                        word %%00000222, %%00222222, %%00000000
                        word %%00000222, %%22222222, %%20000000
                        word %%00000222, %%22322232, %%20002200
                        word %%00000222, %%22322222, %%22022200
                        word %%00000023, %%22332222, %%32222000
                        word %%00000022, %%22233322, %%33222000
                        word %%00000022, %%22233333, %%33222000
                        word %%00000022, %%32233333, %%33320000
                        word %%00000022, %%23233333, %%33320000
                        word %%00000022, %%23233333, %%33220000
                        word %%00000002, %%33333333, %%32220000
                        word %%00000000, %%22233333, %%22220000
                        
fire3                   word
                        byte 3,32,12,0
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%02000000, %%00000000
                        word %%00000000, %%02000000, %%00000000
                        word %%00000000, %%02000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000200, %%00020000, %%00000000
                        word %%00000000, %%00002000, %%00000000
                        word %%00000000, %%00002000, %%00000000
                        word %%00000000, %%00002000, %%00000000
                        word %%00000200, %%00000000, %%00000000
                        word %%00000220, %%00000000, %%00000000
                        word %%00000232, %%20200000, %%00000000
                        word %%00000223, %%20220000, %%00000000
                        word %%00000023, %%20222000, %%00000000
                        word %%00000023, %%20222220, %%00000000
                        word %%00000022, %%20222220, %%00000000
                        word %%00000002, %%00222222, %%00000000
                        word %%00000002, %%02223222, %%00000000
                        word %%00000000, %%02223222, %%20000000
                        word %%00000000, %%22233222, %%20000000
                        word %%00000200, %%22233222, %%22000000
                        word %%00002220, %%22233223, %%22000000
                        word %%00002222, %%23333323, %%22002000
                        word %%00002233, %%33333333, %%22022000
                        word %%00002333, %%33333333, %%22222000
                        word %%00002333, %%33333333, %%32220000
                        word %%00002333, %%33333333, %%32220000
                        word %%00002222, %%33333333, %%32200000
                        word %%00000222, %%33333223, %%33200000
                        word %%00000222, %%23322223, %%32000000
                        word %%00000022, %%22322222, %%20000000
                        
                        
fire4                   word
                        byte 3,32,12,0
                        word %%00000000, %%00200000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00200000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000200, %%00000000
                        word %%00000000, %%00000200, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%02200000, %%00000000
                        word %%00000000, %%02222000, %%00000000
                        word %%00000000, %%22222000, %%00000000
                        word %%00000000, %%23222000, %%00000000
                        word %%00000000, %%23232200, %%00000000
                        word %%00000000, %%22322220, %%00200000
                        word %%00000000, %%22323222, %%00200000
                        word %%00000000, %%22222222, %%00000000
                        word %%00000000, %%02222322, %%00000000
                        word %%00000000, %%22222322, %%00000000
                        word %%00000002, %%22222222, %%00000000
                        word %%00000002, %%22222322, %%00000000
                        word %%00000002, %%32223322, %%00020000
                        word %%00000022, %%32233322, %%20220000
                        word %%00000023, %%32233332, %%22220000
                        word %%00000023, %%32333332, %%22220000
                        word %%00000023, %%33333333, %%22220000
                        word %%00000023, %%33333333, %%32220000
                        word %%00000223, %%33333322, %%22320000
                        word %%00000223, %%33333222, %%32320000
                        word %%00000222, %%23333222, %%22220000
                        word %%00000222, %%22333322, %%22220000   
                        

fire5                   word
                        byte 3,32,12,0
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000020, %%00000000, %%00000000
                        word %%00000000, %%00200000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000002, %%00000000, %%00000000
                        word %%00000022, %%20000000, %%00000000
                        word %%00000022, %%20000000, %%00000000
                        word %%00000002, %%20000000, %%00000000
                        word %%00000002, %%22220000, %%00000000
                        word %%00000002, %%32222000, %%00000000
                        word %%00000002, %%23232000, %%00000000
                        word %%00000002, %%23222000, %%00000000
                        word %%00000002, %%22222000, %%00000000
                        word %%00000002, %%22222200, %%00000000
                        word %%00000000, %%22232200, %%00000000
                        word %%00000000, %%00233200, %%00000000
                        word %%00000000, %%00232200, %%00000000
                        word %%00000000, %%02222220, %%00000000
                        word %%00000002, %%02223220, %%00000000
                        word %%00000002, %%22233320, %%00200000
                        word %%00000002, %%22333320, %%00200000
                        word %%00000002, %%22233220, %%02200000
                        word %%00000022, %%22222220, %%02200000
                        word %%00000222, %%23322222, %%22200000
                        word %%00002233, %%33332322, %%32200000
                        word %%00002333, %%33322223, %%32200000
                        word %%00002333, %%33322333, %%32200000
                        word %%00002333, %%33323333, %%32200000
                        word %%00002233, %%33322333, %%22200000
                        word %%00000233, %%33333333, %%33200000  
                        
                        
fire6                   word
                        byte 3,32,12,0
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00200000, %%00000000
                        word %%00000000, %%00200000, %%00000000
                        word %%00000000, %%00200000, %%00000000
                        word %%00000000, %%20000000, %%00000000
                        word %%00000000, %%20000000, %%00000000
                        word %%00000000, %%20000000, %%00000000
                        word %%00000000, %%20000000, %%00000000
                        word %%00000000, %%22000000, %%00000000
                        word %%00000000, %%22000000, %%00000000
                        word %%00000000, %%23200000, %%00000000
                        word %%00000000, %%23220000, %%00000000
                        word %%00000002, %%23320000, %%00000000
                        word %%00000002, %%33322000, %%00000000
                        word %%00000002, %%33322000, %%00000000
                        word %%00000002, %%23322200, %%00000000
                        word %%00000002, %%22322200, %%00000000
                        word %%00000000, %%22222200, %%00000000
                        word %%00000000, %%22232220, %%00000000
                        word %%00000000, %%22222220, %%00000000
                        word %%00000002, %%22322222, %%00000000
                        word %%00000002, %%22332222, %%20000000
                        word %%00000022, %%22223222, %%22000000
                        word %%00000022, %%23322232, %%22000000
                        word %%00000222, %%22333223, %%22000000
                        word %%00002222, %%32333323, %%22000000
                        word %%00002222, %%32233333, %%22000000
                        word %%00002223, %%33233322, %%22000000
                        word %%00002223, %%33333323, %%22000000
                        word %%00000222, %%33333332, %%22000000
                        word %%00000022, %%23332222, %%20000000
                        
                        
fire7                   word
                        byte 3,32,12,0
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00200000, %%00000000
                        word %%00000002, %%00002000, %%00000000
                        word %%00000002, %%00002000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00200000, %%00000000
                        word %%00000000, %%02200000, %%00000000
                        word %%00000000, %%02200000, %%00000000
                        word %%00000000, %%22220000, %%00000000
                        word %%00000000, %%23322000, %%00000000
                        word %%00000000, %%23322200, %%00000000
                        word %%00000002, %%23322220, %%00000000
                        word %%00000002, %%22332222, %%00000000
                        word %%00000002, %%22333222, %%00000000
                        word %%00000002, %%22233222, %%00000000
                        word %%00000002, %%22222222, %%20000000
                        word %%00000002, %%22233222, %%20000000
                        word %%00020002, %%22233222, %%20000000
                        word %%00022002, %%23233232, %%20020000
                        word %%00022002, %%23232233, %%20020000
                        word %%00020022, %%33222233, %%22020000
                        word %%00000222, %%33322233, %%32000000
                        word %%00002223, %%23322333, %%32000000
                        word %%00002233, %%32222323, %%33200000
                        word %%00002333, %%33323333, %%33200000
                        word %%00002233, %%33333333, %%33200000
                        word %%00000223, %%33333333, %%32200000
                        word %%00000222, %%23333322, %%22000000   
                        

fire8                   word
                        byte 3,32,12,0
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%02002000, %%00000000
                        word %%00000020, %%02000000, %%00000000
                        word %%00000000, %%02200000, %%00000000
                        word %%00000000, %%02320000, %%00000000
                        word %%00000000, %%23320000, %%00000000
                        word %%00000000, %%02200000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%02000000, %%00000000
                        word %%00000000, %%22200000, %%00000000
                        word %%00000002, %%32200000, %%00000000
                        word %%00000002, %%33200000, %%00000000
                        word %%00000002, %%23320000, %%00000000
                        word %%00000022, %%23322200, %%00000000
                        word %%00000022, %%23332220, %%00000000
                        word %%00000223, %%23332222, %%00000000
                        word %%00200232, %%22232322, %%00000000
                        word %%00200222, %%22222232, %%00000000
                        word %%00222222, %%22232232, %%00020000
                        word %%00222223, %%32232222, %%00220000
                        word %%00222223, %%32232222, %%02220000
                        word %%00222223, %%33332222, %%22200000
                        word %%00222333, %%33332223, %%22200000
                        word %%00022233, %%33322233, %%22200000
                        word %%00002233, %%33322333, %%22000000
                        word %%00000223, %%33323333, %%22000000
                        word %%00000022, %%33333332, %%22000000
                        word %%00000022, %%33333222, %%20000000 
                        
stocking                word
                        byte 2, 20, 8, 10
                        word %%00003333, %%33333333
                        word %%00003333, %%33333333
                        word %%00003333, %%33333333
                        word %%00000022, %%22222200
                        word %%00000022, %%22222200
                        word %%00000022, %%22222200
                        word %%00000022, %%22222200
                        word %%00000022, %%22222200
                        word %%00000022, %%22222200
                        word %%00000022, %%22222200
                        word %%00000022, %%22222200
                        word %%00000022, %%22222200
                        word %%00000222, %%22222200
                        word %%00022222, %%22222200
                        word %%02222222, %%22222200
                        word %%22222222, %%22222200
                        word %%22222222, %%22222200
                        word %%22222222, %%22222000
                        word %%02222222, %%22220000
                        word %%00222222, %%22000000
                        

fireplace               word 
                        byte 4,23,16,10
                        word %%00000000, %%00133333, %%33333100, %%00000000
                        word %%00000000, %%00122223, %%22222100, %%00000000
                        word %%00000000, %%00133333, %%33333100, %%00000000
                        word %%00000000, %%00123222, %%23222100, %%00000000
                        word %%00111111, %%11111111, %%11111111, %%11111100
                        word %%00111111, %%11111111, %%11111111, %%11111100
                        word %%00111111, %%11111111, %%11111111, %%11111100
                        word %%00012223, %%22222322, %%22232222, %%23221000
                        word %%00013000, %%00333333, %%33333300, %%00031000
                        word %%00013033, %%30322222, %%32222203, %%33021000
                        word %%00013300, %%03333333, %%33333330, %%00331000
                        word %%00012202, %%02222322, %%22232220, %%20221000
                        word %%00013022, %%03311111, %%11111330, %%22031000
                        word %%00013000, %%22100000, %%00000132, %%00021000
                        word %%00013333, %%31000000, %%00000013, %%33331000
                        word %%00012223, %%21000000, %%00000012, %%23221000
                        word %%00013333, %%31000000, %%00000013, %%33331000
                        word %%00013222, %%21000000, %%00000012, %%22221000
                        word %%00013333, %%31000000, %%00000013, %%33331000
                        word %%00012223, %%21000000, %%00000012, %%23221000
                        word %%00013333, %%31000000, %%00000013, %%33331000
                        word %%00013222, %%21000000, %%00000012, %%22221000
                        word %%00011111, %%11111111, %%11111111, %%11111000
                        
santa                   word
                        byte 1,8,4,4
                        word %%02222220
                        word %%02222220
                        word %%01113110
                        word %%02222220
                        word %%02222220
                        word %%02200220
                        word %%01100110
                        word %%11100111
                                                
                        
gnome                   word
                        byte 3, 26, 12, 13
                        word %%00000000, %%00000222, %%00000000
                        word %%00000000, %%00002222, %%20000000
                        word %%00000000, %%00022220, %%20000000
                        word %%00000000, %%00022200, %%21100000
                        word %%00000000, %%00222200, %%11110000
                        word %%00000000, %%02222201, %%11110000
                        word %%00000000, %%22222220, %%11110000
                        word %%00000000, %%22222220, %%11100000
                        word %%00000000, %%22222222, %%00000000
                        word %%00000002, %%22222222, %%00000000
                        word %%00000002, %%22222222, %%20000000
                        word %%00000002, %%22200222, %%20000000
                        word %%00000022, %%20033002, %%22000000
                        word %%00000020, %%03333330, %%02000000
                        word %%00000001, %%03333330, %%10000000
                        word %%00000111, %%10033001, %%11100000
                        word %%00000111, %%11100111, %%11100000
                        word %%00001111, %%11111111, %%11110000
                        word %%00001111, %%11111111, %%11110000
                        word %%00011111, %%11111111, %%11111000
                        word %%00001111, %%11111111, %%11110000
                        word %%00011111, %%11111111, %%11111000
                        word %%00001111, %%11111111, %%11110000
                        word %%00011100, %%01111110, %%00111000
                        word %%00111022, %%20111102, %%22011100
                        word %%00010222, %%22011022, %%22201000
                        
leglampshade            word
                        byte 5, 42, 20, 21
                        word %%00000000, %%00111111, %%11111111, %%11111100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%00133331, %%33333333, %%13333100, %%00000000
                        word %%00000000, %%01133331, %%33333333, %%13333110, %%00000000
                        word %%00000000, %%01333331, %%33333333, %%13333310, %%00000000
                        word %%00000000, %%01333331, %%33333333, %%13333310, %%00000000
                        word %%00000000, %%01333331, %%33333333, %%13333310, %%00000000
                        word %%00000000, %%01333331, %%33333333, %%13333310, %%00000000
                        word %%00000000, %%01333331, %%33333333, %%13333310, %%00000000
                        word %%00000000, %%11333331, %%33333333, %%13333311, %%00000000
                        word %%00000000, %%13333331, %%33333333, %%13333331, %%00000000
                        word %%00000000, %%13333313, %%33333333, %%31333331, %%00000000
                        word %%00000000, %%13333313, %%33333333, %%31333331, %%00000000
                        word %%00000001, %%13333313, %%33333333, %%31333331, %%10000000
                        word %%00000001, %%33333313, %%33333333, %%31333333, %%10000000
                        word %%00000011, %%33333133, %%33333333, %%33133333, %%11000000
                        word %%00000113, %%33333133, %%33333333, %%33133333, %%31100000
                        word %%00001133, %%33331333, %%33333333, %%33313333, %%33110000
                        word %%00011333, %%33313333, %%33333333, %%33331333, %%33311000
                        word %%00113333, %%33133333, %%33333333, %%33333133, %%33331100
                        word %%11111111, %%11111111, %%11111111, %%11111111, %%11111111
                        word %%13333333, %%33133333, %%33333333, %%33333133, %%33333331
                        word %%13333333, %%33133333, %%33333333, %%33333133, %%33333331
                        word %%13333333, %%33133333, %%33333333, %%33333133, %%33333331
                        word %%13333333, %%33133333, %%33333333, %%33333133, %%33333331
                        word %%11111111, %%11111111, %%11111111, %%11111111, %%11111111
                        word %%10101010, %%10101010, %%10101010, %%10010101, %%01010101
                        word %%10101010, %%10101010, %%10101010, %%10010101, %%01010101
                        word %%10101010, %%10101010, %%10101010, %%10010101, %%01010101
                        word %%10101010, %%10101010, %%10101010, %%10010101, %%01010101
                        word %%10101010, %%10101010, %%10101010, %%10010101, %%01010101
                        word %%10101010, %%10101010, %%10101010, %%10010101, %%01010101
                        
leglampleg              word
                        byte 3, 65, 12, 15
                        word %%00000000, %%22222222, %%22222000
                        word %%00000000, %%22222222, %%22222000
                        word %%00000000, %%22222222, %%22222000
                        word %%00000000, %%22222222, %%22222000
                        word %%00000000, %%22222222, %%22222000
                        word %%00000000, %%22222222, %%22222000
                        word %%00000000, %%22222222, %%22222000
                        word %%00000000, %%22222222, %%22222000
                        word %%00000000, %%11111111, %%11111000
                        word %%00000000, %%11111000, %%11111000
                        word %%00000000, %%21212221, %%21222000
                        word %%00000000, %%22122222, %%12222000
                        word %%00000000, %%21212221, %%21222000
                        word %%00000000, %%12221212, %%22121000
                        word %%00000000, %%22222122, %%22212000
                        word %%00000000, %%12221212, %%22121000
                        word %%00000000, %%21212221, %%21222000
                        word %%00000000, %%22122222, %%12222000
                        word %%00000000, %%01212221, %%21222000
                        word %%00000000, %%02221212, %%22121000
                        word %%00000000, %%02222122, %%22212000
                        word %%00000000, %%02221212, %%22121000
                        word %%00000000, %%00212221, %%21222000
                        word %%00000000, %%00122222, %%12222000
                        word %%00000000, %%00012221, %%21222000
                        word %%00000000, %%00021212, %%22121000
                        word %%00000000, %%00022122, %%22212000
                        word %%00000000, %%00021212, %%22121000
                        word %%00000000, %%00012221, %%21222000
                        word %%00000000, %%00002222, %%12222200
                        word %%00000000, %%00000221, %%21222120
                        word %%00000000, %%00000212, %%22121220
                        word %%00000000, %%00000122, %%22212220
                        word %%00000000, %%00000212, %%22121220
                        word %%00000000, %%00000221, %%21222120
                        word %%00000000, %%00000222, %%12222210
                        word %%00000000, %%00000221, %%21222120
                        word %%00000000, %%00000212, %%22121220
                        word %%00000000, %%00000122, %%22212220
                        word %%00000000, %%00000212, %%22121200
                        word %%00000000, %%00000221, %%21222100
                        word %%00000000, %%00000222, %%12222200
                        word %%00000000, %%00000221, %%21222000
                        word %%00000000, %%00000212, %%22121000
                        word %%00000000, %%00000122, %%22212000
                        word %%00000000, %%00000212, %%22121000
                        word %%00000000, %%00000221, %%21222000
                        word %%00000000, %%00000222, %%12222000
                        word %%00000000, %%00000221, %%21222000
                        word %%00000000, %%00000212, %%22121100
                        word %%00000000, %%00000122, %%22212110
                        word %%00000000, %%00000212, %%22121111
                        word %%00000000, %%00000221, %%21222111
                        word %%00000000, %%00000222, %%12221111
                        word %%00000000, %%00000221, %%21211111
                        word %%00000000, %%00000212, %%22111111
                        word %%00000000, %%00002122, %%21111111
                        word %%00000000, %%00021212, %%11111111
                        word %%00000000, %%00212221, %%11111111
                        word %%00000000, %%22122211, %%11011110
                        word %%00000011, %%21212111, %%11001100
                        word %%00001112, %%12221111, %%10001100
                        word %%00111111, %%11111110, %%00001100
                        word %%01111111, %%11111100, %%00001100
                        word %%11111111, %%11110000, %%00001100
                        
logs                    word
                        byte 3, 8, 12, 4
                        word %%00000000, %%00000000, %%00000000
                        word %%00000000, %%00000000, %%00000000
                        word %%00111110, %%00000000, %%01111100
                        word %%01331111, %%11111111, %%11133310
                        word %%13333311, %%11111111, %%11333331
                        word %%13333311, %%11100111, %%11333331
                        word %%01333111, %%10000000, %%11133310
                        word %%00111100, %%00000000, %%00011100