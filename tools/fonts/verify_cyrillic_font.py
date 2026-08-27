#!/usr/bin/env python3
"""Prove a Cyrillic-extended maptext font is a strict superset of the original.

The whole point of add_cyrillic_glyphs.py is that English runechat must not
move by a single pixel. This asserts that: every codepoint the original font
had still renders to the identical bitmap with the identical advance width and
bounding box, the vertical metrics that drive line spacing are untouched, the
family name still matches what interface/skin.dmf asks for, and the Russian
alphabet actually draws something.

Usage:
    python tools/fonts/verify_cyrillic_font.py ORIGINAL.ttf EXTENDED.ttf
"""

import sys

from fontTools.ttLib import TTFont
from PIL import ImageFont

RUSSIAN = (
    "\u0410\u0411\u0412\u0413\u0414\u0415\u0401\u0416\u0417\u0418\u0419\u041a"
    "\u041b\u041c\u041d\u041e\u041f\u0420\u0421\u0422\u0423\u0424\u0425\u0426"
    "\u0427\u0428\u0429\u042a\u042b\u042c\u042d\u042e\u042f"
    "\u0430\u0431\u0432\u0433\u0434\u0435\u0451\u0436\u0437\u0438\u0439\u043a"
    "\u043b\u043c\u043d\u043e\u043f\u0440\u0441\u0442\u0443\u0444\u0445\u0446"
    "\u0447\u0448\u0449\u044a\u044b\u044c\u044d\u044e\u044f"
)
# Runechat is 6pt; BYOND rasterises that at 8px. The larger sizes catch
# rounding that only shows up when maptext is scaled.
SIZES = (8, 16, 32)


def check(original_path, extended_path):
    failures = []
    orig_tt, ext_tt = TTFont(original_path), TTFont(extended_path)

    orig_cmap, ext_cmap = set(orig_tt.getBestCmap()), set(ext_tt.getBestCmap())
    lost = sorted(orig_cmap - ext_cmap)
    if lost:
        failures.append(f"dropped codepoints: {[hex(c) for c in lost]}")
    print(f"codepoints: {len(orig_cmap)} -> {len(ext_cmap)} (+{len(ext_cmap - orig_cmap)})")

    def family(font):
        return next(str(r) for r in font["name"].names if r.nameID == 1 and r.platformID == 3)

    if family(orig_tt) != family(ext_tt):
        failures.append(f"family name changed: {family(orig_tt)!r} -> {family(ext_tt)!r}")
    print(f"family name: {family(ext_tt)!r}")

    # These drive line height and baseline placement in maptext.
    for table, fields in (
        ("head", ["unitsPerEm"]),
        ("hhea", ["ascent", "descent", "lineGap"]),
        ("OS/2", ["sTypoAscender", "sTypoDescender", "sTypoLineGap", "usWinAscent", "usWinDescent"]),
    ):
        for field in fields:
            a, b = getattr(orig_tt[table], field), getattr(ext_tt[table], field)
            if a != b:
                failures.append(f"{table}.{field} changed: {a} -> {b}")

    for size in SIZES:
        orig, ext = (ImageFont.truetype(p, size) for p in (original_path, extended_path))
        if orig.getmetrics() != ext.getmetrics():
            failures.append(f"{size}px line metrics changed: {orig.getmetrics()} -> {ext.getmetrics()}")
        changed = []
        for codepoint in sorted(orig_cmap):
            char = chr(codepoint)
            a, b = orig.getmask(char, mode="L"), ext.getmask(char, mode="L")
            if (
                a.size != b.size
                or bytes(a) != bytes(b)
                or orig.getlength(char) != ext.getlength(char)
                or orig.getbbox(char) != ext.getbbox(char)
            ):
                changed.append(hex(codepoint))
        if changed:
            failures.append(f"{size}px: {len(changed)} pre-existing glyphs changed: {changed[:10]}")
        blank = [c for c in RUSSIAN if ext.getmask(c, mode="L").size[0] == 0]
        if blank:
            failures.append(f"{size}px: {len(blank)} Russian letters render blank")
        print(f"{size}px: {len(orig_cmap)} existing glyphs unchanged, {len(RUSSIAN)} Russian letters drawn")

    if failures:
        print("\nFAILED:")
        for f in failures:
            print("  -", f)
        return 1
    print("\nOK: extended font is a strict superset of the original")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    sys.exit(check(sys.argv[1], sys.argv[2]))
