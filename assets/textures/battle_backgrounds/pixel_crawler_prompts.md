# Prompty do generowania teł walki (Pixel Crawler)

Proste prompty do teł walki (16:9, pixel art, perspektywa 1. osoby) dla biomów paczek **Pixel Crawler**.
Na biom **5 wariantów**: 3 jednopoziomowe i 2 **z platformami** (podest / taras / pomost, na którym wrogowie
stoją wyżej). Materiały i rekwizyty są spisane z mockupów autorów paczek („Z mockupów” przy biomie), żeby tło
walki wyglądało jak mapa, po której chodzi gracz.

Tło losuje się z folderu mapy przy każdej walce (`folder_battle_background.gd`) — dodanie grafiki do folderu
wystarczy, bez zmian w kodzie.

---

## 🎨 Zasady (wersja 2026-10-07 — styl sprawdzonych wzorców)

Sprawdzone wzorce, które trzymały perspektywę: `pixel_crawler_prompts_wzorzec_v1.md` (pierwsza wersja)
i `pixel_crawler_prompts_wzorzec_gemini.md` (4 warianty × 11 biomów). Każdy prompt tutaj ma tę samą budowę:

1. **Jeden akapit, ~70–100 słów.** Pierwsze zdanie: „A 16-bit pixel art JRPG battle background of X,
   first-person battle perspective.” (albo eye-level / low-angle).
2. **„The lower half features …”** — pusta, płaska posadzka (to na niej stoją wrogowie; dolna ćwierć jest
   pod oknem UI walki, więc nic ważnego).
3. **„In the background, …”** — dekoracje z mockupu. Tylko rekwizyty paczki — to jedyne, co różni te prompty
   od wzorców (wzorce miały kryształy, belki, latarnie itp. spoza paczek).
4. **Koniec:** „16:9 aspect ratio, retro pixel art, …, no characters, no monsters, no UI.”

**Mockup biomu możesz dołączyć** jako referencję kolorystyki i materiałów — z pierwszą wersją promptów tak było
i perspektywa wychodziła dobrze (krótki prompt z perspektywą w 1. zdaniu wygrywa z mockupem). **Nie dołączaj
arkuszy `Tiles.png` / `Props.png`** przy generowaniu od zera (z nimi wychodził widok z góry) i nie dopisuj
procentów ani zakazów typu „not top-down” (same te słowa ciągną w stronę widoku z góry). Arkusz `Props.png`
tylko przy edycji gotowego tła (dopasowanie wyglądu rekwizytów).
Gdy posadzka wychodzi za nisko: dopisz na końcu „The floor starts right at the middle of the image.”

**Warianty z platformami:** „Behind it, a wide raised … with a flat top and a straight front edge, reached
by … at the side.” Po wygenerowaniu w `scenes/tools/battle_layout_preview.tscn` każdy poziom dostaje własne pole
(**Ctrl+D**), narożniki na górnej powierzchni; wąski podest = `rows = 1`, `row_capacity = 2–3`
(`docs/kontekst/walka.md`).

**Które foldery używa gra:** jaskinie generowane → `cave`, zamek generowany → `castle`, las generowany →
`fairy_forest` (alias `forest`), `tutorial_area` → `battle_backgrounds/tutorial_area/`
(`tutorial_area_prompts.md`). Pozostałe biomy czekają na mapy — folder zadziała sam, gdy mapa dostanie klucz.
Edycja istniejących teł: `correction_prompts.md`.

---

## 🏰 Biomy

---

### 1. Zamek (castle)
- **Mockupy (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/castle/Social/MockUp_01.png`, `MockUp_02.png`
- **Z mockupów:** ciepły szarobeżowy kamień ścian z ciemniejszym gzymsem, posadzka **granatowo-indygo w romby**
  (nie szachownica), czerwone chodniki z cienkim złotym obszyciem, fioletowe proporce ze złotym brzegiem
  i szpicem, białe kamienne kinkiety ze świecami, terakotowe donice ze stożkowatymi krzewami, czerwone ławy,
  kamienne popiersia na cokołach ze stalowoniebieskimi tabliczkami, wąskie stele z łukową niszą, gotyckie okna
  z bursztynowego szkła, czerwony tron, komnata z kominkiem i podłogą z desek, tarcze czerwono-żółte
  w ćwiartki, drzwi z żelaznymi kratami, ciemne belki dachu.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/castle/`

#### Wariant 1: Sala Tronowa (Throne Hall)
```text
A 16-bit pixel art JRPG battle background of a castle throne hall, first-person battle perspective. The lower half features a wide, flat, empty floor of dark navy-indigo stone tiles in a diamond pattern with a red carpet runner with thin gold edges leading to the back. In the background, warm grey-beige stone walls, a red throne under a tall gothic window of glowing amber glass, stone portrait busts on plinths, purple banners with gold trim, terracotta pots with small conical shrubs and white stone wall sconces with warm candlelight. 16:9 aspect ratio, retro pixel art, crisp pixels, no characters, no monsters, no UI, clean scenery.
```

#### Wariant 2: Galeria Popiersi (Hall of Busts)
```text
A 16-bit pixel art JRPG battle background of a castle gallery of stone busts, eye-level battle perspective. The lower half features a wide, flat, empty floor of dark navy-indigo diamond-patterned stone tiles framed by a red carpet with thin gold edges. In the background, rows of stone portrait busts on plinths with small steel-blue plaques, narrow stone stelae with arched niches, warm grey-beige stone walls with small arched windows, purple banners with gold trim, red benches and white stone candle sconces with warm glow. 16:9 aspect ratio, retro pixel art, clean pixel cluster shading, no characters, no monsters, no UI, empty scenery.
```

#### Wariant 3: Komnata z Kominkiem (Hearth Chamber)
```text
A 16-bit pixel art JRPG battle background of a castle hearth chamber, first-person battle perspective. The lower half is a wide, flat, empty warm brown wooden plank floor. In the background, a large stone fireplace with a glowing orange fire, two tall gothic windows of amber glass, dark wood bookshelves and a wooden desk at the sides, red-and-yellow quartered heraldic shields on warm grey-beige stone walls, white stone candle sconces and dark wooden roof beams above. 16:9 aspect ratio, retro pixel art, warm lighting, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Podwyższenie Tronu (Throne Dais)
```text
A 16-bit pixel art JRPG battle background of a castle throne hall with a raised dais, first-person battle perspective. The lower half features a wide, flat, empty floor of dark navy-indigo diamond-patterned tiles with a red carpet with gold edges. Behind it, a wide raised stone dais with a flat top and a straight front edge, reached by broad steps in the middle. In the background, a red throne under a tall amber stained-glass window, stone busts on plinths, purple banners with gold trim and white stone candle sconces. 16:9 aspect ratio, retro pixel art, crisp pixels, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Balkon nad Halą (Gallery Balcony)
```text
A 16-bit pixel art JRPG battle background of a castle great hall with a stone balcony, eye-level battle perspective. The lower half features a wide, flat, empty floor of dark navy-indigo diamond-patterned tiles with a red carpet. Behind it, a long stone balcony with a flat floor and a low carved parapet along the back wall, reached by stone staircases at the left and right. In the background, warm grey-beige stone walls, purple banners with gold trim hanging below the balcony, narrow amber glass windows and white stone candle sconces. 16:9 aspect ratio, retro pixel art, clean pixel shading, no characters, no monsters, no UI.
```

---

### 2. Jaskinia (cave) — jaskinie generowane
- **Mockup (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/cave/Social/MockUp_01.png` (te same kafle
  i obiekty co jaskinie w grze: `objects_caves.json`)
- **Z mockupów:** brązowa ziemia z drobną ciemniejszą fakturą kamyków, plamy ciemnozielonego mchu,
  **fioletowe grzyby-parasole** o falbaniastych kapeluszach z bladoniebieskimi „soplami” i skręconych
  szaroniebieskich trzonach, **czerwono-pomarańczowe grzyby-rurki** (kępy kielichów jak koral), małe brązowe
  grzybki, zwinięte kiełki z turkusowym świecącym czubkiem, kępki szarych kamyków, **stożkowate brązowe
  stalagmity z pierścieniami**, skarpy z brązowej skały oplecione skręconymi korzeniami, wyciosane w ziemi
  schody, czarna pustka. **Bez kryształów, rusztowań i latarń** — tego nie ma w paczce.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/cave/`
- **Wycinek mapy (do wglądu):** `pixel_crawler/cave_reference/wycinek_mapy_grzyby.png`

#### Wariant 1: Grzybowa Pieczara (Mushroom Hollow)
```text
A 16-bit pixel art JRPG battle background inside a dim underground mushroom cavern, first-person battle perspective. The lower half features a wide, flat, empty brown earth floor with small pebbles and patches of dark green moss, open across the whole width and ready for combat encounters. The background shows a brown rock wall of twisted root-like curls fading into darkness, giant purple umbrella mushrooms with frilled caps dripping pale icy-blue drops on tall twisted blue-grey stems, clusters of red-orange tube fungi like coral cups, cone-shaped ringed brown stalagmites, small grey pebble piles and tiny curled sprouts with glowing teal tips, soft purple glow. 16:9 aspect ratio, retro pixel art, clean pixel shading, no characters, no monsters, no UI, empty background.
```

#### Wariant 2: Wylot Tunelu (Tunnel Mouth)
```text
A 16-bit pixel art JRPG battle background in a wide cave hall in front of a dark tunnel, first-person battle perspective. The bottom half features a wide, flat, empty brown earth floor with small pebbles, a few flat grey stones and dark green moss, open across the whole width and ready for combat encounters. The background shows a big round tunnel opening into black depth framed by brown rock with twisted roots and green moss, red-orange tube fungi like coral cups and cone-shaped ringed brown stalagmites on both sides of the opening, purple umbrella mushrooms with pale icy-blue drips growing on the rock, soft purple and teal glow. 16:9 aspect ratio, retro pixel art, clean pixel shading, no characters, no monsters, no UI, empty background.
```

#### Wariant 3: Las Stalagmitów (Stalagmite Grove)
```text
A 16-bit pixel art JRPG battle background of a dark cave chamber full of stalagmites, first-person battle perspective. The bottom half features a wide, flat, empty brown earth floor with small pebbles and sparse dark green moss, open across the whole width and ready for combat encounters. The background shows rows of cone-shaped ringed brown stalagmites of many sizes in front of a brown rock wall with twisted roots, one huge purple umbrella mushroom with pale icy-blue drips glowing softly in the middle, a few red-orange tube fungi like coral cups and grey pebble piles, deep darkness above. 16:9 aspect ratio, retro pixel art, clean pixel shading, no characters, no monsters, no UI, empty background.
```

#### Wariant 4 (platforma): Płaskowyż ze Schodami (Cave Plateau)
```text
A 16-bit pixel art JRPG battle background of a cave with a raised rock plateau, first-person battle perspective. The lower half features a wide, flat, empty brown earth floor with small pebbles and dark green moss. Behind it, a wide plateau of brown rock wrapped in twisted roots, with a flat earthen top and a straight front cliff edge, reached by earthen stairs carved into the cliff at one side. In the background, purple umbrella mushrooms with pale icy-blue drips, red-orange tube fungi, cone-shaped ringed stalagmites and black darkness above. 16:9 aspect ratio, retro pixel art, clean pixel shading, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Półka nad Pieczarą (Rock Ledge)
```text
A 16-bit pixel art JRPG battle background of a cave with a high rock ledge, low eye-level battle perspective. The lower half features a wide, flat, empty brown earth floor with pebbles and moss. Behind it, a broad flat earthen ledge a few steps higher, edged by a low cliff of brown rock with twisted roots, reached by carved earthen steps at the left. In the background, a giant purple umbrella mushroom with icy-blue drips on a twisted blue-grey stem, red-orange tube fungi and cone-shaped stalagmites on the cliff tops, tiny glowing teal sprouts and black darkness above. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

### 3. Pustynia (desert)
- **Mockupy (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/desert/Social/MockUp-01-export.png`, `MockUp-02.png`, `MockUp-03.png`
- **Z mockupów:** **nasycony pomarańczowy piasek** z plamami rdzawobrązowego żwiru, grzbiety czerwonobrązowej
  skały o pionowych, słupowych ścianach, płaskie ostańce, kopulaste głazy z ciemnymi otworami jaskiń, ogromne
  zakrzywione kły / żebra koloru kości słoniowej, zaokrąglone zielone kaktusy (kolumnowe i beczkowate), nagie
  szarofioletowe drzewka z fioletowymi pąkami, suche krzaki z patyków. Świątynia: złocisty piaskowiec
  z **turkusowymi / lazurowymi pasami**, filary z niebieskimi inkrustacjami, schody z niebieskimi pasami,
  obelisk z niebieskimi znakami, niebiesko-złote dzbany, wyłom w murze.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/desert/`

#### Wariant 1: Wąwóz Kłów (Tusk Canyon)
```text
A 16-bit pixel art JRPG battle background of a desert canyon, low eye-level battle perspective. The lower half is a wide, flat, empty ground of saturated orange sand with patches of rust-brown gravel. In the background, ridges of red-brown rock with vertical columnar cliffs, a dark cave opening in the rock, huge curved ivory tusks and rib bones jutting from the sand, rounded green columnar and barrel cacti, bare grey-violet trees with tiny purple buds and dry stick bushes under a pale hazy sky. 16:9 aspect ratio, retro pixel art, warm desert palette, no characters, no monsters, no UI.
```

#### Wariant 2: Kotlina z Kolumnami (Pillar Hollow)
```text
A 16-bit pixel art JRPG battle background of a round sandy hollow ringed by rock, first-person battle perspective. The lower half features a wide, flat, empty floor of saturated orange sand with rust-brown gravel. In the background, a curved wall of red-brown columnar rock, two lone golden sandstone column stumps inlaid with small blue gems, huge curved ivory tusks half-buried in sand, rounded green cacti, a bare grey-violet tree with purple buds and a dome boulder with a dark cave mouth, warm afternoon light. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 3: Przed Świątynią (Temple Forecourt)
```text
A 16-bit pixel art JRPG battle background in front of ruined desert temple walls, eye-level battle perspective. The lower half is a wide, flat, empty ground of saturated orange sand with rust-brown gravel and a few broken sandstone blocks. In the background, a wall of golden sandstone bricks with turquoise and lapis-blue stripes, pillars inlaid with blue gems, a dark breach in the wall, a tall obelisk with blue glyphs, blue-and-gold clay urns, red-brown rock ridges and green cacti at the sides. 16:9 aspect ratio, retro pixel art, rich gold and turquoise accents, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Taras Świątyni (Temple Terrace)
```text
A 16-bit pixel art JRPG battle background of a desert temple terrace, first-person battle perspective. The lower half features a wide, flat, empty ground of saturated orange sand with rust-brown gravel. Behind it, a wide golden sandstone terrace with a flat paved top and a straight front edge trimmed with turquoise stripes, reached by broad stairs with blue-striped steps in the middle. In the background, the temple entrance with pillars inlaid with blue gems, a tall obelisk with blue glyphs, blue-and-gold urns and red-brown rock ridges under a pale hazy sky. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Skalna Półka (Rock Ledge)
```text
A 16-bit pixel art JRPG battle background of a red rock ledge in the desert, low eye-level battle perspective. The lower half features a wide, flat, empty ground of saturated orange sand with rust-brown gravel. Behind it, a broad flat-topped ledge of red-brown columnar rock covered in orange sand, with a straight front edge, reached by a sandy ramp at one side. In the background, huge curved ivory tusks at the foot of the cliffs, rounded green cacti, bare grey-violet trees with purple buds and flat-topped mesas on the horizon. 16:9 aspect ratio, retro pixel art, warm desert palette, no characters, no monsters, no UI.
```

---

### 4. Baśniowy Las (fairy_forest) — też las generowany (`forest`)
- **Mockupy (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/fairy_forest/Pixel Crawler - Fairy Forest 1.7/Social/MockUp_01.png` … `MockUp_04.png`
- **Z mockupów:** głębokie ciemne zielenie, korony z warstwowych kęp liści: ciemnozielone, **turkusowo-niebieskie**
  i **liliowo-fioletowe**, rdzawopomarańczowe krzewy, grube skręcone brązowe pnie, **zaokrąglone szaroniebieskie
  kamienie runiczne z jednym świecącym turkusowym okiem**, turkusowa mgła przy ziemi, drobne białe kwiatki,
  pomarańczowe huby, czerwone muchomory na cienkich nóżkach, zielone pnącza z beżowymi dzwonkami, **świecące
  fioletowe kwiaty-trąbki z turkusowym słupkiem**, jaskrawoniebieski potok, trawiaste skarpy z brązową ziemią,
  stary pniak, skośne smugi światła.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/fairy_forest/`

#### Wariant 1: Polana Kamieni Runicznych (Runestone Glade)
```text
A 16-bit pixel art JRPG battle background of a mystical fairy forest glade, low eye-level battle perspective. The lower half consists of a wide, flat, empty mossy green ground with tiny white flowers and soft teal mist. In the background, rounded blue-grey runestones each with a single glowing turquoise eye, thick twisted brown tree trunks, layered leafy canopies in dark green, turquoise-blue and lilac-purple, rusty orange bushes and red-capped toadstools on thin stems. 16:9 aspect ratio, retro pixel art, enchanting atmosphere, no characters, no monsters, no UI.
```

#### Wariant 2: Brzeg Potoku (Streamside)
```text
A 16-bit pixel art JRPG battle background on a forest clearing by a stream, first-person battle perspective. The lower half is a wide, flat, empty grassy clearing with small white flowers. In the background, a bright blue stream with grey stones crossing behind the clearing, grassy banks with exposed brown earth, thick twisted trees with dark green, turquoise and lilac leaf clusters, orange bracket fungi on the trunks and an old tree stump. 16:9 aspect ratio, 16-bit pixel art, lush colors, no characters, no monsters, no UI.
```

#### Wariant 3: Gęstwina w Smugach Światła (Sunbeam Thicket)
```text
A 16-bit pixel art JRPG battle background of a deep forest thicket at dusk, eye-level battle perspective. The lower half features a wide, flat, empty dark mossy ground. In the background, glowing purple trumpet flowers with turquoise pistils, green twisting vines with beige bell flowers climbing thick brown trunks, a dense canopy of dark green and lilac leaves, red toadstools and diagonal beams of soft light falling through the leaves. 16:9 aspect ratio, retro pixel art, dreamy pixel aesthetic, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Leśna Skarpa (Forest Ledge)
```text
A 16-bit pixel art JRPG battle background of a forest with a grassy ledge, first-person battle perspective. The lower half features a wide, flat, empty mossy green ground with tiny white flowers. Behind it, a wide grassy ledge with a flat top and a straight front bank of exposed brown earth and roots, reached by a gentle earthen slope at one side. In the background, thick twisted trees with dark green, turquoise and lilac canopies, rounded blue-grey runestones with one glowing turquoise eye and teal mist. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Taras nad Potokiem (Terrace Above the Stream)
```text
A 16-bit pixel art JRPG battle background of a forest terrace above a stream, low eye-level battle perspective. The lower half features a wide, flat, empty grassy clearing. Behind it, a narrow bright blue stream and a raised grassy terrace on its far bank with a flat top and a straight earthen edge, reached by flat stepping stones across the water at one side. In the background, layered trees in dark green, turquoise and lilac, orange bracket fungi on trunks, glowing purple trumpet flowers and diagonal sunbeams. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

### 5. Kuźnia (forge)
- **Mockupy (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/forge/Social/MockUp-00.png`, `MockUp-01.png`, `MockUp-02.png`
- **Z mockupów:** posadzka z **przydymionych fioletowoszarych płyt** o skośnej fakturze, jaśniejsze szarobeżowe
  kamienne obrzeża, ściany z **ciemnoczerwonej cegły z cienkimi żarzącymi się pomarańczowymi szczelinami**,
  kamienne pilastry z rombowymi ozdobami o pomarańczowym rdzeniu, wąskie łukowe okna z pomarańczowymi kratami
  w jodełkę, duże łukowe wrota z żarzącymi się prętami w jodełkę, płaskie baseny pomarańczowej lawy z kamiennymi
  blankami na brzegu, metalowe kraty-mosty w pomarańczową szachownicę, płyta w pomarańczowo-czarne ukośne
  pasy, kamienne posągi brodatych krasnoludów, ceglane piece-słupy z kamienną czapą, maszyny ścienne
  z brązowymi kołami zębatymi, beczki (niektóre z niebieską wodą), skrzynie, prawie czarna bordowa pustka.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/forge/`

#### Wariant 1: Sala przed Wrotami (Chevron Gate Hall)
```text
A 16-bit pixel art JRPG battle background of a dwarven forge hall, first-person battle perspective. The lower half is a wide, flat, empty floor of smoky violet-grey stone slabs with light grey-beige stone borders. In the background, dark red brick walls with thin glowing orange cracks, a large arched gate with glowing orange chevron bars, stone pilasters with orange-cored diamond ornaments, narrow arched windows with orange herringbone grilles, barrels and crates by the walls. 16:9 aspect ratio, retro pixel art, molten orange and dark contrast, no characters, no monsters, no UI.
```

#### Wariant 2: Jezioro Lawy z Posągami (Lava Lake Statues)
```text
A 16-bit pixel art JRPG battle background of a forge cavern by a lava pool, low eye-level battle perspective. The lower half features a wide, flat, empty floor of smoky violet-grey stone slabs. In the background, a flat pool of glowing orange lava edged with small stone merlons, big stone statues of bearded dwarves on both sides, dark red brick walls with glowing orange cracks and dark burgundy shadows above. 16:9 aspect ratio, 16-bit pixel art, fiery lighting, no characters, no monsters, no UI.
```

#### Wariant 3: Hala Maszyn (Machine Hall)
```text
A 16-bit pixel art JRPG battle background of a forge machine hall, eye-level battle perspective. The lower half is a wide, flat, empty floor of smoky violet-grey stone slabs with a hazard plate of diagonal orange and black stripes near the back. In the background, wall machines with bronze cogwheels and glowing orange rods, brick furnace columns with stone caps, barrels of blue water, wooden crates and dark red brick walls with glowing cracks. 16:9 aspect ratio, retro pixel art, crisp mechanical detail, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Pomost nad Lawą (Grate Bridge Over Lava)
```text
A 16-bit pixel art JRPG battle background of a forge with a raised metal walkway, first-person battle perspective. The lower half features a wide, flat, empty floor of smoky violet-grey stone slabs. Behind it, a narrow glowing orange lava channel and beyond it a wide raised walkway of metal grating in an orange checker pattern with a flat top and a straight front edge, reached by stone steps at one side. In the background, dark red brick walls with glowing cracks, stone dwarf statues and a large arched gate with glowing chevron bars. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Podest Pieców (Furnace Platform)
```text
A 16-bit pixel art JRPG battle background of a forge with a raised furnace platform, low-angle battle perspective. The lower half features a wide, flat, empty floor of smoky violet-grey stone slabs. Behind it, a wide stone platform with a flat top of grey-beige stone and a straight front edge, reached by stone stairs in the middle. In the background, brick furnace columns with stone caps glowing orange inside, wall machines with bronze cogwheels, barrels and crates and dark red brick walls with glowing cracks. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

### 6. Ogród (garden)
- **Mockup (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/garden/Social/MockUp_01.png`
- **Z mockupów:** ścieżki z **sześciokątnych jasnoszaro-liliowych kostek**, ciemnozielony trawnik obrzeżony
  jaśniejszym żółtozielonym strzyżonym żywopłotem, kolumnowe ciemne cyprysy, **kwadratowe rabaty magenty**,
  kamienne urny z niebieskimi kwiatami na cokołach, niskie kamienne balustrady, drewniane ławki, ośmiokątna
  dwupiętrowa kamienna fontanna, długa sadzawka z ząbkowanym kamiennym brzegiem, posągi nimf lejących wodę,
  liście lilii z różowymi kwiatami, drewniane trejaże na tle głębokiego fioletu, kamienne bramy łukowe
  z bluszczem, łuk z żywopłotu.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/garden/`

#### Wariant 1: Plac z Fontanną (Fountain Plaza)
```text
A 16-bit pixel art JRPG battle background of a palace garden plaza, eye-level battle perspective. The lower half consists of a wide, flat, empty pavement of light grey-lilac hexagonal cobbles. In the background, an octagonal two-tiered stone fountain splashing water, square flower beds of magenta flowers, dark columnar cypress trees, trimmed yellow-green hedges, stone urns with blue flowers, low stone balustrades and wooden benches. 16:9 aspect ratio, retro pixel art, crisp colors, no characters, no monsters, no UI.
```

#### Wariant 2: Sadzawka z Nimfami (Nymph Pool)
```text
A 16-bit pixel art JRPG battle background of a garden promenade by a long pool, first-person battle perspective. The bottom half is a wide, flat, empty terrace of light grey-lilac hexagonal cobbles. In the background, a long pool with a notched stone rim, two stone nymph statues pouring water, lily pads with pink flowers, dark cypress trees, trimmed hedges and stone urns with blue flowers. 16:9 aspect ratio, 16-bit pixel art, peaceful garden aesthetic, no characters, no monsters, no UI.
```

#### Wariant 3: Brama z Trejażami (Trellis Gate)
```text
A 16-bit pixel art JRPG battle background in front of a garden gate, low eye-level battle perspective. The lower half features a wide, flat, empty path of light grey-lilac hexagonal cobbles bordered by dark green lawn. In the background, a stone archway covered in ivy, wooden trellises against a deep violet evening sky, an arch cut into a trimmed hedge, square magenta flower beds and dark cypress trees. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Taras Ogrodu (Garden Terrace)
```text
A 16-bit pixel art JRPG battle background of a stepped palace garden, first-person battle perspective. The lower half features a wide, flat, empty pavement of light grey-lilac hexagonal cobbles. Behind it, a wide raised terrace with a flat cobbled top and a low stone balustrade along its straight front edge, reached by stone stairs in the middle. In the background, an octagonal stone fountain on the terrace, magenta flower beds, dark cypress trees and stone urns with blue flowers. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Stopnie nad Sadzawką (Steps Above the Pool)
```text
A 16-bit pixel art JRPG battle background of a garden with a raised walk above a pool, eye-level battle perspective. The lower half features a wide, flat, empty pavement of light grey-lilac hexagonal cobbles. Behind it, a long pool with a notched stone rim and beyond it a raised stone walk with a flat top and a straight front edge, reached by stone steps at one side. In the background, nymph statues pouring water, lily pads with pink flowers, trimmed hedges, cypress trees and wooden trellises. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

### 7. Kryjówka (hideout)
- **Mockup (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/hideout/Pixel Crawler - Hideout/Social/MockUp_01.png`
- **Z mockupów:** posadzka z **ciemnego szarozielonego bruku**, rama z ciemnych drewnianych słupów i belek,
  ściany z ciemnej omszałej kamiennej cegły, zieleń przy krawędziach i ciemny las wokół, wielkie **leżące
  beczki na wino z ciemnofioletowymi plamami**, świece na ścianach z pomarańczową poświatą, **podarte białawe
  chorągwie z czerwoną czaszką**, beżowe posłania, kamienny krąg ogniska, prosty stół z cynowymi kuflami
  i zielonymi butelkami, skrzynki ze **świecącymi zielonymi eliksirami** i fioletowymi, okuta skrzynia, worki,
  złamane deski, pajęczyny, dziura w dachu z żółtym światłem dnia, drewniane schody, mała żelazna klatka.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/hideout/`

#### Wariant 1: Sala Beczek (Barrel Hall)
```text
A 16-bit pixel art JRPG battle background inside a bandit hideout, first-person battle perspective. The lower half features a wide, flat, empty floor of dark grey-green cobblestones with a few dark purple wine stains. In the background, huge wine barrels lying on their sides, torn off-white banners with a red skull, dark wooden posts and beams, mossy dark stone brick walls and wall candles casting warm orange light. 16:9 aspect ratio, retro pixel art, gritty pixel shading, no characters, no monsters, no UI.
```

#### Wariant 2: Kwatera z Ogniskiem (Campfire Quarters)
```text
A 16-bit pixel art JRPG battle background of bandit sleeping quarters, eye-level battle perspective. The lower half features a wide, flat, empty floor of dark grey-green cobblestones. In the background, a stone ring campfire with glowing embers, beige bedrolls along mossy stone walls, a simple wooden table with pewter mugs and green bottles, sacks, a small iron cage, dark wooden beams and warm candlelight. 16:9 aspect ratio, retro pixel art, rustic mood, no characters, no monsters, no UI.
```

#### Wariant 3: Magazyn Eliksirów (Potion Storeroom)
```text
A 16-bit pixel art JRPG battle background of a hidden storeroom, low eye-level battle perspective. The bottom half is a wide, flat, empty floor of dark grey-green cobblestones. In the background, wooden crates of glowing green and purple potions, an iron-bound chest, stacked sacks, leaning broken planks, cobwebs in the corners, boarded-up windows and a hole in the roof letting in a beam of yellow daylight. 16:9 aspect ratio, 16-bit pixel art, atmospheric shadows, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Antresola (Loft)
```text
A 16-bit pixel art JRPG battle background of a hideout with a wooden loft, first-person battle perspective. The lower half features a wide, flat, empty floor of dark grey-green cobblestones. Behind it, a wide wooden loft with a flat plank floor and a straight front beam, reached by wooden stairs at one side. In the background, wine barrels and crates on the loft, torn off-white banners with a red skull, dark wooden posts, mossy stone walls and warm candlelight. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Zawalona Izba (Collapsed Room)
```text
A 16-bit pixel art JRPG battle background of a half-collapsed hideout room, low-angle battle perspective. The lower half features a wide, flat, empty floor of dark grey-green cobblestones. Behind it, a raised heap of fallen stone and planks with a flat stone top and a straight front edge, reached by broken wooden steps at one side. In the background, a hole in the roof with yellow daylight, mossy stone walls with green plants growing in, cobwebs, sacks and crates of glowing green potions. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

### 8. Biblioteka (library)
- **Mockup (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/library/Social/MockUp_01.png`
- **Z mockupów:** **ciepły terakotowo-pomarańczowy parkiet w jodełkę**, ciemna turkusowa szachownica w środkowej
  sali, długi turkusowy chodnik w złote romby, **turkusowe kolumny ze złotymi głowicami**, antresole z ciemnego
  drewna z tralkami i szerokie drewniane schody, wnęki regałów z małymi złotymi tabliczkami, drewniane biurka
  ze złotymi kandelabrami i turkusowe krzesła, stosy czerwonych, niebieskich i zielonych książek, krzewy
  w donicach, wysokie okno z bladoniebieskiego szkła w złotą kratę między turkusowymi zasłonami, turkusowe łukowe
  drzwi ze złotem, wiszące złote latarnie z turkusowym szkłem, pomarańczowe ławy.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/library/` (do utworzenia)

#### Wariant 1: Czytelnia (Reading Hall)
```text
A 16-bit pixel art JRPG battle background of a grand library reading hall, low-angle first-person battle perspective. The lower half features a wide, flat, empty warm terracotta-orange herringbone parquet floor with a long teal carpet runner with gold diamonds. In the background, wooden desks with gold three-candle candelabras and teal chairs, tall bookshelves full of red, blue and green books, teal pillars with gold capitals and hanging gold lanterns with teal glass. 16:9 aspect ratio, retro pixel art, rich jewel tones, no characters, no monsters, no UI.
```

#### Wariant 2: Pod Wielkim Oknem (Under the Great Window)
```text
A 16-bit pixel art JRPG battle background of a library hall with a great window, eye-level battle perspective. The bottom half is a wide, flat, empty floor of dark teal checkerboard tiles. In the background, a tall window of pale blue glass in a gold lattice between teal curtains, teal pillars with gold capitals, potted shrubs with gold trim, orange benches and bookshelves on both sides. 16:9 aspect ratio, 16-bit pixel art, scholarly atmosphere, no characters, no monsters, no UI.
```

#### Wariant 3: Aleja Regałów (Shelf Aisle)
```text
A 16-bit pixel art JRPG battle background of a library aisle between bookshelves, first-person battle perspective. The lower half features a wide, flat, empty warm terracotta-orange herringbone parquet floor. In the background, tall dark wood bookshelves with small gold plates, stacks of red, blue and green books, a teal arched door with gold trim at the end, a teal and gold chest and hanging gold lanterns with teal glass. 16:9 aspect ratio, retro pixel art, crisp fine details, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Antresola ze Schodami (Mezzanine Stairs)
```text
A 16-bit pixel art JRPG battle background of a library with a mezzanine, first-person battle perspective. The lower half features a wide, flat, empty warm terracotta-orange herringbone parquet floor. Behind it, a long dark wood mezzanine with a flat floor and a balustrade along its straight front edge, reached by a broad wooden staircase in the middle. In the background, bookshelves on both levels, teal pillars with gold capitals and hanging gold lanterns with teal glass. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Podest Czytelni (Reading Dais)
```text
A 16-bit pixel art JRPG battle background of a library with a raised reading dais, eye-level battle perspective. The lower half features a wide, flat, empty floor of dark teal checkerboard tiles. Behind it, a wide raised dais of terracotta-orange parquet with a flat top and a straight front edge, reached by wooden steps at the sides. In the background, wooden desks with gold candelabras and teal chairs on the dais, a tall pale blue window in a gold lattice and bookshelves full of colourful books. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

### 9. Kanały (sewer)
- **Mockupy (referencja kolorów — można dołączyć):** `assets/pixel_crawler/environments/sewer/Social/MockUp-01.png`, `MockUp-02.png`
- **Z mockupów:** posadzka z **ciemnobrązowej cegły**, prawie czarne ściany z panelami ciemnozielonych kafli,
  łupkowe filary z małymi miedzianymi lampkami, **półokrągłe miedziane kraty odpływów**, okrągłe miedziane wyloty
  rur, miedziane barierki z rur, wysokie pionowe miedziane rury, duże prostokątne miedziane kratki w posadzce,
  **płaskie kanały limonkowego szlamu**, kładki z desek, drewniane skrzynie, beczki z niebieskimi obręczami,
  worki i gliniane dzbany, drewniane schody do włazu, prosty stół z krzesłami, mech w kątach.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/sewer/` (do utworzenia)

#### Wariant 1: Skrzyżowanie Kanałów (Canal Junction)
```text
A 16-bit pixel art JRPG battle background of an underground sewer hall, first-person battle perspective. The lower half features a wide, flat, empty walkway of dark brown brick. In the background, a flat channel of lime-green sludge with copper pipe railings, a wooden plank bridge across it, almost black walls with panels of dark green tiles, slate pillars with small copper lamps and half-round copper drain grates in the wall. 16:9 aspect ratio, retro pixel art, gritty sewer palette, no characters, no monsters, no UI.
```

#### Wariant 2: Hala Krat (Grate Hall)
```text
A 16-bit pixel art JRPG battle background of a sewer drainage chamber, low eye-level battle perspective. The bottom half is a wide, flat, empty floor of dark brown brick with large rectangular copper grates set flat into it. In the background, almost black walls with dark green tile panels, round copper pipe outlets, tall vertical copper pipes, slate pillars with small copper lamps and moss in the corners. 16:9 aspect ratio, 16-bit pixel art, damp atmosphere, no characters, no monsters, no UI.
```

#### Wariant 3: Posterunek w Kanałach (Sewer Outpost)
```text
A 16-bit pixel art JRPG battle background of a sewer outpost, eye-level battle perspective. The lower half features a wide, flat, empty floor of dark brown brick. In the background, wooden crates, barrels with blue hoops, sacks and clay jars against almost black walls with dark green tiles, a simple wooden table with chairs, wooden stairs up to a hatch and copper wall lamps. 16:9 aspect ratio, retro pixel art, detailed pixel clusters, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Pomost nad Kanałem (Walkway Over the Canal)
```text
A 16-bit pixel art JRPG battle background of a sewer with a raised walkway, first-person battle perspective. The lower half features a wide, flat, empty walkway of dark brown brick. Behind it, a flat channel of lime-green sludge and beyond it a raised brick walkway with a flat top and copper pipe railings along its straight front edge, reached by a wooden plank bridge at one side. In the background, almost black walls with dark green tiles, half-round copper drain grates and tall copper pipes. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Podest Konserwatorów (Maintenance Platform)
```text
A 16-bit pixel art JRPG battle background of a sewer maintenance platform, low-angle battle perspective. The lower half features a wide, flat, empty floor of dark brown brick. Behind it, a wide raised brick platform with a flat top and a straight front edge, reached by wooden stairs at one side. In the background, barrels with blue hoops and wooden crates on the platform, tall vertical copper pipes, round copper pipe outlets, almost black walls with dark green tiles and small copper lamps. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

### 10. Cmentarz (cemetery)
- **Arkusze (paczka nie ma mockupu — arkuszy nie dołączać):** `assets/pixel_crawler/environments/cemetery/Pixel Crawler - Cemetery/Environment/Props/Graves.png`, `Props.png`, `Tree.png`, `Structures/Roof.png`
- **Z arkuszy:** szare kamienne nagrobki (zaokrąglone, prostokątne, z krzyżem), kamienne i żelazne krzyże
  (jeden czerwony), płyty grobowe i sarkofagi z czerwonymi wstawkami, małe kapliczki z daszkiem, ozdobne złote
  drzwi mauzoleum, drewniane trumny, łopata, kopczyki ziemi, oliwkowożółty suchy krzak, małe posągi (aniołek,
  kostucha z kosą), ciemnozielone i brązowe uschnięte świerki, dachy z gontu w ciemnej zieleni, łukowe
  przejście, szare kłęby mgły; całość w zimnym łupkowo-niebieskim tonie.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/cemetery/` (do utworzenia)

#### Wariant 1: Rzędy Nagrobków (Rows of Graves)
```text
A 16-bit pixel art JRPG battle background of a graveyard at night, low eye-level battle perspective. The lower half is a wide, flat, empty ground of dark soil with sparse dead grass and grey mist. In the background, rows of grey stone tombstones (rounded, rectangular and cross-topped), stone and iron crosses, small shrines with roofs, dark green and dead brown spruce trees, all in cold slate-blue light. 16:9 aspect ratio, retro pixel art, atmospheric dark fantasy, no characters, no monsters, no UI.
```

#### Wariant 2: Przed Mauzoleum (Mausoleum Door)
```text
A 16-bit pixel art JRPG battle background in front of a mausoleum, first-person battle perspective. The bottom half is a wide, flat, empty ground of cracked grey flagstones with mist. In the background, a stone mausoleum with ornate golden doors under a dark green shingle roof, stone sarcophagi with red inlays, a small angel statue and a hooded reaper statue with a scythe, grey tombstones and spruce trees in cold slate-blue light. 16:9 aspect ratio, 16-bit pixel art, somber mood, no characters, no monsters, no UI.
```

#### Wariant 3: Świeże Groby (Open Graves)
```text
A 16-bit pixel art JRPG battle background of a burial ground, low-angle battle perspective. The lower half features a wide, flat, empty ground of dark soil with grey mist. In the background, mounds of fresh earth, an upright shovel, wooden coffins, grey tombstones and a red cross, olive-yellow dry bushes and dead brown spruce trees under cold slate-blue night light. 16:9 aspect ratio, retro pixel art, eerie atmosphere, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Cmentarny Taras (Graveyard Terrace)
```text
A 16-bit pixel art JRPG battle background of a terraced graveyard, first-person battle perspective. The lower half features a wide, flat, empty ground of dark soil with mist. Behind it, a wide raised terrace held by a grey stone wall, with a flat grassy top and a straight front edge, reached by stone steps in the middle. In the background, rows of tombstones and crosses on the terrace, a small roofed shrine, spruce trees and cold slate-blue light. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Schody do Krypty (Crypt Steps)
```text
A 16-bit pixel art JRPG battle background of a graveyard chapel above a crypt, eye-level battle perspective. The lower half features a wide, flat, empty floor of cracked grey flagstones. Behind it, a wide raised stone landing with a flat top and a straight front edge, reached by stone stairs at one side, in front of a chapel with a dark green shingle roof and an arched doorway. In the background, tombstones, a reaper statue, dead spruce trees and grey mist in cold slate-blue light. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

### 11. Karczma (tavern)
- **Mockup (referencja kolorów — można dołączyć):** `assets/pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/MockUps/Tavern.png`
- **Z mockupu:** drewniana podłoga z desek, **beżowe tynkowane ściany z ciemnymi drewnianymi belkami**, kuchnia
  z szarego kamienia (piec chlebowy z cegły, okap, blaty), żelazne żyrandole ze świecami, stojące pochodnie
  z czerwonym płomieniem, stoły z **czerwonymi i niebieskimi obrusami** i pieczystym, bar z butelkami, drewniane
  schody, **podwyższenie jadalni** ze schodkami i oknami, głowy niedźwiedzia i wilka na ścianie, miecze na ścianie,
  rośliny w donicach, magentowe kwiaty, zielony dywan, pokoje z łóżkami.
- **Folder:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/tavern/` (do utworzenia)

#### Wariant 1: Sala Biesiadna (Feast Hall)
```text
A 16-bit pixel art JRPG battle background inside a medieval tavern hall, first-person battle perspective. The lower half is a wide, flat, empty wooden plank floor. In the background, tables with red and blue tablecloths and roast meat, beige plaster walls with dark wooden beams, bear and wolf heads and crossed swords on the wall, iron chandeliers with candles, standing torches with red flames and potted plants with magenta flowers. 16:9 aspect ratio, retro pixel art, warm cozy palette, no characters, no monsters, no UI.
```

#### Wariant 2: Przy Barze (By the Bar)
```text
A 16-bit pixel art JRPG battle background facing a tavern bar, eye-level battle perspective. The bottom half features a wide, flat, empty wooden plank floor with a green rug. In the background, a dark wooden bar counter, shelves of bottles, beige plaster walls with dark beams, a wooden staircase going up at the side and iron chandeliers with warm candlelight. 16:9 aspect ratio, 16-bit pixel art, detailed tavern props, no characters, no monsters, no UI.
```

#### Wariant 3: Kuchnia (Kitchen)
```text
A 16-bit pixel art JRPG battle background of a tavern kitchen, low eye-level battle perspective. The lower half is a wide, flat, empty floor of grey stone flags. In the background, a brick bread oven with a glowing fire, a stone hood, grey stone counters with pots and bread, hanging roast meat, beige plaster walls with dark wooden beams and warm firelight. 16:9 aspect ratio, retro pixel art, rustic interior, no characters, no monsters, no UI.
```

#### Wariant 4 (platforma): Podwyższenie Jadalni (Raised Dining Floor)
```text
A 16-bit pixel art JRPG battle background of a tavern with a raised dining area, first-person battle perspective. The lower half features a wide, flat, empty wooden plank floor. Behind it, a wide raised wooden dining platform with a flat floor and a straight front edge, reached by short wooden steps in the middle. In the background, tables with red and blue tablecloths on the platform, windows in beige plaster walls with dark beams, iron chandeliers with candles and potted magenta flowers. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

#### Wariant 5 (platforma): Schody na Piętro (Stairs to the Rooms)
```text
A 16-bit pixel art JRPG battle background of a tavern hall with an upper landing, eye-level battle perspective. The lower half features a wide, flat, empty wooden plank floor with a green rug. Behind it, a long wooden landing with a flat floor and a railing along its straight front edge, reached by a wooden staircase at one side, with doors to guest rooms behind it. In the background, beige plaster walls with dark wooden beams, standing torches with red flames and bear and wolf heads on the wall. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

---

## 🛠️ Jak dodać tło do gry

1. Wygeneruj obraz (**16:9**) promptem z tego pliku; opcjonalnie dołącz mockup biomu (kolory), bez arkuszy.
2. Zapisz go w folderze biomu: `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/<biom>/`
   (png / jpg / webp, nazwa dowolna). Mapa ręczna ma folder o nazwie pliku sceny:
   `battle_backgrounds/<nazwa_sceny>/` (np. `tutorial_area`).
3. Otwórz projekt w edytorze (import grafiki), potem `scenes/tools/battle_layout_preview.tscn`: ustaw pole (pola)
   walki na posadzce — plik `<grafika>_layout.tres` zapisze się obok grafiki. Bez niego gra używa pola
   domyślnego (dwa rzędy pośrodku), co na tłach z platformami postawi wrogów w powietrzu.
4. Gotowe — `folder_battle_background.gd` losuje wariant z folderu przy każdej walce, także w eksporcie.
