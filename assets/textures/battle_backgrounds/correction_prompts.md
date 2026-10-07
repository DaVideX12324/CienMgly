# Prompty korekcyjne do istniejących teł walki (kadr 16:9 na cały ekran)

## ⭐ Najpierw to (2026-10-07) — proste prompty edycji

Długie prompty niżej (korekty 1–4) okazały się za ciężkie: generator ignorował „zoom out / scale down”,
a przy płótnie zamykał scenę ścianami wokół starego obrazu (jak pomieszczenie) zamiast ją rozszerzać.
Proste wersje w stylu sprawdzonych wzorców (`pixel_crawler_prompts.md`, „Zasady”):

**A. Edycja samej grafiki (bez płótna)** — dołącz tylko tło do poprawy:
```text
Edit the attached 16-bit pixel art JRPG battle background: show the same place from further away, as if the camera stepped several metres backwards, first-person battle perspective. Keep the same style, colours, lighting and objects. The lower half of the new picture is a wide, flat, empty floor of the same ground that comes closer toward the viewer, and the scenery from the original picture now sits further back above it. 16:9 aspect ratio, retro pixel art, no characters, no monsters, no UI.
```

**B. Płótno (obraz pomniejszony u góry, reszta szara)** — gdy A nie oddala kadru:
```text
Fill the flat grey areas of the attached image by continuing the same scene outward, first-person battle perspective. The picture in the middle is only the far back part of a much bigger, wide open hall: the same floor spreads wider and comes closer toward the viewer all the way to the bottom edge, and the walls continue outward past the left and right edges of the image, so the space feels open and wide. Keep the existing picture exactly as it is. 16:9 aspect ratio, retro pixel art, matching colours and lighting, no characters, no monsters, no UI.
```
- W B nie opisuj ścian „przy krawędziach” ani „ramy” — generator dorysowuje wtedy ściany wokół starego
  obrazu. Zdanie „the picture in the middle is only the far back part of a much bigger hall” każe mu
  rozszerzać przestrzeń. Gdy szary obszar jest duży po bokach, szansa na zamknięcie rośnie — lepiej dać
  szeroki obraz (mniej szarego po bokach, więcej na dole).

---

Obecne tła mają kadr pod stary obszar walki (1920×830 nad paskiem UI, „cover”): posadzka z wrogami leży
na **~70–85% wysokości obrazu**, więc przy tle na cały ekran 16:9 przedni rząd wszedłby pod dolny pasek UI.
Każdy prompt poniżej **edytuje istniejącą grafikę** (dołącz ją do promptu): oddala ją tak, żeby zajęła
górne ~80% nowego kadru, i dorysowuje posadzkę w dół do krawędzi oraz brzegi sceny po bokach. Pole wrogów
przesuwa się wtedy na ~55–68% wysokości — zgodnie z nowymi zasadami (`pixel_crawler_prompts.md`,
„Pasy kadru”).

- **Zdanie „Optional fix”** poprawia niezgodność z paczką (z uwag przy biomach) — usuń je, jeśli
  chcesz zostać tylko przy zmianie kadru.
- **Po korekcie:** podmień plik (ta sama nazwa) i przestaw pole w `scenes/tools/battle_layout_preview.tscn`
  (stare pole będzie za nisko). Od `deb8866` (2026-10-06) gra rysuje tło na cały ekran 16:9 — stare kadry
  mają przez to posadzkę za nisko (pod oknem UI); tutorial jest już poprawiony.
- Gdy generator nie chce oddalić obrazu: najpierw powiększ płótno do 16:9 z obrazem u góry (np. w edytorze
  grafiki, puste miejsce na dole i po bokach), potem użyj promptu jako „uzupełnij puste obszary”.

**Wspólna część** (wklejona w każdym prompcie):
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI.
```

---

### Zamek — `pixel_crawler/castle/variant_1.jpg`
- posadzka z wrogami teraz na 70–83% wysokości obrazu; uwagi: szara szachownica zamiast granatowych rombów (jak w paczce)
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: replace the grey checkerboard floor with dark navy-indigo stone tiles in a subtle diamond pattern, keeping the red carpet with thin gold edges.
```

### Jaskinia — `pixel_crawler/cave/variant_1.jpg` (korekta 2 — 2026-10-07)
- Na pełnym ekranie (od `deb8866`): posadzka u wylotu tunelu zaczyna się na ~66% wysokości, wrogowie stoją
  na ~70–90% (pod oknem UI od 77%); w dolnej części stoją stalagmity i grzyby, które po oddaleniu weszłyby
  w pole wrogów. Wzorzec: tutorial `variant_2_training.jpg` — podstawa tylnej ściany ~50%, pod UI gładka posadzka.
- Skala: obraz do górnych **75%** kadru → początek posadzki 0,66 × 0,75 ≈ **50%**.
```text
Edit the attached image. Keep the same place, art style, palette, lighting and the cave mouth, walls, crystals, scaffolding, lanterns and mushrooms on the walls exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: scale the whole current picture down to 75% of the new frame size, centred horizontally and touching the top edge, and extend the scene around it — continue the rocky cave walls and roots on the left and right sides seamlessly, and continue the same dirt-and-stone floor straight down to the bottom edge toward the viewer. After this change the open floor in front of the tunnel must begin at about half of the image height. Remove the small stalagmites, purple mushrooms and red tube fungi standing on the floor in the lower middle part of the original picture; small decorations may stay only within the outer 10% of the width at the far left and far right. The whole floor between 50% and 100% of the image height must be open, flat and empty in the middle, and the bottom quarter must be plain, flat floor with no objects and no important details (it will be hidden under the game's menu window). Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: remove the cyan crystals, the wooden mining scaffolding and the hanging lanterns; in their place put purple umbrella mushrooms with icy-blue drips, red-orange tube fungi and conical ringed brown stalagmites.
```

### Jaskinia (grzyby) — `pixel_crawler/cave/Gemini_Generated_Image_q1ekwiq1ekwiq1ek.jpg` (korekta 2 — 2026-10-07)
- Na pełnym ekranie: otwarta posadzka zaczyna się na ~70% wysokości (za kamieniami i stalagmitami), z przodu
  po bokach rurkowate grzyby i stożkowe stalagmity; brak `_layout.tres` (pole domyślne).
- Skala: obraz do górnych **72%** kadru → początek posadzki 0,70 × 0,72 ≈ **50%**.
```text
Edit the attached image. Keep the same place, art style, palette, lighting and the giant dripping mushrooms, cave walls, roots and stalactites exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: scale the whole current picture down to 72% of the new frame size, centred horizontally and touching the top edge, and extend the scene around it — continue the rocky cave walls, roots and red tube fungi on the left and right sides seamlessly, and continue the same mossy dirt floor straight down to the bottom edge toward the viewer. After this change the open floor must begin at about half of the image height. Keep the conical stalagmites, rock piles and tube fungi only within the outer 10% of the width at the far left and far right; remove any of them that would stand in the middle part of the floor. The whole floor between 50% and 100% of the image height must be open, flat and empty in the middle, and the bottom quarter must be plain, flat floor with no objects and no important details (it will be hidden under the game's menu window). Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI.
```

- **Wynik korekty 2 (2026-10-07):** generator zrobił tylko „Optional fix” (`Gemini_Generated_Image_zhhwdzzhhwdzzhhw.jpg`
  — bez kryształów i rusztowań), ale **nie oddalił kadru** (posadzka dalej od ~66%). Prompty „scale down / zoom out”
  są ignorowane → **metoda płótna** (korekta 3): obraz pomniejszony i wklejony u góry pustego kadru 16:9
  (szare tło 128,128,128), generator tylko dorysowuje szare pola. Skala = 0,42 / początek posadzki
  (tunel `zhhw…` 0,64; grzyby `q1ek…` 0,60) → posadzka od ~**42%**. Płótna robi skrypt (scratchpad sesji,
  `plotna/`); odtworzenie: PIL `resize(W·s, H·s)` + `paste` na środek górnej krawędzi płótna 2752 × 1536.
```text
Fill in the flat grey areas of the attached image. Keep the existing picture in the upper middle exactly as it is — do not change, redraw, move or rescale anything in it. The result is a 16:9 full-screen game background of a cave seen from ground level. Continue the scene seamlessly into the grey areas: on the left and right extend the same rocky cave walls, roots and purple dripping mushrooms upward and downward to the image edges; below, continue the same mossy dirt-and-stone floor straight down to the bottom edge toward the viewer, getting slightly larger and closer. The floor in the middle must stay open, flat and empty; small rocks or mushrooms only along the far left and far right edges. The bottom quarter must be plain, flat floor with no objects and no important details (it will be hidden under the game's menu window). Match the palette, lighting and perspective exactly. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI, no grey left anywhere.
```

- **Wynik korekty 3 (2026-10-07):** oddalenie działa (`5slvaz…`, `xbr29z…`), ale boczna „rama” oryginału
  (skały, korzenie, grzyby przy krawędziach obrazu) po pomniejszeniu wypada w środku kadru — generator przedłuża
  ją w dół i skośne ściany / szwy dzielą pole walki (~20–28% i 72–80% szerokości). **Korekta 4:** płótno
  z **wyciętym środkiem** oryginału bez ramy — tunel `zhhw…` x 21–79%, y 0–90%; grzyby `q1ek…` x 14–86%,
  y 0–88%; skala jak wyżej (posadzka od ~42%); ściany dorysowuje generator dopiero przy krawędziach ekranu.
```text
Fill in the flat grey areas of the attached image. Keep the existing picture in the upper middle exactly as it is — do not change, redraw, move or rescale anything in it. The result is a 16:9 full-screen game background: a wide underground cavern seen from ground level, with the existing picture as its far back wall. Continue the scene seamlessly into the grey areas so that the cavern opens up wide: the same mossy dirt-and-stone floor spreads continuously across the WHOLE width of the image from about 42% of the height down to the bottom edge, getting slightly larger and closer toward the viewer. Rocky cave walls, roots and purple dripping mushrooms appear only at the far left and far right edges (outer 10% of the width) and frame the scene; there must be NO rock walls, ledges, slopes, pillars or seams inside the middle 80% of the width below 42% of the height. The floor in the middle must stay open, flat and empty; the bottom quarter must be plain, flat floor with no objects and no important details (it will be hidden under the game's menu window). Match the palette, lighting and perspective exactly. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI, no grey left anywhere.
```

- **Po podmianie obu jaskiń:** pola walki w `scenes/tools/battle_layout_preview.tscn` jak w tutorialu —
  przedni rząd y ≈ 765, tylny y ≈ 540–600 (w tutorialu 537), szerokość tyłu ~480–1440. Dla Gemini utworzyć
  `Gemini_Generated_Image_q1ekwiq1ekwiq1ek_layout.tres` (dziś pole domyślne).

### Pustynia — `pixel_crawler/desert/variant_1.png`
- posadzka z wrogami teraz na 68–83% wysokości obrazu; uwagi: blady żółty piasek i szare kolumny (w paczce pomarańczowy piasek, złociste kolumny z niebieskim)
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: make the sand saturated orange with rust-brown gravel patches, and turn the grey stone columns into golden sandstone columns inlaid with small blue gems.
```

### Baśniowy las — `pixel_crawler/fairy_forest/variant_1.jpg`
- posadzka z wrogami teraz na 69–83% wysokości obrazu; uwagi: kamienie z literami „R” i różowe grzybki (w paczce kamień z jednym okiem, czerwone muchomory)
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: replace the runestones with letters by rounded blue-grey runestones each with a single glowing turquoise eye-gem, and the pink mushrooms by red-capped toadstools on thin stems.
```

### Kuźnia — `pixel_crawler/forge/variant_1.jpg`
- posadzka z wrogami teraz na 69–83% wysokości obrazu; uwagi: zgodna z paczką
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI.
```

### Ogród — `pixel_crawler/garden/variant_1.jpg`
- posadzka z wrogami teraz na 70–83% wysokości obrazu; uwagi: prostokątne płyty zamiast sześciokątnych kostek, brak magentowych rabat, jaśniejsza paleta
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: replace the rectangular path slabs with light grey-lilac hexagonal cobbles, add square magenta flower beds, and slightly mute the palette.
```

### Kryjówka — `pixel_crawler/hideout/variant_1.jpg`
- posadzka z wrogami teraz na 70–83% wysokości obrazu; uwagi: deski zamiast bruku, tarcza do rzutek spoza paczki
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: replace the wooden plank floor with dark grey-green cobblestones and remove the dartboard.
```

### Tutorial — brama — `tutorial_area/variant_1_gate.jpg`
- posadzka z wrogami teraz na 71–83% wysokości obrazu; uwagi: brak złotych drzwi z chorągwiami z mapy
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: put a pair of golden wooden plank doors with iron fittings in the middle of the back wall, flanked by red banners with a gold crest.
```

### Tutorial — sala ćwiczeń — `tutorial_area/variant_2_training.jpg`
- posadzka z wrogami teraz na 61–83% wysokości obrazu; uwagi: pole walki ustawione już ręcznie (y 537–765) — po korekcie przesunąć je w podglądzie
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI.
```

### Tutorial — schody — `tutorial_area/variant_3_stairs.jpg`
- posadzka z wrogami teraz na 70–83% wysokości obrazu; uwagi: —
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI.
```

### Tutorial — komnata — `tutorial_area/variant_4_chamber.jpg`
- posadzka z wrogami teraz na 68–83% wysokości obrazu; uwagi: brak palenisk w niszach z mapy
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: add fire braziers burning inside stone niches in the back wall.
```
