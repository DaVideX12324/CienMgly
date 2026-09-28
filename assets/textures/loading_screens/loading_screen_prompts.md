# Prompty do generowania grafik ekranu ładowania (Loading Screens)

Gotowe prompty do grafik tła ekranu ładowania (16:9, Pixel Art) dla wszystkich stref gry z
`docs/game_design.md`. Styl jest spójny z tłami walk (`../battle_backgrounds/pixel_crawler_prompts.md`),
ale kadr jest inny: zamiast płaskiej areny walki — **szeroki, klimatyczny widok całej lokacji**
(„establishing shot”), który zapowiada, dokąd gracz się wybiera.
Dla każdej strefy **3 warianty** — ekran losuje jedną grafikę z folderu mapy przy każdym ładowaniu.

---

## 🎨 Uniwersalne wytyczne stylu i kompozycji

1. **Format i rozdzielczość:** Proporcje **16:9** (rekomendowane 1920x1080).
2. **Stylistyka (jak tła walk):** `High quality pixel art, 16-bit / 32-bit JRPG style, clean pixel
   cluster shading, limited atmospheric color palette`.
3. **Kadr:** szeroki widok lokacji z lekko podwyższonej kamery (establishing shot), wyraźna głębia
   i perspektywa atmosferyczna, jeden mocny punkt zainteresowania w środku / górnej połowie kadru.
4. **Dolna krawędź:** najniższe **~12% kadru** zasłania pasek ładowania (napis + pasek na całą
   szerokość) — ma być spokojne i ciemniejsze (cień, ziemia, woda, mgła), bez ważnych detali.
5. **Brzegi:** grafika wypełnia ekran z zachowaniem proporcji, więc na ekranach innych niż 16:9 brzegi
   są przycinane — nic ważnego przy samych krawędziach.
6. **Czystość sceny:** bez postaci, potworów, tekstu, logo i elementów UI
   (`No characters, no monsters, no text, no logo, no UI`).

**Wspólny dopisek (wklejany na końcu każdego promptu):**
```text
16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

## 🗺️ Prompty dla stref gry

---

### 1. Tutorial Dungeon (tutorial_area)
- **Referencja w projekcie:** `../battle_backgrounds/tutorial_area/variant_1_gate.jpg` … `variant_4_chamber.jpg`
  (fioletowo-szara cegła, szara posadzka z płyt, pochodnie, tarcze strzeleckie i manekiny treningowe)
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
- **Referencja w projekcie:** tileset jaskiń `modules/quiz_rpg/resources/maps/caves.tres` (brązowa ziemia,
  zielony mech, skalne ściany z kolcami i splątanymi korzeniami), `../battle_backgrounds/pixel_crawler/cave/`
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
- **Referencja w projekcie:** brak — hub fabularny: sklep, zapis, NPC, magiczna bariera Strażnika nad miastem
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
- **Referencja w projekcie:** `assets/pixel_crawler/environments/sewer/Social/MockUp-01.png`, `MockUp-02.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/sewer/`

#### Wariant 1: Kanał Główny (Main Sewer Canal)
```text
A 16-bit pixel art JRPG loading screen illustration of a long vaulted sewer tunnel, wide establishing shot with deep perspective. A channel of glowing toxic green sludge flowing down the middle, narrow stone walkways on both sides, mossy brick arches repeating into the distance, rusty copper pipes along the walls dripping water, a single grated light shaft from the street above. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Śluzy i Przełączniki (Sluice Gate Junction)
```text
A 16-bit pixel art JRPG loading screen illustration of a large underground sewer junction with massive iron sluice gates, wide establishing shot. Several canals meeting in a round brick chamber, heavy gears and lever mechanisms on the walls, chains and valves, green-tinted water pouring through half-open gates, old lanterns on iron hooks, damp stone and hanging moss. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Wyjście ku Cmentarzowi (Grate to the Cemetery)
```text
A 16-bit pixel art JRPG loading screen illustration of the end of a sewer tunnel with a rusted iron grate opening onto a misty night graveyard, wide establishing shot. Wet brick tunnel walls in the foreground framing the view, pale moonlight falling through the grate, silhouettes of crooked gravestones and a dead tree visible outside in blue fog. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 5. Cemetery (cemetery)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/cemetery/Pixel Crawler - Cemetery/Environment/Props/Graves.png`, `Tree.png`, `Structures/Walls.png`
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
- **Referencja w projekcie:** `assets/pixel_crawler/environments/fairy_forest/Pixel Crawler - Fairy Forest 1.7/Social/MockUp_01.png` … `MockUp_03.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/fairy_forest/`

#### Wariant 1: Rozstaje Trzech Bram (Crossroads of Three Gates)
*Opis scenerii:* Hub-skrzyżowanie: polana z trzema starymi kamiennymi bramami prowadzącymi w różne strony (piasek, żar, śnieg w prześwitach) i ledwie widoczną czwartą ścieżką wśród paproci.
```text
A 16-bit pixel art JRPG loading screen illustration of an enchanted forest crossroads glade, wide establishing shot. Three ancient moss-covered stone archways standing around a clearing, each glimpsing a different land through it: golden desert dunes, glowing red volcanic light, and snowy pines; a barely visible fourth overgrown path hidden among ferns, glowing runestones, floating fireflies and soft god rays through tall trees. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Magiczny Potok (Enchanted Stream)
```text
A 16-bit pixel art JRPG loading screen illustration of a magical forest stream at dusk, wide establishing shot. Crystal-clear water winding between mossy boulders, giant mushrooms and glowing blue bellflowers on the banks, a small wooden footbridge, huge ancient trees with hanging vines, fireflies and floating light motes, pink and turquoise evening light. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Pradawne Drzewo (The Elder Tree)
```text
A 16-bit pixel art JRPG loading screen illustration of a colossal ancient elder tree in the heart of a fairy forest, wide establishing shot. Enormous glowing roots spreading across a clearing, carved runes shining softly in the bark, small lanterns hanging from branches, a ring of standing stones around the trunk, drifting glowing pollen, deep green and gold palette. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 7. Desert → Desert Temple (desert, desert_temple)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/desert/Social/MockUp-01.png` … `MockUp-03.png`, `Social/Desert-Gold.png`
- **Foldery docelowe:** `modules/quiz_rpg/assets/textures/loading_screens/desert/` (otwarta mapa),
  `modules/quiz_rpg/assets/textures/loading_screens/desert_temple/` (świątynia)

#### Wariant 1 (desert): Morze Wydm (Sea of Dunes)
```text
A 16-bit pixel art JRPG loading screen illustration of an endless golden desert at sunset, wide establishing shot. Rolling sand dunes with wind ripples, half-buried sandstone pillars and a broken statue head, sun-bleached bones, a distant oasis with palm trees, and on the horizon the silhouette of a great sandstone temple, orange and magenta sky with heat haze. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2 (desert_temple): Fasada Świątyni (Temple Facade)
```text
A 16-bit pixel art JRPG loading screen illustration of a colossal sandstone temple facade carved into a cliff, wide establishing shot. Giant guardian statues flanking a dark doorway half-choked with sand, hieroglyph-like carvings (no readable text), golden sun disc above the entrance, crumbling steps, sand pouring from cracks, harsh midday light with deep shadows. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3 (desert_temple): Złota Krypta (Golden Crypt)
```text
A 16-bit pixel art JRPG loading screen illustration of a vast golden burial chamber deep inside a desert temple, wide establishing shot. Rows of sandstone columns, a raised sarcophagus on a stepped dais, heaps of gold coins and treasure, braziers with blue flames, a glowing fragment of an ancient artifact resting on an altar, thin beams of sunlight through ceiling cracks. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 8. Volcano → Forge (volcano, forge)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/forge/Social/MockUp-00.png` … `MockUp-02.png`
- **Foldery docelowe:** `modules/quiz_rpg/assets/textures/loading_screens/volcano/`,
  `modules/quiz_rpg/assets/textures/loading_screens/forge/`

#### Wariant 1 (volcano): Platformy nad Lawą (Lava Platforms)
```text
A 16-bit pixel art JRPG loading screen illustration of a volcanic caldera, wide establishing shot. Floating basalt platforms and narrow rock bridges over a glowing lake of molten lava, rising embers and heat shimmer, jagged black rock spires, rivers of magma pouring from the crater walls, dark red smoky sky. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2 (forge): Wielka Kuźnia (The Great Forge)
```text
A 16-bit pixel art JRPG loading screen illustration of a colossal dwarven forge built inside a volcano, wide establishing shot. A giant anvil on a stone platform, massive bellows and chains, channels of molten metal glowing orange, racks of weapons and armor, runic carvings glowing on the pillars, sparks everywhere, warm orange against deep shadow. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3 (forge): Stare Wrota Kuźni (Ancient Forge Gates)
```text
A 16-bit pixel art JRPG loading screen illustration of huge ancient iron gates sealed with glowing runes at the end of a lava-lit tunnel, wide establishing shot. Obsidian walls, cooled lava rock floor with glowing cracks, heavy chains and a giant keyhole mechanism, braziers burning on both sides. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

---

### 9. Dense Forest → biom zimowy (forest, winter)
- **Referencja w projekcie:** brak dedykowanej paczki; poziom generowany `FOREST_OVERWORLD` → folder `forest`
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
- **Referencja w projekcie:** `assets/pixel_crawler/environments/library/Social/MockUp_01.png`, `Assets/Tiles.png`
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
- **Referencja w projekcie:** `assets/pixel_crawler/environments/garden/Social/MockUp_01.png`, `Assets/Tiles.png`
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
- **Referencja w projekcie:** `assets/pixel_crawler/environments/castle/Social/MockUp_01.png`, `MockUp_02.png`, `Assets/Tiles.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/loading_screens/castle/`

#### Wariant 1: Zamek Arcymaga (The Archmage's Castle)
```text
A 16-bit pixel art JRPG loading screen illustration of a towering dark castle on a cliff, wide establishing shot at night. Gothic spires and battlements, a long stone bridge leading to the main gate, a swirling violet magical glow and a giant rotating arcane circle above the highest tower, storm clouds lit by purple lightning. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 2: Sala Tronowa (Throne Hall)
```text
A 16-bit pixel art JRPG loading screen illustration of a grand gothic throne hall, wide establishing shot with deep perspective. A long red carpet between massive stone pillars, royal red and purple banners with gold trim, iron chandeliers with candles, an empty ornate throne beneath a huge amber stained glass window. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
```

#### Wariant 3: Komnata Urządzenia (The Device Chamber)
```text
A 16-bit pixel art JRPG loading screen illustration of a circular arcane chamber at the top of a castle tower, wide establishing shot. A huge magical machine of brass rings and floating crystals in the center, glowing runic circles on the floor, beams of violet energy rising through an open dome into a stormy sky, scattered scrolls and instruments. 16:9 aspect ratio, 16-bit pixel art, crisp pixels, clean pixel cluster shading, wide establishing shot, calm darker strip along the bottom edge, no characters, no monsters, no text, no logo, no UI.
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
