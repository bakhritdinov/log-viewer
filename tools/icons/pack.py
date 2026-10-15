"""Builds the app icons from the PNGs that render.qml produced.

    qml tools/icons/render.qml -- <repo>/src/resources <png dir>
    python tools/icons/pack.py <png dir> <repo>/src/resources

Writes icon.png (window, Linux), icon.ico (Windows, 16-256), icon.icns
(macOS, 16-1024) and pwa/ (web and Android, including maskable icons).
Both .ico and .icns store PNG data, which every supported system reads.
"""
import shutil
import struct
import sys
from pathlib import Path


def png_size(data: bytes) -> int:
    return struct.unpack(">I", data[16:20])[0]


def write_ico(path: Path, pngs: list[bytes]) -> None:
    header = struct.pack("<HHH", 0, 1, len(pngs))
    offset = 6 + 16 * len(pngs)
    entries = b""
    for data in pngs:
        size = png_size(data)
        side = 0 if size >= 256 else size          # 0 means 256 in an ICO entry
        entries += struct.pack("<BBBBHHII", side, side, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    path.write_bytes(header + entries + b"".join(pngs))


def write_icns(path: Path, chunks: list[tuple[bytes, bytes]]) -> None:
    body = b"".join(kind + struct.pack(">I", 8 + len(data)) + data for kind, data in chunks)
    path.write_bytes(b"icns" + struct.pack(">I", 8 + len(body)) + body)


def main() -> None:
    pngs, res = Path(sys.argv[1]), Path(sys.argv[2])
    read = lambda name: (pngs / name).read_bytes()

    shutil.copyfile(pngs / "icon-256.png", res / "icon.png")
    write_ico(res / "icon.ico", [read(f"icon-{s}.png") for s in (16, 24, 32, 48, 64, 128, 256)])
    write_icns(res / "icon.icns", [
        (b"icp4", read("icon-16.png")), (b"icp5", read("icon-32.png")), (b"icp6", read("icon-64.png")),
        (b"ic07", read("icon-128.png")), (b"ic08", read("icon-256.png")), (b"ic09", read("icon-512.png")),
        (b"ic10", read("icon-1024.png")),                                   # 512@2x
        (b"ic11", read("icon-32.png")), (b"ic12", read("icon-64.png")),     # 16@2x, 32@2x
        (b"ic13", read("icon-256.png")), (b"ic14", read("icon-512.png")),   # 128@2x, 256@2x
    ])
    web = res / "pwa"
    web.mkdir(exist_ok=True)
    shutil.copyfile(pngs / "pwa-192.png", web / "icon-192.png")
    shutil.copyfile(pngs / "icon-512.png", web / "icon-512.png")
    shutil.copyfile(pngs / "maskable-192.png", web / "maskable-192.png")
    shutil.copyfile(pngs / "maskable-512.png", web / "maskable-512.png")


if __name__ == "__main__":
    main()
