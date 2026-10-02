# Prompty korekcyjne do istniejących teł walki (kadr 16:9 na cały ekran)

Obecne tła mają kadr pod stary obszar walki (1920×830 nad paskiem UI, „cover”): posadzka z wrogami leży
na **~70–85% wysokości obrazu**, więc przy tle na cały ekran 16:9 przedni rząd wszedłby pod dolny pasek UI.
Każdy prompt poniżej **edytuje istniejącą grafikę** (dołącz ją do promptu): oddala ją tak, żeby zajęła
górne ~80% nowego kadru, i dorysowuje posadzkę w dół do krawędzi oraz brzegi sceny po bokach. Pole wrogów
przesuwa się wtedy na ~55–68% wysokości — zgodnie z nowymi zasadami (`pixel_crawler_prompts.md`,
„Pasy kadru”).

- **Zdanie „Optional fix”** poprawia niezgodność z paczką (z uwag przy biomach) — usuń je, jeśli
  chcesz zostać tylko przy zmianie kadru.
- **Po korekcie:** podmień plik (ta sama nazwa) i przestaw pole w `scenes/tools/battle_layout_preview.tscn`
  (stare pole będzie za nisko). Gra rysuje dziś tło jeszcze po staremu (cover nad paskiem UI) — przełączenie
  na tło na cały ekran wymaga zmiany w `folder_battle_background.gd` i nowych pól, razem z nowymi grafikami.
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

### Jaskinia — `pixel_crawler/cave/variant_1.jpg`
- posadzka z wrogami teraz na 70–83% wysokości obrazu; uwagi: kryształy, rusztowania i latarnie spoza paczki
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI. Optional fix: remove the cyan crystals, the wooden mining scaffolding and the hanging lanterns; in their place put purple umbrella mushrooms with icy-blue drips, red-orange tube fungi and conical ringed brown stalagmites.
```

### Jaskinia (grzyby) — `pixel_crawler/cave/Gemini_Generated_Image_q1ekwiq1ekwiq1ek.jpg`
- pole domyślne; uwagi: zgodna z paczką; brak pliku `_layout.tres` (pole domyślne) — po korekcie ustawić pole w podglądzie
```text
Edit the attached image. Keep the same place, art style, palette, lighting and every existing object exactly as they are — do not redraw or move them. Recompose it into a 16:9 frame for a full-screen game background: zoom out so that the whole current picture fills only the upper ~80% of the new frame, centred horizontally and touching the top edge; extend the scene around it — continue the same floor straight down to the bottom edge toward the viewer, and continue the walls and scenery at the left and right sides so they match seamlessly. The newly added bottom part must be plain, flat, empty floor with no objects and no important details (it will be hidden under the game's menu window). Keep the existing empty floor in the middle completely empty. Same first-person ground-level perspective, NOT top-down, NOT isometric. 16-bit pixel art: crisp pixels, dark outlines, clean pixel cluster shading, no blur, no characters, no monsters, no text, no logo, no UI.
```

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
