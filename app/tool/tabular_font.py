# Usage: python3 tool/tabular_font.py assets/fonts/ChakraPetch-Bold.ttf assets/fonts/PetchTabular-Bold.ttf (needs fonttools)
# Derive a tabular-figure cut of Chakra Petch: digits share one advance, centred.
import sys
from fontTools.ttLib import TTFont
src, dst = sys.argv[1], sys.argv[2]
f = TTFont(src)
cmap = f.getBestCmap(); hm = f['hmtx']; glyf = f['glyf']
digits = [cmap[ord(c)] for c in '0123456789']
adv = max(hm[g][0] for g in digits)
for g in digits:
    w, lsb = hm[g]
    dx = (adv - w) // 2
    gl = glyf[g]
    if gl.isComposite():
        for c in gl.components: c.x += dx
    elif gl.numberOfContours > 0:
        gl.coordinates.translate((dx, 0))
    gl.recalcBounds(glyf)
    hm[g] = (adv, lsb + dx)
name = f['name']
for rec in name.names:
    if rec.nameID in (1, 3, 4, 6, 16):
        s = rec.toUnicode()
        s = s.replace('Chakra Petch', 'Petch Tabular').replace('ChakraPetch', 'PetchTabular')
        rec.string = s
f.save(dst)
print(dst, adv)
