# Prompty do teł walki — Tutorial Area („Starożytne Ruiny”)

Tła walki dla mapy `tutorial_area` (na ekranie ładowania: „Starożytne Ruiny”). Zasady kadru, perspektywy
i warianty wielopoziomowe są te same co w `pixel_crawler_prompts.md` (obszar walki 1920×830 → generuj
w **21:9**, płaska pusta posadzka w dolnych ~40%, bez widoku z góry). Tu: 3 warianty jednopoziomowe
i 2 wielopoziomowe.

- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/tutorial_area/` (tło losuje
  się z folderu przy każdej walce; pole walki: `scenes/tools/battle_layout_preview.tscn`).
- **Referencje:** tileset nie ma mockupu autora, więc w
  `modules/quiz_rpg/assets/textures/battle_backgrounds/tutorial_area_reference/` są zrzuty prawdziwej mapy
  z gry (bez wrogów): `tutorial_area_gate_hall.png`, `tutorial_area_braziers.png`,
  `tutorial_area_stairs.png`, `tutorial_area_barrels_gate.png`, `tutorial_area_overview.png`. Dołącz ten
  z linii *Referencja* wariantu — to widok z góry, więc tylko paleta, materiały i propsy.
- **Tileset:** `assets/textures/legacy_amonra/atlases/Dungeon tileset/Dungeon tileset.png` + obiekty
  `free-2d-top-down-pixel-dungeon-asset-pack/PNG/Objects.png`.

## Z mapy i tilesetu

Ściany z **ciemnej śliwkowo-fioletowej cegły** (pęknięcia, gdzieniegdzie wykruszone cegły) zwieńczone
**jasnoliliowym kamiennym gzymsem**, liliowe narożne słupy; posadzka z **chłodnych szaroniebieskich płyt
łupkowych** z cienkimi liliowymi pęknięciami; za ścianami ciemna, prawie czarna turkusowa pustka.
Propsy: **złote dwuskrzydłowe drzwi z desek** z żelaznymi okuciami, **czerwone chorągwie ze złotym
herbem** i granatowe ze złotą gwiazdą, małe łukowe okienka z żelazną kratą, **paleniska w niszach ściany**
(ogień w kamiennej wnęce), świeca w żelaznym uchwycie na ścianie, **świecące złote kraty** zamykające wąskie
przejścia, rzeźbione liliowe filary, szare kamienne schody, czerwonobrązowe beczki (stojące w grupach),
drewniane i metalowe wiadra, skrzynie okute na niebiesko, kupki złotych monet, drewniane skrzynki,
granatowe i brązowe dzbany, niebieskie tarcze, kolce w posadzce, czaszka z kośćmi.

**Uwaga do obecnych grafik** (`variant_1_gate` … `variant_4_chamber`): materiały zgodne, ale horyzont
wysoko — posadzka zajmuje ponad połowę kadru, a górna część (z drzwiami / bramą) częściowo ucina się
w grze; brak złotych drzwi z chorągwiami, palenisk w niszach i świecących krat z mapy.

## Wspólne dopiski (wklejone na końcu każdego promptu poniżej)

**Jednopoziomowe:**
```text
Battle arena composition: ultra-wide panoramic frame, a broad flat open floor fills the lower 40% of the image with its middle completely empty so monsters can stand there, the floor seen in gentle perspective up to a back wall at about mid-height, tall scenery only in the background and along the left and right edges, calm top and bottom edges without important details. First-person ground-level perspective: camera at human eye height, looking straight ahead, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down screenshot of the game map: use it only for colour palette, materials and props, never for the camera angle or layout. 16-bit pixel art matching the reference: crisp pixels, dark outlines, clean pixel cluster shading, muted cool palette, no characters, no monsters, no text, no logo, no UI.
```

**Wielopoziomowe:**
```text
Multi-level battle arena composition: ultra-wide panoramic frame with two or three flat standing levels stepping up into the distance — the front floor along the bottom of the image, a raised level behind it whose flat top surface is at about the middle of the image height, and optionally a third, narrower and higher level behind that; every level has an even, clearly readable top surface with a straight front edge, is wide enough for two or three monsters, is reached by stairs at the side, and has nothing tall standing on it; tall scenery only behind the highest level and along the left and right edges; calm top and bottom edges without important details. First-person ground-level perspective: camera at human eye height, looking straight ahead, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down screenshot of the game map: use it only for colour palette, materials and props, never for the camera angle or layout. 16-bit pixel art matching the reference: crisp pixels, dark outlines, clean pixel cluster shading, muted cool palette, no characters, no monsters, no text, no logo, no UI.
```

---

## Warianty

#### Wariant 1: Sala Złotych Drzwi (Golden Door Hall)
*Referencja:* `tutorial_area_gate_hall.png` — złote drzwi między czerwonymi chorągwiami, świeca na ścianie.
```text
A 16-bit pixel art JRPG battle background inside an ancient ruined dungeon hall. Flat floor of cool grey-blue slate slabs with thin lilac cracks. In the middle of the back wall a pair of golden wooden plank doors with iron fittings, flanked by two red banners with a gold crest; walls of dark plum-purple bricks with cracks and a few missing bricks, topped by a pale lilac stone cornice, pale lilac corner pillars, an iron wall holder with a lit candle, small arched windows with iron bars, dark teal-black shadows above the walls. Battle arena composition: ultra-wide panoramic frame, a broad flat open floor fills the lower 40% of the image with its middle completely empty so monsters can stand there, the floor seen in gentle perspective up to a back wall at about mid-height, tall scenery only in the background and along the left and right edges, calm top and bottom edges without important details. First-person ground-level perspective: camera at human eye height, looking straight ahead, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down screenshot of the game map: use it only for colour palette, materials and props, never for the camera angle or layout. 16-bit pixel art matching the reference: crisp pixels, dark outlines, clean pixel cluster shading, muted cool palette, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Sala Palenisk (Brazier Hall)
*Referencja:* `tutorial_area_braziers.png` — paleniska w niszach, okienka z kratą, beczki, złote kraty w przejściach.
```text
A 16-bit pixel art JRPG battle background of a long hall in an ancient ruined dungeon. Flat floor of cool grey-blue slate slabs with thin lilac cracks. In the back wall of dark plum-purple bricks with a pale lilac stone cornice: two fire braziers burning inside stone niches in the wall, small arched windows with iron bars, cracks in the brickwork. On the left and right narrow passages closed by glowing golden bars between pale lilac pillars, small groups of red-brown wooden barrels standing near the walls, dark teal-black darkness above. Battle arena composition: ultra-wide panoramic frame, a broad flat open floor fills the lower 40% of the image with its middle completely empty so monsters can stand there, the floor seen in gentle perspective up to a back wall at about mid-height, tall scenery only in the background and along the left and right edges, calm top and bottom edges without important details. First-person ground-level perspective: camera at human eye height, looking straight ahead, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down screenshot of the game map: use it only for colour palette, materials and props, never for the camera angle or layout. 16-bit pixel art matching the reference: crisp pixels, dark outlines, clean pixel cluster shading, muted cool palette, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Zrujnowany Skarbiec (Ruined Treasury)
*Referencja:* `tutorial_area_barrels_gate.png` (paleta) + tileset / obiekty — skrzynie, monety, dzbany, tarcze, kolce.
```text
A 16-bit pixel art JRPG battle background of a ruined treasure chamber in an ancient dungeon. Flat floor of cool grey-blue slate slabs with thin lilac cracks, a skull and scattered bones at one side. In the background carved pale lilac stone pillars against walls of dark plum-purple bricks with a pale lilac cornice, a navy banner with a gold star and a red banner with a gold crest, wooden chests with blue iron bands, small piles of gold coins, dark blue and brown clay pots, blue kite shields leaning on the wall, wooden crates, a row of iron floor spikes along the base of the back wall, a fire brazier glowing in a wall niche. Battle arena composition: ultra-wide panoramic frame, a broad flat open floor fills the lower 40% of the image with its middle completely empty so monsters can stand there, the floor seen in gentle perspective up to a back wall at about mid-height, tall scenery only in the background and along the left and right edges, calm top and bottom edges without important details. First-person ground-level perspective: camera at human eye height, looking straight ahead, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down screenshot of the game map: use it only for colour palette, materials and props, never for the camera angle or layout. 16-bit pixel art matching the reference: crisp pixels, dark outlines, clean pixel cluster shading, muted cool palette, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 4 (wielopoziomowy): Schody na Górny Korytarz (Stairs to the Upper Corridor)
*Referencja:* `tutorial_area_stairs.png` — szare kamienne schody na końcu korytarza, ściany z gzymsem.
```text
A 16-bit pixel art JRPG battle background of an ancient dungeon hall with stairs to an upper corridor. Front level: flat floor of cool grey-blue slate slabs with thin lilac cracks. Behind it a wide raised stone landing of the same slate slabs, its front a low wall of dark plum-purple bricks with a pale lilac cornice, reached by a broad flight of grey stone stairs at the right side. Highest and furthest: a narrow upper corridor along the back wall, reached by a second short flight of grey stone stairs at the left, with small arched windows with iron bars and a fire brazier in a wall niche above it. Pale lilac corner pillars, red-brown barrels only at the far ends of the landing, dark teal-black darkness above. Multi-level battle arena composition: ultra-wide panoramic frame with two or three flat standing levels stepping up into the distance — the front floor along the bottom of the image, a raised level behind it whose flat top surface is at about the middle of the image height, and optionally a third, narrower and higher level behind that; every level has an even, clearly readable top surface with a straight front edge, is wide enough for two or three monsters, is reached by stairs at the side, and has nothing tall standing on it; tall scenery only behind the highest level and along the left and right edges; calm top and bottom edges without important details. First-person ground-level perspective: camera at human eye height, looking straight ahead, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down screenshot of the game map: use it only for colour palette, materials and props, never for the camera angle or layout. 16-bit pixel art matching the reference: crisp pixels, dark outlines, clean pixel cluster shading, muted cool palette, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 5 (wielopoziomowy): Podwyższenie przed Złotymi Drzwiami (Dais Before the Golden Doors)
*Referencja:* `tutorial_area_gate_hall.png` — złote drzwi, czerwone chorągwie; `tutorial_area_overview.png` — układ sal.
```text
A 16-bit pixel art JRPG battle background of an ancient dungeon throne-like hall with a raised dais. Front level: flat floor of cool grey-blue slate slabs with thin lilac cracks. Behind it a wide raised dais of slate slabs with a front face of dark plum-purple bricks and a pale lilac stone edge, reached by grey stone steps at both ends, with carved pale lilac pillars only at its far left and right corners. At the back of the dais a pair of golden wooden plank doors with iron fittings set in the dark plum brick wall, flanked by red banners with a gold crest and navy banners with a gold star, two fire braziers burning in wall niches, cracks and missing bricks in the wall, dark teal-black shadows above. Multi-level battle arena composition: ultra-wide panoramic frame with two or three flat standing levels stepping up into the distance — the front floor along the bottom of the image, a raised level behind it whose flat top surface is at about the middle of the image height, and optionally a third, narrower and higher level behind that; every level has an even, clearly readable top surface with a straight front edge, is wide enough for two or three monsters, is reached by stairs at the side, and has nothing tall standing on it; tall scenery only behind the highest level and along the left and right edges; calm top and bottom edges without important details. First-person ground-level perspective: camera at human eye height, looking straight ahead, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down screenshot of the game map: use it only for colour palette, materials and props, never for the camera angle or layout. 16-bit pixel art matching the reference: crisp pixels, dark outlines, clean pixel cluster shading, muted cool palette, no characters, no monsters, no text, no logo, no UI.
```

---

## Jak dodać

1. Wygeneruj (21:9) z referencją z linii *Referencja*.
2. Zapisz w `battle_backgrounds/tutorial_area/` (nazwa dowolna).
3. Edytor: import, potem w `battle_layout_preview.tscn` pole (pola) walki — `<grafika>_layout.tres` obok
   grafiki; przy wielopoziomowych osobne pole na każdy poziom (Ctrl+D).
