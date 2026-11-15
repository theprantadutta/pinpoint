"""Pinpoint Play Store promo video, LANDSCAPE 1920x1080, light "Sketchbook" look.

Adapted from the Snake Classic renderer: captions on the left, the phone recording
on the right, intro and outro cards. Usage:
    python pp_render.py <ffmpeg.exe> <scenes.json> <out.mp4>
"""

import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

D = Path(__file__).parent
APP = Path(r"G:\Personal\MyProjects\pinpoint\pinpoint")
FONTS = APP / "assets" / "fonts" / "google_fonts"
FF, SCENES, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
W, H = 1920, 1080

PAPER = (245, 243, 236)
SURFACE = (255, 253, 248)
INK = (20, 20, 20)
MUTED = (106, 104, 97)
DOODLE = (216, 212, 248)
YELLOW = (246, 226, 122)
PASTELS = {"yellow": YELLOW, "lavender": (185, 182, 242), "mint": (201, 237, 180),
           "sky": (169, 211, 245), "pink": (247, 184, 200)}

INTRO, OUTRO, FADE = 3.2, 4.8, 0.3

PH = 940
PW = round(PH * 1080 / 2340 / 2) * 2
PX, PY = 1260, (H - PH) // 2
RADIUS = 46
CAP_X, CAP_W = 150, 930


def font(weight, size):
    return ImageFont.truetype(str(FONTS / f"PlusJakartaSans-{weight}.ttf"), size)


def caveat(size):
    return ImageFont.truetype(str(FONTS / "Caveat-SemiBold.ttf"), size)


def wrap(draw, text, f, width):
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if draw.textlength(trial, font=f) <= width:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    return lines + [cur]


def swoosh(d, y0, amp, phase, width, color, x0=-100, x1=W + 100):
    pts = [(x, y0 + amp * math.sin((x / W) * 2 * math.pi * 0.9 + phase))
           for x in range(x0, x1, 8)]
    d.line(pts, fill=color, width=width, joint="curve")


def squiggle(d, x, y, color, n=2, w=9):
    pts = [(x + i * 3, y + 14 * math.sin(i * 3 / 42 * 2 * math.pi)) for i in range(0, 28 * n)]
    d.line(pts, fill=color, width=w, joint="curve")


def band(d, path, width, color, s):
    """A thick stroke as one filled polygon: Pillow's wide polylines leave
    ragged ticks at every joint."""
    up, down = [], []
    for i, (x, y) in enumerate(path):
        x0, y0 = path[max(i - 1, 0)]
        x1, y1 = path[min(i + 1, len(path) - 1)]
        dx, dy = x1 - x0, y1 - y0
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n * width / 2, dx / n * width / 2
        up.append(((x + nx) * s, (y + ny) * s))
        down.append(((x - nx) * s, (y - ny) * s))
    d.polygon(up + down[::-1], fill=color)
    r = width / 2 * s
    for (x, y) in (path[0], path[-1]):
        d.ellipse((x * s - r, y * s - r, x * s + r, y * s + r), fill=color)


def background():
    s = 2  # supersampled, then scaled down for smooth edges
    img = Image.new("RGB", (W * s, H * s), PAPER)
    d = ImageDraw.Draw(img)
    wave = lambda y0, amp, ph: [(x, y0 + amp * math.sin((x / W) * 2 * math.pi * 0.9 + ph))
                                for x in range(-120, W + 120, 6)]
    band(d, wave(170, 70, 0.4), 44, DOODLE, s)
    band(d, wave(930, 60, 2.6), 44, DOODLE, s)
    band(d, [(1610 + i * 1.5, 120 + 14 * math.sin(i * 1.5 / 42 * 2 * math.pi)) for i in range(112)],
         9, YELLOW, s)
    return img.resize((W, H), Image.LANCZOS)


def phone_assets():
    bg = background()
    d = ImageDraw.Draw(bg)
    # Sticker shadow, then an ink outline around the screen.
    d.rounded_rectangle((PX - 8 + 16, PY - 8 + 16, PX + PW + 8 + 16, PY + PH + 8 + 16),
                        radius=RADIUS + 8, fill=INK)
    d.rounded_rectangle((PX - 8, PY - 8, PX + PW + 8, PY + PH + 8),
                        radius=RADIUS + 8, fill=INK)
    bg.save(D / "pstage.png")
    mask = Image.new("L", (PW, PH), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, PW - 1, PH - 1), radius=RADIUS, fill=255)
    mask.save(D / "pmask.png")


def chip(d, x, y, label, color):
    f = font("ExtraBold", 30)
    tw = d.textlength(label, font=f)
    h = 62
    d.rounded_rectangle((x + 5, y + 5, x + tw + 56 + 5, y + h + 5), radius=h // 2, fill=INK)
    d.rounded_rectangle((x, y, x + tw + 56, y + h), radius=h // 2, fill=color,
                        outline=INK, width=3)
    d.text((x + 28, y + h / 2 + 1), label, font=f, fill=INK, anchor="lm")
    return y + h


def marker(d, x, y, text, f, pad=10):
    """Yellow marker highlight behind text drawn at (x, y) with anchor 'la'."""
    l, t, r, b = d.textbbox((x, y), text, font=f, anchor="la")
    d.rounded_rectangle((l - pad, t + (b - t) * 0.18, r + pad, b + pad * 0.6), radius=8, fill=YELLOW)


def caption_png(i, label, color, title, sub):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ft, fs = font("ExtraBold", 88), font("Medium", 42)
    tlines = wrap(d, title, ft, CAP_W)
    slines = wrap(d, sub, fs, CAP_W - 60)[:3]
    block = 62 + 46 + len(tlines) * 104 + 34 + len(slines) * 58
    y = (H - block) // 2
    y = chip(d, CAP_X, y, label, PASTELS.get(color, YELLOW)) + 46
    for n, line in enumerate(tlines):
        if n == len(tlines) - 1:
            marker(d, CAP_X - 4, y, line, ft)
        d.text((CAP_X - 4, y), line, font=ft, fill=INK, anchor="la")
        y += 104
    y += 34
    for line in slines:
        d.text((CAP_X, y), line, font=fs, fill=MUTED, anchor="la")
        y += 58
    p = D / f"pcap{i}.png"
    img.save(p)
    return p


def icon(size):
    return Image.open(APP / "branding" / "app-icon-sticker-1024.png").convert("RGBA").resize(
        (size, size), Image.LANCZOS)


def card(name, build):
    img = background()
    d = ImageDraw.Draw(img)
    build(img, d)
    p = D / f"{name}.png"
    img.save(p)
    return p


def intro(img, d):
    ic = icon(300)
    img.paste(ic, ((W - 300) // 2, 170), ic)
    fw = font("ExtraBold", 150)
    d.text((W / 2, 560), "Pinpoint", font=fw, fill=INK, anchor="mm")
    ft = font("ExtraBold", 70)
    a, b = "Notes that stay ", "yours."
    wa, wb = d.textlength(a, font=ft), d.textlength(b, font=ft)
    x0 = (W - wa - wb) / 2
    marker(d, x0 + wa, 690, b, ft)
    d.text((x0, 690), a, font=ft, fill=INK, anchor="la")
    d.text((x0 + wa, 690), b, font=ft, fill=INK, anchor="la")
    d.text((W / 2, 870), "notes · checklists · voice · reminders", font=caveat(60), fill=MUTED,
           anchor="mm")


def outro(img, d):
    ic = icon(230)
    img.paste(ic, (160, 140), ic)
    d.text((420, 255), "Pinpoint", font=font("ExtraBold", 120), fill=INK, anchor="lm")
    items = [("Notes, checklists and voice", "yellow"), ("Reminders right on time", "lavender"),
             ("Folders and fast search", "mint"), ("Encrypted on your device", "sky")]
    fi = font("Bold", 50)
    y = 470
    for t, c in items:
        d.rounded_rectangle((190, y - 2, 236, y + 44), radius=10, fill=PASTELS[c], outline=INK, width=3)
        d.text((275, y + 21), t, font=fi, fill=INK, anchor="lm")
        y += 100
    bw, bh = 640, 150
    bx, by = 1140, 420
    d.rounded_rectangle((bx + 10, by + 10, bx + bw + 10, by + bh + 10), radius=bh // 2, fill=INK)
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=bh // 2, fill=YELLOW, outline=INK, width=4)
    d.text((bx + bw / 2, by + bh / 2), "Free on Google Play", font=font("ExtraBold", 52), fill=INK,
           anchor="mm")
    d.text((bx + bw / 2, by + bh + 90), "Notes that stay yours.", font=caveat(64), fill=MUTED,
           anchor="mm")


def main():
    scenes = json.loads(Path(SCENES).read_text(encoding="utf-8"))["segments"]
    phone_assets()
    caps = [caption_png(i, s["chip"], s.get("color", "yellow"), s["title"], s["sub"])
            for i, s in enumerate(scenes)]
    intro_p, outro_p = card("pintro", intro), card("poutro", outro)

    durs = [s["b"] - s["a"] for s in scenes]
    demo_len = sum(durs)
    total = INTRO + demo_len + OUTRO

    srcs = sorted({s["src"] for s in scenes})
    inputs, idx = [], {}
    for sp in srcs:
        idx[sp] = len(inputs) // 2
        inputs += ["-i", str(D / sp)]
    n_src = len(srcs)
    inputs += ["-loop", "1", "-i", str(D / "pstage.png")]
    inputs += ["-i", str(D / "pmask.png")]
    inputs += ["-loop", "1", "-t", str(INTRO), "-i", str(intro_p)]
    inputs += ["-loop", "1", "-t", str(OUTRO), "-i", str(outro_p)]
    cap0 = n_src + 4
    for p, du in zip(caps, durs):
        inputs += ["-loop", "1", "-t", f"{du:.3f}", "-i", str(p)]
    silence_i = cap0 + len(scenes)
    inputs += ["-f", "lavfi", "-t", f"{total:.3f}", "-i", "anullsrc=r=48000:cl=stereo"]

    fc = []
    uses = {sp: [i for i, s in enumerate(scenes) if s["src"] == sp] for sp in srcs}
    for sp, ids in uses.items():
        k = idx[sp]
        outs = "".join(f"[r{i}]" for i in ids)
        # screenrecord only writes frames when the screen changes: constant 30 fps,
        # and hold the last frame so a still ending is not cut short.
        base = f"[{k}:v]fps=30,tpad=stop_mode=clone:stop_duration=15"
        fc.append(f"{base},split={len(ids)}{outs}" if len(ids) > 1 else f"{base}{outs}")
    for i, s in enumerate(scenes):
        fc.append(f"[r{i}]trim={s['a']}:{s['b']},setpts=PTS-STARTPTS[t{i}]")
    fc.append("".join(f"[t{i}]" for i in range(len(scenes))) + f"concat=n={len(scenes)}:v=1:a=0[rec]")
    fc.append(f"[rec]scale={PW}:{PH}:flags=lanczos,format=rgba[ph]")
    fc.append(f"[{n_src + 1}:v]format=gray[mk]")
    fc.append("[ph][mk]alphamerge[phr]")
    fc.append(f"[{n_src}:v]fps=30,trim=0:{demo_len:.3f},setpts=PTS-STARTPTS[stg]")
    fc.append(f"[stg][phr]overlay={PX}:{PY}:shortest=1[a0]")
    last, t = "a0", 0.0
    for i, du in enumerate(durs):
        fades = f"fade=in:st=0:d={FADE}:alpha=1,fade=out:st={du - FADE:.3f}:d={FADE}:alpha=1"
        fc.append(f"[{cap0 + i}:v]format=rgba,{fades},setpts=PTS-STARTPTS+{t:.3f}/TB[c{i}]")
        fc.append(f"[{last}][c{i}]overlay=0:0:eof_action=pass[b{i}]")
        last, t = f"b{i}", t + du
    fc.append(f"color=c=0x141414:s={W}x8:r=30:d={demo_len:.3f}[bar]")
    fc.append(f"[{last}][bar]overlay=x='-{W}+{W}*t/{demo_len:.3f}':y={H - 8}:shortest=1,"
              f"format=yuv420p,setsar=1[demo]")
    fc.append(f"[{n_src + 2}:v]fps=30,format=yuv420p,fade=in:st=0:d=0.35:c=0xF5F3EC,"
              f"fade=out:st={INTRO - 0.35}:d=0.35:c=0xF5F3EC,setsar=1[in]")
    fc.append(f"[{n_src + 3}:v]fps=30,format=yuv420p,fade=in:st=0:d=0.35:c=0xF5F3EC,"
              f"fade=out:st={OUTRO - 0.6}:d=0.6:c=0xF5F3EC,setsar=1[out]")
    fc.append("[in][demo][out]concat=n=3:v=1:a=0[v]")

    cmd = [FF, "-hide_banner", "-loglevel", "error", "-y", *inputs, "-filter_complex", ";".join(fc),
           "-map", "[v]", "-map", f"{silence_i}:a", "-t", f"{total:.2f}", "-c:v", "libx264",
           "-crf", "19", "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
           "-movflags", "+faststart", OUT]
    subprocess.run(cmd, check=True)
    print("done", round(total, 2))


main()
