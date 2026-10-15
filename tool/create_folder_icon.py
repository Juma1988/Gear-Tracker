"""Create the GearTracker folder-style Windows icon and folder customization file."""

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "src"
OUT.mkdir(exist_ok=True)

NAVY = (6, 14, 32, 255)
MINT = (78, 218, 163, 255)
FOLDER = (242, 184, 75, 255)
FOLDER_DARK = (208, 143, 42, 255)


def gear_points(cx: float, cy: float, outer: float, root: float, teeth: int = 9):
    points = []
    step = 360 / teeth
    for tooth in range(teeth):
        base = tooth * step
        for offset, radius in (
            (0, root),
            (step * 0.18, root),
            (step * 0.28, outer),
            (step * 0.70, outer),
            (step * 0.82, root),
        ):
            import math

            angle = math.radians(base + offset - 90)
            points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def render(size: int) -> Image.Image:
    scale = 4
    canvas = size * scale
    image = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Folder tab and body, with a dark outline for visibility on Windows backgrounds.
    outline = max(2, canvas // 32)
    tab = (canvas * 0.12, canvas * 0.16, canvas * 0.56, canvas * 0.39)
    body = (canvas * 0.08, canvas * 0.28, canvas * 0.92, canvas * 0.86)
    draw.rounded_rectangle(tab, radius=canvas * 0.08, fill=NAVY)
    draw.rounded_rectangle(
        (body[0] - outline, body[1] - outline, body[2] + outline, body[3] + outline),
        radius=canvas * 0.09,
        fill=NAVY,
    )
    draw.rounded_rectangle(body, radius=canvas * 0.075, fill=FOLDER)
    draw.rounded_rectangle(
        (body[0], body[1] + canvas * 0.06, body[2], body[3]),
        radius=canvas * 0.06,
        fill=FOLDER_DARK,
    )
    draw.rounded_rectangle(
        (body[0], body[1], body[2], body[3] - canvas * 0.05),
        radius=canvas * 0.075,
        fill=FOLDER,
    )

    # Existing GearTracker mark, simplified for small-size legibility.
    cx, cy = canvas * 0.50, canvas * 0.55
    outer, root = canvas * 0.245, canvas * 0.19
    draw.polygon(gear_points(cx, cy, outer, root), fill=NAVY)
    draw.ellipse((cx - canvas * 0.105, cy - canvas * 0.105, cx + canvas * 0.105, cy + canvas * 0.105), fill=MINT)
    draw.ellipse((cx - canvas * 0.055, cy - canvas * 0.055, cx + canvas * 0.055, cy + canvas * 0.055), fill=NAVY)

    return image.resize((size, size), Image.Resampling.LANCZOS)


sizes = [16, 24, 32, 48, 64, 128, 256]
frames = [render(size) for size in sizes]
frames[-1].save(OUT / "GearTracker-folder.ico", format="ICO", sizes=[(size, size) for size in sizes])
(OUT / "desktop.ini").write_text(
    "[.ShellClassInfo]\nIconResource=GearTracker-folder.ico,0\nIconFile=GearTracker-folder.ico\nIconIndex=0\n",
    encoding="utf-8",
)
print(f"Created {OUT / 'GearTracker-folder.ico'}")
print(f"Created {OUT / 'desktop.ini'}")
