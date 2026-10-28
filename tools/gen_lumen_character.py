"""Postacie ze szablonu LumenLorePixels („Top Down Prototype Character Template”, assets/lumenlore/prototype_template).

Szablon ma części ciała w płaskich kolorach (głowa, twarz, oczy, tułów góra / dół, ramię i przedramię + noga po każdej
stronie). Generator w każdej klatce każdej animacji rozpoznaje części (przedramię od nogi tego samego koloru: spójny
obszar stykający się z ramieniem = ręka, w nim kratki > HIP_SLACK rzędów pod biodrem = noga), maluje je kolorami postaci
z cieniowaniem (górna krawędź części jaśniej, dolna / prawa ciemniej, kończyny strony odwróconej od widza ciemniej),
dokłada pas, buty, dłonie i kontur. Klatki 64×64, rzędy E/NE/N/NW/W/SW/S/SE (jak w szablonie).

Wynik: assets/lumenlore/characters/<postać>/<Animacja>.png (arkusze jak w szablonie) + podgląd.
Licencja szablonu: przeróbki do gry OK, bez rozpowszechniania plików (wynik tylko w prywatnym repo assets).

Użycie: python gen_lumen_character.py <postać> [--preview]
"""
import os, sys
from collections import deque
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
TEMPLATE = ROOT + 'assets/lumenlore/prototype_template/'
OUT = ROOT + 'assets/lumenlore/characters/'
FRAME = 64
DIRS = ['E', 'NE', 'N', 'NW', 'W', 'SW', 'S', 'SE']
ANIMS = {
    'Idle': 'Human_Character_Template/Idle.png',
    'Walk': 'Human_Character_Template/Walk.png',
    'Run': 'Human_Character_Template/Run.png',
    'Death': 'Human_Character_Template/Death.png',
    'Punch': 'Human_Character_Template/Right-Hand-Punch.png',
}
# Kolory części szablonu.
T = {
    (60, 234, 240): 'head', (55, 159, 219): 'face', (0, 0, 0): 'eye',
    (106, 190, 48): 'torso_up', (55, 148, 110): 'torso_lo',
    (172, 50, 50): 'r_up', (110, 32, 37): 'r_lo', (48, 96, 130): 'l_up', (48, 70, 130): 'l_lo',
}
# Strona odwrócona od widza (ciemniejsza) w kierunku: postać patrzy na wschód -> jej lewa strona z tyłu.
BACK_SIDE = {'E': 'l', 'NE': 'l', 'SE': 'l', 'W': 'r', 'NW': 'r', 'SW': 'r', 'N': '', 'S': ''}
HIP_SLACK = 2       # dłoń sięga do 2 rzędów pod biodro; niżej w obszarze ręki = noga
BOOT_ROWS = 2
HAND_PX = 2         # tyle kratek przedramienia najdalej od ramienia = dłoń
OUTLINE = (22, 18, 28)

CHARACTERS = {
    # Bohater — rycerz: hełm, niebieski wapenrok na kolczudze, stalowe naramienniki i rękawice.
    'bohater': {
        'head': [(214, 222, 230), (156, 168, 184), (92, 100, 118)],
        'face': [(246, 206, 170), (226, 170, 132), (170, 116, 90)],
        'eye': (36, 28, 40),
        'torso_up': [(92, 136, 206), (62, 100, 176), (38, 62, 124)],
        'torso_lo': [(78, 120, 194), (54, 88, 160), (34, 56, 112)],
        'belt': [(150, 100, 56), (112, 72, 40), (72, 46, 28)],
        'arm_up': [(204, 212, 222), (146, 158, 176), (86, 94, 112)],
        'arm_lo': [(170, 180, 196), (124, 136, 154), (78, 86, 104)],
        'hand': [(204, 212, 222), (146, 158, 176), (86, 94, 112)],
        'leg': [(110, 112, 126), (82, 84, 98), (56, 56, 70)],
        'boot': [(132, 88, 52), (98, 64, 38), (64, 40, 26)],
    },
}


def load_frames(path):
    im = Image.open(path).convert('RGBA')
    cols, rows = im.width // FRAME, im.height // FRAME
    return im, cols, rows


def segment(fr):
    """Etykieta części każdej kratki klatki (dict (x, y) -> nazwa)."""
    lab = {}
    for y in range(FRAME):
        for x in range(FRAME):
            px = fr.getpixel((x, y))
            if px[3] < 200:
                continue
            name = T.get(px[:3])
            if name:
                lab[(x, y)] = name
    torso_ys = [p[1] for p, n in lab.items() if n == 'torso_lo']
    hip = max(torso_ys) if torso_ys else FRAME
    for side in ('r', 'l'):
        lo = {p for p, n in lab.items() if n == side + '_lo'}
        up = {p for p, n in lab.items() if n == side + '_up'}
        seen = set()
        for start in lo:
            if start in seen:
                continue
            comp, q = [], deque([start])
            seen.add(start)
            while q:
                c = q.popleft()
                comp.append(c)
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (c[0] + d[0], c[1] + d[1])
                    if n in lo and n not in seen:
                        seen.add(n)
                        q.append(n)
            arm = any((c[0] + d[0], c[1] + d[1]) in up for c in comp for d in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            for c in comp:
                lab[c] = side + ('_arm' if arm and c[1] <= hip + HIP_SLACK else '_leg')
        # dłoń: kratki przedramienia najdalej (BFS) od ramienia
        arm_px = {p for p, n in lab.items() if n == side + '_arm'}
        dist = {}
        q = deque()
        for p in arm_px:
            if any((p[0] + d[0], p[1] + d[1]) in up for d in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dist[p] = 0
                q.append(p)
        while q:
            c = q.popleft()
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + d[0], c[1] + d[1])
                if n in arm_px and n not in dist:
                    dist[n] = dist[c] + 1
                    q.append(n)
        if dist:
            far = sorted(dist, key=lambda p: -dist[p])[:HAND_PX]
            for p in far:
                if dist[p] >= 2:
                    lab[p] = side + '_hand'
    return lab


def part_ramp(name, spec):
    if name in ('r_up', 'l_up'):
        return spec['arm_up']
    if name in ('r_arm', 'l_arm'):
        return spec['arm_lo']
    if name in ('r_hand', 'l_hand'):
        return spec['hand']
    if name in ('r_leg', 'l_leg'):
        return spec['leg']
    return spec[name]


def paint(fr, spec, direction):
    lab = segment(fr)
    # pas: górny rząd dołu tułowia (kratki torso_lo z torso_up nad sobą)
    for p, n in list(lab.items()):
        if n == 'torso_lo' and lab.get((p[0], p[1] - 1)) == 'torso_up':
            lab[p] = 'belt'
    # buty: dolne BOOT_ROWS rzędów każdej nogi (per kolumna)
    for side in ('r', 'l'):
        legs = [p for p, n in lab.items() if n == side + '_leg']
        cols = {}
        for p in legs:
            cols.setdefault(p[0], []).append(p[1])
        for x, ys in cols.items():
            bottom = max(ys)
            for y in ys:
                if y > bottom - BOOT_ROWS:
                    lab[(x, y)] = side + '_boot'
    out = Image.new('RGBA', (FRAME, FRAME), (0, 0, 0, 0))
    back = BACK_SIDE[direction]
    for (x, y), n in lab.items():
        if n == 'eye':
            out.putpixel((x, y), spec['eye'] + (255,))
            continue
        ramp = spec['boot'] if n.endswith('_boot') else part_ramp(n, spec)
        tone = 1
        group = n.split('_')[0] if n[:2] in ('r_', 'l_') else n
        above = lab.get((x, y - 1))
        below = lab.get((x, y + 1))
        right = lab.get((x + 1, y))
        if above is None or (above != n and above.split('_')[0] != group):
            tone = 0
        elif below is None or right is None:
            tone = 2
        if back and n.startswith(back + '_'):
            tone = min(2, tone + 1)
        out.putpixel((x, y), ramp[tone] + (255,))
    # kontur
    solid = set(lab)
    for (x, y) in list(solid):
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + d[0], y + d[1])
            if n not in solid and 0 <= n[0] < FRAME and 0 <= n[1] < FRAME:
                out.putpixel(n, OUTLINE + (255,))
    return out


def build(char_id, preview):
    spec = CHARACTERS[char_id]
    dst = OUT + char_id + '/'
    os.makedirs(dst, exist_ok=True)
    sheets = {}
    for anim, rel in ANIMS.items():
        src, cols, rows = load_frames(TEMPLATE + rel)
        sheet = Image.new('RGBA', src.size, (0, 0, 0, 0))
        for r in range(rows):
            for c in range(cols):
                fr = src.crop((c * FRAME, r * FRAME, (c + 1) * FRAME, (r + 1) * FRAME))
                if fr.getbbox() is None:
                    continue
                sheet.alpha_composite(paint(fr, spec, DIRS[r]), (c * FRAME, r * FRAME))
        sheet.save(dst + anim + '.png')
        sheets[anim] = (sheet, cols)
        print(anim, src.size, '->', dst + anim + '.png')
    if preview:
        _preview(char_id, sheets)


def _preview(char_id, sheets):
    """Podgląd: pierwsza klatka Idle i klatki Walk dla 8 kierunków (×4) + GIF chodu."""
    tmp = os.environ.get('LUMEN_PREVIEW_DIR', os.environ.get('TEMP', '.'))
    walk, wcols = sheets['Walk']
    idle, _ = sheets['Idle']
    crop = (16, 8, 48, 56)   # postać w klatce 64×64
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]
    S = 4
    pv = Image.new('RGBA', ((wcols + 1) * cw, 8 * ch), (70, 70, 70, 255))
    for r in range(8):
        pv.alpha_composite(idle.crop((crop[0], r * FRAME + crop[1], crop[2], r * FRAME + crop[3])), (0, r * ch))
        for c in range(wcols):
            pv.alpha_composite(walk.crop((c * FRAME + crop[0], r * FRAME + crop[1], c * FRAME + crop[2], r * FRAME + crop[3])), ((c + 1) * cw, r * ch))
    pv = pv.resize((pv.width * S, pv.height * S), Image.NEAREST)
    pv.save(os.path.join(tmp, 'lumen_%s_preview.png' % char_id))
    frames = []
    for c in range(wcols):
        f = Image.new('RGBA', (8 * cw, ch), (70, 70, 70, 255))
        for r in range(8):
            f.alpha_composite(walk.crop((c * FRAME + crop[0], r * FRAME + crop[1], c * FRAME + crop[2], r * FRAME + crop[3])), (r * cw, 0))
        frames.append(f.resize((f.width * S, f.height * S), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(tmp, 'lumen_%s_walk.gif' % char_id), save_all=True, append_images=frames[1:], duration=120, loop=0)
    print('podgląd:', os.path.join(tmp, 'lumen_%s_preview.png' % char_id))


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] not in CHARACTERS:
        print(__doc__)
        print('postacie:', ', '.join(CHARACTERS))
        sys.exit(1)
    build(sys.argv[1], '--preview' in sys.argv)
