# Play Console uchun do'kon grafikalarini yaratadi (ikonka + feature graphic).
# Qayta ishlatish (logotip yangilansa):  python tool/make_store_assets.py
# Talab: pip install pillow  |  Shriftlar: Windows'dagi Segoe UI.
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store")
os.makedirs(OUT, exist_ok=True)

BLUE = (2, 0, 102)          # #020066 — brend ko'ki
BLUE_LIGHT = (26, 22, 150)  # gradient uchun ochroq ton
ACCENT = (174, 182, 255)    # matn aksenti

FONT_B = r"C:\Windows\Fonts\segoeuib.ttf"
FONT_R = r"C:\Windows\Fonts\segoeui.ttf"
FONT_SL = r"C:\Windows\Fonts\segoeuisl.ttf"

logo = Image.open(os.path.join(ROOT, "assets", "logo.png")).convert("RGBA")

# ---------------------------------------------------------------- 512x512 ikonka
# Play ikonkasi: 512x512 PNG, shaffoflik ISHLATILMAYDI (Play o'zi niqob qo'yadi).
icon = Image.new("RGB", (512, 512), BLUE)
icon.paste(logo.resize((512, 512), Image.LANCZOS), (0, 0), logo.resize((512, 512), Image.LANCZOS))
icon.save(os.path.join(OUT, "icon-512.png"), "PNG", optimize=True)

# ------------------------------------------------------- 1024x500 feature graphic
W, H = 1024, 500
fg = Image.new("RGB", (W, H), BLUE)
d = ImageDraw.Draw(fg)

# Diagonal gradient (chapdan pastdan o'ngga tepaga ochroq).
for y in range(H):
    for_x_t = y / H
    for x in range(0, W, 8):
        t = (x / W) * 0.55 + (1 - for_x_t) * 0.45
        c = tuple(int(BLUE[i] + (BLUE_LIGHT[i] - BLUE[i]) * t) for i in range(3))
        d.rectangle([x, y, x + 8, y + 1], fill=c)

# Yumshoq yorug'lik dog'i (o'ng yuqorida).
glow = Image.new("L", (W, H), 0)
ImageDraw.Draw(glow).ellipse([620, -180, 1180, 380], fill=90)
glow = glow.filter(ImageFilter.GaussianBlur(120))
fg = Image.composite(Image.new("RGB", (W, H), (60, 60, 200)), fg, glow)
d = ImageDraw.Draw(fg)

# Logo kartochkasi (yumaloq burchakli, chapda).
CARD = 300
card = logo.resize((CARD, CARD), Image.LANCZOS)
mask = Image.new("L", (CARD, CARD), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, CARD - 1, CARD - 1], radius=64, fill=255)
cx, cy = 72, (H - CARD) // 2

# Kartochka soyasi.
shadow = Image.new("L", (W, H), 0)
ImageDraw.Draw(shadow).rounded_rectangle(
    [cx + 6, cy + 12, cx + CARD + 6, cy + CARD + 12], radius=64, fill=110)
shadow = shadow.filter(ImageFilter.GaussianBlur(18))
fg = Image.composite(Image.new("RGB", (W, H), (0, 0, 30)), fg, shadow)
fg.paste(card, (cx, cy), mask)
d = ImageDraw.Draw(fg)
d.rounded_rectangle([cx, cy, cx + CARD - 1, cy + CARD - 1], radius=64,
                    outline=(255, 255, 255, 60), width=2)

# Matn bloki.
tx = cx + CARD + 56
f_title = ImageFont.truetype(FONT_B, 76)
f_sub = ImageFont.truetype(FONT_SL, 32)
f_foot = ImageFont.truetype(FONT_R, 26)

d.text((tx, 126), "Intellect", font=f_title, fill=(255, 255, 255))
d.text((tx, 214), "Student", font=f_title, fill=ACCENT)
d.text((tx, 336), "Davomat · Baholar · Testlar · To‘lovlar", font=f_sub, fill=(225, 228, 255))
d.text((tx, 394), "Intellect Kokand o‘quv markazi", font=f_foot, fill=(160, 168, 230))

fg.save(os.path.join(OUT, "feature-graphic-1024x500.png"), "PNG", optimize=True)

for f in ("icon-512.png", "feature-graphic-1024x500.png"):
    p = os.path.join(OUT, f)
    print(f, Image.open(p).size, f"{os.path.getsize(p)/1024:.0f} KB")
