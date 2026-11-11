"""Play Store feature graphic (1024x500) uretici - yalnizca oyunun kendi varliklarini kullanir.
Calistir: python docs/play/store/make_feature_graphic.py  (repo kokunden)
Girdi: assets/backgrounds/*, assets/icon/icon_512.png, assets/fonts/PixeloidSans-Bold.ttf
Cikti: docs/play/store/feature_graphic_1024x500.png (24-bit, alfa yok)
Spoiler yok: Shilda, X ve final karesi kullanilmaz."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1024, 500
VOID = (0x22, 0x1B, 0x27); IVORY = (0xE1, 0xD3, 0xD1); CRIMSON = (0x7E, 0x2D, 0x3A); LILAC = (0xAB, 0x98, 0xA9)

def region(name):
    comp = Image.new("RGBA", (640, 360), VOID + (255,))
    for l in ("far", "mid", "front"):
        comp.alpha_composite(Image.open(f"assets/backgrounds/{name}/{l}.png").convert("RGBA"))
    return comp

# Arka plan: Uyanis + Kutuphane + Aynalar panoramasi (ust 2/3 mimari bolgesi kullanilir)
panels = [region(n).crop((0, 0, 640, 250)) for n in ("awakening", "library", "mirrors")]
pano = Image.new("RGBA", (640 * 3, 250))
for i, p in enumerate(panels):
    pano.paste(p, (i * 640, 0))
scale = H / 250
pano = pano.resize((int(pano.width * scale), H), Image.NEAREST)
bg = pano.crop((0, 0, W, H)).convert("RGB")

# Soldan sagdan koyulasan gradyan (metin okunurlugu)
grad = Image.new("L", (W, 1))
for x in range(W):
    t = x / W
    grad.putpixel((x, 0), int(235 * max(0.0, 1 - t * 1.35)) + 20)
grad = grad.resize((W, H))
dark = Image.new("RGB", (W, H), VOID)
bg = Image.composite(dark, bg, grad)

# Sagda Noroi'nin gozu (ikon varligi), yuvarlak vinyet
eye = Image.open("assets/icon/icon_512.png").convert("RGB").resize((420, 420), Image.LANCZOS)
mask = Image.new("L", (420, 420), 0)
ImageDraw.Draw(mask).ellipse((6, 6, 414, 414), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(10))
bg.paste(eye, (W - 420 - 40, (H - 420) // 2), mask)

d = ImageDraw.Draw(bg)
f_title = ImageFont.truetype("assets/fonts/PixeloidSans-Bold.ttf", 58)
f_sub = ImageFont.truetype("assets/fonts/PixeloidSans-Bold.ttf", 26)
f_tag = ImageFont.truetype("assets/fonts/PixeloidSans.ttf", 22)
x0 = 56
d.text((x0, 150), "THE ROOM", font=f_title, fill=IVORY, stroke_width=3, stroke_fill=VOID)
d.text((x0, 214), "REMEMBERS", font=f_title, fill=IVORY, stroke_width=3, stroke_fill=VOID)
d.rectangle((x0, 292, x0 + 220, 295), fill=CRIMSON)
d.text((x0, 310), "SEN UNUTURSUN.", font=f_sub, fill=LILAC, stroke_width=2, stroke_fill=VOID)
d.text((x0, 346), "ODA HATIRLAR.", font=f_sub, fill=(0xC2, 0x4A, 0x5C), stroke_width=2, stroke_fill=VOID)
d.text((x0, 410), "Gotik gizem  ·  Pixel art  ·  Bulmaca", font=f_tag, fill=LILAC, stroke_width=2, stroke_fill=VOID)
bg.save("docs/play/store/feature_graphic_1024x500.png", optimize=True)
print("ok", bg.size, bg.mode)
