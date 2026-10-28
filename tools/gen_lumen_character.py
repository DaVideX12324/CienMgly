"""Postacie ze szablonu LumenLorePixels („Top Down Prototype Character Template”, assets/lumenlore/prototype_template).

Szablon ma części ciała w płaskich kolorach (głowa, twarz, oczy, tułów góra / dół, ramię i przedramię + noga po każdej
stronie). Generator w każdej klatce każdej animacji rozpoznaje części (przedramię od nogi tego samego koloru: spójny
obszar stykający się z ramieniem = ręka, w nim kratki > HIP_SLACK rzędów pod biodrem = noga), przerabia je wg postaci
i maluje paletą: część jednolita (średni odcień), ciemna krawędź tam, gdzie styka się z inną częścią (prawy / dolny brzeg
części, np. ręka na tułowiu), kończyny strony odwróconej od widza ciemniej, kontur dookoła. Klatki 64×64, rzędy E/NE/N/NW/W/SW/S/SE (jak w szablonie).

Postać (CHARACTERS): palety części (3 odcienie: jasny, średni, ciemny — barwy z Pixel Crawlera, styl gry) oraz:
- head: "hair" (włosy / goła głowa), "helmet" (hełm z odsłoniętą twarzą: osłony policzków od wysokości oczu w dół,
  złoty pas przez środek do linii twarzy), "hood" (kaptur o 1 px szerszy od głowy, złota lamówka przy twarzy), "hood_dark" (kaptur, twarz w cieniu,
  świecące oczy), "wizard" (spiczasty kapelusz z rondem, siwe włosy, broda na piersi), "hair_long" (włosy opadające
  4 rzędy na ramiona / plecy), "bald" (łysa głowa w kolorze skóry); klucz "beard" = broda (też przy włosach i łysinie);
- body: "plain" (spodnie, pas, buty) albo "robe" (szata do kostek: przerwa między nogami wypełniona, lamówka na dole);
- detale ubioru (klucz z paletą = detal włączony): "tabard" (środkowy pas tułowia, szer. 2·tabard_half, np. wapenrok
  na napierśniku), "collar" (górny rząd tułowia pod głową), "emblem" (krzyżyk na piersi, tylko od przodu), "buckle"
  (klamra na środku pasa, od przodu), "cuff" (mankiet przy dłoni), "knee" (nakolannik w połowie nogi), "stole" (pionowy
  pas przez środek tułowia i szaty, od przodu), "strap" (skośny pas przez tułów, nie z boku).

Wynik: assets/lumenlore/characters/<postać>/<Animacja>.png (arkusze jak w szablonie) + podgląd.
Licencja szablonu: przeróbki do gry OK, bez rozpowszechniania plików (wynik tylko w prywatnym repo assets).

Użycie: python gen_lumen_character.py <postać|all> [--preview]
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
# Kierunek patrzenia w poziomie (czubek kapelusza maga przechyla się do tyłu).
FACING_X = {'E': 1, 'NE': 1, 'SE': 1, 'W': -1, 'NW': -1, 'SW': -1, 'N': 0, 'S': 0}
HIP_SLACK = 2       # dłoń sięga do 2 rzędów pod biodro; niżej w obszarze ręki = noga
BOOT_ROWS = 2
HAND_PX = 2         # tyle kratek przedramienia najdalej od ramienia = dłoń
D4 = ((1, 0), (-1, 0), (0, 1), (0, -1))

# Barwy Pixel Crawlera (royal crew, NPC).
OUTLINE = (20, 20, 18)
SKIN = [(240, 154, 83), (204, 120, 62), (128, 74, 30)]
METAL = [(255, 255, 254), (204, 201, 194), (146, 143, 136)]
METAL_D = [(204, 201, 194), (146, 143, 136), (112, 110, 104)]
GOLD = [(255, 192, 0), (167, 117, 32), (112, 80, 25)]
BLUE = [(69, 83, 189), (51, 60, 129), (26, 32, 82)]
LEATHER = [(181, 108, 48), (128, 74, 30), (71, 40, 13)]
OLIVE = [(146, 130, 48), (95, 86, 37), (55, 58, 32)]
PURPLE = [(147, 45, 139), (95, 46, 92), (67, 35, 65)]
WHITE = [(253, 253, 253), (203, 195, 188), (124, 108, 94)]
DARK = [(64, 69, 69), (37, 39, 22), (20, 20, 18)]
CHAIN = [(146, 143, 136), (112, 110, 104), (64, 69, 69)]
BLUE_D = [(51, 60, 129), (26, 32, 82), (20, 20, 18)]
OLIVE_D = [(95, 86, 37), (55, 58, 32), (37, 39, 22)]
RED = [(186, 58, 52), (130, 38, 40), (78, 24, 30)]
RED_D = [(130, 38, 40), (78, 24, 30), (48, 16, 22)]
GREEN = [(90, 135, 24), (43, 94, 14), (15, 57, 15)]
GREEN_D = [(43, 94, 14), (15, 57, 15), (20, 20, 18)]
LINEN = [(226, 214, 186), (186, 170, 140), (124, 108, 94)]
CLOTH = [(112, 104, 98), (82, 76, 72), (52, 48, 46)]
BROWN = [(128, 92, 60), (96, 66, 42), (64, 44, 30)]
HAIR_BROWN = [(128, 74, 30), (95, 56, 24), (71, 40, 13)]
HAIR_BLONDE = [(240, 196, 96), (200, 150, 60), (150, 100, 30)]
HAIR_BLACK = [(70, 62, 62), (44, 40, 42), (20, 20, 18)]
HAIR_AUBURN = [(176, 82, 42), (128, 56, 30), (80, 34, 20)]

CHARACTERS = {
    # Bohater — rycerz (wzór: royal Knight): srebrna zbroja, hełm z odsłoniętą twarzą i złotym pasem, niebieski wapenrok.
    'bohater': {
        'head_style': 'helmet', 'body': 'plain',
        'head': METAL_D, 'face': SKIN, 'eye': (20, 20, 18), 'trim': GOLD,
        'torso_up': METAL, 'torso_lo': BLUE_D, 'belt': LEATHER, 'buckle': GOLD,
        'tabard': BLUE, 'tabard_half': 2.5, 'emblem': GOLD, 'collar': METAL_D,
        'arm_up': METAL, 'arm_lo': CHAIN, 'hand': LEATHER, 'cuff': METAL_D,
        'leg': CHAIN, 'knee': METAL, 'boot': METAL_D,
    },
    # Kapłan (wzór: royal Priest): niebieski kaptur i szata ze złotą lamówką.
    'kaplan': {
        'head_style': 'hood', 'body': 'robe',
        'head': BLUE, 'hood': BLUE, 'face': SKIN, 'eye': (20, 20, 18), 'trim': GOLD,
        'torso_up': BLUE, 'torso_lo': BLUE, 'belt': BLUE_D, 'robe': BLUE, 'stole': GOLD, 'collar': BLUE_D,
        'arm_up': BLUE, 'arm_lo': BLUE, 'hand': SKIN, 'cuff': GOLD,
        'leg': BLUE, 'boot': LEATHER,
    },
    # Łotrzyk (wzór: NPC Rogue): oliwkowy kaptur, twarz w cieniu, świecące oczy, skórzany pas i buty.
    'lotrzyk': {
        'head_style': 'hood_dark', 'body': 'plain',
        'head': OLIVE, 'hood': OLIVE, 'face': DARK, 'eye': (12, 152, 214), 'trim': OLIVE,
        'torso_up': OLIVE, 'torso_lo': OLIVE_D, 'belt': LEATHER, 'buckle': METAL_D, 'strap': LEATHER,
        'collar': DARK,
        'arm_up': OLIVE, 'arm_lo': OLIVE_D, 'hand': LEATHER, 'cuff': LEATHER,
        'leg': OLIVE_D, 'boot': LEATHER,
    },
    # Mag (wzór: NPC Wizzard): fioletowy spiczasty kapelusz i szata, siwa broda.
    'mag': {
        'head_style': 'wizard', 'body': 'robe',
        'head': PURPLE, 'hat': PURPLE, 'hair': WHITE, 'beard': WHITE, 'face': SKIN, 'eye': (20, 20, 18),
        'trim': GOLD,
        'torso_up': PURPLE, 'torso_lo': PURPLE, 'belt': LEATHER, 'buckle': GOLD, 'robe': PURPLE,
        'arm_up': PURPLE, 'arm_lo': PURPLE, 'hand': SKIN, 'cuff': GOLD,
        'leg': PURPLE, 'boot': LEATHER,
    },
    # --- NPC miasta (sceny scenes/npc/) ---
    # Kowal: łysy, czarna broda, skórzany fartuch na szarej koszuli, gołe ręce, rękawice.
    'kowal': {
        'head_style': 'bald', 'body': 'plain', 'beard': HAIR_BLACK,
        'head': SKIN, 'face': SKIN, 'eye': (20, 20, 18), 'trim': LEATHER,
        'torso_up': CLOTH, 'torso_lo': CLOTH, 'tabard': LEATHER, 'tabard_half': 2.5, 'belt': DARK, 'buckle': METAL_D,
        'arm_up': SKIN, 'arm_lo': SKIN, 'hand': LEATHER,
        'leg': BROWN, 'boot': DARK,
    },
    # Płatnerz: brązowe włosy, kolczuga z czerwonym wapenrokiem, skórzane spodnie.
    'platnerz': {
        'head_style': 'hair', 'body': 'plain',
        'head': HAIR_BROWN, 'hair': HAIR_BROWN, 'face': SKIN, 'eye': (20, 20, 18), 'trim': GOLD,
        'torso_up': CHAIN, 'torso_lo': RED_D, 'tabard': RED, 'tabard_half': 1.5, 'belt': LEATHER, 'buckle': METAL_D,
        'arm_up': CHAIN, 'arm_lo': CHAIN, 'hand': LEATHER, 'cuff': LEATHER,
        'leg': BROWN, 'boot': LEATHER,
    },
    # Zielarka: rude długie włosy, zielona suknia, lniany fartuch.
    'zielarka': {
        'head_style': 'hair_long', 'body': 'robe',
        'head': HAIR_AUBURN, 'hair': HAIR_AUBURN, 'face': SKIN, 'eye': (20, 20, 18), 'trim': GREEN_D,
        'torso_up': GREEN, 'torso_lo': GREEN, 'robe': GREEN, 'tabard': LINEN, 'tabard_half': 2.0, 'belt': LEATHER,
        'arm_up': GREEN, 'arm_lo': GREEN, 'hand': SKIN,
        'leg': GREEN, 'boot': LEATHER,
    },
    # Karczmarka: jasne długie włosy, czerwona suknia, biały fartuch, podwinięte lniane rękawy.
    'karczmarka': {
        'head_style': 'hair_long', 'body': 'robe',
        'head': HAIR_BLONDE, 'hair': HAIR_BLONDE, 'face': SKIN, 'eye': (20, 20, 18), 'trim': RED_D,
        'torso_up': RED, 'torso_lo': RED, 'robe': RED, 'tabard': WHITE, 'tabard_half': 2.5, 'belt': LEATHER,
        'arm_up': RED, 'arm_lo': LINEN, 'hand': SKIN,
        'leg': RED, 'boot': LEATHER,
    },
    # Mistrz fechtunku: czarne włosy i broda, czerwony kubrak z białym kołnierzem i mankietami, złota klamra.
    'mistrz': {
        'head_style': 'hair', 'body': 'plain', 'beard': HAIR_BLACK,
        'head': HAIR_BLACK, 'hair': HAIR_BLACK, 'face': SKIN, 'eye': (20, 20, 18), 'trim': GOLD,
        'torso_up': RED, 'torso_lo': RED_D, 'collar': WHITE, 'belt': LEATHER, 'buckle': GOLD,
        'arm_up': RED, 'arm_lo': RED, 'hand': LEATHER, 'cuff': WHITE,
        'leg': DARK, 'boot': LEATHER,
    },
    # Mieszkanka: brązowe długie włosy, niebieska suknia z białym kołnierzem.
    'mieszkanka': {
        'head_style': 'hair_long', 'body': 'robe',
        'head': HAIR_BROWN, 'hair': HAIR_BROWN, 'face': SKIN, 'eye': (20, 20, 18), 'trim': BLUE_D,
        'torso_up': BLUE, 'torso_lo': BLUE, 'robe': BLUE, 'collar': WHITE, 'belt': LEATHER,
        'arm_up': BLUE, 'arm_lo': BLUE, 'hand': SKIN,
        'leg': BLUE, 'boot': LEATHER,
    },
    # Mieszkaniec: brązowe włosy, lniana koszula, skórzany pas, brązowe spodnie.
    'mieszkaniec': {
        'head_style': 'hair', 'body': 'plain',
        'head': HAIR_BROWN, 'hair': HAIR_BROWN, 'face': SKIN, 'eye': (20, 20, 18), 'trim': LEATHER,
        'torso_up': LINEN, 'torso_lo': LINEN, 'belt': LEATHER, 'buckle': METAL_D,
        'arm_up': LINEN, 'arm_lo': LINEN, 'hand': SKIN,
        'leg': BROWN, 'boot': LEATHER,
    },
}

LABEL_KEY = {'r_up': 'arm_up', 'l_up': 'arm_up', 'r_arm': 'arm_lo', 'l_arm': 'arm_lo', 'r_hand': 'hand',
             'l_hand': 'hand', 'r_leg': 'leg', 'l_leg': 'leg', 'r_boot': 'boot', 'l_boot': 'boot',
             'r_cuff': 'cuff', 'l_cuff': 'cuff', 'r_knee': 'knee', 'l_knee': 'knee'}
# Kierunki, w których widać przód tułowia (znak na piersi, klamra, stuła).
FRONT = {'S', 'SE', 'SW'}
TORSO = ('torso_up', 'torso_lo', 'belt', 'robe', 'robe_hem')


def load_frames(path):
    im = Image.open(path).convert('RGBA')
    return im, im.width // FRAME, im.height // FRAME


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
                for d in D4:
                    n = (c[0] + d[0], c[1] + d[1])
                    if n in lo and n not in seen:
                        seen.add(n)
                        q.append(n)
            arm = any((c[0] + d[0], c[1] + d[1]) in up for c in comp for d in D4)
            for c in comp:
                lab[c] = side + ('_arm' if arm and c[1] <= hip + HIP_SLACK else '_leg')
        # dłoń: kratki przedramienia najdalej (BFS) od ramienia
        arm_px = {p for p, n in lab.items() if n == side + '_arm'}
        dist = {}
        q = deque()
        for p in arm_px:
            if any((p[0] + d[0], p[1] + d[1]) in up for d in D4):
                dist[p] = 0
                q.append(p)
        while q:
            c = q.popleft()
            for d in D4:
                n = (c[0] + d[0], c[1] + d[1])
                if n in arm_px and n not in dist:
                    dist[n] = dist[c] + 1
                    q.append(n)
        if dist:
            for p in sorted(dist, key=lambda p: -dist[p])[:HAND_PX]:
                if dist[p] >= 2:
                    lab[p] = side + '_hand'
    return lab, hip


def center_cols(x0, x1):
    """Kolumny środka obrysu x0..x1: przy parzystej szerokości 2 (model ma 2-pikselowy środek), przy nieparzystej 1."""
    w = x1 - x0 + 1
    return [x0 + w // 2 - 1, x0 + w // 2] if w % 2 == 0 else [x0 + w // 2]


def _bbox(cells):
    xs = [p[0] for p in cells]
    ys = [p[1] for p in cells]
    return min(xs), min(ys), max(xs), max(ys)


def shape_head(lab, spec, direction):
    style = spec['head_style']
    head = [p for p, n in lab.items() if n == 'head']
    face = [p for p, n in lab.items() if n in ('face', 'eye')]
    if not head:
        return
    x0, y0, x1, y1 = _bbox(head + face)
    eye_rows = {p[1] for p, n in lab.items() if n == 'eye'}
    if style == 'helmet':
        # osłony policzków: skrajne kratki twarzy przy hełmie od wysokości oczu w dół
        if eye_rows:
            for p in face:
                if lab[p] == 'face' and p[1] >= min(eye_rows) and any(lab.get((p[0] + dx, p[1])) == 'head' for dx in (-1, 1)):
                    lab[p] = 'guard'
            for p in list(lab):
                if lab[p] == 'guard':
                    lab[p] = 'head'
        # pas hełmu: linia środkowa głowy od czoła przez czubek do karku, rzutowana wg kierunku
        fx = FACING_X[direction]
        hx0, _, hx1, _ = _bbox(head)
        if fx != 0 and direction in ('E', 'W'):
            # z boku: wzdłuż górnego obrysu głowy
            for x in range(hx0, hx1 + 1):
                ys = [p[1] for p in head if p[0] == x]
                if ys and lab.get((x, min(ys))) == 'head':
                    lab[(x, min(ys))] = 'trim'
        else:
            # od przodu / tyłu: przez środek; ukosy: 1 px w stronę twarzy (S*) albo potylicy (N*)
            shift = 0 if fx == 0 else (fx if direction.startswith('S') else -fx)
            face_top = min((p[1] for p in face), default=y1 + 1)
            for cx in center_cols(hx0, hx1):
                for y in range(y0, face_top if direction.startswith('S') else y1 + 1):
                    if lab.get((cx + shift, y)) == 'head':
                        lab[(cx + shift, y)] = 'trim'
    elif style in ('hood', 'hood_dark'):
        for p in head:
            lab[p] = 'hood'
        # kaptur szerszy o 1 px (boki i góra), nie pod linią twarzy
        face_bottom = max(p[1] for p in face) if face else y1
        for p in list(lab):
            if lab[p] != 'hood':
                continue
            for d in ((1, 0), (-1, 0), (0, -1)):
                n = (p[0] + d[0], p[1] + d[1])
                if n[1] <= face_bottom and lab.get(n) in (None, 'torso_up', 'r_up', 'l_up'):
                    lab[n] = 'hood_edge'
        for p in list(lab):
            if lab[p] == 'hood_edge':
                lab[p] = 'hood'
        if style == 'hood':
            for p in list(lab):
                if lab[p] == 'hood' and any(lab.get((p[0] + d[0], p[1] + d[1])) == 'face' for d in D4):
                    lab[p] = 'trim'
        else:
            for p in face:
                if lab[p] == 'face':
                    lab[p] = 'shadow'
    elif style == 'wizard':
        brim_y = y0 + max(2, (y1 - y0) * 2 // 5)
        for p in head:
            lab[p] = 'hat' if p[1] < brim_y else 'hair'
        for x in range(x0 - 2, x1 + 3):
            if lab.get((x, brim_y)) in (None, 'hair', 'head', 'hat', 'face', 'torso_up') and lab.get((x, brim_y)) != 'eye':
                lab[(x, brim_y)] = 'brim'
        w = x1 - x0 + 1
        tilt = -FACING_X[direction]
        cxf = (x0 + x1) / 2.0
        for k in range(1, 8):
            half = max(0, int((w - 2) / 2 * (1 - k / 8.0)))
            cx = int(round(cxf + tilt * k * 0.45))
            for x in range(cx - half, cx + half + 1):
                lab[(x, y0 - k)] = 'hat'
    elif style in ('hair', 'hair_long'):
        for p in head:
            lab[p] = 'hair'
        if style == 'hair_long':
            # kolumny, w których najniżej jest włos (boki, tył głowy) — włosy opadają 4 rzędy
            for x in range(x0, x1 + 1):
                ys = [p[1] for p in head + face if p[0] == x]
                if not ys or lab.get((x, max(ys))) != 'hair':
                    continue
                for k in range(1, 5):
                    q = (x, max(ys) + k)
                    if lab.get(q) in (None, 'torso_up', 'r_up', 'l_up', 'r_arm', 'l_arm'):
                        lab[q] = 'hair'
                    else:
                        break
    elif style == 'bald':
        for p in head:
            lab[p] = 'face'
    if face and (style == 'wizard' or 'beard' in spec):
        add_beard(lab, face)


def add_beard(lab, face):
    """Broda: dwa dolne rzędy twarzy i trzy rzędy zwężającej się brody na piersi."""
    fx0, fy0, fx1, fy1 = _bbox(face)
    for p in face:
        if lab[p] == 'face' and p[1] >= fy1 - 1:
            lab[p] = 'beard'
    for k in range(1, 4):
        for x in range(fx0 + k - 1, fx1 - k + 2):
            if lab.get((x, fy1 + k)) in ('torso_up', 'torso_lo', None, 'r_up', 'l_up'):
                lab[(x, fy1 + k)] = 'beard'


def shape_body(lab, style, hip):
    # pas: górny rząd dołu tułowia (kratki torso_lo z torso_up nad sobą)
    for p, n in list(lab.items()):
        if n == 'torso_lo' and lab.get((p[0], p[1] - 1)) == 'torso_up':
            lab[p] = 'belt'
    legs = {p: n for p, n in lab.items() if n in ('r_leg', 'l_leg')}
    if style == 'robe' and legs:
        rows = {}
        for p in legs:
            rows.setdefault(p[1], []).append(p[0])
        bottom = max(rows)
        for y, xs in rows.items():
            if y >= bottom:
                continue
            for x in range(min(xs), max(xs) + 1):
                if lab.get((x, y)) in (None, 'r_leg', 'l_leg', 'torso_lo'):
                    lab[(x, y)] = 'robe_hem' if y == bottom - 1 else 'robe'
        for p, n in legs.items():
            if p[1] >= bottom and lab.get(p) in ('r_leg', 'l_leg'):
                lab[p] = n.split('_')[0] + '_boot'
        for p, n in list(lab.items()):
            if n == 'torso_lo':
                lab[p] = 'robe'
        return
    for side in ('r', 'l'):
        cols = {}
        for p, n in legs.items():
            if n == side + '_leg':
                cols.setdefault(p[0], []).append(p[1])
        for x, ys in cols.items():
            bottom = max(ys)
            for y in ys:
                if y > bottom - BOOT_ROWS:
                    lab[(x, y)] = side + '_boot'


# Kawałki postaci: ciemna krawędź tylko na styku różnych kawałków (nie między rękawem a dłonią, pasem a tułowiem itp.).
PIECE = {'head': 'head', 'hood': 'head', 'hat': 'head', 'brim': 'head', 'hair': 'head', 'trim': 'head',
         'face': 'face', 'eye': 'face', 'shadow': 'face', 'beard': 'face',
         'torso_up': 'torso', 'torso_lo': 'torso', 'belt': 'torso', 'robe': 'torso', 'robe_hem': 'torso',
         'tabard': 'torso', 'collar': 'torso', 'emblem': 'torso', 'buckle': 'torso', 'stole': 'torso', 'strap': 'torso'}


def piece(n):
    if n[:2] in ('r_', 'l_'):
        side, part = n.split('_', 1)
        return side + ('_leg' if part in ('leg', 'boot', 'knee') else '_arm')
    return PIECE.get(n, n)


def add_details(lab, spec, direction):
    torso = [p for p, n in lab.items() if n in TORSO]
    up = [p for p, n in lab.items() if n == 'torso_up']
    if not torso or not up:
        return
    tx0, ty0, tx1, ty1 = _bbox(up)
    cxf = (tx0 + tx1 + 1) / 2.0
    mid = center_cols(tx0, tx1)
    wide = tx1 - tx0 + 1 >= 6           # widok od przodu / tyłu (z boku tułów ma 4-5 px)
    front = direction in FRONT
    above_head = ('head', 'face', 'eye', 'hood', 'hair', 'beard', 'shadow', 'trim', 'brim')
    if 'tabard' in spec and wide:
        for p in torso:
            if lab[p] in ('torso_up', 'torso_lo', 'robe') and abs(p[0] + 0.5 - cxf) <= spec['tabard_half']:
                lab[p] = 'tabard'
    if 'collar' in spec:
        for p in up:
            if lab.get(p) in ('torso_up', 'tabard') and lab.get((p[0], p[1] - 1)) in above_head:
                lab[p] = 'collar'
    if 'strap' in spec and wide:
        belt_y = min((p[1] for p, n in lab.items() if n == 'belt'), default=ty1)
        h = max(1, belt_y - ty0)
        for k in range(h + 1):
            t = k / h
            x = round(tx0 + 1 + (tx1 - tx0 - 2) * t) if direction != 'N' else round(tx1 - 1 - (tx1 - tx0 - 2) * t)
            if lab.get((x, ty0 + k)) in ('torso_up', 'torso_lo', 'collar'):
                lab[(x, ty0 + k)] = 'strap'
    if front and 'emblem' in spec and wide:
        ey = ty0 + 3
        cross = [(x, ey + dy) for x in mid for dy in (-1, 0, 1)] + [(mid[0] - 1, ey), (mid[-1] + 1, ey)]
        for q in cross:
            if lab.get(q) in ('tabard', 'torso_up'):
                lab[q] = 'emblem'
    if front and 'stole' in spec:
        for p in list(lab):
            if p[0] in mid and lab[p] in ('torso_up', 'torso_lo', 'robe', 'collar'):
                lab[p] = 'stole'
    if front and 'buckle' in spec:
        for p, n in list(lab.items()):
            if n == 'belt' and p[0] in mid:
                lab[p] = 'buckle'
    for side in ('r', 'l'):
        if 'cuff' in spec:
            for p, n in list(lab.items()):
                if n == side + '_arm' and any(lab.get((p[0] + d[0], p[1] + d[1])) == side + '_hand' for d in D4):
                    lab[p] = side + '_cuff'
        if 'knee' in spec:
            ys = [p[1] for p, n in lab.items() if n in (side + '_leg', side + '_boot')]
            if ys:
                ky = min(ys) + (max(ys) - min(ys)) // 2 - 1
                for p, n in list(lab.items()):
                    if n == side + '_leg' and p[1] == ky:
                        lab[p] = side + '_knee'


def ramp_for(n, spec):
    if n in ('trim', 'robe_hem'):
        return spec['trim']
    if n == 'brim':
        return [spec['hat'][1], spec['hat'][2], spec['hat'][2]]
    if n == 'shadow':
        return [spec['face'][1], spec['face'][2], spec['face'][2]]
    key = LABEL_KEY.get(n, n)
    return spec.get(key) or spec['torso_lo']


def paint(fr, spec, direction):
    lab, hip = segment(fr)
    shape_head(lab, spec, direction)
    shape_body(lab, spec['body'], hip)
    add_details(lab, spec, direction)
    out = Image.new('RGBA', (FRAME, FRAME), (0, 0, 0, 0))
    back = BACK_SIDE[direction]
    for (x, y), n in lab.items():
        if not (0 <= x < FRAME and 0 <= y < FRAME):
            continue
        if n == 'eye':
            out.putpixel((x, y), spec['eye'] + (255,))
            continue
        ramp = ramp_for(n, spec)
        group = piece(n)
        tone = 2 if back and n.startswith(back + '_') else 1
        for d in ((1, 0), (0, 1)):
            nb = lab.get((x + d[0], y + d[1]))
            if nb is not None and piece(nb) != group:
                tone = 2
        out.putpixel((x, y), ramp[tone] + (255,))
    solid = {p for p in lab if 0 <= p[0] < FRAME and 0 <= p[1] < FRAME}
    for (x, y) in solid:
        for d in D4:
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
    print(char_id, '->', dst)
    if preview:
        _preview(char_id, sheets)


def _preview(char_id, sheets):
    """Podgląd: pierwsza klatka Idle i klatki Walk dla 8 kierunków (×4) + GIF chodu."""
    tmp = os.environ.get('LUMEN_PREVIEW_DIR', os.environ.get('TEMP', '.'))
    walk, wcols = sheets['Walk']
    idle, _ = sheets['Idle']
    crop = (16, 4, 48, 56)   # postać w klatce 64×64 (z kapeluszem maga)
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


if __name__ == '__main__':
    ids = list(CHARACTERS) if len(sys.argv) > 1 and sys.argv[1] == 'all' else sys.argv[1:2]
    if not ids or any(i not in CHARACTERS for i in ids):
        print(__doc__)
        print('postacie:', ', '.join(CHARACTERS))
        sys.exit(1)
    for i in ids:
        build(i, '--preview' in sys.argv)
