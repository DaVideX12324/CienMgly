# Prompty do generowania teł bitewnych (Pixel Crawler Battle Backgrounds)

Ten dokument zawiera gotowe, zoptymalizowane prompty do generowania teł walki (16:9, styl Pixel Art) dla wszystkich biomów i zestawów **Pixel Crawler**.
Dla każdego biomu przygotowano **4 zróżnicowane warianty scenerii** (łącznie 44 prompty w 11 środowiskach), wiernie bazujące na oficjalnych teksturach, makietach (MockUps) oraz kafelkach (tilesets/props) z poszczególnych paczek.

---

## 🎨 Uniwersalne wytyczne stylu i perspektywy

Wszystkie tła walki w grze muszą spełniać poniższe kryteria kompozycyjne:

1. **Format i rozdzielczość:** Proporcje **16:9** (rekomendowane np. 1920x1080 lub 1280x720).
2. **Stylistyka:** `High quality pixel art, 16-bit / 32-bit JRPG battle background style, clean pixel cluster shading, limited atmospheric color palette`.
3. **Perspektywa:** Kąt kamery na wysokości oczu / lekko obniżony (RPG first-person battle arena view).
   - **Dolne 40-50% kadru:** Płaska posadzka / podłoże z czytelną głębią perspektywy, na której czytelnie i stabilnie stoją jednostki wrogów. Środek pola walki powinien być wolny od wysokich przeszkód.
   - **Górne 50-60% kadru:** Ściana tła, filary, sklepienie, łuki architektoniczne lub malowniczy horyzont.
4. **Czystość sceny (Brak postaci):** Kategoryczny zakaz generowania postaci, potworów, elementów HUD, pasków życia czy napisów (`No characters, no monsters, no party members, no UI, clean empty scenery`).

---

## 🏰 Prompty dla biomów Pixel Crawler

---

### 1. Zamek / Komnata Zamkowa (Castle)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/castle/Social/MockUp_01.png`, `MockUp_02.png`, `Assets/Tiles.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/castle/`

#### Wariant 1: Sala Tronowa (Throne Chamber)
*Opis scenerii:* Majestatyczna sala tronowa z ciemnego kamienia, centralny czerwony dywan, królewskie fioletowo-złote proporce na filarach i potężny tron z bursztynowym witrażem w tle.
```text
A 16-bit pixel art JRPG battle background of a grand medieval castle throne chamber, low-angle first-person battle perspective. In the foreground and lower half, a spacious polished dark stone tiled floor with a wide royal red carpet runner leading toward the background. In the background, towering dark stone brick walls, gothic arched doorways, majestic royal red and purple banners with gold trim hanging from carved stone pillars, potted topiary shrubs, iron torch sconces casting warm flickering light, and an ornate high throne beneath a glowing amber stained glass window. 16:9 aspect ratio, retro pixel art, crisp pixels, no characters, no monsters, no UI, clean scenery.
```

#### Wariant 2: Galeria Bohaterów / Sala Popiersi (Hall of Heroes)
*Opis scenerii:* Reprezentacyjna sala zamkowa z podłogą w geometryczną szachownicę, czerwonym obrzeżem dywanowym i rzeźbionymi popiersiami bohaterów na kamiennych cokołach.
```text
A 16-bit pixel art JRPG battle background of an imperial castle gallery and hall of heroes, eye-level battle perspective. The bottom half features a diamond checkerboard pattern blue-slate tiled floor with rich red carpet runners along the sides. The background features grand gothic stone pillars supporting vaulted stone arches, marble portrait bust sculptures resting on stone plinths along the walls, decorative red cushioned benches, purple heraldic pennants, and warm torchlight illuminating stone brick masonry. 16:9 aspect ratio, retro pixel art, clean pixel cluster shading, no characters, no monsters, no UI, empty scenery.
```

#### Wariant 3: Komnata Kominkowa / Królewska Izba (Hearth Chamber & Study)
*Opis scenerii:* Przytulna sala z ciepłą drewnianą podłogą z desek, potężnym kamiennym kominkiem z buchającym ogniem, regałami z księgami i nastrojowym oświetleniem.
```text
A 16-bit pixel art JRPG battle background inside a medieval castle hearth chamber and royal study, first-person battle perspective. The lower half is a clean polished dark wood plank floor with gentle fire reflections. In the background, a massive roaring brick and stone fireplace with a glowing hearth mantle, dark wood bookshelves filled with leather-bound tomes, heavy timber support beams, warm iron candelabras casting golden amber light, and gothic arched leaded glass windows. 16:9 aspect ratio, 16-bit pixel art, atmospheric warm lighting, no characters, no monsters, no UI.
```

#### Wariant 4: Dziedziniec Murów Obronnych (Castle Battlement Courtyard)
*Opis scenerii:* Otwarty kamienny taras zamkowy otoczony blankami, z tarczami rycerskimi na ścianach i widokiem na wieczorne niebo.
```text
A 16-bit pixel art JRPG battle background of an open castle fortress battlement courtyard, eye-level battle perspective. The bottom half consists of sturdy grey stone flagstones with subtle battle space. The background showcases crenellated stone ramparts, battlements, medieval red and yellow heraldic knight shields mounted on stone pillars, iron braziers with crackling fires, and an atmospheric twilight sky with faint purple clouds. 16:9 aspect ratio, retro pixel art aesthetic, crisp pixel detailing, no characters, no monsters, no UI.
```

---

### 2. Jaskinia / Kopalnia Kryształów (Cave)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/cave/Social/MockUp_01.png`, `Assets/Props.png`, `Social/Spore_Roots.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/cave/`

#### Wariant 1: Grota Świecących Grzybów (Bioluminescent Fungal Hollow)
*Opis scenerii:* Wilgotna podziemna jaskinia z ciemną ziemią, gigantycznymi fioletowymi grzybami-parasolami kapiącymi neonowo-błękitnymi zarodnikami i pomarańczowymi grzybami trąbkowymi.
```text
A 16-bit pixel art JRPG battle background inside a glowing bioluminescent fungal cavern, first-person battle perspective. The lower half features a flat damp dark soil floor with patches of moss and small glowing blue sprouts. The background is dominated by giant purple canopy umbrella mushrooms with glowing cyan bioluminescent spores dripping from the edges, vibrant orange funnel-shaped horn mushrooms growing on rocky walls, clay stalagmites, and deep cavern shadows illuminated by gentle purple and teal glow. 16:9 aspect ratio, retro pixel art, vibrant pixel shading, no characters, no monsters, no UI.
```

#### Wariant 2: Kryształowa Jaskinia i Podziemne Jezioro (Crystal Cavern & Subterranean Pool)
*Opis scenerii:* Skalna pieczara ze skupiskami lśniących błękitnych kryształów, spokojną taflą podziemnego jeziora i chłodną turkusową mgiełką.
```text
A 16-bit pixel art JRPG battle background of a subterranean crystal cavern, low eye-level battle perspective. The bottom half consists of a flat rocky gravel and dark stone floor bordering the calm reflective shore of an underground pool. In the background, massive clusters of luminous cyan and azure mineral crystals jutting from dark rugged cavern walls, dripping stalactites hanging from high stone arches, and soft turquoise ambient mist hovering in the air. 16:9 aspect ratio, retro pixel art style, high quality pixel clusters, no characters, no monsters, no UI.
```

#### Wariant 3: Czeluść Pradawnych Korzeni (Ancient Root Cavern / Spore Roots)
*Opis scenerii:* Erozja skalna opleciona potężnymi, skamieniałymi korzeniami drzew rosnących na powierzchni, z wiszącymi pąkami zarodników.
```text
A 16-bit pixel art JRPG battle background of an ancient subterranean root chasm, first-person battle perspective. The bottom half is compacted dark brown earth and smooth cave stone. The background reveals colossal twisting petrified tree roots breaking through the rock walls and ceiling, hanging vine tendrils with glowing pale blue spore bulbs, natural stone rock arches, and a mysterious deep underground chasm illuminated by faint bioluminescence. 16:9 aspect ratio, retro pixel art, rich atmospheric depth, no characters, no monsters, no UI.
```

#### Wariant 4: Opuszczone Wyrobisko Górnicze (Abandoned Mine Drift)
*Opis scenerii:* Stary tunel kopalniany z drewnianymi stemplami, wiszącymi mosiężnymi lampami naftowymi i odsłoniętymi żyłami złotej rudy w skale.
```text
A 16-bit pixel art JRPG battle background of an abandoned underground mine drift, low eye-level battle perspective. The bottom half features a flat rocky gravel floor with old embedded timber planks and subtle ore dust. The background features heavy rustic wooden support beams and scaffolding framing the rock tunnel, hanging mining lanterns casting warm circular amber glow, pickaxes leaning against rock walls, and exposed veins of gold and quartz glittering in dark cavern rock. 16:9 aspect ratio, 16-bit retro pixel art, no characters, no monsters, no UI, clean scenery.
```

---

### 3. Pustynia / Zewnętrzne Ruiny Pustynne (Desert)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/desert/Social/MockUp-01.png`, `MockUp-02.png`, `MockUp-03.png`, `Social/Desert-Gold.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/desert/`

#### Wariant 1: Starożytna Świątynia z Piaskowca (Sandstone Temple Ruins)
*Opis scenerii:* Monumentalne schody i portal świątyni z piaskowca z turkusowymi fryzami, obeliskami pokrytymi niebieskimi runami oraz starożytnymi urnami.
```text
A 16-bit pixel art JRPG battle background of ancient sandstone temple ruins in the desert, low eye-level battle perspective. The lower half is a wide flat golden sand battle ground with drifted sand dunes and broken sandstone tiles. In the background, majestic weathered sandstone temple stairs leading up to an arched portal, stone pillars decorated with turquoise geometric borders, tall obelisks etched with glowing cyan runes, terracotta amphora vessels, and distant golden sand dunes under a hazy blue sky. 16:9 aspect ratio, retro pixel art, clean pixel detailing, no characters, no monsters, no UI.
```

#### Wariant 2: Wąwóz Skamielin i Czerwony Kanion (Fossil Canyon & Red Bluffs)
*Opis scenerii:* Czerwone skały kanionu, olbrzymie skamieniałe kły i żebra prehistorycznych bestii wystające z wydm, kaktusy saguaro i spalone słońcem ciernie.
```text
A 16-bit pixel art JRPG battle background of a rugged red sandstone desert canyon, first-person battle perspective. The lower half features wind-swept golden sand and flat plateau rock. The background showcases towering red-brown stratified rock cliffs, colossal prehistoric fossilized tusks and rib bones jutting dramatically out of sand dunes, tall green saguaro cacti, dry gnarled desert shrubs with purple blossom tips, and a blazing sun creating sharp warm shadows. 16:9 aspect ratio, 16-bit pixel art, vibrant desert palette, no characters, no monsters, no UI.
```

#### Wariant 3: Wnętrze Grobowca Faraona (Pharaoh's Tomb & Golden Crypt)
*Opis scenerii:* Podziemna komnata grobowa z hieroglifami, złotymi sarkofagami, stertami antycznych monet i płonącymi misami ogniowymi.
```text
A 16-bit pixel art JRPG battle background inside an ancient Egyptian-style pharaoh's tomb, low-angle battle perspective. The lower half is a flat sandstone flagstone floor with scattered golden coins and sand dust. In the background, sandstone crypt walls covered with gold and turquoise painted hieroglyphs, a carved golden sarcophagus resting upon a raised stone dais, gilded urns and treasure chests, and bronze fire braziers casting warm flickering orange flames and dancing shadows. 16:9 aspect ratio, retro pixel art, rich gold and turquoise accents, no characters, no monsters, no UI.
```

#### Wariant 4: Pustynna Oaza o Zmierzchu (Desert Oasis at Sunset)
*Opis scenerii:* Delikatne fale piasku nad brzegiem czystego źródła oazy, smukłe palmy daktylowe i sylwetki piramid na tle purpurowo-złotego zmierzchu.
```text
A 16-bit pixel art JRPG battle background of a tranquil desert oasis at sunset, eye-level battle perspective. The lower half consists of smooth golden sand dunes bordering clear calm water reflecting the sky. In the background, swaying date palm trees with lush green fronds, sandstone pillars half-buried in sand, the distant dark silhouette of majestic step pyramids against an intense purple, magenta and golden-orange twilight sky. 16:9 aspect ratio, retro pixel art, atmospheric gradient lighting, no characters, no monsters, no UI.
```

---

### 4. Baśniowy Las (Fairy Forest)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/fairy_forest/Pixel Crawler - Fairy Forest 1.7/Social/MockUp_01.png`, `MockUp_02.png`, `MockUp_03.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/fairy_forest/`

#### Wariant 1: Polana Mistycznych Runów (Enchanted Runestone Glade)
*Opis scenerii:* Wilgotna, porośnięta mchem polana z białymi leśnymi kwiatkami, starożytnymi monolitami runicznymi jarzącymi się błękitnym okiem i mgłą.
```text
A 16-bit pixel art JRPG battle background of a mystical fairy forest glade, low eye-level battle perspective. The lower half consists of a flat vibrant green mossy ground dotted with tiny white wildflowers and soft clover patches. In the background, ancient carved standing stones and monoliths pulsing with glowing turquoise rune eyes, swirls of ethereal teal ground mist, towering ancient oaks and weeping willows with hanging vines, and floating magical sparkles. 16:9 aspect ratio, retro pixel art style, enchanting atmosphere, no characters, no monsters, no UI.
```

#### Wariant 2: Brzeg Magicznego Potoku (Enchanted Woodland Stream)
*Opis scenerii:* Czysty leśny potok o lazurowej wodzie z gładkimi kamieniami rzecznymi, drzewami o fioletowych koronach i świetlikami.
```text
A 16-bit pixel art JRPG battle background along an enchanted forest riverbank, first-person battle perspective. The bottom half is a flat lush grassy clearing beside a gently flowing azure blue stream with smooth stepping stones. The background features majestic woodland trees with deep emerald and lavender-purple foliage, glowing orange mushrooms on tree roots, dangling creeping ivy, and floating golden fireflies illuminating the tranquil forest canopy. 16:9 aspect ratio, 16-bit pixel art, lush colors, no characters, no monsters, no UI.
```

#### Wariant 3: Ogród Świecących Dzwonków (Glowing Bellflower Hollow)
*Opis scenerii:* Magiczna gęstwina leśna otoczona gigantycznymi purpurowo-niebieskimi dzwonkami kwiatowymi emitującymi własne światło.
```text
A 16-bit pixel art JRPG battle background of a fairy flower grove at dusk, eye-level battle perspective. The lower half features dark mossy soil with scattered purple flower petals. The background is filled with giant enchanted purple bellflowers with glowing cyan pistils shining like magical lamps, curling spiral vines climbing mossy tree trunks, a dense leafy green canopy with dappled twilight sunbeams, and sparkling fairy dust floating in the cool air. 16:9 aspect ratio, retro pixel art, dreamy pixel aesthetic, no characters, no monsters, no UI.
```

#### Wariant 4: Pradawne Drzewo Elfów (The Ancient Elder Tree)
*Opis scenerii:* Przestrzeń u stóp gigantycznego, wiekowego pnia drzewa, którego korzenie tworzą naturalne tarasy, z lampionami i pnączami.
```text
A 16-bit pixel art JRPG battle background in the shadow of a gargantuan elder tree, low-angle battle perspective. The lower half is a flat earthen woodland terrace framed by massive surface tree roots covered in soft green velvet moss. In the background, the colossal trunk of an ancient hollow elder tree, hanging woven vines with glowing magical lanterns, autumn-orange foliage mixed with deep green canopies, and a soft purple twilight glow filtering through the branches. 16:9 aspect ratio, retro pixel art, epic fantasy nature, no characters, no monsters, no UI.
```

---

### 5. Kuźnia / Wulkaniczna Zbrojownia (Forge)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/forge/Social/MockUp-00.png`, `MockUp-01.png`, `MockUp-02.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/forge/`

#### Wariant 1: Główna Sala Kowalska i Kowadło (Grand Foundry & Anvil)
*Opis scenerii:* Podziemna kuźnia z ciemnych bazaltowych płyt, wielkie kowadło na kamiennym postumencie, koryta z płynną lawą i stojaki z bronią.
```text
A 16-bit pixel art JRPG battle background of a subterranean dwarven master forge, first-person battle perspective. The lower half is a heat-resistant dark basalt stone slab floor with diagonal hazard-metal floor plates. In the background, a massive iron anvil resting upon a stone dais, conduits and troughs of molten orange lava flowing down volcanic brick walls, heavy iron chains hanging from the ceiling, weapon racks lined with glowing forged steel blades, and intense warm firelight illuminating the smoke-filled chamber. 16:9 aspect ratio, retro pixel art, vivid molten orange and dark charcoal contrast, no characters, no monsters, no UI.
```

#### Wariant 2: Most nad Jeziorem Lawy (Magma Lake Walkway)
*Opis scenerii:* Metalowa kładka z balustradą rozciągająca się ponad bulgoczącym jeziorem lawy, kamienne posągi kowali z gorejącymi oczami.
```text
A 16-bit pixel art JRPG battle background of an iron walkway spanning a volcanic lava lake, low eye-level battle perspective. The lower half features a sturdy industrial dark steel grating bridge with diamond tread plates and iron railings. The background reveals an expansive lake of bubbling bright orange magma, colossal carved stone statues of dwarven smiths with glowing fiery eyes, fortified brick arches with glowing heat vents, and drifting volcanic embers in the dark air. 16:9 aspect ratio, 16-bit pixel art, fiery dramatic lighting, no characters, no monsters, no UI.
```

#### Wariant 3: Piece Hutnicze i Baseny Chłodzące (Smelting Works & Quenching Vats)
*Opis scenerii:* Przemysłowa zbrojownia z dymiącymi piecami hutniczymi, basenami z wodą do hartowania stali, żelaznymi beczkami i rozżarzonymi sztabami.
```text
A 16-bit pixel art JRPG battle background of a volcanic armory and smelting foundry, eye-level battle perspective. The bottom half is a dark scorched brick floor with cooling grates and scattered metal shavings. In the background, roaring stone blast furnaces glowing with white-hot heat, large oak and iron barrels of quenching water, stacks of glowing orange metal ingots on heavy workbenches, heavy iron doors with chevron grating, and billows of white steam mixing with dark soot. 16:9 aspect ratio, retro pixel art, crisp mechanical detailing, no characters, no monsters, no UI.
```

#### Wariant 4: Wulkaniczny Rdzeń Runiczny (Runed Core & Magma Conduits)
*Opis scenerii:* Magmowa komnata z geometrycznymi kanałami lawy w podłodze, runicznymi kolumnami i potężną żelazną bramą wulkaniczną.
```text
A 16-bit pixel art JRPG battle background of a volcanic rune sanctum, low-angle battle perspective. The lower half features dark basalt flagstones crisscrossed by narrow geometric channels of flowing orange magma emitting warm light. In the background, massive dark stone pillars engraved with glowing heat runes, an arched iron portcullis gate with illuminated chevron slats, fiery lava waterfalls cascading into wall reservoirs, and intense red and amber atmospheric glow. 16:9 aspect ratio, retro pixel art, clean pixel art shading, no characters, no monsters, no UI.
```

---

### 6. Starożytny Ogród (Garden Environment)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/garden/Social/MockUp_01.png`, `Assets/Tiles.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/garden/`

#### Wariant 1: Dziedziniec Dwukondygnacyjnej Fontanny (Grand Tiered Fountain Courtyard)
*Opis scenerii:* Elegancki dziedziniec z jasnego kamienia, centralna sześciokątna marmurowa fontanna z tryskającą wodą, rabaty z różami w kolorze magenty i cyprysy.
```text
A 16-bit pixel art JRPG battle background of a royal palace garden courtyard, eye-level battle perspective. The lower half consists of a clean light grey cobblestone paved plaza framed by manicured green lawn borders. In the background, an ornate two-tiered hexagonal carved marble fountain splashing clear blue water, vibrant magenta rose flowerbeds bordered by low stone balustrades, tall columnar cypress trees, wooden garden benches, and bright sunny sky filtering through lush foliage. 16:9 aspect ratio, retro pixel art, crisp vibrant colors, no characters, no monsters, no UI.
```

#### Wariant 2: Sadzawka Nimf Wodnych (Nymph Reflecting Pool Promenade)
*Opis scenerii:* Marmurowa promenada wzdłuż podłużnego basenu z rzeźbami nimf lejących wodę z dzbanów, liliami wodnymi i żywopłotami.
```text
A 16-bit pixel art JRPG battle background of a classical sanctuary garden promenade, first-person battle perspective. The bottom half is a wide smooth flagstone terrace beside an ornamental turquoise reflecting pool. In the background, stone statues of water nymphs on pedestals pouring streams of water into the pool, floating pink water lilies and green pads, symmetrical topiary hedges, stone urns filled with bright blue delphiniums, and graceful classical colonnades under a golden afternoon sun. 16:9 aspect ratio, 16-bit pixel art, peaceful royal garden aesthetic, no characters, no monsters, no UI.
```

#### Wariant 3: Marmurowa Pergola i Różana Aleja (Marble Pergola & Rose Arches)
*Opis scenerii:* Zadaszona pnączami róż pergola z białego marmuru, drewniane trejaże, kamienne ławki i miękkie promienie słońca.
```text
A 16-bit pixel art JRPG battle background inside an overgrown classical garden pergola, low eye-level battle perspective. The lower half features antique white marble tiles with gentle cracks and fallen flower petals. In the background, fluted marble columns supporting arched wooden pergolas heavily draped with climbing crimson roses and ivy, ornate stone archways leading to distant verdant hills, sunbeams cutting through the canopy, and warm tranquil lighting. 16:9 aspect ratio, retro pixel art, rich botanical details, no characters, no monsters, no UI.
```

#### Wariant 4: Zatopiona Świątynia Ogrodowa (Sunken Garden Sanctuary)
*Opis scenerii:* Kamienny amfiteatr ogrodowy z ciosanych bloków, omszałe schody, pnącza bluszczu i starożytny kamienny pawilon.
```text
A 16-bit pixel art JRPG battle background of a secluded sunken garden sanctuary, low-angle battle perspective. The bottom half features wide curved stone terrace steps and aged paved ground with moss between stones. In the background, a circular open-air stone temple pavilion with weathered Corinthian pillars overgrown with wild green ivy, stone birdbaths, dark cypress silhouettes against a soft pastel sky, and gentle afternoon shadows. 16:9 aspect ratio, retro pixel art, lush greenery and antique stone, no characters, no monsters, no UI.
```

---

### 7. Kryjówka / Gildia Złodziei (Hideout)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/hideout/Pixel Crawler - Hideout/Social/MockUp_01.png`, `Assets/Tiles.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/hideout/`

#### Wariant 1: Piwnica Szmuglerów i Szynk (Smugglers' Cellar Den)
*Opis scenerii:* Podziemna kryjówka z posadzką z ciemnego bruku i desek, wielkie dębowe beczki z plamami wina, tarcze i podarte proporce z czerwoną czaszką.
```text
A 16-bit pixel art JRPG battle background inside a rogue smugglers' underground hideout, first-person battle perspective. The lower half features a rugged dark cobblestone and timber plank floor with ample combat space. In the background, massive oak wine barrels with dark red wine stains on the stone, tattered banners bearing a red skull emblem, rough wooden trestle tables with green glass bottles and tankards, wooden ceiling support beams, and iron wall sconces casting flickering warm amber light. 16:9 aspect ratio, retro pixel art, gritty pixel shading, no characters, no monsters, no UI.
```

#### Wariant 2: Skarbiec Gildii i Magazyn Kontrabandy (Thieves' Vault & Contraband Depot)
*Opis scenerii:* Ukryty magazyn łupów z okuwanymi skrzyniami skarbów, stertami worków, półkami z jarzącymi się na zielono flakonami eliksirów i pajęczynami.
```text
A 16-bit pixel art JRPG battle background of an underground thieves' guild treasure vault, low eye-level battle perspective. The bottom half is an uneven flagstone cellar floor with scattered coins and wooden crates. The background is packed with stacked iron-reinforced treasure chests, wooden shelving holding glowing green alchemical potion bottles, hanging coils of rope, an iron barred cell gate, cobwebs draping brick corners, and a dim lantern casting moody golden highlights. 16:9 aspect ratio, 16-bit pixel art, atmospheric shadows, no characters, no monsters, no UI.
```

#### Wariant 3: Sala Narad i Palenisko Obozowe (Planning Den & Campfire Hollow)
*Opis scenerii:* Kwatera mieszkalna bandytów z kamiennym kręgiem ogniska, polowymi pryczami wzdłuż ceglanych ścian i stołem z mapami.
```text
A 16-bit pixel art JRPG battle background of an underground bandit encampment and war room, eye-level battle perspective. The lower half features a stone brick cellar floor centered around a charred stone campfire pit with glowing embers. In the background, wooden bunk cots with grey blankets lining the damp brick wall, a sturdy strategy table with rolled parchment maps and daggers, weapon racks with cross-hilted blades, and warm torchlight reflecting off damp cellar masonry. 16:9 aspect ratio, retro pixel art, rustic underworld aesthetic, no characters, no monsters, no UI.
```

#### Wariant 4: Podziemna Przystań Kanałowa (Secret Underground Wharf)
*Opis scenerii:* Drewniany pomost nad ciemną, spokojną wodą podziemnego kanału, zacumowane łodzie, sieci rybackie i snop światła z zapadniętego stropu.
```text
A 16-bit pixel art JRPG battle background of a clandestine underground canal dock, first-person battle perspective. The lower half consists of a flat weathered wooden pier and wet stone embankment with combat room. In the background, dark still canal water reflecting warm lantern light, moored wooden rowboats, stacked cargo burlap sacks, hanging fishing nets, and a dramatic vertical beam of dusty sunlight piercing through a collapsed wooden ceiling hole into the dark cellar. 16:9 aspect ratio, retro pixel art, dynamic lighting, no characters, no monsters, no UI.
```

---

### 8. Starożytna Biblioteka (Library)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/library/Social/MockUp_01.png`, `Assets/Tiles.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/library/`

#### Wariant 1: Wielka Sala Czytelniana (Grand Reading Nave)
*Opis scenerii:* Monumentalna sala biblioteczna z ciemnym parkietem, turkusowym dywanem ze złotymi rombami, biurkami z mosiężnymi lampkami i piętrami książek.
```text
A 16-bit pixel art JRPG battle background of an arcane grand library reading hall, low-angle first-person battle perspective. The lower half features a dark polished wood parquet floor with an ornate teal and gold diamond patterned carpet runner. In the background, heavy mahogany study desks equipped with brass banker lamps and open grimoires, towering wooden bookshelves reaching to the ceiling with rolling ladders, teal curtains hanging beside arched leaded glass windows, and warm candlelight sconces. 16:9 aspect ratio, retro pixel art, rich jewel tones, no characters, no monsters, no UI.
```

#### Wariant 2: Antresola i Schody Archiwum (Mezzanine & Dual Staircase)
*Opis scenerii:* Dwupoziomowa biblioteka z rzeźbionymi drewnianymi schodami, antresolą, turkusowo-złotymi kolumnami i indeksowanymi regałami.
```text
A 16-bit pixel art JRPG battle background of a two-story grand academy library archive, eye-level battle perspective. The bottom half is a clean polished timber floor with wide battle arena space. In the background, an elegant wooden staircase dividing into upper mezzanine balconies with carved balustrades, polished teal and gold pillars, categorized bookshelves labeled with illuminated golden plates, hanging brass chandelier lanterns, and warm sunbeams pouring through a high geometric rose window. 16:9 aspect ratio, 16-bit pixel art, majestic scholarly atmosphere, no characters, no monsters, no UI.
```

#### Wariant 3: Dział Ksiąg Zakazanych (Restricted Arcane Vault)
*Opis scenerii:* Mroczne archiwum czarnoksiężników z łańcuchami opinającymi potężne tomy, lewitującymi księgami i fioletowo-błękitną poświatą magii.
```text
A 16-bit pixel art JRPG battle background inside a secret forbidden arcane library vault, low-angle battle perspective. The lower half consists of dark polished mahogany floorboards with faint glowing magic circle runes. The background displays towering iron-reinforced bookshelves with heavy chains locking forbidden dark grimoires, reading lecterns holding massive ancient spellbooks, gentle floating mystical books with glowing blue and violet pages, and eerie purple candlelight in iron candelabras. 16:9 aspect ratio, retro pixel art, mystical dark fantasy lighting, no characters, no monsters, no UI.
```

#### Wariant 4: Gabinet Astrologa i Alchemika (Scholar's Observatory & Study)
*Opis scenerii:* Pracownia naukowa z globusami sfer niebieskich, astrolabiami, fiolkami alchemicznymi i wielkim łukowym oknem z widokiem na gwiazdy.
```text
A 16-bit pixel art JRPG battle background of an astronomer scholar's observatory in the library tower, eye-level battle perspective. The bottom half is a herringbone patterned polished wood floor. In the background, large brass celestial armillary spheres, rolling library ladders beside tall book stacks, study benches covered in star charts and glowing glass alchemical flasks, and a colossal arched gothic window revealing a deep indigo night sky filled with twinkling stars. 16:9 aspect ratio, retro pixel art, crisp fine details, no characters, no monsters, no UI.
```

---

### 9. Miejskie Kanały (Sewer)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/sewer/Social/MockUp-01.png`, `MockUp-02.png`, `Assets/Props.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/sewer/`

#### Wariant 1: Główny Kanał Toksycznego Szlamu (Toxic Sludge Canal & Walkway)
*Opis scenerii:* Ciemny ceglany deptak z miedzianymi barierkami, jaskrawo zielony świecący strumień ścieków przecinający kadr i drewniany pomost.
```text
A 16-bit pixel art JRPG battle background of a dark subterranean sewer canal, first-person battle perspective. The lower half features a damp dark brick walkway with copper handrails running alongside a channel of vibrant glowing neon-green toxic sludge, crossed by a sturdy wooden plank bridge. The background showcases vaulted dark stone arches with green subway tile wainscoting, dripping iron pipes, arched outflow tunnels barred by heavy grates, and wall lanterns casting sickly greenish-amber highlights. 16:9 aspect ratio, retro pixel art, gritty industrial sewer palette, no characters, no monsters, no UI.
```

#### Wariant 2: Komnata Miedzianych Krat (Drainage Grate Cistern)
*Opis scenerii:* Wilgotna podziemna komora z dużymi miedzianymi kratownicami odpływowymi w podłodze, plamami pleśni na cegłach i rurami.
```text
A 16-bit pixel art JRPG battle background of an underground sewer drainage vault, low eye-level battle perspective. The bottom half is a wet dark stone brick floor embedded with large rectangular copper floor drainage grates. In the background, massive arched brick sewer conduits with green glazed ceramic tiles, circular drainage pipe outlets with copper rims, damp green moss clinging to wet mortar, and warm brass oil sconces illuminating the subterranean chamber. 16:9 aspect ratio, 16-bit pixel art, atmospheric damp reflections, no characters, no monsters, no UI.
```

#### Wariant 3: Węzeł Śluz i Zbiornik Retencyjny (Sluice Gate Junction)
*Opis scenerii:* Wysokie ceglane sklepienie kanału, potężne żelazne koła śluz, wodospad ścieków spływający do głębokiego rezerwuaru i wiszące łańcuchy.
```text
A 16-bit pixel art JRPG battle background inside a massive sewer sluice gate reservoir, eye-level battle perspective. The lower half is a raised stone maintenance platform bordered by low iron curbs. In the background, colossal arched brick tunnel chambers, giant rusted iron floodgate valve wheels mounted on pillars, a murky green waterfall pouring into an overflow pool, dripping stalactite formations on brick arches, and heavy iron chains hanging from the ceiling. 16:9 aspect ratio, retro pixel art, moody subterranean depth, no characters, no monsters, no UI.
```

#### Wariant 4: Obozowisko w Odnogach Kanałów (Sewer Maintenance Lair)
*Opis scenerii:* Sucha ceglana odnoga kanału zaadaptowana na posterunek – skrzynie, beczki, prowizoryczny stół i miedziane rury parowe.
```text
A 16-bit pixel art JRPG battle background of a concealed sewer alcove outpost, low-angle battle perspective. The lower half is a flat dry dark cobblestone floor with drainage gutters along the edges. In the background, stacks of wooden storage crates and barrels against dark brick walls, copper steam pipes venting faint mist, arched sewer outlets, a crude wooden table with a flickering lantern, and green slime dripping down damp masonry. 16:9 aspect ratio, retro pixel art, detailed pixel clusters, no characters, no monsters, no UI.
```

---

### 10. Cmentarzysko / Mroczna Krypta (Cemetery)
- **Referencja w projekcie:** `assets/pixel_crawler/environments/cemetery/Pixel Crawler - Cemetery/Environment/Props/Graves.png`, `Tree.png`, `Structures/Walls.png`, `Floor.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/cemetery/`

#### Wariant 1: Wzgórze Nagrobków i Żelazna Brama (Gothic Graveyard & Spiked Fence)
*Opis scenerii:* Nocny cmentarz z ciemną ziemią, snującą się niebieskawą mgłą przygruntową, pochylonymi krzyżami, kutym żelaznym ogrodzeniem ze szpicami i sosnami.
```text
A 16-bit pixel art JRPG battle background of a haunted gothic cemetery at midnight, low eye-level battle perspective. The lower half is uneven dark muddy soil with patches of dead grass and cold pale blue ground fog rolling across. The background features tilted weathered stone crosses and gothic tombstones, an ornate spiked wrought-iron cemetery fence, tall dark gothic pine trees, and a pale full moon casting eerie cold blue and purple moonlight through mist. 16:9 aspect ratio, retro pixel art, atmospheric dark fantasy, no characters, no monsters, no UI.
```

#### Wariant 2: Wnętrze Kamiennego Mauzoleum (Mausoleum Interior Crypt)
*Opis scenerii:* Wnętrze grobowca z kamiennymi sarkofagami z płaskorzeźbami czaszek, niszami na urny, żelazną kratą z pentagramem i chłodnym blaskiem lampionu.
```text
A 16-bit pixel art JRPG battle background inside an ancient gothic stone mausoleum crypt, first-person battle perspective. The bottom half is a cracked grey flagstone floor with carved stone border steps. In the background, ornate stone sarcophagi featuring carved skull reliefs, wall niches holding antique funerary urns, an arched doorway with a wrought-iron pentagram gate, spiderwebs in dark stone corners, and a cold spectral blue lantern casting haunting long shadows. 16:9 aspect ratio, 16-bit pixel art, somber crypt mood, no characters, no monsters, no UI.
```

#### Wariant 3: Świeży Grób i Płaczący Anioł (The Open Grave & Mourning Angel)
*Opis scenerii:* Cmentarna polana ze świeżo wykopanym grobem, stertą ciemnej ziemi ze szpadlem, otwartą trumną, posągiem skrzydlatego anioła i sękatym drzewem.
```text
A 16-bit pixel art JRPG battle background of a secluded burial plot in a gothic graveyard, low-angle battle perspective. The lower half features dark earth and overgrown weeds beside a freshly dug open grave pit with a mound of dirt and an upright iron shovel, and an empty wooden coffin. In the background, a weathered stone weeping angel statue on a marble pedestal, tilted tombstones, a gnarled dead oak tree with twisted bare branches, and cold blue starlight shining through wisps of fog. 16:9 aspect ratio, retro pixel art, eerie cemetery atmosphere, no characters, no monsters, no UI.
```

#### Wariant 4: Ruiny Gotyckiej Kaplicy (Ruined Cemetery Chapel)
*Opis scenerii:* Zrujnowana cmentarna kaplica z potłuczonymi płytami nagrobnymi, omszałymi łukami gotyckimi, posągiem Ponurego Żniwiarza z kosą i księżycem.
```text
A 16-bit pixel art JRPG battle background inside the roofless ruins of a gothic cemetery chapel, eye-level battle perspective. The bottom half consists of broken flagstones overgrown with moss and dead thistles. The background showcases crumbling stone gothic arches, shattered stained-glass rose window frames letting in bright moonlight beams, a carved stone Grim Reaper statue holding a scythe, and dark towering spruce trees silhouetted against a midnight purple sky. 16:9 aspect ratio, retro pixel art, gothic horror aesthetic, no characters, no monsters, no UI.
```

---

### 11. Karczma / Gospoda (Tavern / Inn) - *Bonus Biom*
- **Referencja w projekcie:** `assets/pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/MockUps/Tavern.png`
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/tavern/`

#### Wariant 1: Główna Sala Biesiadna (Main Tavern Hall & Hearth)
*Opis scenerii:* Rustykalna karczma z wypolerowaną drewnianą posadzką, długimi ławami biesiadnymi, pieczonym mięsem i kuflami na stołach, kamiennym paleniskiem i żelaznymi żyrandolami.
```text
A 16-bit pixel art JRPG battle background inside a lively medieval tavern banquet hall, first-person battle perspective. The lower half is a wide clean polished wooden plank floor ready for combat encounters. In the background, long rustic wooden feast tables laden with ceramic mugs and trenchers, a roaring stone hearth fireplace and brick cooking oven, mounted wolf and bear trophy heads on timber walls, heavy iron candelabras with flaming torches, and warm cozy amber light filling the room. 16:9 aspect ratio, retro pixel art, warm cozy tavern palette, no characters, no monsters, no UI.
```

#### Wariant 2: Szynkwas i Regał Trunkowy (Tavern Bar & Spirit Shelf)
*Opis scenerii:* Kadr na długi dębowy bar zastawiony butelkami, beczkami piwa, kufelkami i schodami prowadzącymi na piętro karczmy.
```text
A 16-bit pixel art JRPG battle background facing a rustic fantasy tavern bar counter, eye-level battle perspective. The bottom half features smooth wooden floorboards with circular rag rugs and battle space. The background displays a sturdy dark oak bar counter, shelves stacked with colorful glass liquor bottles and clay tankards, large wooden beer casks with brass taps, a wooden staircase leading up to an inn balcony, and warm iron lanterns casting inviting golden glow on wooden beams. 16:9 aspect ratio, 16-bit pixel art, detailed tavern props, no characters, no monsters, no UI.
```

#### Wariant 3: Korytarz Piętra i Pokoje Gościnne (Inn Upper Floor Corridor)
*Opis scenerii:* Przytulny korytarz na piętrze zajazdu z deskami podłogowymi, drewnianymi drzwiami do pokoi, dywanikami i oknami z widokiem na wieś.
```text
A 16-bit pixel art JRPG battle background of an upper floor hallway in a fantasy inn, low eye-level battle perspective. The lower half is a clean wooden floorboard corridor with green woven runner rugs. In the background, wooden room doors with iron ring latches, timber wall studs with hanging flower pots, warm brass wall lamps, half-open wooden windows revealing sunny medieval village rooftops, and peaceful golden daytime illumination. 16:9 aspect ratio, retro pixel art, warm rustic aesthetic, no characters, no monsters, no UI.
```

#### Wariant 4: Spiżarnia i Piwnica Karczmarza (Tavern Cellar & Larder)
*Opis scenerii:* Chłodna piwnica z kamiennymi płytami, wiszącymi wędzonymi szynkami, stertami worków ze zbożem, skrzynkami warzyw i beczkami z cydrem.
```text
A 16-bit pixel art JRPG battle background inside a medieval tavern larder and food cellar, first-person battle perspective. The lower half consists of a flat grey stone flagstone floor with ample arena room. The background is filled with cured meats and garlic braids hanging from heavy ceiling beams, stacks of grain sacks, wooden vegetable crates, rows of aged cider barrels along stone walls, and a flickering oil lantern casting warm yellow and soft brown shadows. 16:9 aspect ratio, retro pixel art, rustic storage interior, no characters, no monsters, no UI.
```

---

## 🛠️ Jak dodawać nowe warianty do gry?

1. Wygeneruj obraz w formacie PNG lub JPG (16:9, np. 1920x1080) używając wybranego promptu powyżej.
2. Zapisz plik w odpowiednim folderze biomu:
   - `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/<nazwa_biomu>/variant_1.jpg`
   - `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/<nazwa_biomu>/variant_2.png`
   - `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/<nazwa_biomu>/variant_3.png`
   - `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/<nazwa_biomu>/variant_4.png`
3. Generator `pixel_crawler_battle_background.gd` automatycznie skanuje folder biomu i losuje warianty przy każdej walce bez konieczności modyfikowania kodu!
