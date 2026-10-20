# Prompty do generowania grafik ekranu ładowania (Loading Screens)

Gotowe prompty do grafik tła ekranu ładowania (16:9, Pixel Art) dla wszystkich stref gry z
`docs/game_design.md`. Styl jest spójny z tłami walk (`../battle_backgrounds/pixel_crawler_prompts.md`),
ale zamiast areny walki — **klimatyczny widok lokacji z perspektywy 1. osoby, z poziomu ziemi**,
który zapowiada, dokąd gracz się wybiera.
Dla każdej strefy **3–4 warianty** — ekran losuje jedną grafikę z folderu mapy przy każdym ładowaniu.

---

## 🎨 Uniwersalne wytyczne stylu i kompozycji

1. **Format i rozdzielczość:** Proporcje **16:9** (rekomendowane 1920x1080).
2. **Stylistyka (jak tła walk):** `High quality pixel art, 16-bit / 32-bit JRPG style, clean pixel
   cluster shading, limited atmospheric color palette`.
3. **Perspektywa — 1. osoba, z poziomu ziemi (najważniejsze!):** kamera na wysokości oczu albo niżej,
   patrzy przed siebie lub lekko w górę — jak tła walk. Ziemia w dolnej części kadru, horyzont i punkt
   zbiegu w górnej połowie, ściany i obiekty stoją pionowo. **Nigdy** widok z góry, z lotu ptaka,
   izometria ani „mapa z gry” — Gemini chętnie to robi, zwłaszcza z mockupem jako referencją, dlatego
   każdy prompt zaczyna się od perspektywy i kończy dopiskiem z zakazami. Jeden mocny punkt
   zainteresowania w środku / górnej połowie kadru.
4. **Dolna krawędź:** ma być spokojna i ciemna (cień, ziemia, woda, mgła, jednolity pas), bez ważnych
   detali. Ekran bierze jej średni kolor i dorysowuje z niego pas pod nazwą lokacji i paskiem ładowania
   (~20% wysokości ekranu, z miękkim przejściem w obraz) — im równiejszy kolor dołu, tym gładsze łączenie.
5. **Brzegi:** grafika wypełnia ekran z zachowaniem proporcji, więc na ekranach innych niż 16:9 brzegi
   są przycinane — nic ważnego przy samych krawędziach.
6. **Czystość sceny:** bez postaci, potworów, tekstu, logo i elementów UI
   (`No characters, no monsters, no text, no logo, no UI`).

**Referencje:** przy każdej strefie są mockupy map zrobione przez autora paczki (`Social/MockUp*`) —
dołącz je do promptu jako obraz referencyjny. Gdy strefa ma kilka mockupów, każdy wariant bazuje na
innym (linia *Referencja* przy wariancie, a prompt opisuje to, co na nim widać). Mockupy to widok mapy
z góry — bierzemy z nich paletę, materiały i props, **nie perspektywę** (dopisek promptu mówi to
modelowi wprost). Gdy mimo to wychodzi widok z góry: wygeneruj bez referencji albo dopisz na początku
„Eye-level first-person view, like standing inside the scene”. Gdzie mockupu nie ma — „brak”.

**Wspólny dopisek (wklejany na końcu każdego promptu):**
```text
First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

## 🗺️ Prompty dla stref gry

---

### 1. Tutorial Dungeon (tutorial_area)
- **Referencja:** tileset tutoriala (`legacy_amonra/atlases/Dungeon tileset`) nie ma mockupu autora — zamiast
  niego zrzuty prawdziwej mapy: `../battle_backgrounds/tutorial_area_reference/*.png` (opis materiałów:
  `../battle_backgrounds/tutorial_area_prompts.md`)
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/tutorial_area/`

#### Wariant 1: Ruiny w Głębi Jaskini (Ruins Deep in the Cave)
*Opis scenerii:* Tutorial to ruiny **wewnątrz jaskiń**, bez wejścia z zewnątrz (uwaga usera 2026-10-21; stary prompt z bramą
w zboczu pod gwiaździstym niebem — do wyrzucenia). Widok z dna jaskini na fasadę ruin wbudowaną w skalną ścianę: złote
drzwi, czerwone chorągwie, paleniska w niszach; nad ruinami strop ze stalaktytami, bez nieba.
*Referencja:* `MockUp_tutorial_area_gate_hall.png` — złote drzwi między czerwonymi chorągwiami (ruiny) +
`MockUp_cave_01.png` (`assets/_nieuzywane/pixel_crawler/environments/cave/Social/`) — skała, dno i korzenie jaskini
wokół ruin (obie tylko kolory i materiały).
```text
A 16-bit pixel art JRPG loading screen, seen from eye level while standing on the floor of a dark natural cave, looking at ancient ruins built into the cave wall. In the background, the facade of an old ruined dungeon set into rough brown-grey cave rock: walls of dark plum-purple bricks with cracks and missing bricks, topped by a pale lilac stone cornice, pale lilac corner pillars, a pair of golden wooden plank doors with iron fittings in the middle, flanked by two red banners with a gold crest, an iron wall holder with a lit candle, fire braziers glowing in stone niches. Above the ruins the cave ceiling with hanging stalactites fades into darkness, roots and moss creep over the brickwork. In the lower half, a path of cool grey-blue slate slabs with thin lilac cracks leads across the damp rocky cave floor to the doors. Warm candle and brazier light against cold teal-black cave shadows, no sky, no daylight. 16:9 widescreen, crisp pixels, dark outlines, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference images only for the color palette, materials and props: MockUp_tutorial_area_gate_hall.png for the ruins (bricks, cornice, doors, banners, braziers) and MockUp_cave_01.png for the surrounding cave (rock, cave floor, roots and moss).
```

#### Wariant 2: Sala Palenisk pod Skałą (Brazier Hall Beneath the Rock)
*Opis scenerii:* Długa sala ruin widziana od wejścia, z poziomu posadzki: paleniska w niszach ściany, przejścia zamknięte
świecącymi złotymi kratami, beczki pod ścianami; część stropu zawalona — w wyrwie naga skała jaskini z korzeniami.
(Dawniej „Sala Treningowa” z tarczami i manekinami — ich nie ma na mapie.)
*Referencja:* `MockUp_tutorial_area_braziers.png` — paleniska w niszach, beczki, złote kraty; `MockUp_tutorial_area_overview.png` — układ sal.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a long hall of ancient ruins buried deep inside a cave, standing at its entrance and looking toward the far wall. Floor of cool grey-blue slate slabs with thin lilac cracks in perspective, walls of dark plum-purple bricks with cracks and missing bricks topped by a pale lilac stone cornice, pale lilac corner pillars, fire braziers burning inside stone niches along both walls, small arched windows with iron bars opening onto pitch-black cave darkness, narrow side passages closed by glowing golden bars, small groups of red-brown wooden barrels near the walls, a red banner with a gold crest on the far wall. Part of the vaulted ceiling has collapsed: through the gap the raw brown-grey cave rock with hanging stalactites and tangled roots is visible, rubble and fallen bricks lie on the floor below it. Warm brazier light against cold teal-black shadows, no sky, no daylight. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference images MockUp_tutorial_area_braziers.png and MockUp_tutorial_area_overview.png as the source of the color palette, materials and props.
```

#### Wariant 3: Schody ku Złotym Drzwiom (Stairs to the Golden Doors)
*Opis scenerii:* Widok z dołu szerokich szarych kamiennych schodów ruin, wciśniętych między ściany z cegły i skałę
jaskini; na górze złote drzwi między chorągwiami, ciepła poświata świecy — zapowiedź przygody, bez nieba.
*Referencja:* `MockUp_tutorial_area_stairs.png` — szare kamienne schody, ściany z gzymsem; `MockUp_tutorial_area_gate_hall.png` — złote drzwi, chorągwie.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a wide flight of grey stone stairs inside ancient ruins buried in a cave, standing at the bottom step and looking up the stairs. Walls of dark plum-purple bricks with cracks and missing bricks topped by a pale lilac stone cornice on both sides, in places broken open to reveal the raw brown-grey cave rock behind them with roots and moss, pale lilac pillars at the landings, fire braziers glowing in stone niches every few steps casting warm orange light that fades into teal-black darkness above. At the top of the stairs a pair of golden wooden plank doors with iron fittings, flanked by a red banner with a gold crest and a navy banner with a gold star, a lit candle in an iron wall holder beside them. Above everything the dark cave ceiling with stalactites, dust motes in the firelight, no sky, no daylight. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference images MockUp_tutorial_area_stairs.png and MockUp_tutorial_area_gate_hall.png as the source of the color palette, materials and props.
```

---

### 2. Cave (cave — jaskinie generowane)
- **Referencja (mockup autora):** `assets/_nieuzywane/pixel_crawler/environments/cave/Social/MockUp_cave_01.png`
  (paczka jaskini używana w grze; dawniej `assets/pixel_crawler/…`, przeniesione do `_nieuzywane` 2026-10-15) —
  wszystkie warianty bazują na nim: fioletowe grzyby-parasole ociekające błękitem, czerwone grzyby-trąbki,
  brązowa ziemia z plamami mchu, skalne ściany z korzeniami i kolcami, kamienne stopnie, kamyki.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/cave/`

#### Wariant 1: Wejście do Jaskini (Cave Mouth)
*Opis scenerii:* Wielki otwór jaskini w zboczu porośniętym korzeniami, stalaktyty jak kły, stare rusztowanie górnicze z latarnią, w głębi słaby błękitny poblask kryształów.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a huge cave mouth in a rocky hillside, dusk. Brown rock walls wrapped in thick tangled tree roots, jagged stalactites framing the entrance like fangs, patches of green moss on packed brown earth, an old wooden mining scaffold with a hanging oil lantern beside the entrance, faint cyan glow of crystals deep inside the darkness, a few glowing purple mushrooms near the rocks. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_cave_01.png as the source of the color palette, materials and props.
```

#### Wariant 2: Kręte Korytarze (Winding Tunnels)
*Opis scenerii:* Widok z wnętrza pieczary, z poziomu ziemi: kręte korytarze z brązowej ziemi i mchu między skalnymi ścianami z kolcami, uniesione płaskowyże ze schodami.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a vast underground cavern, standing on the cave floor and looking straight along a winding corridor. A path of brown packed earth with patches of green moss winding between thick rock walls topped with sharp stone spikes and tangled roots, raised rocky plateaus with carved stone stairs leading up on the side, pools of darkness between chambers, scattered glowing purple mushrooms and cyan crystals as small light sources, distant cavern walls fading into blue haze. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_cave_01.png as the source of the color palette, materials and props.
```

#### Wariant 3: Grota Nietoperzy (Bat Roost Grotto)
*Opis scenerii:* Wysoka grota z dziurą w sklepieniu, przez którą wpada księżycowe światło; pod sklepieniem ciemne kształty śpiących nietoperzy (sylwetki), na dnie kałuże odbijające światło.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a tall cave grotto with a hole in the ceiling letting in a column of pale moonlight. Dark rock ceiling covered with hanging roots and clusters of tiny dark bat silhouettes asleep in the shadows, brown earth floor with green moss and shallow puddles reflecting the light, stone spikes along the walls, glowing purple mushrooms and faint cyan crystals in the corners. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_cave_01.png as the source of the color palette, materials and props.
```

---

### 3. Miasto (town)
- **Referencja (mockup autora):** brak — hub fabularny: sklep, zapis, NPC, magiczna bariera Strażnika nad miastem
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/town/`

#### Wariant 1: Miasto pod Barierą (Town Under the Barrier)
*Opis scenerii:* Średniowieczne miasteczko widziane z drogi prowadzącej do bramy, nad nim ledwo widoczna, mieniąca się kopuła bariery; ciepłe światła okien, wieża zegarowa.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a cozy medieval town at twilight, standing on the cobblestone road just before the town gate. Timber-framed houses with red and blue roofs, a stone clock tower in the center, warm glowing windows, a market square with colorful stall awnings, the cobblestone road leading ahead through the open town gate, and a faint shimmering translucent magical dome barrier arching over the whole town against a purple evening sky. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Rynek w Dzień (Market Square)
*Opis scenerii:* Gwarny (ale pusty) rynek: stragany, studnia, szyld sklepu, drzewo pośrodku placu.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a sunny medieval town market square. Cobblestone plaza with a stone well and a large leafy tree in the center, wooden market stalls with striped awnings, crates of fruit and barrels, a blacksmith sign and a potion shop sign hanging from iron brackets (no readable text), timber-framed houses with flower boxes, soft white clouds in a blue sky. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Brama Miejska nocą (Town Gate at Night)
*Opis scenerii:* Kamienna brama z latarniami, droga wychodząca w ciemność, a w oddali na horyzoncie sylwetka zamku.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a stone town gate at night. Thick stone walls with wooden battlements, two hanging lanterns glowing warm yellow, the gate open onto a dirt road that winds away into dark fields, and far on the horizon the silhouette of a tall castle with a single ominous violet light at the top of its tower, starry sky. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 4. Sewer (sewer)
- **Mockupy autora:** `assets/pixel_crawler/environments/sewer_old/Social/MockUp_sewer_old_01.png`, `MockUp_sewer_old_02.png`
- **Wspólne z mockupów:** jaskrawozielony toksyczny szlam, ciemna cegła z zielonymi kaflami przy ścianach, miedziane barierki i rury, łukowe kraty odpływów, żelazne kratki w posadzce, kamienne filary z lampkami, drewniane kładki z desek.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/sewer/`

#### Wariant 1: Skrzyżowanie Kanałów (Canal Crossroads)
*Referencja:* `MockUp_sewer_old_01.png` — skrzyżowanie kanałów w kształcie T, kładki z desek, miedziane barierki, pionowe miedziane rury.
*Opis scenerii:* Trzy kanały szlamu zbiegają się w jednym miejscu, nad nimi drewniane kładki; na brzegach kratki, miedziane barierki i okrągłe wyloty rur w ścianach.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of an underground sewer junction where three canals of glowing lime-green toxic sludge meet in a T-shape, standing on the brick walkway at the edge of the canal and looking across the junction. Wooden plank bridges spanning the canals, copper pipe railings along dark brick walkways, round copper pipe outlets and arched copper drain grates in dark brick walls with dark green tiles, tall vertical copper pipes, stone pillars with small wall lamps, iron floor grates, a few crates and sacks by the wall. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_sewer_old_01.png as the source of the color palette, materials and props.
```

#### Wariant 2: Magazyn nad Kanałem (Storage Hall by the Canal)
*Referencja:* `MockUp_sewer_old_02.png` — długa hala z rzędem łukowych krat odpływów, beczki, skrzynie, stół z krzesłami, szeroki kanał z kładką.
*Opis scenerii:* Długa, kamienna hala kanałów z rzędem łukowych krat w ścianie, beczkami i skrzyniami przemytników, a u dołu szeroki kanał szlamu przecięty kładką.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a long sewer storage hall. A row of large arched copper drain grates in a dark brick wall with dark green tiles, stone pillars with small lamps, big iron floor grates, stacks of wooden crates and barrels, a rough wooden table with chairs, a wooden ladder to an upper hatch, and along the front a wide channel of glowing lime-green sludge crossed by a narrow wooden plank bridge behind a copper railing. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_sewer_old_02.png as the source of the color palette, materials and props.
```

#### Wariant 3: Wyjście ku Cmentarzowi (Grate to the Cemetery)
*Referencja:* `MockUp_sewer_old_01.png` — ceglane ściany, miedziane rury i kraty jako rama kadru.
*Opis scenerii:* Koniec tunelu kanałów: przez zardzewiałą kratę widać mglisty, nocny cmentarz.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of the end of a sewer tunnel with a large arched copper grate opening onto a misty night graveyard. Dark wet brick walls with dark green tiles and copper pipes framing the view, a thin stream of lime-green sludge running toward the grate, pale moonlight falling through the bars, silhouettes of crooked gravestones and a dead tree outside in blue fog. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_sewer_old_01.png as the source of the color palette, materials and props.
```

---

### 5. Cemetery (cemetery)
- **Referencja (mockup autora):** brak — paczka Cemetery nie ma mockupu mapy (tylko propsy)
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/cemetery/`

#### Wariant 1: Wzgórze Nagrobków (Graveyard Hill)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of an old graveyard on a hill under a full moon. Rows of crooked stone gravestones and celtic crosses, a spiked black iron fence, twisted leafless trees, low blue-grey fog drifting between the graves, a gothic mausoleum at the top of the hill with a faint green glow in its doorway. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Aleja Mauzoleów (Mausoleum Avenue)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a long cemetery avenue lined with stone mausoleums and weeping angel statues, deep one-point perspective into the distance. Cracked flagstone path, iron lanterns with flickering pale flames, ivy climbing the tombs, dead leaves, heavy mist and a cold teal moonlit palette. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Chata Strażnika Cmentarza (Gravekeeper's Lodge)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a small stone gravekeeper's lodge at the edge of a cemetery at night. A single warm lit window, a shovel and lantern by the door, a small fenced garden of graves, a large old key hanging on a hook by the door, a dark forest behind, moon and drifting fog. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 6. Fairy Forest (fairy_forest)
- **Mockupy autora:** `assets/pixel_crawler/environments/fairy_forest/Pixel Crawler - Fairy Forest 1.7/Social/MockUp_fairy_forest_01.png` … `MockUp_fairy_forest_04.png`
- **Wspólne z mockupów:** gęste zielone i fioletowe korony drzew, pomarańczowe krzewy, świecące turkusowe kamienie runiczne w błękitnej poświacie, świecące fioletowe dzwonki, błękitny potok, skarpy z odsłoniętą ziemią.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/fairy_forest/`

#### Wariant 1: Rozstaje Trzech Bram (Crossroads of Three Gates)
*Referencja:* `MockUp_fairy_forest_01.png` — polany ze świecącymi kamieniami runicznymi w błękitnej mgiełce, wielkie dęby, fioletowe drzewa, pień.
*Opis scenerii:* Hub-skrzyżowanie: polana z kamieniami runicznymi i trzema starymi łukami prowadzącymi w różne strony (piasek, żar, śnieg w prześwitach) oraz ledwie widoczną czwartą ścieżką.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of an enchanted forest crossroads glade. Glowing teal runestones standing in pools of soft blue mist, huge green oaks and trees with purple foliage, orange shrubs and an old tree stump; three ancient moss-covered stone archways around the clearing, each glimpsing a different land: golden desert dunes, glowing red volcanic light, and snowy pines; a barely visible fourth overgrown path hidden among ferns, fireflies. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_fairy_forest_01.png as the source of the color palette, materials and props.
```

#### Wariant 2: Magiczny Potok (Enchanted Stream)
*Referencja:* `MockUp_fairy_forest_02.png` — błękitny potok przecinający las po skosie, polany z ziemią, świecące kamienie runiczne.
*Opis scenerii:* Błękitny potok wijący się przez las, na brzegach skarpy i polanki, przy wodzie świecące kamienie.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a bright blue stream winding diagonally through a magical forest. Grassy banks with small earthen cliffs and bare dirt clearings, trees with green and purple foliage, orange shrubs, tree stumps, glowing teal runestones in blue mist near the water, tiny white flowers, soft dusk light. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_fairy_forest_02.png as the source of the color palette, materials and props.
```

#### Wariant 3: Fioletowe Drzewo i Dzwonki (Violet Tree & Bellflowers)
*Referencja:* `MockUp_fairy_forest_03.png` — wielkie drzewo o fioletowych liściach, świecące fioletowe dzwonki, potok, pnącza z pomarańczowymi kwiatami, skarpy.
*Opis scenerii:* Pradawne drzewo o fioletowej koronie nad potokiem, wokół świecące dzwonki i skręcone pnącza.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a colossal ancient tree with a violet canopy standing above a forest stream. Clusters of glowing purple bellflowers, twisting green vines with orange trumpet flowers, rocky earthen ledges, a bright blue stream curving past the roots, drifting glowing pollen, deep green and violet palette. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_fairy_forest_03.png as the source of the color palette, materials and props.
```

#### Wariant 4: Zacieniony Gąszcz (Sunbeam Thicket)
*Referencja:* `MockUp_fairy_forest_04.png` — ciemny, gęsty las, skośne smugi światła, wysokie pnące łodygi, czerwone grzyby, szare kamienie, fioletowe dzwonki.
*Opis scenerii:* Mroczny gąszcz, do którego wpadają skośne smugi słońca; mała polanka z grzybami i świecącymi kwiatami.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a dark dense fairy forest thicket pierced by diagonal sunbeams. A small mossy clearing surrounded by thick shadowy canopies, tall curling vine stalks with orange buds, little red-capped mushrooms, grey stones, glowing purple bellflowers, floating light motes in the beams. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_fairy_forest_04.png as the source of the color palette, materials and props.
```

---

### 7. Desert → Desert Temple (desert, desert_temple)
- **Mockupy autora:** `assets/pixel_crawler/environments/desert/Social/MockUp_desert_01.png`, `MockUp_desert_02.png`, `MockUp_desert_03.png`;
  świątynia: `assets/textures/legacy_amonra/atlases/ArenaFinalAssets/Desert_Dungeon_Pack/Desert_Dungeon_Preview.png`
- **Wspólne z mockupów:** pomarańczowy piasek z ciemniejszymi plamami, grzbiety i ostańce z czerwonej skały, gigantyczne kły/kości, kaktusy, suche krzaki, otwory jaskiń w skałach; świątynia z piaskowca z filarami i schodami.
- **Foldery docelowe:** `modules/quiz_rpg/assets/textures/loading_screens/desert/` (otwarta mapa),
  `modules/quiz_rpg/assets/textures/loading_screens/desert_temple/` (świątynia)

#### Wariant 1 (desert): Morze Wydm i Ostańców (Dunes & Red Mesas)
*Referencja:* `MockUp_desert_01.png` — piasek, grzbiety czerwonej skały, otwory jaskiń, kły, kaktusy, suche drzewka.
*Opis scenerii:* Bezkresna pustynia o zachodzie, grzbiety czerwonych skał z otworami jaskiń, na horyzoncie sylwetka świątyni.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a vast orange desert at sunset. Sand with darker patches, winding ridges and pillars of red rock with dark cave openings, giant pale curved tusks half-buried in the sand, green cacti, dry thorny bushes and dead trees, and on the far horizon the silhouette of a great sandstone temple, orange and magenta sky with heat haze. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_desert_01.png as the source of the color palette, materials and props.
```

#### Wariant 2 (desert): Kanion Kłów (Canyon of Tusks)
*Referencja:* `MockUp_desert_02.png` — koliste zagłębienie otoczone skałą, ogromne kły, kaktusy, samotne kolumny z piaskowca.
*Opis scenerii:* Kotlina w czerwonym kanionie z ogromnymi kłami wystającymi z piasku i resztkami kolumn dawnej drogi do świątyni.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a red rock canyon basin in the desert. A ring of low red rock ridges around a sandy hollow, enormous pale curved tusks and bones jutting from the sand, green cacti and dry red shrubs, a few lonely broken sandstone columns marking an ancient road, harsh afternoon sun with long shadows. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_desert_02.png as the source of the color palette, materials and props.
```

#### Wariant 3 (desert_temple): Ruiny u Wrót Świątyni (Temple Ruins)
*Referencja:* `MockUp_desert_03.png` — ruiny z piaskowca, filary, szerokie schody, wyłom w murze, obelisk, dzbany i posągi.
*Opis scenerii:* Wejście do świątyni: szerokie schody, filary, wyłom w murze prowadzący w ciemność, obelisk i posągi strażników.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of sandstone temple ruins at the edge of the desert. Wide stone stairs leading up between carved sandstone pillars, a broken wall with a dark breach into the temple, a tall obelisk, guardian statues, clay pots and a small chest among rubble, red rock ridges with giant tusks in the foreground sand, harsh midday light. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_desert_03.png as the source of the color palette, materials and props.
```

#### Wariant 4 (desert_temple): Komnaty Grobowca (Tomb Chambers)
*Referencja:* `Desert_Dungeon_Preview.png` — komnaty z piaskowca, pochodnie, dzbany, ciemna studnia, schody, skrzynia skarbu.
*Opis scenerii:* Wnętrze świątyni: ciąg komnat z piaskowca, ciemna studnia pośrodku, pochodnie na ścianach, skrzynia ze skarbem.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of sandstone tomb chambers deep inside a desert temple. Connected rooms of pale sandstone bricks and floor tiles, a dark square pit in the middle of the main chamber, wall torches with warm flames, clay pots and urns, short stairs between levels, a golden treasure chest glowing on a dais, thin beams of dusty light. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 8. Volcano → Forge (volcano, forge)
- **Mockupy autora:** `assets/pixel_crawler/environments/forge/Social/MockUp_forge_00.png`, `MockUp_forge_01.png`, `MockUp_forge_02.png`
- **Wspólne z mockupów:** ciemnofioletowo-szara posadzka, ściany z czerwonej cegły z pomarańczowo żarzącymi się szczelinami i łukowymi wrotami w jodełkę, kanały i baseny lawy, metalowe kraty-mosty nad lawą, kamienne posągi krasnoludów, piece i kowadła na postumentach.
- **Foldery docelowe:** `modules/quiz_rpg/assets/textures/loading_screens/volcano/`,
  `modules/quiz_rpg/assets/textures/loading_screens/forge/`

#### Wariant 1 (volcano): Kraty nad Lawą (Grated Lava Walkways)
*Referencja:* `MockUp_forge_01.png` — jezioro lawy z posągami krasnoludów, metalowe kraty-mosty nad kanałem lawy, piece na postumentach.
*Opis scenerii:* Rozżarzona hala nad jeziorem lawy: posągi krasnoludów stoją w lawie, przez kanał prowadzą metalowe kraty.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a volcanic hall above a glowing lake of molten lava. Stone dwarf statues standing in the lava, a lava channel crossed by heavy metal grate walkways, dark purple-grey stone floor with small forge furnaces on square pedestals, red brick walls with glowing orange slit vents and chevron-patterned arched gates, rising embers and heat shimmer. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_forge_01.png as the source of the color palette, materials and props.
```

#### Wariant 2 (forge): Sala Wielkiego Pieca (Great Furnace Hall)
*Referencja:* `MockUp_forge_00.png` — symetryczna sala, łukowe wrota z żarzącą się jodełką, dwa baseny lawy, kratowany pomost, czerwone filary.
*Opis scenerii:* Symetryczna hala kuźni: pośrodku kratowany pomost prowadzący do wielkich łukowych wrót, po bokach baseny lawy.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a grand symmetrical forge hall. A central metal grate walkway leading to a huge arched gate glowing with orange chevron patterns, two rectangular basins of bright molten lava on both sides, red brick pillars and walls with glowing orange rune slits, stone buttresses with glowing lines, dark purple-grey stone floor with scattered rubble. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_forge_00.png as the source of the color palette, materials and props.
```

#### Wariant 3 (forge): Wrota Zbrojowni (Armory Gates)
*Referencja:* `MockUp_forge_02.png` — łukowe wrota, kraty z pomarańczowymi pierścieniami, posągi krasnoludów, skrzynie, kałuże ciemnej wody, kraty-mosty nad lawą.
*Opis scenerii:* Korytarze zbrojowni z zakratowanymi wrotami, posągami i skrzyniami; u dołu kanał lawy pod kratami.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of an ancient dwarven armory with massive barred gates. Red brick walls with gothic arched doors glowing orange, iron portcullis gates decorated with glowing orange rings, stone dwarf statues, treasure chests and weapon racks, dark puddles of cooled water on the purple-grey stone floor, and along the bottom a lava channel under heavy metal grates. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_forge_02.png as the source of the color palette, materials and props.
```

---

### 9. Dense Forest → biom zimowy (forest, winter)
- **Referencja (mockup autora):** las: `assets/pixel_crawler/environments/world_build/MockUps/Trees.png`; biom zimowy: brak
- **Foldery docelowe:** `modules/quiz_rpg/assets/textures/loading_screens/forest/`,
  `modules/quiz_rpg/assets/textures/loading_screens/winter/`

#### Wariant 1 (forest): Gęstwina (The Dense Woods)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a dark, dense ancient forest. Towering tree trunks close together, tangled undergrowth and ferns, a faint narrow path disappearing between trees, crooked signposts pointing in different directions (no readable text), thin shafts of light breaking through the canopy, deep greens with cold blue shadows. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2 (forest): Skraj Lasu i Pierwszy Śnieg (Forest Edge, First Snow)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of the edge of a dense forest where autumn turns to winter. The left side lush green and orange trees, the right side pine trees dusted with fresh snow, a path leading toward snowy mountains, light snowfall beginning, cold grey-blue sky. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3 (winter): Zamarznięta Polana (Frozen Clearing)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a frozen snowy clearing surrounded by tall snow-covered pines. A frozen lake with cracked ice, an ancient stone shrine half-buried in snow holding a faintly glowing artifact fragment, icicles on rocks, aurora lights in a dark blue night sky. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 10. Library (library)
- **Referencja (mockup autora):** `assets/pixel_crawler/environments/library/Social/MockUp_library_01.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/library/`

#### Wariant 1: Wielka Nawa Biblioteki (Grand Library Nave)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of an immense ancient library hall. Towering bookshelves several stories high, wooden ladders and walkways, reading tables with candles, a huge round stained glass window casting colored light, floating dust motes, warm amber and deep brown palette. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_library_01.png as the source of the color palette, materials and props.
```

#### Wariant 2: Spiralne Archiwum (Spiral Archive)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, looking up into a spiral archive tower of books. Curving bookshelves spiraling upward around a central void, floating open books and loose pages, magical glowing orbs as lamps, a glass dome at the top with night sky and stars. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_library_01.png as the source of the color palette, materials and props.
```

#### Wariant 3: Dział Zakazany (Restricted Section)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a sealed restricted section of an old library. Chained bookshelves, a heavy locked iron gate with glowing blue runes, an old scroll resting on a lectern under a single beam of light, scattered notes pinned to a board, cold blue and purple arcane lighting. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_library_01.png as the source of the color palette, materials and props.
```

---

### 11. Garden (garden)
- **Referencja (mockup autora):** `assets/pixel_crawler/environments/garden/Social/MockUp_garden_01.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/garden/`

#### Wariant 1: Labirynt Żywopłotów (Hedge Maze)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a royal hedge maze, standing at its entrance between tall hedge walls. Tall neatly trimmed green hedge walls rising on both sides of a gravel path that turns out of sight, white marble statues and fountains at intersections, rose bushes, gravel paths, a palace wall in the distance, soft afternoon sunlight. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_garden_01.png as the source of the color palette, materials and props.
```

#### Wariant 2: Wielka Fontanna (Grand Fountain Courtyard)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a grand tiered marble fountain in a royal garden courtyard. Sparkling water, stone balustrades, flowering arches and pergolas, trimmed topiary, flower beds in red and violet, elite guard posts (empty) with banners, castle towers rising behind the garden walls. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_garden_01.png as the source of the color palette, materials and props.
```

#### Wariant 3: Zatopiona Świątynia Ogrodowa (Sunken Sanctuary)
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a sunken garden sanctuary. A small domed marble temple on an island in a reflecting pool, water lilies, weeping willows, overgrown ivy on ruined columns, golden evening light reflecting on the water. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_garden_01.png as the source of the color palette, materials and props.
```

---

### 12. Castle (castle — finał)
- **Mockupy autora:** `assets/pixel_crawler/environments/castle/Social/MockUp_castle_01.png`, `MockUp_castle_02.png`
- **Wspólne z mockupów:** ciemnoszary kamień, posadzka w granatową szachownicę, czerwone dywany ze złotym obszyciem, fioletowe proporce, kamienne popiersia na cokołach, rośliny w donicach, świeczniki, bursztynowe witraże.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/castle/`

#### Wariant 1: Zamek Arcymaga (The Archmage's Castle)
*Referencja:* brak mockupu z zewnątrz — paleta i detale z `MockUp_castle_01.png` (kamień, fioletowe proporce, bursztynowe okna).
*Opis scenerii:* Mroczny zamek na klifie nocą, nad najwyższą wieżą wirujący krąg magii urządzenia.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a towering dark grey stone castle on a cliff, night. Gothic spires and battlements, purple banners with gold trim, warm amber stained glass windows, a long stone bridge leading to the main gate, a swirling violet magical glow and a giant rotating arcane circle above the highest tower, storm clouds lit by purple lightning. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_castle_01.png as the source of the color palette, materials and props.
```

#### Wariant 2: Sala Tronowa (Throne Hall)
*Referencja:* `MockUp_castle_01.png` — tron pod bursztynowym witrażem, popiersia, fioletowe proporce, czerwony dywan, drzewka w donicach, komnata z kominkiem, tarcze herbowe.
*Opis scenerii:* Sala tronowa: czerwony dywan prowadzi do tronu pod bursztynowym witrażem, po bokach popiersia i proporce.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a gothic castle throne hall, deep one-point perspective into the distance. A long red carpet with gold trim across a dark blue checkerboard floor, purple banners with gold trim on grey stone pillars, potted topiary trees in clay pots, marble busts on pedestals flanking an empty ornate throne beneath a glowing amber stained glass window, a side chamber with a roaring fireplace, red and yellow heraldic shields on the walls. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_castle_01.png as the source of the color palette, materials and props.
```

#### Wariant 3: Galeria Popiersi (Hall of Busts)
*Referencja:* `MockUp_castle_02.png` — dywan w kształcie litery U, popiersia na cokołach, kamienne słupki, świece, fioletowe proporce, ławy.
*Opis scenerii:* Galeria bohaterów: czerwony dywan okrąża podwójny rząd popiersi, przy ścianach świece i proporce.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a castle gallery of heroes. A red carpet with gold trim forming a U around two rows of marble portrait busts on stone pedestals, small carved stone posts between them, dark blue checkerboard floor, grey stone walls with purple banners and wall candles casting warm light, red cushioned benches, potted cypress trees. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference image MockUp_castle_02.png as the source of the color palette, materials and props.
```

#### Wariant 4: Komnata Urządzenia (The Device Chamber)
*Referencja:* brak mockupu — paleta z `MockUp_castle_01.png` / `MockUp_castle_02.png`.
*Opis scenerii:* Okrągła komnata na szczycie wieży z wielką magiczną maszyną — cel całej gry.
```text
A 16-bit pixel art JRPG loading screen illustration, first-person view from the ground at eye level, of a circular arcane chamber at the top of a castle tower. A huge magical machine of brass rings and floating crystals in the center, glowing violet runic circles on a dark blue checkerboard floor, purple banners, beams of violet energy rising through an open dome into a stormy sky, scattered scrolls and instruments. First-person ground-level perspective: camera at human eye height or lower, looking straight ahead or slightly upward, ground in the lower part of the frame, horizon and vanishing point in the upper half, walls and objects rising vertically. NOT top-down, NOT bird's-eye view, NOT isometric, NOT an overhead game map, NOT a tilemap. If a reference image is attached, it is a top-down game map: use it only for color palette, materials and props, never for the camera angle. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI. Use the reference images MockUp_castle_01.png and MockUp_castle_02.png as the source of the color palette, materials and props.
```

---

## 🛠️ Jak dodawać grafiki do gry?

1. Wygeneruj obraz 16:9 (np. 1920x1080, PNG / JPG / WebP) wybranym promptem.
2. Zapisz go w folderze mapy: `modules/quiz_rpg/assets/textures/loading_screens/<folder_mapy>/`
   (dowolna nazwa pliku, np. `variant_1.jpg`). Brakujący folder po prostu utwórz.
3. Ekran ładowania (`scripts/ui/loading_screen.gd`) sam skanuje folder i losuje jedną grafikę przy
   każdym ładowaniu — bez zmian w kodzie. Pusty folder = ciemne tło.

**Który folder dla której mapy:**
- **mapa generowana** (`procedural_level`): pole `loading_screen_key` w inspektorze; puste = biom z typu
  poziomu (`CAVE_DUNGEON` → `cave`, `DUNGEON_CASTLE` → `castle`, `FOREST_OVERWORLD` → `forest`);
- **mapa ręczna** (np. `tutorial_area.tscn`): nazwa pliku sceny bez rozszerzenia — gdy ekran ładowania
  zostanie podpięty pod wczytywanie map ręcznych w `level_manager`.
