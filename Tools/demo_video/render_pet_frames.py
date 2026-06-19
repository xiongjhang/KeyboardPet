#!/usr/bin/env python3
"""Render crisp, high-res pet animation frames for the demo video.

A faithful Python/PIL port of the app's pet renderer (tauri/src/main.js, itself a
1:1 port of the Swift ClawdSpriteContent + ClawdEffects + PixelFont). It draws the
real 64px sprite art (bundled in ./sprites) with NEAREST-NEIGHBOR scaling — exactly
like the app (imageSmoothingEnabled=false / .interpolation(.none)) — so the output
stays pixel-crisp instead of the lanczos-softened README GIFs.

Output: $KP_WORK/pet/<state>/f_%04d.png  (transparent RGBA, 1000x1000, 30 fps)
"""
import math, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSET = os.path.join(HERE, "sprites")
WORK = os.environ.get("KP_WORK", "/tmp/kp")
OUT = os.path.join(WORK, "pet")

K = 5                       # supersample: 200 logical -> 1000px
SIZE, SPRITE = 200, 150
CENTER = (100, 104)
HEAD_TOP = 58
FPS_OUT = 30
TAU = math.pi * 2
ROUND_FONT = "/System/Library/Fonts/SFNSRounded.ttf"  # SF Pro Rounded (matches the app)

FPS = {"typing":6,"deleting":9,"flow":7,"record":6,
       "idle":0.8,"thinking":1.2,"sleepy":0.9,"sleeping":0.6,"wakeup":1}

def frames_for(state):
    return [f"{state}_0.png"] if state == "wakeup" else [f"{state}_0.png", f"{state}_1.png"]

_imgcache = {}
def sprite(name):
    if name not in _imgcache:
        _imgcache[name] = Image.open(os.path.join(ASSET, name)).convert("RGBA")
    return _imgcache[name]

def frac(x): return x - math.floor(x)
def newlayer(): return Image.new("RGBA", (SIZE*K, SIZE*K), (0,0,0,0))

def ellipse(base, x, y, w, h, rgba):
    L = newlayer(); ImageDraw.Draw(L).ellipse([x*K, y*K, (x+w)*K, (y+h)*K], fill=rgba)
    base.alpha_composite(L)

def roundrect(base, x, y, w, h, r, rgba):
    L = newlayer(); ImageDraw.Draw(L).rounded_rectangle([x*K, y*K, (x+w)*K, (y+h)*K], radius=r*K, fill=rgba)
    base.alpha_composite(L)

_fontcache = {}
def rfont(px):
    key = int(px*K)
    if key not in _fontcache:
        _fontcache[key] = ImageFont.truetype(ROUND_FONT, max(1, key))
    return _fontcache[key]

def bubble(base, s, x, y, size, rgba):
    if s == "✦":  # four-point sparkle as a polygon (the round font may lack the glyph)
        cx, cy, R = x*K, y*K, size*K*0.62
        r = R*0.36; pts = []
        for i in range(8):
            ang = -math.pi/2 + i*math.pi/4
            rad = R if i % 2 == 0 else r
            pts.append((cx+math.cos(ang)*rad, cy+math.sin(ang)*rad))
        L = newlayer(); ImageDraw.Draw(L).polygon(pts, fill=rgba); base.alpha_composite(L)
        return
    L = newlayer()
    ImageDraw.Draw(L).text((x*K, y*K), s, font=rfont(size), fill=rgba, anchor="mm")
    base.alpha_composite(L)

# ---- WPM pixel font (PixelFont) ----
GLYPHS = {
 "0":["111","101","101","101","111"],"1":["010","110","010","010","111"],
 "2":["111","001","111","100","111"],"3":["111","001","111","001","111"],
 "4":["101","101","111","001","001"],"5":["111","100","111","001","111"],
 "6":["111","100","111","101","111"],"7":["111","001","010","010","010"],
 "8":["111","101","111","101","111"],"9":["111","101","111","001","111"],
 "W":["10001","10001","10101","11011","10001"],
 "P":["11110","10001","11110","10000","10000"],
 "M":["10001","11011","10101","10001","10001"]," ":["00","00","00","00","00"]}
FONT_HEIGHT = 5

def font_width(s, pixel, spacing=1):
    w = 0; cs = list(s)
    for i, ch in enumerate(cs):
        g = GLYPHS.get(ch)
        if not g: continue
        w += len(g[0])*pixel
        if i < len(cs)-1: w += spacing*pixel
    return w

def font_draw(base, s, x, y, pixel, rgba, spacing=1):
    L = newlayer(); d = ImageDraw.Draw(L); cx = x
    for ch in s:
        g = GLYPHS.get(ch)
        if not g: continue
        for r, row in enumerate(g):
            for c, bit in enumerate(row):
                if bit == "1":
                    d.rectangle([(cx+c*pixel)*K, (y+r*pixel)*K,
                                 (cx+c*pixel+pixel)*K, (y+r*pixel+pixel)*K], fill=rgba)
        cx += len(g[0])*pixel + spacing*pixel
    base.alpha_composite(L)

def font_centered(base, s, centerx, top, pixel, rgba, spacing=1):
    font_draw(base, s, centerx - font_width(s, pixel, spacing)/2, top, pixel, rgba, spacing)

# ---- motion (PetTheme) ----
def breathing(t): return 1.0 + 0.025*math.sin(t*1.6)
def paw_bob(t, ph): return math.sin(t*14+ph)
def excited_bob(t): return math.sin(t*9)
def glow(t): return 0.4 + 0.2*math.sin(t*4)
def wakeup_bounce(p): return abs(math.sin(p*8))*max(0, 1-p/2.0)*14

def bob_offset(state, t, age):
    if state == "typing": return paw_bob(t,0)*1.5
    if state == "flow": return excited_bob(t)*4
    if state == "record": return excited_bob(t)*3
    if state == "wakeup": return -wakeup_bounce(age)
    return 0.0

# ---- effects (ClawdEffects) ----
def draw_shadow(b): ellipse(b, SIZE/2-46, SIZE*0.82, 92, 16, (0,0,0,int(0.18*255)))
def draw_glow(b, t):
    r = 84; ellipse(b, CENTER[0]-r, CENTER[1]-r, r*2, r*2, (255,165,0, int(glow(t)*0.45*255)))

def draw_fireworks(b, t):
    bursts = [(SIZE*0.28,SIZE*0.22,(255,45,85)),(SIZE*0.72,SIZE*0.18,(255,255,0)),(SIZE*0.5,SIZE*0.32,(0,255,255))]
    L = newlayer(); d = ImageDraw.Draw(L)
    for i,(bx,by,col) in enumerate(bursts):
        phase = frac(t*0.9 + i*0.4); radius = phase*32; alpha = int(max(0,1-phase)*255); a = 0.0
        while a < TAU:
            px = bx+math.cos(a)*radius; py = by+math.sin(a)*radius
            d.ellipse([(px-2.5)*K,(py-2.5)*K,(px+2.5)*K,(py+2.5)*K], fill=col+(alpha,)); a += math.pi/5
    b.alpha_composite(L)

OUTLINE = (0,0,0,int(0.82*255))

def draw_front(b, state, t):
    if state == "deleting":
        for i, dx in enumerate((-34,34)):
            phase = frac(t*2 + i*0.5)
            ellipse(b, CENTER[0]+dx, HEAD_TOP + phase*30, 8, 11, (102,179,255,int((1-phase)*255)))
    elif state == "thinking":
        bubble(b, "?", CENTER[0]+56, HEAD_TOP-4, 30, OUTLINE)
    elif state == "sleeping":
        bx, by = CENTER[0]+44, HEAD_TOP
        for i in range(3):
            phase = frac(t*0.6 + i*0.33)
            bubble(b, "z", bx+phase*26, by-phase*42, 14+i*5, (0,0,0,int(0.82*(1-phase)*255)))
    elif state == "wakeup":
        bubble(b, "!", CENTER[0]+48, HEAD_TOP-10, 34, (255,0,0,255))
    elif state == "flow":
        for i,(dx,dy) in enumerate(((-62,-34),(60,-26),(-52,32),(56,38))):
            tw = abs(math.sin(t*3+i))
            bubble(b, "✦", CENTER[0]+dx, CENTER[1]+dy, 12+tw*8, (255,255,0,int((0.6+tw*0.4)*255)))

def shows_wpm(state): return state in ("typing","flow","deleting","record")
def wpm_color(w):
    if w < 40: return (140,217,179)
    if w < 80: return (255,209,77)
    return (255,115,77)

def draw_wpm(b, wpm, t):
    s = str(wpm); numpx=4; unitpx=2; numtop=12
    numW = font_width(s, numpx); unitW = font_width("WPM", unitpx)
    unittop = numtop + FONT_HEIGHT*numpx + 5
    r,g,bl = wpm_color(wpm); contentW = max(numW, unitW)
    px = CENTER[0]-contentW/2-8; py = numtop-6
    pw = contentW+16; ph = unittop + FONT_HEIGHT*unitpx + 6 - (numtop-6)
    roundrect(b, px, py, pw, ph, 5, (0,0,0,int(0.32*255)))
    font_centered(b, s, CENTER[0]+1, numtop+1, numpx, (0,0,0,int(0.5*255)))
    font_centered(b, s, CENTER[0], numtop, numpx, (r,g,bl,255))
    font_centered(b, "WPM", CENTER[0], unittop, unitpx, (r,g,bl,int(0.85*255)))

def draw_sprite(b, state, t):
    fr = frames_for(state); fps = FPS.get(state,1)
    idx = int(math.floor(t*fps)) % len(fr)
    img = sprite(fr[idx])
    bob = bob_offset(state, t, max(0, t))           # stateChangedAt = 0
    scale = breathing(t) if state == "idle" else 1.0
    size = SPRITE*scale
    scaled = img.resize((max(1,int(round(size*K))),)*2, Image.NEAREST)
    x0 = int(round((CENTER[0] - size/2)*K)); y0 = int(round((100 + bob - size/2)*K))
    b.alpha_composite(scaled, (x0, y0))

def render(state, wpm, dur):
    d = os.path.join(OUT, state); os.makedirs(d, exist_ok=True)
    for f in range(int(round(dur*FPS_OUT))):
        t = f / FPS_OUT
        b = Image.new("RGBA", (SIZE*K, SIZE*K), (0,0,0,0))
        draw_shadow(b)
        if state == "flow": draw_glow(b, t)
        if state == "record": draw_fireworks(b, t)
        draw_sprite(b, state, t)
        draw_front(b, state, t)
        if shows_wpm(state): draw_wpm(b, wpm, t)
        b.save(os.path.join(d, f"f_{f:04d}.png"))
    print(f"  {state}: {int(round(dur*FPS_OUT))} frames")

# state -> (wpm, seconds). wpm chosen to land in each color band; idle covers the
# longest scene (outro 3.4s) and is reused for the intro.
JOBS = [("idle",0,3.4),("typing",58,2.6),("flow",104,2.6),("deleting",35,2.6),
        ("thinking",0,2.6),("sleepy",0,2.6),("sleeping",0,2.6),("wakeup",0,2.6),("record",120,2.6)]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for st, wpm, dur in JOBS:
        render(st, wpm, dur)
    print("pet frames done ->", OUT)
