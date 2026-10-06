#!/usr/bin/env python3
"""Draws the app icon: an angular elephant in Gruvbox dark colors.

Shapes are straight-edged polygons on a 1024 pt grid, drawn at 4x and
downsampled for clean edges. Run from the repository root:

    python3 scripts/design/app_icon.py
"""
from PIL import Image, ImageDraw
S=4
BG=(0x1D,0x20,0x21); ORANGE=(0xFE,0x80,0x19); DARK=(0xD6,0x5D,0x0E); CREAM=(0xEB,0xDB,0xB2)
DY=-25
def P(pts): return [(x*S,(y+DY)*S) for x,y in pts]
im=Image.new('RGB',(1024*S,1024*S),BG); d=ImageDraw.Draw(im)
# body
d.polygon(P([(430,300),(740,300),(840,360),(860,560),(830,610),(830,730),(735,730),(735,630),(600,630),(600,730),(505,730),(505,610),(440,570)]),fill=ORANGE)
# head
d.polygon(P([(210,360),(330,300),(470,300),(520,540),(440,580),(330,560),(250,480)]),fill=ORANGE)
# trunk
d.polygon(P([(250,470),(345,520),(330,700),(385,730),(375,775),(285,775),(250,700)]),fill=ORANGE)
# ear (darker) with bg seam
seam=[(392,318),(596,318),(642,472),(520,562),(428,502)]
d.polygon(P(seam),fill=BG)
d.polygon(P([(408,332),(582,332),(622,465),(520,542),(444,490)]),fill=DARK)
# tusk
d.polygon(P([(335,560),(268,610),(352,590)]),fill=CREAM)
# eye
d.polygon(P([(300,395),(330,395),(330,425),(300,425)]),fill=BG)
# tail
d.polygon(P([(838,380),(856,372),(912,512),(894,520)]),fill=ORANGE)
im=im.resize((1024,1024),Image.LANCZOS)
im.save('Yaht/Assets.xcassets/AppIcon.appiconset/AppIcon.png')
