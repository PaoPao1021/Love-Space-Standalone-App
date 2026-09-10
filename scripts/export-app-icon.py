"""Export generated artwork to Android launcher densities (requires Pillow)."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "app/assets/branding"
RES = ROOT / "app/android/app/src/main/res"
source = Image.open(BRANDING / "lovespace-icon-source.png").convert("RGBA")
background = (255, 248, 239, 255)


def artwork(size, scale):
    canvas = Image.new("RGBA", (size, size))
    edge = round(size * scale)
    symbol = source.resize((edge, edge), Image.Resampling.LANCZOS)
    canvas.alpha_composite(symbol, ((size - edge) // 2, (size - edge) // 2))
    return canvas


def opaque(layer):
    base = Image.new("RGBA", layer.size, background)
    return Image.alpha_composite(base, layer).convert("RGB")


opaque(artwork(1024, 1.0)).save(BRANDING / "lovespace-icon.png")
for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                      "xxhdpi": 144, "xxxhdpi": 192}.items():
    directory = RES / f"mipmap-{density}"
    directory.mkdir(parents=True, exist_ok=True)
    opaque(artwork(size, 1.0)).save(directory / "ic_launcher.png")
    # Adaptive layers are 108dp: keep the emblem inside the central safe zone.
    artwork(round(size * 108 / 48), 0.80).save(directory / "ic_launcher_foreground.png")
print("Exported preview, five legacy icons and five adaptive foreground layers.")
