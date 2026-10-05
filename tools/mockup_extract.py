#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Uniwersalny ekstraktor makiet Aseprite (.aseprite) do JSON z dopasowaniem kafli z atlasów.

Użycie:
    python tools/mockup_extract.py \\
        --atlas T="assets/pixel_crawler/environments/sewer/Assets/Tiles.png" \\
        --atlas P="assets/pixel_crawler/environments/sewer/Assets/Props.png" \\
        --input "assets/pixel_crawler/environments/sewer/Social/MockUp-01.aseprite" \\
        --output-dir "modules/quiz_rpg/resources/maps/mockups"
"""

import argparse
import glob
import json
import os
import struct
import sys
import zlib
import numpy as np
from PIL import Image


def load_atlas(path: str, sid: str, tile_size: int = 16):
    img = Image.open(path).convert("RGBA")
    arr = np.array(img, dtype=np.int16)
    tiles = []
    th = arr.shape[0] // tile_size
    tw = arr.shape[1] // tile_size
    for ty in range(th):
        for tx in range(tw):
            t = arr[ty * tile_size:(ty + 1) * tile_size, tx * tile_size:(tx + 1) * tile_size]
            if (t[:, :, 3] > 0).sum() == 0:
                continue
            # warianty odbić
            for fl, tt in [
                ("", t),
                ("h", t[:, ::-1]),
                ("v", t[::-1, :]),
                ("hv", t[::-1, ::-1]),
            ]:
                tiles.append(((sid, tx, ty, fl), tt))
    return tiles


def parse_aseprite(path: str):
    data = open(path, "rb").read()
    fsize, magic, frames, W, H, depth = struct.unpack_from("<IHHHHH", data, 0)
    if magic != 0xA5E0:
        raise ValueError(f"Nieprawidłowy plik Aseprite (magic {hex(magic)}): {path}")

    pos = 128
    palette = np.zeros((256, 4), dtype=np.uint8)
    layers = []
    frames_data = []

    for fi in range(frames):
        fbytes, fmagic, old_chunks, dur = struct.unpack_from("<IHHH", data, pos)
        nchunks = struct.unpack_from("<I", data, pos + 12)[0] or old_chunks
        cp = pos + 16
        cels = []

        for _ in range(nchunks):
            csize, ctype = struct.unpack_from("<IH", data, cp)
            body = data[cp + 6: cp + csize]

            if ctype == 0x2004:  # Layer chunk
                flags, ltype, child, dw, dh, blend, opac = struct.unpack_from("<HHHHHHB", body, 0)
                nlen = struct.unpack_from("<H", body, 16)[0]
                name = body[18: 18 + nlen].decode("utf-8", "replace")
                layers.append({"name": name, "type": ltype, "flags": flags, "opacity": opac})

            elif ctype == 0x2019:  # Palette chunk
                n, first, last = struct.unpack_from("<III", body, 0)
                p = 20
                for i in range(first, last + 1):
                    eflags, r, g, b, a = struct.unpack_from("<HBBBB", body, p)
                    palette[i] = (r, g, b, a)
                    p += 6
                    if eflags & 1:
                        sl = struct.unpack_from("<H", body, p)[0]
                        p += 2 + sl

            elif ctype == 0x2005:  # Cel chunk
                li, cx, cy, opac, ctyp = struct.unpack_from("<HhhBH", body, 0)
                p = 16
                if ctyp == 0:  # raw cel
                    cw, ch = struct.unpack_from("<HH", body, p)
                    raw = body[p + 4:]
                    img = _unpack_pixels(raw, cw, ch, depth, palette)
                    cels.append({"layer_idx": li, "x": cx, "y": cy, "w": cw, "h": ch, "img": img})
                elif ctyp == 2:  # compressed image cel
                    cw, ch = struct.unpack_from("<HH", body, p)
                    raw = zlib.decompress(body[p + 4:])
                    img = _unpack_pixels(raw, cw, ch, depth, palette)
                    cels.append({"layer_idx": li, "x": cx, "y": cy, "w": cw, "h": ch, "img": img})

            cp += csize

        frames_data.append(cels)
        pos += fbytes

    return W, H, depth, layers, frames_data


def _unpack_pixels(raw, w, h, depth, palette):
    if depth == 32:
        return np.frombuffer(raw, dtype=np.uint8).reshape(h, w, 4).copy()
    elif depth == 8:
        idx = np.frombuffer(raw, dtype=np.uint8).reshape(h, w)
        return palette[idx]
    elif depth == 16:
        g = np.frombuffer(raw, dtype=np.uint8).reshape(h, w, 2)
        return np.dstack([g[:, :, 0], g[:, :, 0], g[:, :, 0], g[:, :, 1]])
    else:
        raise ValueError(f"Nieobsługiwana głębia koloru: {depth}")


def match_tile(cell: np.ndarray, atlas_tiles, tolerance: int = 2):
    cell_alpha = cell[:, :, 3] > 0
    if not cell_alpha.any():
        return None

    for key, t in atlas_tiles:
        t_alpha = t[:, :, 3] > 0
        if (t_alpha != cell_alpha).any():
            continue
        # Sprawdzenie kanałów RGB na widocznych pikselach
        diff = np.abs(t[:, :, :3][cell_alpha] - cell[:, :, :3][cell_alpha])
        if (diff <= tolerance).all():
            return key
    return "?"


def extract_mockup(ase_path: str, atlas_tiles, tile_size: int = 16, tolerance: int = 2, frame_idx: int = 0):
    W, H, depth, layers, frames = parse_aseprite(ase_path)
    if frame_idx >= len(frames):
        frame_idx = 0
    cels = frames[frame_idx]

    gw = (W + tile_size - 1) // tile_size
    gh = (H + tile_size - 1) // tile_size

    # Warstwy według indeksu
    layer_canvases = {}
    for li, layer_info in enumerate(layers):
        layer_canvases[li] = {
            "name": layer_info["name"],
            "canvas": np.zeros((H, W, 4), dtype=np.int16),
            "offgrid": []
        }

    for cel in cels:
        li = cel["layer_idx"]
        if li not in layer_canvases:
            continue
        cx, cy, cw, ch = cel["x"], cel["y"], cel["w"], cel["h"]
        img = cel["img"].astype(np.int16)

        # Sprawdzenie czy cel jest wyrównany do siatki
        if cx % tile_size != 0 or cy % tile_size != 0:
            layer_canvases[li]["offgrid"].append({
                "x": int(cx), "y": int(cy), "w": int(cw), "h": int(ch)
            })

        # Wklejenie do canvasu warstwy
        x0, y0 = max(0, cx), max(0, cy)
        x1, y1 = min(W, cx + cw), min(H, cy + ch)
        if x1 > x0 and y1 > y0:
            sx0, sy0 = x0 - cx, y0 - cy
            sx1, sy1 = sx0 + (x1 - x0), sy0 + (y1 - y0)
            layer_canvases[li]["canvas"][y0:y1, x0:x1] = img[sy0:sy1, sx0:sx1]

    # Analiza kratek i dopasowywanie
    extracted_layers = []
    total_occupied = 0
    total_matched = 0
    total_unknown = 0

    for li, ldata in layer_canvases.items():
        canvas = ldata["canvas"]
        matched_cells = []
        unknown_cells = []

        for gy in range(gh):
            for gx in range(gw):
                x0, y0 = gx * tile_size, gy * tile_size
                cell = canvas[y0:min(H, y0 + tile_size), x0:min(W, x0 + tile_size)]
                if cell.shape[0] < tile_size or cell.shape[1] < tile_size:
                    padded = np.zeros((tile_size, tile_size, 4), dtype=np.int16)
                    padded[:cell.shape[0], :cell.shape[1]] = cell
                    cell = padded

                res = match_tile(cell, atlas_tiles, tolerance)
                if res is None:
                    continue

                total_occupied += 1
                if res == "?":
                    total_unknown += 1
                    unknown_cells.append({"gx": gx, "gy": gy})
                else:
                    total_matched += 1
                    sid, tx, ty, fl = res
                    matched_cells.append({
                        "gx": gx,
                        "gy": gy,
                        "atlas": sid,
                        "tx": int(tx),
                        "ty": int(ty),
                        "flip": fl
                    })

        extracted_layers.append({
            "layer_index": li,
            "name": ldata["name"],
            "matched_cells": matched_cells,
            "unknown_cells": unknown_cells,
            "offgrid_elements": ldata["offgrid"]
        })

    coverage = (100.0 * total_matched / max(1, total_occupied)) if total_occupied > 0 else 100.0

    return {
        "source_file": os.path.basename(ase_path),
        "width": W,
        "height": H,
        "tile_size": tile_size,
        "grid_width": gw,
        "grid_height": gh,
        "frame_index": frame_idx,
        "stats": {
            "occupied_cells": total_occupied,
            "matched_cells": total_matched,
            "unknown_cells": total_unknown,
            "coverage_percent": round(coverage, 2)
        },
        "layers": extracted_layers
    }


def main():
    parser = argparse.ArgumentParser(description="Uniwersalny ekstraktor makiet Aseprite do JSON")
    parser.add_argument("--atlas", action="append", required=True,
                        help="Definicja atlasu w formacie ID=SCIEZKA lub ID:SCIEZKA (np. T=assets/.../Tiles.png)")
    parser.add_argument("--input", nargs="+", required=True,
                        help="Ścieżki do plików .aseprite lub maska wyszukiwania")
    parser.add_argument("--output-dir", required=True,
                        help="Katalog docelowy na pliki JSON")
    parser.add_argument("--tile-size", type=int, default=16,
                        help="Rozmiar kafla w pikselach (domyślnie 16)")
    parser.add_argument("--tolerance", type=int, default=2,
                        help="Tolerancja składowych RGB (domyślnie 2)")
    parser.add_argument("--frame", type=int, default=0,
                        help="Indeks klatki do ekstrakcji (domyślnie 0)")

    args = parser.parse_args()

    # Załadowanie atlasów
    atlas_tiles = []
    for a in args.atlas:
        delimiter = "=" if "=" in a else ":"
        sid, apath = a.split(delimiter, 1)
        if not os.path.isfile(apath):
            sys.exit(f"BŁĄD: Plik atlasu nie istnieje: {apath}")
        loaded = load_atlas(apath, sid.strip(), args.tile_size)
        atlas_tiles.extend(loaded)
        print(f"Załadowano atlas '{sid}': {len(loaded)} wariantów kafli z {os.path.basename(apath)}")

    # Zebranie plików wejściowych
    input_files = []
    for inp in args.input:
        matched = glob.glob(inp)
        if matched:
            input_files.extend(matched)
        elif os.path.isfile(inp):
            input_files.append(inp)

    if not input_files:
        sys.exit(f"BŁĄD: Brak pasujących plików makiet dla {args.input}")

    os.makedirs(args.output_dir, exist_ok=True)

    print(f"\nEkstrakcja {len(input_files)} makiet do {args.output_dir}...")
    for fpath in input_files:
        base_name = os.path.splitext(os.path.basename(fpath))[0]
        out_name = f"{base_name.lower().replace('-', '_')}.json"
        out_path = os.path.join(args.output_dir, out_name)

        result = extract_mockup(fpath, atlas_tiles, args.tile_size, args.tolerance, args.frame)

        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2, ensure_ascii=False)

        stats = result["stats"]
        print(f"  [{os.path.basename(fpath)}] -> {out_name}: "
              f"kratek {stats['occupied_cells']}, dopasowane {stats['matched_cells']} "
              f"({stats['coverage_percent']}%), nieznane {stats['unknown_cells']}")

    print("\nEkstrakcja zakończona pomyślnie.")


if __name__ == "__main__":
    main()
