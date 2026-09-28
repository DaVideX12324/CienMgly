# Prompty do generowania grafik ekranu ładowania (Loading Screens)

Gotowe prompty do grafik tła ekranu ładowania (16:9, Pixel Art) dla wszystkich stref gry z
`docs/game_design.md`. Styl jest spójny z tłami walk (`../battle_backgrounds/pixel_crawler_prompts.md`),
ale kadr jest inny: zamiast płaskiej areny walki — **szeroki, klimatyczny widok całej lokacji**
(„establishing shot”), który zapowiada, dokąd gracz się wybiera.
Dla każdej strefy **3–4 warianty** — ekran losuje jedną grafikę z folderu mapy przy każdym ładowaniu.

---

## 🎨 Uniwersalne wytyczne stylu i kompozycji

1. **Format i rozdzielczość:** Proporcje **16:9** (rekomendowane 1920x1080).
2. **Stylistyka (jak tła walk):** `High quality pixel art, 16-bit / 32-bit JRPG style, clean pixel
   cluster shading, limited atmospheric color palette`.
3. **Kadr:** szeroki widok lokacji z lekko podwyższonej kamery (establishing shot), wyraźna głębia
   i perspektywa atmosferyczna, jeden mocny punkt zainteresowania w środku / górnej połowie kadru.
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
z góry — bierzemy z nich paletę, materiały i props, nie perspektywę. Gdzie mockupu nie ma — „brak”.

**Wspólny dopisek (wklejany na końcu każdego promptu):**
```text
16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

## 🗺️ Prompty dla stref gry

---

### 1. Tutorial Dungeon (tutorial_area)
- **Referencja (mockup autora):** brak — tileset tutoriala (`legacy_amonra/atlases/Dungeon tileset`) nie ma
  mockupu mapy; kierunek stylu: tła walk `../battle_backgrounds/tutorial_area/`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/tutorial_area/`

#### Wariant 1: Brama Lochu Treningowego (Training Dungeon Gate)
*Opis scenerii:* Widok z zewnątrz na masywną bramę z fioletowo-szarej cegły, wpuszczoną w zbocze; po bokach pochodnie, nad łukiem wyblakły herb, za kratą ciepłe światło korytarza.
```text
A 16-bit pixel art JRPG loading screen illustration of the entrance to an old training dungeon, wide establishing shot from a slightly elevated camera. A massive gate of muted purple-grey brick set into a rocky hillside at night, a half-raised iron portcullis revealing a warmly torch-lit stone corridor beyond, two iron wall torches with flickering orange flames, a faded heraldic crest carved above the arch, worn grey flagstone path leading to the gate, moss in the cracks, starry deep-indigo sky. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Sala Treningowa z Góry (Training Hall Overview)
*Opis scenerii:* Duża sala treningowa widziana z balkonu: grube płyty posadzki, rzędy tarcz strzeleckich, drewniane manekiny, stojaki z bronią, pochodnie na fioletowych ścianach.
```text
A 16-bit pixel art JRPG loading screen illustration of a vast underground training hall seen from a high stone balcony, wide establishing shot. Large grey stone floor tiles in perspective, rows of round straw archery targets, wooden training dummies, racks of practice swords and spears, a central stone sparring platform, muted purple-grey brick walls with narrow arched windows, iron wall torches casting warm pools of light, dark vaulted ceiling fading into shadow. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Schody w Głąb Lochu (Stairway Into the Depths)
*Opis scenerii:* Szerokie kamienne schody schodzące w półmrok, z pochodniami co kilka stopni i drzwiami na kolejne poziomy — zapowiedź przygody.
```text
A 16-bit pixel art JRPG loading screen illustration of a wide stone staircase descending deep into a training dungeon, dramatic perspective looking down. Muted purple-grey brick walls on both sides, iron torches every few steps casting warm orange light that fades into blue darkness below, heavy wooden doors with iron studs on side landings, faint glow of a lit chamber far at the bottom, dust motes in the torchlight. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 2. Cave (cave — jaskinie generowane)
- **Referencja (mockup autora):** `assets/pixel_crawler/_versions_archive/cave_v1/Pixel Crawler - Cave/Social/MockUp_01.png`
  (wersja paczki używana przez jaskinie w grze; `environments/cave/Social/MockUp_01.png` to ten sam obraz) —
  wszystkie warianty bazują na nim: fioletowe grzyby-parasole ociekające błękitem, czerwone grzyby-trąbki,
  brązowa ziemia z plamami mchu, skalne ściany z korzeniami i kolcami, kamienne stopnie, kamyki.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/cave/`

#### Wariant 1: Wejście do Jaskini (Cave Mouth)
*Opis scenerii:* Wielki otwór jaskini w zboczu porośniętym korzeniami, stalaktyty jak kły, stare rusztowanie górnicze z latarnią, w głębi słaby błękitny poblask kryształów.
```text
A 16-bit pixel art JRPG loading screen illustration of a huge cave mouth in a rocky hillside, wide establishing shot at dusk. Brown rock walls wrapped in thick tangled tree roots, jagged stalactites framing the entrance like fangs, patches of green moss on packed brown earth, an old wooden mining scaffold with a hanging oil lantern beside the entrance, faint cyan glow of crystals deep inside the darkness, a few glowing purple mushrooms near the rocks. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Labirynt Korytarzy z Góry (Winding Tunnels Overview)
*Opis scenerii:* Rozległa podziemna pieczara widziana z wysokiej półki skalnej: kręte korytarze z brązowej ziemi i mchu między skalnymi ścianami z kolcami, uniesione płaskowyże ze schodami.
```text
A 16-bit pixel art JRPG loading screen illustration of a vast underground cavern seen from a high rock ledge, wide establishing shot. Winding corridors of brown packed earth with patches of green moss snaking between thick rock walls topped with sharp stone spikes and tangled roots, raised rocky plateaus connected by carved stone stairs, pools of darkness between chambers, scattered glowing purple mushrooms and cyan crystals as small light sources, distant cavern walls fading into blue haze. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Grota Nietoperzy (Bat Roost Grotto)
*Opis scenerii:* Wysoka grota z dziurą w sklepieniu, przez którą wpada księżycowe światło; pod sklepieniem ciemne kształty śpiących nietoperzy (sylwetki), na dnie kałuże odbijające światło.
```text
A 16-bit pixel art JRPG loading screen illustration of a tall cave grotto with a hole in the ceiling letting in a column of pale moonlight, wide establishing shot. Dark rock ceiling covered with hanging roots and clusters of tiny dark bat silhouettes asleep in the shadows, brown earth floor with green moss and shallow puddles reflecting the light, stone spikes along the walls, glowing purple mushrooms and faint cyan crystals in the corners. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 3. Miasto (town)
- **Referencja (mockup autora):** brak — hub fabularny: sklep, zapis, NPC, magiczna bariera Strażnika nad miastem
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/town/`

#### Wariant 1: Miasto pod Barierą (Town Under the Barrier)
*Opis scenerii:* Średniowieczne miasteczko widziane ze wzgórza, nad nim ledwo widoczna, mieniąca się kopuła bariery; ciepłe światła okien, wieża zegarowa.
```text
A 16-bit pixel art JRPG loading screen illustration of a cozy medieval town seen from a hilltop at twilight, wide establishing shot. Timber-framed houses with red and blue roofs, a stone clock tower in the center, warm glowing windows, a market square with colorful stall awnings, a winding cobblestone road leading to the town gate, and a faint shimmering translucent magical dome barrier arching over the whole town against a purple evening sky. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Rynek w Dzień (Market Square)
*Opis scenerii:* Gwarny (ale pusty) rynek: stragany, studnia, szyld sklepu, drzewo pośrodku placu.
```text
A 16-bit pixel art JRPG loading screen illustration of a sunny medieval town market square, wide establishing shot. Cobblestone plaza with a stone well and a large leafy tree in the center, wooden market stalls with striped awnings, crates of fruit and barrels, a blacksmith sign and a potion shop sign hanging from iron brackets (no readable text), timber-framed houses with flower boxes, soft white clouds in a blue sky. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Brama Miejska nocą (Town Gate at Night)
*Opis scenerii:* Kamienna brama z latarniami, droga wychodząca w ciemność, a w oddali na horyzoncie sylwetka zamku.
```text
A 16-bit pixel art JRPG loading screen illustration of a stone town gate at night, wide establishing shot. Thick stone walls with wooden battlements, two hanging lanterns glowing warm yellow, the gate open onto a dirt road that winds away into dark fields, and far on the horizon the silhouette of a tall castle with a single ominous violet light at the top of its tower, starry sky. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 4. Sewer (sewer)
- **Mockupy autora:** `assets/pixel_crawler/environments/sewer/Social/MockUp-01.png`, `MockUp-02.png`
- **Wspólne z mockupów:** jaskrawozielony toksyczny szlam, ciemna cegła z zielonymi kaflami przy ścianach, miedziane barierki i rury, łukowe kraty odpływów, żelazne kratki w posadzce, kamienne filary z lampkami, drewniane kładki z desek.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/sewer/`

#### Wariant 1: Skrzyżowanie Kanałów (Canal Crossroads)
*Referencja:* `MockUp-01.png` — skrzyżowanie kanałów w kształcie T, kładki z desek, miedziane barierki, pionowe miedziane rury.
*Opis scenerii:* Trzy kanały szlamu zbiegają się w jednym miejscu, nad nimi drewniane kładki; na brzegach kratki, miedziane barierki i okrągłe wyloty rur w ścianach.
```text
A 16-bit pixel art JRPG loading screen illustration of an underground sewer junction where three canals of glowing lime-green toxic sludge meet in a T-shape, wide establishing shot from a slightly elevated camera. Wooden plank bridges spanning the canals, copper pipe railings along dark brick walkways, round copper pipe outlets and arched copper drain grates in dark brick walls with dark green tiles, tall vertical copper pipes, stone pillars with small wall lamps, iron floor grates, a few crates and sacks by the wall. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Magazyn nad Kanałem (Storage Hall by the Canal)
*Referencja:* `MockUp-02.png` — długa hala z rzędem łukowych krat odpływów, beczki, skrzynie, stół z krzesłami, szeroki kanał z kładką.
*Opis scenerii:* Długa, kamienna hala kanałów z rzędem łukowych krat w ścianie, beczkami i skrzyniami przemytników, a u dołu szeroki kanał szlamu przecięty kładką.
```text
A 16-bit pixel art JRPG loading screen illustration of a long sewer storage hall, wide establishing shot. A row of large arched copper drain grates in a dark brick wall with dark green tiles, stone pillars with small lamps, big iron floor grates, stacks of wooden crates and barrels, a rough wooden table with chairs, a wooden ladder to an upper hatch, and along the front a wide channel of glowing lime-green sludge crossed by a narrow wooden plank bridge behind a copper railing. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Wyjście ku Cmentarzowi (Grate to the Cemetery)
*Referencja:* `MockUp-01.png` — ceglane ściany, miedziane rury i kraty jako rama kadru.
*Opis scenerii:* Koniec tunelu kanałów: przez zardzewiałą kratę widać mglisty, nocny cmentarz.
```text
A 16-bit pixel art JRPG loading screen illustration of the end of a sewer tunnel with a large arched copper grate opening onto a misty night graveyard, wide establishing shot. Dark wet brick walls with dark green tiles and copper pipes framing the view, a thin stream of lime-green sludge running toward the grate, pale moonlight falling through the bars, silhouettes of crooked gravestones and a dead tree outside in blue fog. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 5. Cemetery (cemetery)
- **Referencja (mockup autora):** brak — paczka Cemetery nie ma mockupu mapy (tylko propsy)
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/cemetery/`

#### Wariant 1: Wzgórze Nagrobków (Graveyard Hill)
```text
A 16-bit pixel art JRPG loading screen illustration of an old graveyard on a hill under a full moon, wide establishing shot. Rows of crooked stone gravestones and celtic crosses, a spiked black iron fence, twisted leafless trees, low blue-grey fog drifting between the graves, a gothic mausoleum at the top of the hill with a faint green glow in its doorway. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Aleja Mauzoleów (Mausoleum Avenue)
```text
A 16-bit pixel art JRPG loading screen illustration of a long cemetery avenue lined with stone mausoleums and weeping angel statues, wide establishing shot with deep perspective. Cracked flagstone path, iron lanterns with flickering pale flames, ivy climbing the tombs, dead leaves, heavy mist and a cold teal moonlit palette. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Chata Strażnika Cmentarza (Gravekeeper's Lodge)
```text
A 16-bit pixel art JRPG loading screen illustration of a small stone gravekeeper's lodge at the edge of a cemetery at night, wide establishing shot. A single warm lit window, a shovel and lantern by the door, a small fenced garden of graves, a large old key hanging on a hook by the door, a dark forest behind, moon and drifting fog. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 6. Fairy Forest (fairy_forest)
- **Mockupy autora:** `assets/pixel_crawler/environments/fairy_forest/Pixel Crawler - Fairy Forest 1.7/Social/MockUp_01.png` … `MockUp_04.png`
- **Wspólne z mockupów:** gęste zielone i fioletowe korony drzew, pomarańczowe krzewy, świecące turkusowe kamienie runiczne w błękitnej poświacie, świecące fioletowe dzwonki, błękitny potok, skarpy z odsłoniętą ziemią.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/fairy_forest/`

#### Wariant 1: Rozstaje Trzech Bram (Crossroads of Three Gates)
*Referencja:* `MockUp_01.png` — polany ze świecącymi kamieniami runicznymi w błękitnej mgiełce, wielkie dęby, fioletowe drzewa, pień.
*Opis scenerii:* Hub-skrzyżowanie: polana z kamieniami runicznymi i trzema starymi łukami prowadzącymi w różne strony (piasek, żar, śnieg w prześwitach) oraz ledwie widoczną czwartą ścieżką.
```text
A 16-bit pixel art JRPG loading screen illustration of an enchanted forest crossroads glade, wide establishing shot. Glowing teal runestones standing in pools of soft blue mist, huge green oaks and trees with purple foliage, orange shrubs and an old tree stump; three ancient moss-covered stone archways around the clearing, each glimpsing a different land: golden desert dunes, glowing red volcanic light, and snowy pines; a barely visible fourth overgrown path hidden among ferns, fireflies. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Magiczny Potok (Enchanted Stream)
*Referencja:* `MockUp_02.png` — błękitny potok przecinający las po skosie, polany z ziemią, świecące kamienie runiczne.
*Opis scenerii:* Błękitny potok wijący się przez las, na brzegach skarpy i polanki, przy wodzie świecące kamienie.
```text
A 16-bit pixel art JRPG loading screen illustration of a bright blue stream winding diagonally through a magical forest, wide establishing shot. Grassy banks with small earthen cliffs and bare dirt clearings, trees with green and purple foliage, orange shrubs, tree stumps, glowing teal runestones in blue mist near the water, tiny white flowers, soft dusk light. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Fioletowe Drzewo i Dzwonki (Violet Tree & Bellflowers)
*Referencja:* `MockUp_03.png` — wielkie drzewo o fioletowych liściach, świecące fioletowe dzwonki, potok, pnącza z pomarańczowymi kwiatami, skarpy.
*Opis scenerii:* Pradawne drzewo o fioletowej koronie nad potokiem, wokół świecące dzwonki i skręcone pnącza.
```text
A 16-bit pixel art JRPG loading screen illustration of a colossal ancient tree with a violet canopy standing above a forest stream, wide establishing shot. Clusters of glowing purple bellflowers, twisting green vines with orange trumpet flowers, rocky earthen ledges, a bright blue stream curving past the roots, drifting glowing pollen, deep green and violet palette. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 4: Zacieniony Gąszcz (Sunbeam Thicket)
*Referencja:* `MockUp_04.png` — ciemny, gęsty las, skośne smugi światła, wysokie pnące łodygi, czerwone grzyby, szare kamienie, fioletowe dzwonki.
*Opis scenerii:* Mroczny gąszcz, do którego wpadają skośne smugi słońca; mała polanka z grzybami i świecącymi kwiatami.
```text
A 16-bit pixel art JRPG loading screen illustration of a dark dense fairy forest thicket pierced by diagonal sunbeams, wide establishing shot. A small mossy clearing surrounded by thick shadowy canopies, tall curling vine stalks with orange buds, little red-capped mushrooms, grey stones, glowing purple bellflowers, floating light motes in the beams. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 7. Desert → Desert Temple (desert, desert_temple)
- **Mockupy autora:** `assets/pixel_crawler/environments/desert/Social/MockUp-01.png`, `MockUp-02.png`, `MockUp-03.png`;
  świątynia: `assets/textures/legacy_amonra/atlases/ArenaFinalAssets/Desert_Dungeon_Pack/Desert_Dungeon_Preview.png`
- **Wspólne z mockupów:** pomarańczowy piasek z ciemniejszymi plamami, grzbiety i ostańce z czerwonej skały, gigantyczne kły/kości, kaktusy, suche krzaki, otwory jaskiń w skałach; świątynia z piaskowca z filarami i schodami.
- **Foldery docelowe:** `modules/quiz_rpg/assets/textures/loading_screens/desert/` (otwarta mapa),
  `modules/quiz_rpg/assets/textures/loading_screens/desert_temple/` (świątynia)

#### Wariant 1 (desert): Morze Wydm i Ostańców (Dunes & Red Mesas)
*Referencja:* `MockUp-01.png` — piasek, grzbiety czerwonej skały, otwory jaskiń, kły, kaktusy, suche drzewka.
*Opis scenerii:* Bezkresna pustynia o zachodzie, grzbiety czerwonych skał z otworami jaskiń, na horyzoncie sylwetka świątyni.
```text
A 16-bit pixel art JRPG loading screen illustration of a vast orange desert at sunset, wide establishing shot. Sand with darker patches, winding ridges and pillars of red rock with dark cave openings, giant pale curved tusks half-buried in the sand, green cacti, dry thorny bushes and dead trees, and on the far horizon the silhouette of a great sandstone temple, orange and magenta sky with heat haze. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2 (desert): Kanion Kłów (Canyon of Tusks)
*Referencja:* `MockUp-02.png` — koliste zagłębienie otoczone skałą, ogromne kły, kaktusy, samotne kolumny z piaskowca.
*Opis scenerii:* Kotlina w czerwonym kanionie z ogromnymi kłami wystającymi z piasku i resztkami kolumn dawnej drogi do świątyni.
```text
A 16-bit pixel art JRPG loading screen illustration of a red rock canyon basin in the desert, wide establishing shot. A ring of low red rock ridges around a sandy hollow, enormous pale curved tusks and bones jutting from the sand, green cacti and dry red shrubs, a few lonely broken sandstone columns marking an ancient road, harsh afternoon sun with long shadows. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3 (desert_temple): Ruiny u Wrót Świątyni (Temple Ruins)
*Referencja:* `MockUp-03.png` — ruiny z piaskowca, filary, szerokie schody, wyłom w murze, obelisk, dzbany i posągi.
*Opis scenerii:* Wejście do świątyni: szerokie schody, filary, wyłom w murze prowadzący w ciemność, obelisk i posągi strażników.
```text
A 16-bit pixel art JRPG loading screen illustration of sandstone temple ruins at the edge of the desert, wide establishing shot. Wide stone stairs leading up between carved sandstone pillars, a broken wall with a dark breach into the temple, a tall obelisk, guardian statues, clay pots and a small chest among rubble, red rock ridges with giant tusks in the foreground sand, harsh midday light. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 4 (desert_temple): Komnaty Grobowca (Tomb Chambers)
*Referencja:* `Desert_Dungeon_Preview.png` — komnaty z piaskowca, pochodnie, dzbany, ciemna studnia, schody, skrzynia skarbu.
*Opis scenerii:* Wnętrze świątyni: ciąg komnat z piaskowca, ciemna studnia pośrodku, pochodnie na ścianach, skrzynia ze skarbem.
```text
A 16-bit pixel art JRPG loading screen illustration of sandstone tomb chambers deep inside a desert temple, wide establishing shot. Connected rooms of pale sandstone bricks and floor tiles, a dark square pit in the middle of the main chamber, wall torches with warm flames, clay pots and urns, short stairs between levels, a golden treasure chest glowing on a dais, thin beams of dusty light. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 8. Volcano → Forge (volcano, forge)
- **Mockupy autora:** `assets/pixel_crawler/environments/forge/Social/MockUp-00.png`, `MockUp-01.png`, `MockUp-02.png`
- **Wspólne z mockupów:** ciemnofioletowo-szara posadzka, ściany z czerwonej cegły z pomarańczowo żarzącymi się szczelinami i łukowymi wrotami w jodełkę, kanały i baseny lawy, metalowe kraty-mosty nad lawą, kamienne posągi krasnoludów, piece i kowadła na postumentach.
- **Foldery docelowe:** `modules/quiz_rpg/assets/textures/loading_screens/volcano/`,
  `modules/quiz_rpg/assets/textures/loading_screens/forge/`

#### Wariant 1 (volcano): Kraty nad Lawą (Grated Lava Walkways)
*Referencja:* `MockUp-01.png` — jezioro lawy z posągami krasnoludów, metalowe kraty-mosty nad kanałem lawy, piece na postumentach.
*Opis scenerii:* Rozżarzona hala nad jeziorem lawy: posągi krasnoludów stoją w lawie, przez kanał prowadzą metalowe kraty.
```text
A 16-bit pixel art JRPG loading screen illustration of a volcanic hall above a glowing lake of molten lava, wide establishing shot. Stone dwarf statues standing in the lava, a lava channel crossed by heavy metal grate walkways, dark purple-grey stone floor with small forge furnaces on square pedestals, red brick walls with glowing orange slit vents and chevron-patterned arched gates, rising embers and heat shimmer. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2 (forge): Sala Wielkiego Pieca (Great Furnace Hall)
*Referencja:* `MockUp-00.png` — symetryczna sala, łukowe wrota z żarzącą się jodełką, dwa baseny lawy, kratowany pomost, czerwone filary.
*Opis scenerii:* Symetryczna hala kuźni: pośrodku kratowany pomost prowadzący do wielkich łukowych wrót, po bokach baseny lawy.
```text
A 16-bit pixel art JRPG loading screen illustration of a grand symmetrical forge hall, wide establishing shot. A central metal grate walkway leading to a huge arched gate glowing with orange chevron patterns, two rectangular basins of bright molten lava on both sides, red brick pillars and walls with glowing orange rune slits, stone buttresses with glowing lines, dark purple-grey stone floor with scattered rubble. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3 (forge): Wrota Zbrojowni (Armory Gates)
*Referencja:* `MockUp-02.png` — łukowe wrota, kraty z pomarańczowymi pierścieniami, posągi krasnoludów, skrzynie, kałuże ciemnej wody, kraty-mosty nad lawą.
*Opis scenerii:* Korytarze zbrojowni z zakratowanymi wrotami, posągami i skrzyniami; u dołu kanał lawy pod kratami.
```text
A 16-bit pixel art JRPG loading screen illustration of an ancient dwarven armory with massive barred gates, wide establishing shot. Red brick walls with gothic arched doors glowing orange, iron portcullis gates decorated with glowing orange rings, stone dwarf statues, treasure chests and weapon racks, dark puddles of cooled water on the purple-grey stone floor, and along the bottom a lava channel under heavy metal grates. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 9. Dense Forest → biom zimowy (forest, winter)
- **Referencja (mockup autora):** las: `assets/pixel_crawler/environments/world_build/MockUps/Trees.png`; biom zimowy: brak
- **Foldery docelowe:** `modules/quiz_rpg/assets/textures/loading_screens/forest/`,
  `modules/quiz_rpg/assets/textures/loading_screens/winter/`

#### Wariant 1 (forest): Gęstwina (The Dense Woods)
```text
A 16-bit pixel art JRPG loading screen illustration of a dark, dense ancient forest, wide establishing shot. Towering tree trunks close together, tangled undergrowth and ferns, a faint narrow path disappearing between trees, crooked signposts pointing in different directions (no readable text), thin shafts of light breaking through the canopy, deep greens with cold blue shadows. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2 (forest): Skraj Lasu i Pierwszy Śnieg (Forest Edge, First Snow)
```text
A 16-bit pixel art JRPG loading screen illustration of the edge of a dense forest where autumn turns to winter, wide establishing shot. The left side lush green and orange trees, the right side pine trees dusted with fresh snow, a path leading toward snowy mountains, light snowfall beginning, cold grey-blue sky. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3 (winter): Zamarznięta Polana (Frozen Clearing)
```text
A 16-bit pixel art JRPG loading screen illustration of a frozen snowy clearing surrounded by tall snow-covered pines, wide establishing shot. A frozen lake with cracked ice, an ancient stone shrine half-buried in snow holding a faintly glowing artifact fragment, icicles on rocks, aurora lights in a dark blue night sky. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 10. Library (library)
- **Referencja (mockup autora):** `assets/pixel_crawler/environments/library/Social/MockUp_01.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/library/`

#### Wariant 1: Wielka Nawa Biblioteki (Grand Library Nave)
```text
A 16-bit pixel art JRPG loading screen illustration of an immense ancient library hall, wide establishing shot. Towering bookshelves several stories high, wooden ladders and walkways, reading tables with candles, a huge round stained glass window casting colored light, floating dust motes, warm amber and deep brown palette. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Spiralne Archiwum (Spiral Archive)
```text
A 16-bit pixel art JRPG loading screen illustration looking up into a spiral archive tower of books, dramatic perspective. Curving bookshelves spiraling upward around a central void, floating open books and loose pages, magical glowing orbs as lamps, a glass dome at the top with night sky and stars. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Dział Zakazany (Restricted Section)
```text
A 16-bit pixel art JRPG loading screen illustration of a sealed restricted section of an old library, wide establishing shot. Chained bookshelves, a heavy locked iron gate with glowing blue runes, an old scroll resting on a lectern under a single beam of light, scattered notes pinned to a board, cold blue and purple arcane lighting. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 11. Garden (garden)
- **Referencja (mockup autora):** `assets/pixel_crawler/environments/garden/Social/MockUp_01.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/garden/`

#### Wariant 1: Labirynt Żywopłotów (Hedge Maze)
```text
A 16-bit pixel art JRPG loading screen illustration of a vast royal hedge maze seen from above at a high angle, wide establishing shot. Tall neatly trimmed green hedge walls forming winding paths, white marble statues and fountains at intersections, rose bushes, gravel paths, a palace wall in the distance, soft afternoon sunlight. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Wielka Fontanna (Grand Fountain Courtyard)
```text
A 16-bit pixel art JRPG loading screen illustration of a grand tiered marble fountain in a royal garden courtyard, wide establishing shot. Sparkling water, stone balustrades, flowering arches and pergolas, trimmed topiary, flower beds in red and violet, elite guard posts (empty) with banners, castle towers rising behind the garden walls. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Zatopiona Świątynia Ogrodowa (Sunken Sanctuary)
```text
A 16-bit pixel art JRPG loading screen illustration of a sunken garden sanctuary, wide establishing shot. A small domed marble temple on an island in a reflecting pool, water lilies, weeping willows, overgrown ivy on ruined columns, golden evening light reflecting on the water. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 12. Castle (castle — finał)
- **Mockupy autora:** `assets/pixel_crawler/environments/castle/Social/MockUp_01.png`, `MockUp_02.png`
- **Wspólne z mockupów:** ciemnoszary kamień, posadzka w granatową szachownicę, czerwone dywany ze złotym obszyciem, fioletowe proporce, kamienne popiersia na cokołach, rośliny w donicach, świeczniki, bursztynowe witraże.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/castle/`

#### Wariant 1: Zamek Arcymaga (The Archmage's Castle)
*Referencja:* brak mockupu z zewnątrz — paleta i detale z `MockUp_01.png` (kamień, fioletowe proporce, bursztynowe okna).
*Opis scenerii:* Mroczny zamek na klifie nocą, nad najwyższą wieżą wirujący krąg magii urządzenia.
```text
A 16-bit pixel art JRPG loading screen illustration of a towering dark grey stone castle on a cliff, wide establishing shot at night. Gothic spires and battlements, purple banners with gold trim, warm amber stained glass windows, a long stone bridge leading to the main gate, a swirling violet magical glow and a giant rotating arcane circle above the highest tower, storm clouds lit by purple lightning. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Sala Tronowa (Throne Hall)
*Referencja:* `MockUp_01.png` — tron pod bursztynowym witrażem, popiersia, fioletowe proporce, czerwony dywan, drzewka w donicach, komnata z kominkiem, tarcze herbowe.
*Opis scenerii:* Sala tronowa: czerwony dywan prowadzi do tronu pod bursztynowym witrażem, po bokach popiersia i proporce.
```text
A 16-bit pixel art JRPG loading screen illustration of a gothic castle throne hall, wide establishing shot with deep perspective. A long red carpet with gold trim across a dark blue checkerboard floor, purple banners with gold trim on grey stone pillars, potted topiary trees in clay pots, marble busts on pedestals flanking an empty ornate throne beneath a glowing amber stained glass window, a side chamber with a roaring fireplace, red and yellow heraldic shields on the walls. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Galeria Popiersi (Hall of Busts)
*Referencja:* `MockUp_02.png` — dywan w kształcie litery U, popiersia na cokołach, kamienne słupki, świece, fioletowe proporce, ławy.
*Opis scenerii:* Galeria bohaterów: czerwony dywan okrąża podwójny rząd popiersi, przy ścianach świece i proporce.
```text
A 16-bit pixel art JRPG loading screen illustration of a castle gallery of heroes, wide establishing shot. A red carpet with gold trim forming a U around two rows of marble portrait busts on stone pedestals, small carved stone posts between them, dark blue checkerboard floor, grey stone walls with purple banners and wall candles casting warm light, red cushioned benches, potted cypress trees. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 4: Komnata Urządzenia (The Device Chamber)
*Referencja:* brak mockupu — paleta z `MockUp_01.png` / `MockUp_02.png`.
*Opis scenerii:* Okrągła komnata na szczycie wieży z wielką magiczną maszyną — cel całej gry.
```text
A 16-bit pixel art JRPG loading screen illustration of a circular arcane chamber at the top of a castle tower, wide establishing shot. A huge magical machine of brass rings and floating crystals in the center, glowing violet runic circles on a dark blue checkerboard floor, purple banners, beams of violet energy rising through an open dome into a stormy sky, scattered scrolls and instruments. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
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
