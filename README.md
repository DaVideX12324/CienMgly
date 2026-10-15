# Cień Mgły

Edukacyjna gra RPG w **Godot 4.7** (GL Compatibility): eksploracja generowanych map, walka turowa w stylu
RPG Makera i pytania quizowe wplecione w walkę. Działa jako moduł platformy
[Artefakt Wiedzy](https://github.com/DaVideX12324/Artefakt-Wiedzy-modular) (`modules/quiz_rpg`, id `quiz_rpg`)
albo jako samodzielny projekt.

## Co jest w grze

- **Świat:** samouczek -> generowana jaskinia -> generowane ścieki (tymczasowo; docelowo jaskinia -> miasto ->
  ścieki). Jaskinia: pokoje, płaskowyże ze schodami, nisze, obiekty (grzyby, stalagmity, kamienie, skrzynie, beczki);
  ścieki: układ `structured` z kanałami, kładkami i platformami. Mapy to sceny dziedziczone po
  `scenes/maps/procedural_level.tscn` (`scenes/maps/levels/`); jeden seed na zapis, seed mapy liczony z niego
  i nazwy sceny. Można wracać do poprzedniego poziomu; przejścia działają po wejściu w obszar albo pod klawiszem
  interakcji (E). Miasto (`town.tscn`) jest w przygotowaniu — mapa malowana ręcznie w LDtk (`town.ldtk`).
- **Generator:** zachowanie biomu w JSON-ie obok TileSetu (`resources/maps/config/*.json`: flagi, tileset, obiekty);
  kształt pokoi (`room_shape`: organic / rect / round / poly / mixed) i wejście na środku mapy (`entrance_mode: center`)
  to flagi tego JSON-a.
- **Walka:** turowa, z pytaniami (odpowiedzi 1–4), okna jak w RPG Makerze, motywy okien i style pasków
  do wyboru w opcjach, po wygranej chwila nietykalności.
- **Postać i postęp:** statystyki i poziomy, klasy postaci, przedmioty, umiejętności i statusy, ekwipunek, złoto,
  skrzynie i klucze wg tieru, sloty zapisu, menu Esc, ekran śmierci drużyny. Teksty w PL i EN (`resources/i18n`).
  Drużyna z towarzyszami jest w budowie (dziś jeden bohater, `resources/heroes`).
- **Wrogowie:** pościg po siatce nawigacji z generatora, wykrywanie gracza.
- **Pytania:** zestawy w `resources/quizzes`, wybór aktywnych i edytor pytań (menu główne, Opcje -> Pytania).
- **Sterowanie:** zmiana klawiszy, chód / bieg (domyślny ruch i tryb klawisza — przytrzymanie albo
  przełączanie) w Opcje -> Sterowanie.

## Uruchamianie

**W Artefakcie Wiedzy** (zalecane do pracy): sklonuj host z submodułami
(`git clone --recurse-submodules …Artefakt-Wiedzy-modular`) i uruchom projekt hosta — Cień Mgły jest na
liście modułów. Assety hosta (`assets/`) są w prywatnym submodule, więc bez dostępu do niego gra się nie uruchomi;
w tym repo są tylko własne grafiki modułu (`assets/textures/battle_backgrounds`, `loading_screens`).

**Samodzielnie:** moduł korzysta z usług hosta (ustawienia, okno, skala UI, quizy, audio). Ich kopie leżą
w `_host/` (z `.gdignore`, więc w hoście są niewidoczne), konfiguracja projektu w `project.godot.off`.

```bash
modules/quiz_rpg/tools/make_standalone.sh <katalog_poza_artefaktem>
godot --path <katalog_poza_artefaktem> --import
```

Po zmianach w zasobach / autoloadach hosta, których moduł używa, odśwież kopie:
`godot --headless --path <host> -s res://modules/quiz_rpg/tools/sync_host_copies.gd`.
Kopie assetów (`_host/assets`) są poza gitem (assety są prywatne) — skrypt tworzy je z lokalnego `assets/` hosta.

## Konwencje

- Ścieżki modułu przez `QuizRpgPaths.path("…")` (`scripts/quiz_rpg_paths.gd`) albo względny `preload`,
  zasoby hosta przez `QuizRpgPaths.host("res://…")` — nigdy `res://modules/quiz_rpg/…` na sztywno.
- Każdy `ext_resource` ma UID; końce linii LF (`.gitattributes`).
- Sceny wrogów dziedziczą po `scenes/enemies/enemy.tscn`; obiekty z kolizją mają `StaticBody2D` jako korzeń.
- Diagnostyki headless w `tests/` są lokalne (poza gitem).

## Struktura

```
autoloads/   GameManager, SaveManager, LevelStateManager, PlayerStats, InventoryService, LootManager, …
scenes/      maps (poziomy, level_manager), player, enemies, objects, quiz (walka), ui (menu, HUD), tools
scripts/     generation (generator map i obiektów, kafle), maps (poziomy, przejścia), quiz, ui, …
resources/   maps (TileSety + config/*.json), quizzes, items, heroes, skills, statuses, enemies, i18n, shaders,
             ui (motyw, skórki, paski)
tools/       sync_host_copies, make_standalone.sh, sync_object_catalogs, narzędzia migracji
_host/       kopie zasobów hosta dla wersji samodzielnej
standalone/  scena startowa wersji samodzielnej
```

Dokumentacja projektu jest w repo hosta: `docs/kontekst/` (stan prac, menu i opcje, walka, kafle, obiekty),
`docs/znane_problemy.md` (do zrobienia, rozwiązane), `docs/game_design.md`, `docs/plan_generator_obiektow.md`.
