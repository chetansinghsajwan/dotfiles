"""Build `Rounded Powerline`: four glyphs for the ends of a bar segment, with slightly rounded corners
(a straight edge on the joining side, a flat middle, corners of about a quarter of the cell height) on codepoints
that no Nerd Font uses, so nothing the main font draws is overridden.

    python3 rounded_powerline.py OUT.ttf

U+E0F0 right end, filled     U+E0F1 right end, outline
U+E0F2 left end, filled      U+E0F3 left end, outline
"""

import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.ttLib.tables.O_S_2f_2 import Panose
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

# JetBrains Mono's cell: 1000 units to the em, 600 wide, from -300 to 1020 (the bar spans the cell height).
UPM, WIDTH, TOP, BOTTOM = 1000, 600, 1020, -300
HEIGHT = TOP - BOTTOM
# The bar reaches a little beyond the cell above and below, so rounding to whole pixels (any font size) never leaves a gap.
OVERSHOOT = 40
GT, GB = TOP + OVERSHOOT, BOTTOM - OVERSHOOT
RY = HEIGHT * 0.36  # corner radius down the edge: about a third of the cell
RX = WIDTH * 0.8  # across: most of the cell, so the corner is an arc of an ellipse, with a short flat middle
STROKE = 70  # width of the outline glyphs
OVERLAP = 30  # the joining edge goes this far outside the cell so there is no seam
K = 0.5523  # cubic approximation of a quarter circle


def right_end(pen, inset=0.0, flat_from=0.0):
    """Outline of a right end: flat on the left, rounded top and bottom corners on the right."""
    x0, x1 = -OVERLAP, WIDTH - inset
    top, bottom = GT - inset, GB + inset
    pen.moveTo((x0, bottom))
    pen.lineTo((x0, top))
    pen.lineTo((x1 - RX, top))
    pen.curveTo((x1 - RX + RX * K, top), (x1, top - RY + RY * K), (x1, top - RY))
    pen.lineTo((x1, bottom + RY))
    pen.curveTo((x1, bottom + RY - RY * K), (x1 - RX + RX * K, bottom), (x1 - RX, bottom))
    pen.closePath()


def right_outline(pen):
    """Only the curved edge, STROKE thick: the outer outline, then the inner one back."""
    x1 = WIDTH
    t = STROKE
    pen.moveTo((-OVERLAP, GT))
    pen.lineTo((x1 - RX, GT))
    pen.curveTo((x1 - RX + RX * K, GT), (x1, GT - RY + RY * K), (x1, GT - RY))
    pen.lineTo((x1, GB + RY))
    pen.curveTo((x1, GB + RY - RY * K), (x1 - RX + RX * K, GB), (x1 - RX, GB))
    pen.lineTo((-OVERLAP, GB))
    pen.lineTo((-OVERLAP, GB + t))
    pen.lineTo((x1 - RX, GB + t))
    pen.curveTo((x1 - RX + RX * K, GB + t), (x1 - t, GB + RY - RY * K + t), (x1 - t, GB + RY))
    pen.lineTo((x1 - t, GT - RY))
    pen.curveTo((x1 - t, GT - RY + RY * K - t), (x1 - RX + RX * K, GT - t), (x1 - RX, GT - t))
    pen.lineTo((-OVERLAP, GT - t))
    pen.closePath()


def mirrored(draw):
    """The glyph drawn by `draw`, flipped left to right inside the cell."""

    def go(pen):
        # Mirroring reverses the winding; the transform pen flips the points and the contour is drawn the same way,
        # so reverse by drawing through a pen that flips x and then reverse direction with a reverse-contour pen.
        from fontTools.pens.reverseContourPen import ReverseContourPen

        draw(ReverseContourPen(TransformPen(pen, (-1, 0, 0, 1, WIDTH, 0))))

    return go


def glyph(draw):
    pen = TTGlyphPen(None)
    draw(Cu2QuPen(pen, 1.0, reverse_direction=False))
    return pen.glyph()


def main(out):
    glyphs = {
        ".notdef": TTGlyphPen(None).glyph(),
        "rp_right": glyph(lambda p: right_end(p)),
        "rp_right_outline": glyph(right_outline),
        "rp_left": glyph(mirrored(lambda p: right_end(p))),
        "rp_left_outline": glyph(mirrored(right_outline)),
    }
    order = list(glyphs)
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({0xE0F0: "rp_right", 0xE0F1: "rp_right_outline", 0xE0F2: "rp_left", 0xE0F3: "rp_left_outline"})
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({n: (WIDTH, 0) for n in order})
    fb.setupHorizontalHeader(ascent=TOP, descent=BOTTOM)
    # A date that does not change, so the font is the same file every build.
    stamp = 3_913_113_600  # 2028-01-01 in seconds since 1904, well after the first release
    fb.setupHead(unitsPerEm=UPM, created=stamp, modified=stamp, fontRevision=1.0, flags=0b11, lowestRecPPEM=8)
    fb.setupNameTable(
        {
            "copyright": "Public domain",
            "familyName": "Rounded Powerline",
            "styleName": "Regular",
            "uniqueFontIdentifier": "RoundedPowerline-Regular;1.000",
            "fullName": "Rounded Powerline",
            "version": "Version 1.000",
            "psName": "RoundedPowerline-Regular",
        }
    )
    fb.setupOS2(
        version=4,
        usWeightClass=400,
        usWidthClass=5,
        fsType=0,
        fsSelection=0x40,
        achVendID="NONE",
        sTypoAscender=TOP,
        sTypoDescender=BOTTOM,
        sTypoLineGap=0,
        usWinAscent=TOP,
        usWinDescent=-BOTTOM,
        sxHeight=500,
        sCapHeight=700,
        panose=Panose(bFamilyType=2, bProportion=9),
    )
    fb.setupPost(isFixedPitch=1, underlinePosition=-100, underlineThickness=50)
    fb.save(out)


if __name__ == "__main__":
    main(sys.argv[1])
