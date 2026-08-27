#!/usr/bin/env python3
"""Add Cyrillic glyphs to one of the bundled maptext fonts, changing nothing else.

BYOND renders runechat, balloon alerts and signboards as maptext, server side,
using the font named by the `.maptext` style in interface/skin.dmf. None of the
fonts tg ships carry a single Cyrillic glyph, so Russian speech comes out as
tofu boxes. Swapping the whole font for a Cyrillic one would re-flow every
English bubble, so instead this copies just the missing letters into a copy of
the existing font and leaves everything already there byte for byte identical:
same outlines, same advance widths, same vertical metrics, same family name.
Because the family name is unchanged, no CSS or span style has to change - only
the `font_family` path in interface/fonts/*.dm and the asset_cache entry.

Donor glyphs come from ss220-space/tgstation's Grand9K_Pixel_modif.ttf, a
Cyrillic extension of the same Jayvee Enaguas font we already ship (CC BY 4.0).

Usage:
    python tools/fonts/add_cyrillic_glyphs.py BASE.ttf DONOR.ttf OUT.ttf

Verify a rebuild with tools/fonts/verify_cyrillic_font.py.
"""

import sys

from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

# The Russian alphabet. Yo/yo sit outside the otherwise contiguous A-ya run.
WANTED = [0x0401, 0x0451] + list(range(0x0410, 0x0450))


def add_cyrillic(base_path, donor_path, out_path):
    base, donor = TTFont(base_path), TTFont(donor_path)
    donor_glyphs, donor_cmap = donor.getGlyphSet(), donor.getBestCmap()
    base_cmap = base.getBestCmap()

    glyf, hmtx = base["glyf"], base["hmtx"]
    order = list(base.getGlyphOrder())
    added = {}

    for codepoint in sorted(WANTED):
        if codepoint in base_cmap:
            continue
        donor_name = donor_cmap.get(codepoint)
        if donor_name is None:
            print(f"  donor is missing U+{codepoint:04X}, skipping")
            continue
        name = "uni%04X" % codepoint
        if name in order:
            raise SystemExit(f"glyph name collision: {name}")
        # Decompose: donor composites reference donor glyph ids, which mean
        # nothing in the base font's glyph order.
        pen = DecomposingRecordingPen(donor_glyphs)
        donor_glyphs[donor_name].draw(pen)
        ttpen = TTGlyphPen(None)
        pen.replay(ttpen)
        glyf[name] = ttpen.glyph()
        hmtx[name] = donor["hmtx"][donor_name]
        order.append(name)
        added[codepoint] = name

    base.setGlyphOrder(order)
    glyf.glyphOrder = order
    base["maxp"].numGlyphs = len(order)
    for subtable in base["cmap"].tables:
        if subtable.isUnicode():
            subtable.cmap.update(added)
    base.save(out_path)
    print(f"added {len(added)} glyphs -> {out_path} ({len(order)} glyphs total)")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    add_cyrillic(*sys.argv[1:4])
