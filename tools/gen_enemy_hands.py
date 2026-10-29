"""Ręce i broń wrogów Pixel Crawlera jako rig (SpriteRig) w scenach scenes/enemies/pixel_crawler/<wróg>.tscn.

Pod AnimatedSprite2D ciała: Rig (Node2D, scripts/enemies/sprite_rig.gd) -> Sprite2D z wycinkami atlasu broni rodziny
(region; atlas broni rodziny z paczki autora w katalogu wrogów) i AnimationPlayer RigAnim z animacjami o nazwach
animacji ciała (klucze dyskretne w czasie klatek ciała). Animacje można potem poprawiać w edytorze (oś czasu RigAnim
pokazuje pasującą klatkę ciała) — ponowne uruchomienie generatora dla rodziny NADPISUJE rig w jej scenach.

Wartości startowe ze wzorów autora paczki (zrzuty z gifów): pozycja części w klatce 64×64 tej klatki Idle, którą
pokazuje wzór (`ref_frame`), przeliczana na Idle 0; kolejność = kolejność rysowania (wszystko przed ciałem, dłoń nad
trzonkiem). W klatkach animacji z `follow` części idą za ciałem: przesunięcie ciała względem Idle 0 (dopasowanie górnej
części sylwetki), w pionie połowa bujania. Animacje z `hidden`: części ukryte (śmierć).

Rodziny:
- rat — szczury ze ścieków (atlas „Poison Weapons”): zwykły — zakrzywiony sztylet, łotrzyk — strzała + łuk,
  wojownik / król — tarcza + włócznia, mag — mikstura + kostur.
- fungus — grzyby z jaskiń (atlas „Spore_Roots”, wersja z environments/cave): młody — maczuga, długi — łuk,
  ciężki — tarcza z kłody + topór, stary — kostur z kulą; dłonie = szare kamyki z lewego górnego rogu atlasu.

Użycie: python gen_enemy_hands.py <rodzina> [--preview]   (--preview: tylko podgląd 4× złożonych klatek do %TEMP%)
"""
import os, re, sys, tempfile
from PIL import Image
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
RIG_SCRIPT = 'res://modules/quiz_rpg/scripts/enemies/sprite_rig.gd'
SCENES = ROOT + 'modules/quiz_rpg/scenes/enemies/pixel_crawler/'
FRAME = 64
GEN_PREFIX = 'RatRig_'  # id zasobów generatora w scenie (do podmiany przy ponownym uruchomieniu; nazwa historyczna)

RAT_HAND = (116, 53, 8, 7)  # dłoń (prawy dolny róg atlasu); lustro = druga ręka
FUNGUS_HAND_FRONT = (53, 5, 7, 7)
FUNGUS_HAND_BACK = (36, 20, 8, 6)

# Rodzina: atlas (źródło, kopia w assets), arkusz ciała (szablon ścieżki), animacje ciała
# {nazwa: (arkusz, klatki, fps)}, animacje z częściami za ciałem / ukrytymi, sceny -> wariant, układ wariantów
# [(węzeł, wycinek x, y, w, h, odbicie, pozycja w klatce ref_frame)].
FAMILIES = {
    'rat': {
        'atlas': 'assets/pixel_crawler/enemies/rat_enemy/Rat Weapons.png',
        'sheet': 'assets/pixel_crawler/enemies/rat_enemy/Rat - {kind}/{sheet}/{sheet}-Sheet.png',
        'anims': {'idle': ('Idle', 4, 6.0), 'walk': ('Run', 6, 10.0), 'death': ('Death', 6, 10.0)},
        'follow': ['idle', 'walk'],
        'hidden': ['death'],
        'scenes': {'rat_base': 'Base', 'rat_rogue': 'Rogue', 'rat_warrior': 'Warrior', 'rat_mage': 'Mage',
                   'rat_king': 'Warrior'},
        'ref_frame': {},
        'layout': {
            'Base': [
                ('Dagger', (32, 16, 16, 32), True, (10, 27)),
                ('HandBack', RAT_HAND, False, (14, 50)),
                ('HandFront', RAT_HAND, True, (40, 53)),
            ],
            'Rogue': [
                ('Arrow', (16, 0, 16, 16), False, (13, 45)),
                ('HandBack', RAT_HAND, False, (17, 50)),
                ('Bow', (48, 48, 16, 32), False, (38, 32)),
                ('HandFront', RAT_HAND, True, (47, 47)),
            ],
            'Warrior': [
                ('Shield', (112, 16, 28, 32), False, (1, 32)),
                ('Spear', (66, 1, 12, 47), False, (43, 17)),
                ('HandFront', RAT_HAND, True, (45, 45)),
            ],
            'Mage': [
                ('Flask', (80, 32, 16, 16), False, (14, 47)),
                ('HandBack', RAT_HAND, False, (18, 49)),
                ('Staff', (96, 1, 16, 47), False, (42, 17)),
                ('HandFront', RAT_HAND, True, (46, 47)),
            ],
        },
    },
    'fungus': {
        'atlas': 'assets/pixel_crawler/environments/cave/Enemies/Fungus Weapons.png',
        'sheet': 'assets/pixel_crawler/environments/cave/Enemies/{kind} Fungus/{sheet}-Sheet.png',
        'anims': {'idle': ('Idle', 4, 6.0), 'walk': ('Run', 6, 10.0), 'hurt': ('Hit', 4, 10.0),
                  'death': ('Death', 6, 10.0)},
        'follow': ['idle', 'walk', 'hurt'],
        'hidden': ['death'],
        'scenes': {'fungus_immature': 'Immature', 'fungus_long': 'Long', 'fungus_heavy': 'Heavy',
                   'fungus_old': 'Old'},
        'ref_frame': {'Heavy': 1, 'Old': 3},  # klatka Idle na wzorze (gif)
        'layout': {
            'Immature': [
                ('HandBack', FUNGUS_HAND_BACK, False, (12, 55)),
                ('Club', (18, 16, 12, 48), False, (44, 13)),
                ('HandFront', FUNGUS_HAND_FRONT, False, (47, 48)),
            ],
            'Long': [
                ('HandBack', FUNGUS_HAND_BACK, False, (12, 50)),
                ('Bow', (183, 112, 9, 48), False, (54, 14)),
                ('HandFront', FUNGUS_HAND_FRONT, False, (55, 36)),
            ],
            'Heavy': [
                ('Shield', (133, 129, 22, 29), False, (1, 39)),
                ('Axe', (0, 64, 16, 64), False, (49, 1)),
                ('HandFront', FUNGUS_HAND_FRONT, False, (53, 39)),
            ],
            'Old': [
                ('HandBack', FUNGUS_HAND_BACK, False, (8, 52)),
                ('Staff', (144, 16, 16, 48), False, (45, 13)),
                ('HandFront', FUNGUS_HAND_FRONT, False, (49, 48)),
            ],
        },
    },
}


def body_shift(base0, frame):
    """(dx, dy) ciała klatki względem Idle 0 — najlepsze pokrycie górnej części sylwetki (wiersze < 52)."""
    best = (-1.0, 0, 0)
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            shifted = np.zeros_like(base0)
            ys, yd = slice(max(0, dy), min(FRAME, FRAME + dy)), slice(max(0, -dy), min(FRAME, FRAME - dy))
            xs, xd = slice(max(0, dx), min(FRAME, FRAME + dx)), slice(max(0, -dx), min(FRAME, FRAME - dx))
            shifted[ys, xs] = base0[yd, xd]
            a, b = shifted[:52], frame[:52]
            m = (a[:, :, 3] > 0) | (b[:, :, 3] > 0)
            score = ((np.abs(a - b).sum(axis=2) < 8) & m).sum() / max(m.sum(), 1)
            if score > best[0]:
                best = (score, dx, dy)
    return best[1], best[2]


def sheet_path(fam, kind, anim):
    sheet = fam['anims'][anim][0]
    return ROOT + fam['sheet'].format(kind=kind, sheet=sheet)


def frame_offsets(fam, kind):
    """{animacja: [(dx, dy) na klatkę]} — przesunięcie części za ciałem (w pionie połowa bujania)."""
    base0 = np.asarray(Image.open(sheet_path(fam, kind, 'idle')).convert('RGBA'), dtype=int)[:, :FRAME]
    out = {}
    for anim in fam['follow']:
        count = fam['anims'][anim][1]
        sheet = Image.open(sheet_path(fam, kind, anim)).convert('RGBA')
        offs = []
        for f in range(count):
            fr = np.asarray(sheet.crop((f * FRAME, 0, (f + 1) * FRAME, FRAME)), dtype=int)
            dx, dy = body_shift(base0, fr)
            offs.append((dx, int(np.sign(dy)) * ((abs(dy) + 1) // 2)))
        out[anim] = offs
    return out


def base_layout(fam, kind, offs):
    """Układ wariantu w klatce Idle 0 (pozycje ze wzoru minus przesunięcie klatki wzoru)."""
    rdx, rdy = offs['idle'][fam['ref_frame'].get(kind, 0)]
    return [(n, r, fl, (px - rdx, py - rdy)) for n, r, fl, (px, py) in fam['layout'][kind]]


def fnum(v):
    return ('%.4f' % v).rstrip('0').rstrip('.') if v != int(v) else str(int(v))


def track(i, path, times, values):
    vals = ', '.join(values)
    return (f'tracks/{i}/type = "value"\ntracks/{i}/imported = false\ntracks/{i}/enabled = true\n'
            f'tracks/{i}/path = NodePath("{path}")\ntracks/{i}/interp = 0\ntracks/{i}/loop_wrap = true\n'
            f'tracks/{i}/keys = {{\n"times": PackedFloat32Array({", ".join(fnum(t) for t in times)}),\n'
            f'"transitions": PackedFloat32Array({", ".join("1" for _ in times)}),\n"update": 1,\n'
            f'"values": [{vals}]\n}}\n')


def rig_sections(fam, kind):
    offs = frame_offsets(fam, kind)
    layout = base_layout(fam, kind, offs)
    atlas_res = 'res://' + fam['atlas']
    subs, nodes = [], []
    for anim, (_, count, fps) in fam['anims'].items():
        times = [i / fps for i in range(count)]
        body = f'[sub_resource type="Animation" id="{GEN_PREFIX}{anim}"]\nresource_name = "{anim}"\n'
        body += f'length = {fnum(count / fps)}\n' + ('loop_mode = 1\n' if anim in ('idle', 'walk') else '')
        i = 0
        for name, _, _, (px, py) in layout:
            if anim in fam['hidden']:
                body += track(i, f'{name}:visible', [0.0], ['false'])
                i += 1
                continue
            body += track(i, f'{name}:visible', [0.0], ['true'])
            if anim in offs:
                body += track(i + 1, f'{name}:position', times,
                              [f'Vector2({px + dx}, {py + dy})' for dx, dy in offs[anim]])
                i += 1
            i += 1
        subs.append(body)
    lib = f'[sub_resource type="AnimationLibrary" id="{GEN_PREFIX}lib"]\n_data = {{\n'
    lib += ',\n'.join(f'&"{a}": SubResource("{GEN_PREFIX}{a}")' for a in fam['anims']) + '\n}\n'
    subs.append(lib)
    nodes.append('[node name="Rig" type="Node2D" parent="AnimatedSprite2D"]\n'
                 f'script = ExtResource("{GEN_PREFIX}script")\n')
    for name, (x, y, w, h), flip, (px, py) in layout:
        nodes.append(f'[node name="{name}" type="Sprite2D" parent="AnimatedSprite2D/Rig"]\n'
                     f'position = Vector2({px}, {py})\ntexture = ExtResource("{GEN_PREFIX}atlas")\ncentered = false\n'
                     + ('flip_h = true\n' if flip else '')
                     + f'region_enabled = true\nregion_rect = Rect2({x}, {y}, {w}, {h})\n'
                     # walka skaluje wroga niecałkowicie — bez tego przecieka rząd pikseli sąsiada z atlasu
                     + 'region_filter_clip_enabled = true\n')
    nodes.append('[node name="RigAnim" type="AnimationPlayer" parent="AnimatedSprite2D/Rig"]\n'
                 f'root_node = NodePath("..")\nlibraries = {{\n&"": SubResource("{GEN_PREFIX}lib")\n}}\n')
    exts = [f'[ext_resource type="Script" path="{RIG_SCRIPT}" id="{GEN_PREFIX}script"]\n',
            f'[ext_resource type="Texture2D" path="{atlas_res}" id="{GEN_PREFIX}atlas"]\n']
    return exts, subs, nodes


def patch_scene(path, fam, kind):
    text = open(path, encoding='utf-8').read()
    parts = re.split(r'(?m)^(?=\[)', text)
    head, sections = parts[0], parts[1:]
    atlas_res = 'res://' + fam['atlas']

    def generated(sec):
        first = sec.split('\n', 1)[0]
        return (f'id="{GEN_PREFIX}' in first or 'parent="AnimatedSprite2D/Rig' in first
                or ('name="Rig"' in first and 'parent="AnimatedSprite2D"' in first)
                or (first.startswith('[ext_resource') and (RIG_SCRIPT in first or atlas_res in first)))
    sections = [s.rstrip('\n') + '\n' for s in sections if not generated(s)]
    exts, subs, nodes = rig_sections(fam, kind)
    kinds = [s.split(' ', 1)[0] for s in sections]
    last_ext = max((i for i, k in enumerate(kinds) if k == '[ext_resource'), default=0)
    first_node = next(i for i, k in enumerate(kinds) if k == '[node')
    out = sections[:last_ext + 1] + exts + sections[last_ext + 1:first_node] + subs + sections[first_node:] + nodes
    open(path, 'w', encoding='utf-8', newline='\n').write(head + '\n'.join(out))


def preview(fam, name):
    atlas = Image.open(ROOT + fam['atlas_src']).convert('RGBA')
    rows = []
    for kind in fam['layout']:
        offs = frame_offsets(fam, kind)
        layout = base_layout(fam, kind, offs)
        for anim in fam['follow']:
            sheet = Image.open(sheet_path(fam, kind, anim)).convert('RGBA')
            for f in range(fam['anims'][anim][1]):
                cell = sheet.crop((f * FRAME, 0, (f + 1) * FRAME, FRAME))
                for _, (x, y, w, h), flip, (px, py) in layout:
                    im = atlas.crop((x, y, x + w, y + h))
                    im = im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im
                    dx, dy = offs[anim][f]
                    cell.alpha_composite(im, (px + dx, py + dy))
                sheet.paste(cell, (f * FRAME, 0))
            rows.append(sheet)
    w, h = max(r.width for r in rows), sum(r.height for r in rows)
    img = Image.new('RGBA', (w, h), (40, 40, 46, 255))
    y = 0
    for r in rows:
        img.alpha_composite(r, (0, y))
        y += r.height
    path = os.path.join(tempfile.gettempdir(), f'{name}_hands_preview.png')
    img.resize((w * 4, h * 4), Image.NEAREST).save(path)
    print(path)


def main():
    names = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(names) != 1 or names[0] not in FAMILIES:
        sys.exit('Użycie: python gen_enemy_hands.py <%s> [--preview]' % '|'.join(FAMILIES))
    name = names[0]
    fam = FAMILIES[name]
    if '--preview' in sys.argv:
        preview(fam, name)
        return
    for scene, kind in fam['scenes'].items():
        patch_scene(SCENES + scene + '.tscn', fam, kind)
        print(scene, '<-', kind)


if __name__ == '__main__':
    main()
