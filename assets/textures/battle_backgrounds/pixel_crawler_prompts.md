# Prompty do generowania teł walki (Pixel Crawler)

Gotowe prompty do generowania teł walki (16:9, Pixel Art) dla wszystkich biomów paczek **Pixel Crawler**.
Opisy materiałów, kolorów, oświetlenia i propsów są wiernie spisane z oficjalnych mockupów i arkuszy (`MockUp*.png`), dzięki czemu tła walki idealnie pasują do mapy, po której porusza się gracz.

Dla każdego biomu przygotowano **5 zróżnicowanych wariantów**:
- **3 warianty jednopoziomowe** (klasyczna, przestronna arena walki),
- **2 warianty wielopoziomowe** (naturalne tarasy, podesty, schody lub balkony z podwyższonymi pozycjami bojowymi).

Tła losują się automatycznie z folderu danego biomu przy każdej walce (`folder_battle_background.gd`).

---

## 🎨 Uniwersalne wytyczne kompozycji

1. **Format i proporcje:** Zawsze **16:9** (np. 1920×1080 lub 2752×1536). Tło wypełnia cały ekran, także pod dolnym paskiem interfejsu.
2. **Kamera i perspektywa:** Kąt kamery z poziomu oczu / lekko obniżony (RPG first-person battle arena view). Patrzymy prosto przed siebie – ściany i filary stoją pionowo.
3. **Pasy kadru (wysokość obrazu):**
   - **0–10%:** Spokojna góra kadru (sklepienie, sufit, niebo) – tło pod okno logu i pytań.
   - **40–45%:** Tylna ściana, łuki architektoniczne lub horyzont.
   - **50–70%:** **Płaska, czysta posadzka / arena**, na której czytelnie stoją jednostki wrogów.
   - **75–100% (dolne 25%):** Czysta podłoga bez wysokich obiektów (znika pod dolnym paskiem menu/akcji gracza).
4. **Warianty wielopoziomowe:** 2 lub 3 czytelne, płaskie poziomy schodzące w głąb kadru: posadzka z przodu, za nią podwyższony taras/podest (górna powierzchnia na ok. 45–50% wysokości) i schody z boku. Po wygenerowaniu w narzędziu `scenes/tools/battle_layout_preview.tscn` każdemu poziomowi przypisuje się osobne pole walki (**Ctrl+D**).
5. **Czystość sceny:** Kategoryczny zakaz generowania postaci, potworów, drużyny, pasków życia, napisów czy elementów UI (`no characters, no monsters, no UI, clean empty scenery`).
6. **Referencje:** mockup biomu można dołączyć (kolorystyka, materiały). **Nie dołączać** arkuszy `Tiles.png` / `Props.png` przy generowaniu od zera — z nimi wychodzi widok z góry. `Props.png` tylko przy edycji gotowego tła (dopasowanie wyglądu rekwizytów).
7. **Wersja promptów (2026-10-07):** przepisane przez Gemini z długiej wersji — w teście A/B (jaskinia, wariant 4, 3 próby na prompt) wygrały z prostą wersją Claude'a: niżej kamera dzięki „**low** eye-level”, pełne tło ze sklepieniem zamiast czarnej pustki, warstwy foreground / midground / background na platformach. W promptach nie pisać „black darkness / void above” (daje czarne niebo). Wzorce: `pixel_crawler_prompts_wzorzec_v1.md`, `pixel_crawler_prompts_wzorzec_gemini.md`.
8. **Gdy posadzka wychodzi za nisko:** dopisz na końcu „The floor starts right at the middle of the image.” Edycja gotowych teł (oddalenie kadru, płótno): `correction_prompts.md` (proste prompty A / B na górze).

---

## 🏰 Biomy i prompty (kolejność progresu gry)

Biomy uporządkowane są w kolejności progresu fabularnego kampanii (zgodnie z docs/game_design.md):
1. **Jaskinia (cave)** — podziemia pod miastem (pierwsza eksploracja po wyjściu z tutoriala)
2. **Miasto / Karczma (`town` / `tavern`)** — miejski hub; całe miasto będzie w przyszłości robione ręcznie, więc docelowe prompty plenerów miejskich powstaną na bazie jego layoutu. Obecnie prompty reprezentują wnętrze miejskiej tawerny (`tavern`).
3. **Kryjówka (hideout)** — miejski hub (kwatera ruchu oporu / przemytników pod miastem)
4. **Kanały (sewer)** — ucieczka z miasta przez wyrwę w barierze
5. **Cmentarz (cemetery)** — za murami miasta, nieumarli
6. **Baśniowy Las (fairy_forest)** — hub-skrzyżowanie do głównych krain
7. **Pustynia (desert)** — odnoga 1: pustynne bezdroża i świątynia (fragment klucza 1)
8. **Kuźnia (forge)** — odnoga 2: podziemia wulkanu (fragment klucza 2)
9. **Biblioteka (library)** — pradawna wiedza, zagadki, odblokowana zebranymi fragmentami
10. **Ogród (garden)** — królewskie ogrody zamkowe i labirynt przed pałacem
11. **Zamek (castle)** — finał gry: twierdza arcymaga, sala tronowa, konfrontacja

*(Uwaga: początkowy Tutorial Dungeon ma odrębny plik: tutorial_area_prompts.md)*

---

### 1. Jaskinia (cave) — jaskinie generowane
- **Referencja z paczki:** `assets/pixel_crawler/environments/cave/Social/MockUp_01.png`
- **Materiały i paleta:** brązowa ziemia z drobną ciemniejszą fakturą kamyków, plamy ciemnozielonego mchu, **fioletowe grzyby-parasole** o falbaniastych kapeluszach z bladoniebieskimi soplami na brzegu i skręconych szaroniebieskich trzonach, **czerwono-pomarańczowe grzyby-rurki** (kępy kielichów jak koral), małe brązowe grzybki, drobne zwinięte kiełki z turkusowym świecącym czubkiem, kępki szarych okrągłych kamyków, **stożkowate brązowe stalagmity z pierścieniami**, skarpy z brązowej skały oplecione korzeniami, wyciosane w ziemi schody, czarna pustka za skałami. **Bez kryształów, rusztowań i latarń**!
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/cave/`

#### Wariant 1: Grzybowa Pieczara (Mushroom Hollow)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background inside a dim underground cavern, first-person battle perspective. The lower half features a flat brown earth floor with a fine darker pebble texture, patches of dark green moss, and a few tiny curled sprouts with glowing teal tips. In the background, giant purple umbrella mushrooms with scalloped caps fringed with pale icy-blue drips and twisted blue-grey stems, clusters of red-orange tube fungi shaped like coral cups, conical ringed brown stalagmites, and brown rock walls wrapped in twisted root curls fading into deep cavern darkness with faint purple and teal bioluminescence. 16:9 aspect ratio, retro pixel art, clean pixel cluster shading, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Korytarz między Skarpami (Corridor Between Cliffs)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a wide subterranean cave passage between vertical rock cliffs, low eye-level battle perspective looking straight ahead from the cave floor. The bottom half is a flat brown earth arena floor with dark pebble texture and patches of dark green moss. On the left and right sides, sheer vertical cliff walls of brown rock wrapped in twisted roots rise to about two-thirds height, where they meet a massive arched stone cavern ceiling and rugged background cave walls stretching overhead. Seen from low eye level, only the sheer vertical rock faces of the cliffs are visible against the background cavern interior, with no visible top platforms. On the arena floor along the base of the cliffs grow conical ringed brown stalagmites, purple umbrella mushrooms with icy-blue drips, red-orange tube fungi, and tiny glowing teal sprouts. In the center, the cave passage recedes deep into the shadowy cavern. 16:9 aspect ratio, retro pixel art, crisp pixel cluster shading, low-angle perspective, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Las Stalagmitów (Stalagmite Grove)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a dark cave chamber full of stalagmites, first-person battle perspective. The lower half features a flat brown earth floor with dark pebble texture and sparse dark green moss. In the background, a natural grove of conical ringed brown stalagmites of various sizes rising from the rocky floor, rugged brown rock walls with twisted roots, one massive purple umbrella mushroom with icy-blue drips glowing softly in the background, clusters of coral-like red-orange tube fungi near the walls, and deep black shadows above. 16:9 aspect ratio, retro pixel art, crisp pixel detailing, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Płaskowyże ze Schodami (Cave Plateaus)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of an underground cavern with stepped rock plateaus, low eye-level battle perspective. In the foreground, a flat brown earth floor with pebble texture and dark green moss. Far behind it, in the distance near the back wall, rises a wide raised rock plateau with a vertical cliff face of brown rock wrapped in twisted root curls, its flat top covered in smooth brown earth and moss, reached by natural earthen stairs carved into the cliff side. In the background, a second narrower raised rock ledge with carved steps, giant purple umbrella mushrooms with icy-blue drips, red-orange tube fungi along the edges, and conical ringed stalagmites at the base of the cliffs. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Półka nad Rozpadliną (Ledge Over a Pit)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a subterranean cavern with a sunken floor and a high rock ledge, first-person battle perspective. The front lower level is a flat brown earth floor with moss and pebble textures. Far back in the distance, near the back wall, a broad flat earthen ledge rises a few steps higher, edged by a low brown rock cliff with exposed roots, reached by carved earthen steps at the side. In the background, a rugged rock wall with an upper shelf, a towering purple umbrella mushroom with icy-blue drips and a twisted blue-grey stem glowing softly, red-orange tube fungi on the cliff tops, and teal-tipped glowing sprouts. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

### 2. Miasto — Karczma (town / tavern)
> [!NOTE]
> **Plan na strefę miasta:** Miasto (miejski hub) będzie w przyszłości budowane ręcznie jako dedykowany layout mapy w Godocie. Docelowe prompty dla plenerów miasta (ulice, rynek, bramy pod barierą) powstaną w przyszłości na bazie gotowego layoutu miasta.
> Poniższe prompty reprezentują wnętrze **Karczmy / Tawerny (`tavern`)** z paczki Pixel Crawler, która pełni rolę gospody w mieście (sceneria do walk wewnątrz budynków, odpoczynku i plotek).

- **Referencja z paczki:** `assets/pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/MockUps/Tavern.png`
- **Materiały i paleta:** drewniana podłoga z desek, **beżowe tynkowane ściany z ciemnymi drewnianymi belkami**, kuchnia z szarego kamienia (piec chlebowy z cegły, okap, blaty), żelazne żyrandole ze świecami, stojące pochodnie z czerwonym płomieniem, stoły z **czerwonymi i niebieskimi obrusami** i pieczystym, bar z butelkami, drewniane schody, **podwyższenie jadalni** ze schodkami i oknami, głowy niedźwiedzia i wilka na ścianie, miecze, rośliny w donicach, magentowe kwiaty, zielony dywan, pokoje na piętrze.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/tavern/`

#### Wariant 1: Sala Biesiadna (Feast Hall)
*Referencja:* `Tavern.png`
```text
A 16-bit pixel art JRPG battle background of a lively medieval fantasy tavern feast hall, low-angle first-person battle perspective. The lower half features a spacious flat floor of warm polished wooden planks with gentle amber light reflections. In the background, beige plastered walls framed by dark wooden timber beams, long feast tables draped in red and blue tablecloths laden with roast meats and ceramic tankards, heavy iron chandeliers with glowing candles hanging from wooden rafters, standing iron torches with red flames, mounted bear and wolf trophy heads with crossed swords on the wall, potted plants and magenta flowers, and small leaded glass windows. 16:9 aspect ratio, retro pixel art, warm cozy tavern palette, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Przy Barze (By the Bar)
*Referencja:* `Tavern.png`
```text
A 16-bit pixel art JRPG battle background facing a rustic fantasy tavern bar counter, eye-level battle perspective. The lower half is a flat floor of warm wooden floorboards with a green runner rug at one side. In the background, a sturdy dark oak bar counter lined with red-cushioned stools, shelves stacked with colorful glass liquor bottles and earthenware jugs, a heavy studded wooden door, beige plastered walls with dark timber studs, iron chandeliers with glowing candles, standing torches with red flames, a small dining table with a red tablecloth, and potted green plants. 16:9 aspect ratio, retro pixel art, rich tavern details, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Kuchnia (Kitchen)
*Referencja:* `Tavern.png` (lewa górna część)
```text
A 16-bit pixel art JRPG battle background of a medieval tavern kitchen and bakery, first-person battle perspective. The lower half features a flat floor of grey stone slabs with generous combat space. In the background, a massive brick bread oven with a glowing orange mouth, an iron stove under a wide stone hood, heavy wooden prep counters bearing bread loaves, baskets of red apples and cuts of meat, hanging copper pots and cooking utensils, shelves lined with ingredient jars, wooden barrels and grain sacks in the corners, and a small square window letting in daylight. 16:9 aspect ratio, retro pixel art, warm culinary hearth aesthetic, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Podwyższenie Jadalni (Raised Dining Floor)
*Referencja:* `Tavern.png` (prawa górna część)
```text
A 16-bit pixel art JRPG battle background of a tavern with an elevated dining floor, low eye-level battle perspective. The front lower level is a flat floor of warm polished wooden planks. Far back in the distance, near the back wall, a broad raised wooden dining platform a few steps higher, with a clean straight front ledge of dark wooden planks, reached by short wooden stairs at the side, with round dining tables and chairs positioned only at the outer ends to leave a clear elevated battle platform. In the background, beige plastered walls with dark timber beams, small square windows with pale blue glass, potted plants, mounted trophy heads, and iron candle chandeliers. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Schody na Piętro (Stairs to the Rooms)
*Referencja:* `Tavern.png`
```text
A 16-bit pixel art JRPG battle background of a tavern great hall with an upper guest room gallery, first-person battle perspective. The front level features a flat floor of warm wooden planks. Far back in the distance, near the back wall, a broad wooden landing rises a few steps across the hall, and in the background a long wooden balcony gallery runs along the back wall with a simple railing, reached by a wooden staircase at the side, leading to wooden bedroom doors. Beige plastered walls with dark beams, standing torches with red flames, iron chandeliers with candles, crossed swords and mounted animal heads below the gallery, and potted plants with magenta flowers at the landing edges. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

### 3. Kryjówka (hideout)
- **Referencja z paczki:** `assets/pixel_crawler/environments/hideout/Pixel Crawler - Hideout/Social/MockUp_01.png`
- **Materiały i paleta:** posadzka z **ciemnego szarozielonego bruku**, rama z ciemnych drewnianych słupów i belek, ściany z ciemnej omszałej kamiennej cegły, zieleń wdzierająca się przy krawędziach i ciemny las wokół, wielkie **leżące beczki na wino z ciemnofioletowymi plamami** na posadzce, świece na ścianach z pomarańczową poświatą, **podarte białawe chorągwie z czerwoną czaszką**, beżowe posłania, kamienny krąg ogniska, stół z kuflami i zielonymi butelkami, skrzynki ze **świecącymi zielonymi eliksirami**, okuta skrzynia, worki, pajęczyny, dziura w dachu ze snopem światła dnia, drewniane schody, mała żelazna klatka, zabite deskami okna.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/hideout/`

#### Wariant 1: Sala Beczek (Barrel Hall)
*Referencja:* `MockUp_01.png` (prawa górna część)
```text
A 16-bit pixel art JRPG battle background inside a rogue smugglers' underground hideout, low-angle first-person battle perspective. The lower half features a flat floor of dark grey-green cobblestones with deep purple wine stains and ample battle space. In the background, a sturdy wall of dark mossy stone bricks framed by dark timber posts and beams, a reinforced wooden door flanked by two wall candles casting warm orange glow, massive oak wine barrels lying on their sides along the wall, a small hanging iron cage, boarded-up cellar windows, cobwebs in the corners, and green leaves creeping in through wall crevices. 16:9 aspect ratio, retro pixel art, gritty underworld palette, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Kwatera z Ogniskiem (Campfire Quarters)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a bandit underground encampment and sleeping quarters, eye-level battle perspective. The lower half is a flat floor of dark grey-green cobblestones centered around a circular stone campfire ring with charred embers. In the background, low cots with beige bedrolls lining the dark mossy brick wall, a rustic wooden table with tin tankards, plates, and green glass bottles, tattered off-white banners bearing a red skull emblem hanging between timber posts, wall candles casting warm orange light, hanging spiderwebs, and dark foliage encroaching from outside. 16:9 aspect ratio, retro pixel art, atmospheric shadows, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Magazyn Eliksirów (Potion Storeroom)
*Referencja:* `MockUp_01.png` (lewa dolna część)
```text
A 16-bit pixel art JRPG battle background of a smugglers' contraband storeroom, first-person battle perspective. The lower half features a flat dark grey-green cobblestone floor with spilled dark purple vintage stains. In the background, wooden crates stacked with glowing neon-green potion bottles, a crate of purple elixir vials, an iron-bound wooden treasure chest, small barrels and grain sacks resting against dark mossy brick walls, broken timber planks leaning on the wall, cobwebs in dark corners, and a dramatic beam of warm golden daylight streaming down through a collapsed hole in the wooden ceiling. 16:9 aspect ratio, retro pixel art, dynamic lighting contrast, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Schody na Antresolę (Loft Stairs)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a bandit hideout with an elevated wooden loft, low eye-level battle perspective. The front lower level is a flat floor of dark grey-green cobblestones. Far behind it, in the distance near the back wall, rises a wide raised wooden platform of dark planks on heavy timber posts, reached by a sturdy wooden staircase at the side, with giant wine barrels lying only at its outer ends, creating an elevated second combat tier. In the background, a narrow wooden loft gallery with a simple timber railing runs along the dark mossy brick wall, with tattered red-skull banners hanging below it, wall candles with warm glow, and creepers entering from above. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Zawalona Izba (Collapsed Room)
*Referencja:* `MockUp_01.png` (lewa górna część)
```text
A 16-bit pixel art JRPG battle background of a half-collapsed underground hideout hall, first-person battle perspective. The front level is a flat floor of dark grey-green cobblestones. Far back in the distance, near the back wall, a broad raised plateau of packed earth and fallen stone debris, secured by a row of broken wooden planks and reached by a ramp at the side, provides a second elevated fighting platform. In the background, a raised stone floor of an adjoining room is visible through a shattered brick wall, framed by angled fallen timber beams, stacked grain sacks, cobwebs, green vines growing in from outside, and bright yellow sunlight pouring through a collapsed ceiling gap. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

---

### 4. Kanały (sewer)
- **Referencja z paczki:** `assets/pixel_crawler/environments/sewer/Social/MockUp-01.png`, `MockUp-02.png`, `MockUp-Extended.png` (wersja rozszerzona — suche kanały bez ścieków)
- **Materiały i paleta:** posadzka z **ciemnobrązowej cegły**, prawie czarne ściany z panelami ciemnozielonych kafli, łupkowe filary z małymi miedzianymi lampkami, **półokrągłe miedziane kraty odpływów**, okrągłe miedziane wyloty rur, miedziane barierki, wysokie pionowe rury, duże prostokątne miedziane kratki w posadzce, kładki z desek, skrzynie, beczki z niebieskimi obręczami, worki i gliniane dzbany, schody/drabina do włazu, stół z krzesłami, drobne odpływy w romby, ciemnozielone kępy liści w kątach.
  - **Dwa typy kanałów do wyboru:**
    - **Kanały ze ściekami (`MockUp-01.png`):** koryta z **jaskrawym limonkowym szlamem**,
    - **Suche kanały odpływowe (`MockUp-Extended.png`, `MockUp-02.png`):** koryta bez ścieków, wyłożone **ciemnoturkusowymi/morskimi kafelkami**, z głębokimi otworami odpływowymi i drewnianymi kładkami.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/sewer/`

#### Wariant 1: Skrzyżowanie Kanałów (Canal Junction — ze szlamem)
*Referencja:* `MockUp-01.png`
```text
A 16-bit pixel art JRPG battle background of a subterranean city sewer canal junction, low-angle first-person battle perspective. The lower half features a damp dark brown brick walkway embedded with a large rectangular copper floor drainage grate. In the background, a flat channel of glowing toxic lime-green sludge flowing horizontally behind a sturdy copper pipe railing, crossed by a flat wooden plank bridge. Along the near-black brick walls, dark green tile wainscoting panels, semicircular copper-arched drain grates, circular copper pipe outlets, tall vertical copper conduits, dark slate pillars with small copper oil sconces, and patches of green moss in the damp corners. 16:9 aspect ratio, retro pixel art, industrial sewer palette, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Hala Krat (Grate Hall — suche kanały)
*Referencja:* `MockUp-02.png`
```text
A 16-bit pixel art JRPG battle background of a subterranean sewer drainage hall, eye-level battle perspective. The lower half is a flat floor of dark brown bricks embedded with large rectangular copper floor grates and diamond-pattern drainage holes. In the background, a repeating row of semicircular copper-arched drain grates set into a near-black brick wall lined with dark green ceramic tiles, dark slate pillars mounted with small copper wall lamps, an iron-framed maintenance hatch, stacked wooden storage crates and a chest, and green moss creeping along the damp stone base, dry floor with no sludge. 16:9 aspect ratio, retro pixel art, moody subterranean depth, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Posterunek w Kanałach (Sewer Outpost — suche kanały)
*Referencja:* `MockUp-Extended.png` (lewa dolna część) lub `MockUp-02.png`
```text
A 16-bit pixel art JRPG battle background of a dry maintenance outpost alcove in the subterranean sewers, first-person battle perspective. The lower half features a flat floor of dark brown bricks with diamond drainage perforations. In the background, a crude wooden table with chairs, clay urns and earthenware pots, wooden barrels bound with blue iron hoops, grain sacks, a wooden staircase leading up to an exit hatch between slate pillars with copper sconces, near-black walls with dark green tiles, round copper pipe outlets, tall vertical copper pipes, stacked crates, and damp dark green leaves creeping along masonry, completely dry with no sludge. 16:9 aspect ratio, retro pixel art, crisp pixel cluster shading, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Suche Koryto z Kładką (Dry Tiled Canal & Bridge)
*Referencja:* `MockUp-Extended.png`
```text
A 16-bit pixel art JRPG battle background of a subterranean dry sewer drainage canal with stepped walkways, low eye-level battle perspective looking straight ahead from the brick walkway floor. The front lower level is a flat floor of dark brown bricks with a large rectangular copper floor grate and diamond drainage perforations. Across a wide dry sunken drainage channel paved with dark teal ceramic tiles and crossed by a sturdy wooden plank bridge, rises a raised brick walkway a few steps higher with a copper pipe railing. In the background against near-black brick walls, dark green tile wainscoting panels, semicircular copper-arched drain grates, vertical copper pipes, slate pillars mounted with glowing copper oil lamps, and dark green leaves creeping in damp corners, with completely dry channels and no green sludge. 16:9 aspect ratio, retro pixel art, crisp pixel cluster shading, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Podest Konserwatorów (Maintenance Platform — ze szlamem)
*Referencja:* `MockUp-01.png`
```text
A 16-bit pixel art JRPG battle background of a sewer chamber with an elevated maintenance platform, first-person battle perspective. The front level features a flat floor of dark brown bricks with a large copper drainage grate. Far behind it, in the distance near the back wall, rises a wide raised brick staging platform with a copper pipe railing along its front edge, reached by wooden stairs at the side, with stacked wooden crates and blue-hooped barrels at its outer corners. In the background, a narrow upper ledge runs along the near-black wall under tall vertical copper pipes and circular outlets, with a channel of lime-green sludge visible below the platform. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

### 5. Cmentarz (cemetery)
- **Referencja z paczki:** `assets/pixel_crawler/environments/cemetery/Pixel Crawler - Cemetery/Environment/Props/Graves.png`, `Props.png`, `Tree.png`, `Structures/Roof.png`
- **Materiały i paleta:** szare kamienne nagrobki (zaokrąglone, prostokątne, z krzyżem), kamienne i żelazne krzyże (jeden czerwony), kamienne płyty grobowe i sarkofagi z czerwonymi wstawkami, małe kapliczki z daszkiem, ozdobne złote drzwi mauzoleum, drewniane trumny, łopata, kopczyki ziemi, oliwkowożółty suchy krzak, małe posągi (aniołek, kostucha z kosą), wysokie ciemnozielone świerki i brązowe uschnięte świerki, dachy z gontu w ciemnej zieleni na drewnianej ramie, drewniane drzwi, łukowe przejście, szare kłęby mgły; chłodny ciemny łupkowo-niebieski ton.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/cemetery/`

#### Wariant 1: Rzędy Nagrobków (Rows of Graves)
*Referencja:* `Graves.png`, `Tree.png`
```text
A 16-bit pixel art JRPG battle background of a gothic graveyard at midnight, low-angle first-person battle perspective. The lower half features a flat floor of dark muddy soil and short withered grass with cold grey ground fog rolling across. In the background, orderly rows of weathered grey stone headstones (rounded, rectangular, and cross-topped), tilted stone crosses, one ornate iron red cross, flat stone grave slabs with small red inlays, fresh dirt mounds, an olive-yellow dry bush, tall dark green spruce trees and withered brown pines, and a pale crescent moon illuminating the scene in a cold slate-blue sky. 16:9 aspect ratio, retro pixel art, dark atmospheric gothic palette, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Przed Mauzoleum (Mausoleum Door)
*Referencja:* `Props.png`, `Structures/Roof.png`
```text
A 16-bit pixel art JRPG battle background in front of an ancient stone mausoleum, eye-level battle perspective. The lower half is a flat floor of dark soil and cracked grey flagstones with drifting pale fog. In the background, a solemn grey stone mausoleum with a dark green shingle roof on a wooden timber frame and an ornate golden door, small gabled grave shrines on both sides, carved stone sarcophagi with red inlays, a small stone mourning angel statue, a carved stone reaper statue holding a scythe, tilted headstones, dark green spruces, and cold slate-blue night air. 16:9 aspect ratio, retro pixel art, somber cemetery mood, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Świeże Groby (Open Graves)
*Referencja:* `Props.png`
```text
A 16-bit pixel art JRPG battle background of a burial clearing at the edge of a cemetery, first-person battle perspective. The lower half features a flat ground of dark earth with patches of dead grass and cold mist. In the background, open wooden coffins resting beside fresh mounds of dark soil, an iron shovel stuck upright in the ground, weathered grey headstones and wooden crosses, a small gabled grave shrine, an olive-yellow dead shrub, tall withered brown spruces and dark pines against a cold dark slate-blue sky with drifting fog. 16:9 aspect ratio, retro pixel art, eerie graveyard aesthetic, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Cmentarne Tarasy (Graveyard Terraces)
*Referencja:* `Graves.png`, `Tree.png`
```text
A 16-bit pixel art JRPG battle background of a terraced graveyard on a gothic hillside, low eye-level battle perspective. The front lower level is a flat ground of dark earth with dead grass and rolling ground fog. Far behind it, in the distance near the back wall, rises a wide raised cemetery terrace supported by a low grey stone retaining wall, reached by worn stone steps in the center, its flat dark earth top holding grey headstones and crosses at its outer ends to provide an elevated battle platform. In the background, a narrow upper terrace features a small grey stone mausoleum with a dark green shingle roof and a golden door, stone sarcophagi with red inlays, and dark spruces against a midnight slate-blue sky with a pale moon. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Krypta pod Kaplicą (Crypt Steps)
*Referencja:* `Props.png`, `Structures/Roof.png`
```text
A 16-bit pixel art JRPG battle background of a sunken crypt yard in front of a cemetery chapel, first-person battle perspective. The front level features flat cracked grey flagstones with low pale fog. Far behind it, in the distance near the back wall, rises a broad raised stone platform with a straight front edge, reached by stone steps on both sides, with stone sarcophagi with red inlays resting only at its outer ends. In the background, the stone porch of a small chapel with a dark green shingle roof on a timber frame and an arched doorway, flanked by a stone reaper statue with a scythe, a small stone angel, grey crosses, and dark spruces under cold slate-blue starlight. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

---

### 6. Baśniowy Las (fairy_forest) — też las generowany (`forest`)
- **Referencja z paczki:** `assets/pixel_crawler/environments/fairy_forest/Pixel Crawler - Fairy Forest 1.7/Social/MockUp_01.png` … `MockUp_04.png`
- **Materiały i paleta:** głębokie ciemne zielenie, korony z warstwowych kęp liści: ciemnozielone, **turkusowo-niebieskie** i **liliowo-fioletowe**, rdzawopomarańczowe krzewy, grube skręcone brązowe pnie, **zaokrąglone szaroniebieskie kamienie runiczne z jednym świecącym turkusowym okiem**, turkusowa mgła przy ziemi, drobne białe kwiatki i pomarańczowe gwiazdki, pomarańczowe huby na pniach, czerwone muchomory, zielone pnącza z beżowymi dzwonkami, **świecące fioletowe kwiaty-trąbki z turkusowym słupkiem**, jaskrawoniebieski potok, trawiaste skarpy, stary pniak, skośne smugi światła.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/fairy_forest/`

#### Wariant 1: Polana Kamieni Runicznych (Runestone Glade)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a mystical fairy forest glade at twilight, low eye-level battle perspective. The lower half features a flat dark green grass ground sprinkled with tiny white wildflowers, small orange star-shaped flowers, and patches of glowing teal ground mist. In the background, rounded blue-grey ancient runestones, each pulsing with a single glowing turquoise eye-gem, standing in soft pools of teal light. Colossal ancient trees with twisted brown trunks and layered canopies in dark green, teal-blue, and lilac-purple, a rust-orange bush beside an old tree stump, and orange bracket fungi clinging to tree bark. 16:9 aspect ratio, retro pixel art, enchanting fantasy palette, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Brzeg Potoku (Streamside)
*Referencja:* `MockUp_02.png` / `MockUp_03.png`
```text
A 16-bit pixel art JRPG battle background on a grassy bank beside a magical forest stream, first-person battle perspective. The lower half is a flat lush dark green grassy clearing with tiny white blossoms. In the background, a bright azure-blue stream winding across the scene with smooth stepping stones, a majestic tree with vibrant lilac-purple foliage, glowing purple trumpet flowers with turquoise pistils growing along the water's edge, curly green vines with beige bell flowers climbing tree trunks, smooth grey river stones, and red-capped toadstools on thin stems under a dense emerald canopy. 16:9 aspect ratio, retro pixel art, rich vibrant foliage, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Gęstwina w Smugach Światła (Sunbeam Thicket)
*Referencja:* `MockUp_04.png`
```text
A 16-bit pixel art JRPG battle background deep inside a dense enchanted forest clearing, low-angle battle perspective. The lower half is a flat dark green grass floor with tiny white wildflowers and scattered grey mossy stones. In the background, a thick wall of layered foliage and massive gnarled brown trunks with orange bracket fungi, dramatic diagonal shafts of soft golden sunlight piercing down through the leafy canopy, red-capped toadstools on thin stems, curly green vines climbing ancient trunks, glowing purple trumpet flowers with turquoise pistils, and gentle floating spores in the air. 16:9 aspect ratio, retro pixel art, atmospheric lighting, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Leśne Skarpy (Forest Ledges)
*Referencja:* `MockUp_01.png` / `MockUp_03.png`
```text
A 16-bit pixel art JRPG battle background of an enchanted forest with stepped grassy ledges, first-person battle perspective. The front lower level is a flat dark green grass ground with tiny white flowers. Far behind it, in the distance near the back wall, rises a wide raised grassy ledge with a vertical face of exposed brown earth and roots, reached by a gentle earthen slope at the side, with glowing purple trumpet flowers with turquoise pistils along its front edge. In the background, a second higher grassy shelf holds a rounded blue-grey runestone glowing with a single turquoise eye in teal mist, framed by ancient trees with lilac-purple and teal-blue canopies and a rust-orange bush. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Tarasy nad Potokiem (Terraces Above the Stream)
*Referencja:* `MockUp_02.png`
```text
A 16-bit pixel art JRPG battle background of stepped forest terraces above a blue stream, low eye-level battle perspective. The front level features a flat grassy bank dotted with tiny white and orange wildflowers. Across a narrow bright blue stream with flat stepping stones rises a middle grassy terrace with a low exposed brown earth bank. In the background, a higher elevated grassy shelf sits beneath massive ancient trees with lilac-purple, teal-blue, and deep green crowns, curly green vines with beige bell flowers, glowing purple trumpet flowers with turquoise pistils, and orange bracket fungi on thick tree trunks. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

---

### 7. Pustynia (desert)
- **Referencja z paczki:** `assets/pixel_crawler/environments/desert/Social/MockUp-01-export.png`, `MockUp-02.png`, `MockUp-03.png`
- **Materiały i paleta:** **nasycony pomarańczowy piasek** z plamami rdzawobrązowego żwiru, grzbiety czerwonobrązowej skały o słupowych ścianach, płaskie mesy, głazy z otworami jaskiń, olbrzymie zakrzywione kły i żebra z kości słoniowej, zielone kaktusy kolumnowe i beczkowate, szarofioletowe drzewka z fioletowymi pąkami, suche krzaki z patyków. Świątynia: złocisty piaskowiec z **turkusowymi / lazurowymi pasami**, filary z niebieskimi klejnotami, szerokie schody z niebieskimi pasami, obelisk z niebieskimi znakami, niebiesko-złote dzbany, wyłom w murze. (Piasek pomarańczowy, kolumny złociste z niebieskim!).
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/desert/`

#### Wariant 1: Wąwóz Kłów (Tusk Canyon)
*Referencja:* `MockUp-01-export.png`
```text
A 16-bit pixel art JRPG battle background of a sun-scorched desert canyon floor, low-angle first-person battle perspective. The lower half is a wide flat arena of saturated orange sand with patches of darker rust-brown gravel and small scattered stones. In the background, towering red-brown rock ridges with vertical columnar cliff faces, a dark cave mouth in the rock, colossal curved ivory tusks and rib bones jutting dramatically from the sand dunes, rounded green columnar and barrel cacti, bare grey-violet dead trees with tiny purple buds, dry brown stick bushes, and a pale hazy sky above the ridges. 16:9 aspect ratio, retro pixel art, warm saturated orange palette, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Kotlina z Kolumnami (Pillar Hollow)
*Referencja:* `MockUp-02.png`
```text
A 16-bit pixel art JRPG battle background of a circular desert basin ringed by red rock cliffs, eye-level battle perspective. The lower half features a flat floor of saturated orange sand with rust-brown gravel patches. In the background, a curved wall of red-brown columnar rock formations, two lone golden sandstone column stumps inlaid with glowing blue gems standing on the rim, huge curved ivory tusks half-buried in the sand, rounded green cacti in small clusters, dry brown stick bushes, a bare grey-violet tree with purple buds, and warm golden afternoon sunlight. 16:9 aspect ratio, retro pixel art, crisp pixel cluster shading, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Przed Świątynią (Temple Forecourt)
*Referencja:* `MockUp-03.png`
```text
A 16-bit pixel art JRPG battle background in front of ruined desert temple walls, low eye-level battle perspective. The lower half consists of flat saturated orange sand with rust-brown gravel and scattered broken sandstone blocks. In the background, a monumental wall of golden sandstone bricks trimmed with turquoise and lapis-blue decorative stripes, stone pillars inlaid with blue gems, a dark breach broken through the masonry, a tall obelisk etched with glowing blue glyphs, blue-and-gold clay urns resting near the wall, small pyramid-shaped stone markers, and red-brown rock ridges under a hazy desert sky. 16:9 aspect ratio, retro pixel art, clean pixel detailing, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Schody Świątyni (Temple Terraces)
*Referencja:* `MockUp-03.png`
```text
A 16-bit pixel art JRPG battle background of an ancient desert temple on stepped terraces, first-person battle perspective. The front lower level is a wide flat floor of saturated orange sand with rust-brown gravel. Far back in the distance, near the back wall, a broad golden sandstone terrace with a low wall trimmed with turquoise and lapis-blue stripes, reached by wide sandstone stairs with blue-striped risers, providing an elevated second battle platform paved with sandstone slabs. Above and behind it in the background, an upper temple terrace with pillars inlaid with blue gems, an obelisk with blue glyphs, blue-and-gold urns, and red-brown rock cliffs at the sides under a pale hazy sky. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Skalne Półki (Rock Ledges)
*Referencja:* `MockUp-01-export.png`
```text
A 16-bit pixel art JRPG battle background of stepped red rock ledges in a desert canyon, low eye-level battle perspective. The front level features a flat ground of saturated orange sand with rust-brown gravel. Far behind it, in the distance near the back wall, rises a broad flat-topped ledge of red-brown rock with a vertical columnar cliff face and an orange sand top surface, reached by a gentle sandy ramp at the side. In the background, a second higher rock shelf with a dark cave opening, colossal curved ivory tusks jutting from the base of the cliffs, rounded green cacti, bare grey-violet trees with purple buds, and flat-topped rock mesas on the horizon under a hazy sky. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

---

### 8. Kuźnia (forge)
- **Referencja z paczki:** `assets/pixel_crawler/environments/forge/Social/MockUp-00.png`, `MockUp-01.png`, `MockUp-02.png`
- **Materiały i paleta:** posadzka z **przydymionych fioletowoszarych płyt** o skośnej fakturze, szarobeżowe kamienne obrzeża, ściany z **ciemnoczerwonej cegły z cienkimi żarzącymi się pomarańczowymi szczelinami**, kamienne pilastry z rombami o pomarańczowym rdzeniu, wąskie łukowe okna z pomarańczowymi kratami w jodełkę, duże wrota z żarzącymi się prętami w jodełkę, płaskie baseny pomarańczowej lawy z kamiennymi blankami, metalowe kraty-mosty w pomarańczową szachownicę, płyta w pomarańczowo-czarne skośne pasy ostrzegawcze, kamienne posągi brodatych krasnoludów, ceglane piece-słupy z czapą, maszyny ścienne z brązowymi kołami zębatymi, beczki z wodą, kałuże, bordowa pustka z pomarańczowymi liniami.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/forge/`

#### Wariant 1: Sala przed Wrotami (Chevron Gate Hall)
*Referencja:* `MockUp-00.png`
```text
A 16-bit pixel art JRPG battle background of a symmetrical dwarven forge hall, low eye-level first-person battle perspective. The lower half features a flat floor of smoky purple-grey stone tiles with a subtle diagonal texture, edged by grey-beige stone walkways, centered around an orange-and-black diagonal hazard-striped floor plate. In the background, dark red brick walls laced with thin glowing orange seams, a monumental arched gateway with glowing orange chevron bars, narrow arched windows with orange chevron grilles, stone pilasters with glowing orange diamond cores, two rectangular pools of molten orange lava with stone crenellations at the sides, and red-brick furnace pillars with stone caps. 16:9 aspect ratio, retro pixel art, vivid molten orange and charcoal contrast, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Jezioro Lawy z Posągami (Lava Lake Statues)
*Referencja:* `MockUp-01.png`
```text
A 16-bit pixel art JRPG battle background of a subterranean dwarven forge beside a lava lake, eye-level battle perspective. The lower half consists of a flat floor of smoky purple-grey stone tiles with diagonal texture and dark blue water puddles. In the background, an expansive lake of glowing orange molten lava bordered by small stone crenellations, two monumental carved stone statues of bearded dwarven smiths standing in the magma, red-brick furnace pillars on stone pedestals, wooden barrels with copper hoops, and dark red brick walls with glowing orange seams and arched chevron windows under a dark maroon vaulted ceiling. 16:9 aspect ratio, retro pixel art, fiery atmospheric lighting, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Hala Maszyn (Machine Hall)
*Referencja:* `MockUp-02.png`
```text
A 16-bit pixel art JRPG battle background of a dwarven machinery forge hall, first-person battle perspective. The lower half features a flat floor of smoky purple-grey stone tiles with a diagonal texture and dark blue puddles. In the background, towering organ-like wall machines with bronze cog wheels and vertical rows of glowing orange bars flanked by stone pilasters with diamond ornaments, dark red brick walls with glowing orange heat seams, a large arched gateway with glowing orange chevron bars, stone dwarf statues at the sides, iron-bound crates, and red-brick furnace pillars with stone caps. 16:9 aspect ratio, retro pixel art, crisp mechanical pixel detailing, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Pomosty nad Lawą (Grate Bridges Over Lava)
*Referencja:* `MockUp-01.png` / `MockUp-02.png`
```text
A 16-bit pixel art JRPG battle background of a volcanic forge with stepped walkways over lava, low eye-level battle perspective. The front lower level is a flat floor of smoky purple-grey stone tiles. Across a wide channel of flat molten orange lava, a broad metal grate bridge with an orange checkerboard pattern leads up a few stone steps to a raised stone platform of purple-grey tiles edged with small stone crenellations, forming an elevated second battle tier. In the background against the dark red brick wall with glowing orange seams, a narrow upper stone ledge sits before a large arched gateway with glowing orange chevron bars, flanked by stone dwarf statues and furnace pillars. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Podesty Pieców (Furnace Platforms)
*Referencja:* `MockUp-01.png`
```text
A 16-bit pixel art JRPG battle background of a dwarven forge with stepped furnace platforms, first-person battle perspective. The front level features a flat floor of smoky purple-grey stone tiles with an orange-and-black hazard-striped plate. Far behind it, in the distance near the back wall, rises a broad raised platform of lighter grey-beige stone, reached by short stairs on both sides, with red-brick furnace pillars with stone caps standing at its outer corners. In the background, a higher stone balcony runs along the dark red brick wall beneath bronze cog machines with glowing orange bars, overlooking pools of molten orange lava below the platforms. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

---

### 9. Biblioteka (library)
- **Referencja z paczki:** `assets/pixel_crawler/environments/library/Social/MockUp_01.png`
- **Materiały i paleta:** **ciepły terakotowo-pomarańczowy parkiet w jodełkę**, ciemna turkusowa szachownica w środkowej sali, długi turkusowy chodnik w złote romby z frędzlami, **turkusowe kolumny ze złotymi głowicami**, antresole z ciemnego drewna z tralkami i szerokie drewniane schody pośrodku, wnęki regałów z małymi złotymi tabliczkami (bez napisów), drewniane biurka ze złotymi kandelabrami na trzy świece i turkusowe krzesła, stosy czerwonych, niebieskich i zielonych książek, krzewy w donicach ze złotym obszyciem, wysokie okno z bladoniebieskiego szkła w złotą kratę między turkusowymi zasłonami, turkusowe łukowe drzwi ze złotem, wiszące złote latarnie z turkusowym szkłem, turkusowo-złota skrzynia, pomarańczowe ławy.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/library/`

#### Wariant 1: Czytelnia (Reading Hall)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a grand arcane library reading hall, low-angle first-person battle perspective. The lower half features a flat floor of dark teal checkerboard tiles centered with an ornate teal carpet runner patterned with gold diamonds. In the background, heavy wooden study desks equipped with three-candle gold candelabras and teal-backed chairs, stacks of red, blue, and green leather-bound books, potted shrubs in gold-trimmed planters, elegant teal columns with polished gold capitals, dark wood bookshelf alcoves with small blank gold index plates, warm terracotta-orange herringbone parquet bordering the walls, and hanging gold lanterns with teal glass. 16:9 aspect ratio, retro pixel art, rich jewel-toned palette, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Pod Wielkim Oknem (Under the Great Window)
*Referencja:* `MockUp_01.png` (górna część)
```text
A 16-bit pixel art JRPG battle background of a grand library entrance hall, eye-level battle perspective. The lower half is a flat floor of warm terracotta-orange herringbone parquet. In the background, a monumental arched window of pale blue leaded glass with an intricate gold lattice, flanked by draped heavy teal curtains. On either side, stately teal columns with gold capitals, a teal arched doorway with gold geometric trim, hanging brass lanterns with glowing teal glass, potted shrubs in gold-trimmed planters, small orderly stacks of colorful books on the floor, and tall dark wood bookcases lining the walls under soft daylight. 16:9 aspect ratio, retro pixel art, clean pixel cluster shading, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Aleja Regałów (Shelf Aisle)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a grand library archive aisle, first-person battle perspective. The lower half features a flat floor of dark teal checkerboard tiles bordered by warm terracotta-orange herringbone parquet. In the background, towering dark wood bookshelf alcoves filled with rows of red, blue, and green books, each alcove framed by small blank gold plaques, polished teal columns with gold capitals standing between bookshelves, long orange-cushioned benches, an ornate teal-and-gold treasure chest, three-candle brass candelabras on small pedestals, and hanging golden lantern chandeliers. 16:9 aspect ratio, retro pixel art, scholarly atmosphere, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Schody na Antresolę (Mezzanine Stairs)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a grand two-story library with a central staircase and mezzanine, low eye-level battle perspective. The front lower level is a flat floor of dark teal checkerboard tiles with a gold-diamond teal rug. Far back in the distance, near the back wall, a broad wooden staircase rises in the center to a wide mezzanine gallery of warm terracotta herringbone parquet with a dark wood balustrade across the back, providing an elevated second battle platform. In the background, tall bookshelf alcoves, teal columns with gold capitals, a high geometric window of pale blue glass in a gold frame draped with teal curtains, and hanging gold lanterns above the gallery. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Podest Czytelni (Reading Dais)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of an arcane library hall with a raised reading dais, first-person battle perspective. The front level features a flat floor of warm terracotta-orange herringbone parquet. Far behind it, in the distance near the back wall, rises a wide raised dais of dark teal checkerboard tiles with a low dark wood balustrade along its front edge, reached by short wooden steps at both sides, with study desks and three-candle gold candelabras positioned only at the far ends. In the background, a narrow upper gallery along the back wall features bookshelf alcoves with small gold plates, teal columns with gold capitals, and hanging gold lanterns with teal glass. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

---

### 10. Ogród (garden)
- **Referencja z paczki:** `assets/pixel_crawler/environments/garden/Social/MockUp_01.png`
- **Materiały i paleta:** ścieżki z **sześciokątnych jasnoszaro-liliowych kostek**, ciemnozielony trawnik obrzeżony jaśniejszym żółtozielonym strzyżonym żywopłotem, kolumnowe ciemne cyprysy, **kwadratowe rabaty magenty**, kamienne urny z niebieskimi kwiatami na cokołach, niskie kamienne balustrady, drewniane ławki, ośmiokątna dwupiętrowa kamienna fontanna, długa sadzawka z ząbkowanym kamiennym brzegiem, dwa kamienne posągi nimf lejących wodę, lilie z różowymi kwiatami, drewniane kratownice (trejaże) na tle głębokiego fioletu, kamienne bramy z bluszczem, łuk z żywopłotu.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/garden/`

#### Wariant 1: Plac z Fontanną (Fountain Plaza)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a royal palace garden courtyard, low eye-level first-person battle perspective. The lower half consists of a flat paving of hexagonal light grey-lilac cobblestones framed by neat lawn borders. In the background, an ornate octagonal two-tier stone fountain splashing clear blue water, square magenta flowerbeds bordered by low stone balustrades, stone urns of blue flowers on square pedestals, wooden garden benches, dark green lawns edged with lighter yellow-green trimmed hedges, tall columnar dark green cypress trees, wooden lattice trellises against a deep violet backdrop, and soft natural daylight. 16:9 aspect ratio, retro pixel art, crisp vibrant garden palette, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Sadzawka z Nimfami (Nymph Pool)
*Referencja:* `MockUp_01.png` (dolna część)
```text
A 16-bit pixel art JRPG battle background of a palace garden promenade beside an ornamental pool, eye-level battle perspective. The lower half features a flat walkway of hexagonal light grey-lilac cobblestones in the foreground. In the background, a long reflecting pool with a notched stone rim, two carved stone nymph statues on pedestals pouring streams of water into the pool, round stepping stones and green lily pads with pink blossoms on the water, a stately row of tall columnar dark green cypress trees behind the pool, trimmed yellow-green hedges, and stone urns filled with blue flowers. 16:9 aspect ratio, retro pixel art, peaceful classical aesthetic, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Brama z Trejażami (Trellis Gate)
*Referencja:* `MockUp_01.png` (górna część)
```text
A 16-bit pixel art JRPG battle background at the entrance gate of a walled royal garden, first-person battle perspective. The lower half is a flat paving of hexagonal light grey-lilac cobblestones. In the background, an antique grey stone garden wall with an arched portal overgrown with green ivy, a manicured archway cut through a tall yellow-green hedge, wooden lattice trellises set against a deep violet backdrop, stone urns of blue flowers on pedestals, vibrant square magenta rosebeds, wooden benches, and tall dark cypress trees framing the scene under soft afternoon light. 16:9 aspect ratio, retro pixel art, rich botanical detailing, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Tarasy Ogrodu (Garden Terraces)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a terraced palace garden sanctuary, low eye-level battle perspective. The front lower level is a flat terrace paved with hexagonal light grey-lilac cobblestones. Far behind it, in the distance near the back wall, rises a wide raised stone terrace with a low carved stone balustrade along its front edge, reached by broad stone steps in the center, floored in matching hexagonal cobblestones with square magenta flowerbeds and stone urns of blue flowers at its ends. In the background, an upper garden tier features an octagonal two-tier stone fountain, wooden lattice trellises against a deep violet backdrop, and tall columnar cypress trees. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, stepped battle arena, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Kamienne Stopnie nad Sadzawką (Steps Above the Pool)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of stepped garden terraces overlooking a reflecting pool, first-person battle perspective. The front level features a flat promenade of hexagonal light grey-lilac cobblestones. Across a long reflecting pool with a notched stone rim, stepping stones, and pink water lilies rises a middle stone terrace with trimmed yellow-green hedges. In the background, an elevated upper lawn terrace hosts two carved stone nymph statues pouring water from pitchers, backed by a majestic colonnade of tall dark green cypress trees under a golden afternoon sky. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, multi-tier battle composition, no characters, no monsters, no UI, clean empty scenery.
```

---

---

### 11. Zamek (castle) — finał
- **Referencja z paczki:** `assets/pixel_crawler/environments/castle/Social/MockUp_01.png`, `MockUp_02.png`
- **Materiały i paleta:** ciepły szarobeżowy kamień ścian z gzymsem, posadzka granatowo-indygo w romby (nie szachownica!), czerwone chodniki ze złotym obszyciem, fioletowe proporce ze złotym szpicem, białe kamienne kinkiety ze świecami, terakotowe donice z krzewami, czerwone ławy z wyszytym X, kamienne popiersia na cokołach ze stalowoniebieskimi tabliczkami, gotyckie okna z bursztynowego szkła, czerwony tron, kominek z deskami podłogowymi, tarcze czerwono-żółte w ćwiartki.
- **Folder docelowy:** `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/castle/`

#### Wariant 1: Sala Tronowa (Throne Hall)
*Referencja:* `MockUp_01.png` (prawa część)
```text
A 16-bit pixel art JRPG battle background of a grand medieval castle throne chamber, low-angle first-person battle perspective. In the foreground and lower half, a spacious polished dark stone floor tiled in a navy-indigo diamond pattern, with a wide royal red carpet runner with gold edges leading toward the background. In the background, towering warm grey-beige stone block walls, gothic arched doorways, majestic purple banners with gold trim hanging from carved pillars, potted topiary shrubs in terracotta planters, white stone candle sconces casting warm orange light, and an ornate red throne beneath a glowing amber gothic stained glass window. 16:9 aspect ratio, retro pixel art, crisp pixels, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 2: Galeria Popiersi (Hall of Busts)
*Referencja:* `MockUp_02.png`
```text
A 16-bit pixel art JRPG battle background of an imperial castle gallery of busts, eye-level battle perspective. The bottom half features a spacious navy-indigo diamond-patterned stone floor framed by wide red carpet runners with gold borders along the sides. Along the left and right walls in the background, rows of carved stone portrait busts on stone plinths with steel-blue plaques, narrow stone stelae with arched niches, warm grey-beige stone walls with small arched windows, purple banners with gold trim, red cushioned benches, and white stone candle sconces casting warm flickering light. 16:9 aspect ratio, retro pixel art, clean pixel cluster shading, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 3: Komnata z Kominkiem (Hearth Chamber)
*Referencja:* `MockUp_01.png` (lewa górna część)
```text
A 16-bit pixel art JRPG battle background of a castle hearth chamber and royal study, first-person battle perspective. The lower half is a clean polished warm brown wood plank floor with gentle firelight reflections. In the background against the warm grey-beige stone walls, a massive roaring stone fireplace with a glowing orange hearth mantle, flanked by two tall gothic arched windows of glowing amber glass. Dark wood bookshelves filled with tomes, a wooden study table at the side, dark wooden ceiling beams, white stone candle sconces casting golden light, and quartered red-and-yellow heraldic shields mounted on the walls. 16:9 aspect ratio, retro pixel art, warm atmospheric lighting, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 4 (wielopoziomowy): Podwyższenie Tronu (Throne Dais)
*Referencja:* `MockUp_01.png`
```text
A 16-bit pixel art JRPG battle background of a castle throne hall with a multi-level stepped dais, low eye-level battle perspective. The foreground and lower half features a flat floor of navy-indigo diamond stone tiles with a central red carpet runner with thin gold edges. Far back in the distance, near the back wall, a broad raised stone dais of warm grey-beige stone with a straight horizontal front ledge, accessed by wide stone steps, providing a clean elevated second battle tier floored in matching diamond tiles. At the back of the dais, an ornate red throne set against a tall amber stained-glass window, flanked by purple heraldic banners with gold trim, stone portrait busts on plinths, and warm candle sconces. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, crisp pixel detailing, no characters, no monsters, no UI, clean empty scenery.
```

#### Wariant 5 (wielopoziomowy): Balkon nad Halą (Gallery Balcony)
*Referencja:* `MockUp_02.png`
```text
A 16-bit pixel art JRPG battle background of a castle great hall with an elevated gallery balcony, first-person battle perspective. The lower half features a flat navy-indigo diamond-tiled arena floor with a red carpet border. Far behind it, in the distance near the back wall, rises a wide stone landing reached by a few steps, and in the background a long elevated stone balcony with a low carved parapet stretches across the back wall at mid-height, reached by stone staircases on the left and right. Warm grey-beige stone walls, purple banners with gold trim hanging below the balcony, white stone candle sconces casting warm light, red cushioned benches, and narrow amber arched windows above the balcony. The raised level is small and far away in the background, close to the back wall; in front of it a large, open, empty front floor fills the whole lower half of the image. 16:9 aspect ratio, retro pixel art, clean pixel shading, no characters, no monsters, no UI, clean empty scenery.
```

---

---

## 🛠️ Jak dodać tło do gry

1. **Generowanie:**
   - Skopiuj prompt z wybranego wariantu.
   - Załącz w generatorze AI (Gemini / Nano Banana / Imagen / Midjourney) plik graficzny wskazany w linii *Referencja* jako wzorzec stylu i palety.
   - Upewnij się, że rozdzielczość ma proporcje **16:9** (np. 1920×1080).
2. **Zapisanie w projekcie:**
   - Zapisz wygenerowany plik graficzny w folderze danego biomu:
     `modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/<nazwa_biomu>/variant_X.png` (lub `.jpg`, `.webp`).
3. **Konfiguracja pól walki w edytorze Godot:**
   - Otwórz scenę narzędziową `scenes/tools/battle_layout_preview.tscn`.
   - Zaznacz pole walki i dopasuj narożniki strefy do posadzki na nowym tle.
   - **Dla teł wielopoziomowych (warianty 4 i 5):** zduplikuj pole walki (**Ctrl+D**) i ustaw osobne pole na każdym tarasie / podeście (plik `<nazwa_tła>_layout.tres` zapisze się automatycznie obok grafiki).
4. **Gotowe:**
   - Skrypt `folder_battle_background.gd` automatycznie wykryje i wylosuje nowy wariant tła podczas walki w grze.
