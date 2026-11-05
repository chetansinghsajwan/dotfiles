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
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

# JetBrains Mono's cell: 1000 units to the em, 600 wide, from -300 to 1020 (the bar spans the cell height).
UPM, WIDTH, TOP, BOTTOM = 1000, 600, 1020, -300
HEIGHT = TOP - BOTTOM
RY = HEIGHT * 0.25  # corner radius down the edge: a quarter of the cell
RX = WIDTH * 0.5  # across: half the cell, so the curve is an arc of an ellipse, not a pill
STROKE = 70  # width of the outline glyphs
OVERLAP = 6  # the joining edge goes this far outside the cell so there is no seam
K = 0.5523  # cubic approximation of a quarter circle


def right_end(pen, inset=0.0, flat_from=0.0):
    """Outline of a right end: flat on the left, rounded top and bottom corners on the right."""
    x0, x1 = -OVERLAP, WIDTH - inset
    top, bottom = TOP - inset, BOTTOM + inset
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
    pen.moveTo((-OVERLAP, TOP))
    pen.lineTo((x1 - RX, TOP))
    pen.curveTo((x1 - RX + RX * K, TOP), (x1, TOP - RY + RY * K), (x1, TOP - RY))
    pen.lineTo((x1, BOTTOM + RY))
    pen.curveTo((x1, BOTTOM + RY - RY * K), (x1 - RX + RX * K, BOTTOM), (x1 - RX, BOTTOM))
    pen.lineTo((-OVERLAP, BOTTOM))
    pen.lineTo((-OVERLAP, BOTTOM + t))
    pen.lineTo((x1 - RX, BOTTOM + t))
    pen.curveTo((x1 - RX + RX * K, BOTTOM + t), (x1 - t, BOTTOM + RY - RY * K + t), (x1 - t, BOTTOM + RY))
    pen.lineTo((x1 - t, TOP - RY))
    pen.curveTo((x1 - t, TOP - RY + RY * K - t), (x1 - RX + RX * K, TOP - t), (x1 - RX, TOP - t))
    pen.lineTo((-OVERLAP, TOP - t))
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
    fb.setupNameTable({"familyName": "Rounded Powerline", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=TOP, sTypoDescender=BOTTOM, usWinAscent=TOP, usWinDescent=-BOTTOM, fsType=0)
    fb.setupPost(isFixedPitch=1)
    fb.save(out)


if __name__ == "__main__":
    main(sys.argv[1])
