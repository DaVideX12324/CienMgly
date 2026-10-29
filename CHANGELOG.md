# Changelog — Cień Mgły

Istotne zmiany widoczne dla gracza i zmiany kompatybilności. Zasady numerów i etapów: `docs/wersjonowanie.md`
w repo hosta (Artefakt Wiedzy). Plany są w roadmapie / zakresie inżynierki, nie tutaj.

## [Unreleased]

### Dodano
- Nowe miasto w `town.tscn` (Pixel Crawler, bez Desert Oasis): domy, ruiny, propsy, NPC z postaciami LumenLore, rośliny.
- Postacie drużyny i NPC generowane z szablonu LumenLorePixels (8 kierunków, bieg).
- Atlas ruin `Ruins.png` i sceny ruin / miejskich propsów (generatory `tools/gen_ruins_atlas.py`, `tools/gen_ruins_scenes.py`).
- Schody i piętro domu (`QuizRpgZTrigger`): poziom postaci (na schodach / za nimi) zależny od drogi, z kolizjami górnego poziomu.
- Banery Pixel Crawlera na słupach (w tym żywioły), strach na wróble, odblokowanie gracza przy zakleszczeniu.
- Grupy efektów dźwiękowych (opcje → Dźwięk, pod „Efekty dźwiękowe”): interfejs, walka, otoczenie. Kroki i kolce
  grają w otoczeniu, okna NPC (sklep, nauczyciel, kowal, karczma, zadania) i umiejętność z menu Esc w interfejsie;
  reszta wg nazwy dźwięku (AudioService).
- Dźwięki kroków bohatera (jak w Amon-Ra): krok na klatkach animacji chodu (dwa na cykl, przy biegu szybciej), dźwięk
  wg podłoża pod stopami — ziemia, trawa, piasek, kamień (ścieki), bruk, metal (kraty); typ z nazwy terenu kafla albo
  danej kafla `ground_type`. Zestawy w `scenes/player/footsteps.tscn`.
- Nowa gra: najpierw imię bohatera (ekran „Nowa gra” w menu; puste = Bohater, do 12 znaków). Easter eggi: reakcje
  na wybrane imiona (np. Freddy, Bohater, Mgła, Artefakt, Promotor — wymagają potwierdzenia „Tak, to ja”); imiona
  towarzyszy i NPC miasta są zajęte.
- Menu deweloperskie → „🥚 Easter eggi imion”: odsłania na ekranie „Nowa gra” edytor easter eggów — dodawanie,
  „zajęte”, reakcje PL / EN, usuwanie; kliknięcie w imię wpisuje je i pokazuje reakcję. Easter eggi są w
  `resources/data/name_easter_eggs.json`; zmiany zapisują się od razu (w wyeksportowanej grze do `user://`).
- Menu deweloperskie → Drużyna: usuwanie towarzyszy (pojedynczo albo wszystkich); ich ekwipunek wraca do plecaka.

### Zmieniono
- Wejście w schody-wnękę (przejście do innej mapy): drużyna ciemnieje i znika stopniowo na ostatnich dwóch stopniach (zamiast zniknąć nagle razem z mapą), a po wczytaniu nowej mapy wynurza się z ciemności.
- Pytania w walce: szansa na zadanie złożone (wpisywanie, kafelki, dopasowanie zamiast wyboru / prawda-fałsz) zależy od tieru atakowanego przeciwnika — tier 1: 20%, 2: 40%, 3: 60%, 4 i boss: 80%. Gdy zestaw nie ma pytań danego rodzaju, pada pytanie z drugiej grupy.
- Ikony mikstur (Shiny RPG Potions, Bonsaiheldin, CC BY-SA 3.0): tier = kolor (HP czerwona → pomarańczowa →
  procentowa różowa, SP niebieski → turkus → procentowy fiolet), rozmiar s / m / l = butelka; odtrutka żółta, Tonik Skupienia
  zielony. Autorzy w `resources/items/icons/CREDITS.md`.
- Mikstury: tier 3 procentowy (s / m / l = 25 / 50 / 100 % maks. HP lub SP; pola `heal_percent` / `sp_percent`), tiery 4–5
  usunięte (przedmioty, sklep, tłumaczenia).
- Walka: sprite wroga ma skalę sprite'a ze swojej sceny (np. boss ×2) — mnożoną przez skalę miejsca na tle.
- Statystyki wrogów: baza (dane / scena) = statystyki na poziomie 1; na poziomie L baza × wzór(L) / wzór(1), gdzie wzór liczy
  bohatera wzorcowego w rekomendowanym sprzęcie mapy (`gear_tier` w companion-JSON; tiery w `resources/data/gear_tiers.json`:
  0 start / sklep w mieście, 1 po Matce Nietoperzy, 2 po bossie ścieków; jaskinie 0, ścieki 1) zamiast krzywej sklepu. Dane
  wszystkich wrogów przeliczone na poziom 1 (balans jaskiń bez zmian), ścieki mocniejsze (sprzęt tieru 1). Samouczek
  z poziomami (szlam 1), statystyki jak dotąd.
- Walka: poziom wroga („Lv N”) przy nazwie na liście wyboru celu (wrogowie bez poziomu, np. samouczek — bez znacznika).
- Ścieki: poziomy wrogów z pasm (`enemy_levels`: t1 9–11, t2 11–13, t3 13–14, Szczurzy Król 15) — statystyki z poziomu jak
  w jaskiniach (wcześniej szablon tieru, w praktyce poziom 1). Zapisane mapy ścieków generują się od nowa.
- Przedmioty: w menu Esc po użyciu zostaje wybór postaci (ta sama zaznaczona) — kolejne Enter używa przedmiotu znowu,
  dopóki jest w plecaku. Przedmiotu, który nic by nie dał (pełne HP / SP / TP, brak statusu do wyleczenia), nie da się
  użyć ani w menu, ani w walce — komunikat z powodem, przedmiot nie przepada.
- Walka z bossem: boss jest zawsze jeden (bez kopii bossa) i dostaje stałą świtę (pole sceny `boss_minions` — zawsze
  ci sami przeciwnicy w tej samej liczbie, poziom z dolnej granicy pasma tieru na mapie): szlam-boss samouczka sam,
  stary grzyb + 2 młode grzyby, Matka Nietoperzy + 2 małe nietoperze (jaskinie: tier 1), Szczurzy Król + szczur
  i szczur-łotrzyk (tier 1–2).
- Wrogowie: gdy cel leży poza siatką nawigacji (wąski pas pod licem płaskowyżu, przy ścianie, między obiektami),
  wróg dochodzi do końca ścieżki, a ostatni odcinek idzie wprost, jeśli jego ciało przejdzie (test ruchu fizyki).
  Wcześniej stał na krawędzi siatki.
- Zakończenie: ekran końca gry pojawia się po wyjściu ze ścieków na cmentarzysko (drabina wyjścia), a nie zaraz po
  pokonaniu bossa ścieków — boss tylko otwiera wyjście (companion-JSON `"exit_ends_game": true`). „Graj dalej” wraca do
  ścieków; ponowne wejście w wyjście znów pokazuje ekran końca. Nowy tekst ekranu końca (PL / EN).
- Ścieki: wyjście zamknięte do pokonania bossa (Szczurzy Król) — obszar wyjścia nie działa, a snop światła nad drabiną
  wyjścia pojawia się dopiero po walce (companion-JSON `"boss": {"locks_exit": true}`).

### Naprawiono
- Menu Esc → zapis: hover / klik działały tylko na pierwszych 3 slotach (kopie wierszy zostawały przy myszy wzoru — też
  lista drużyny). Usuwanie slotu: przytrzymanie klawisza akcji (E) albo Delete / Backspace przez 5 s (postęp w stopce,
  puszczenie anuluje), już nie pod strzałką.
- Jaskinie: schody szerokości 1 na długim licu płaskowyżu — schody łączące nieosiągalne miejsce brały tylko kawałek lica
  naprzeciw niego; teraz cały bieg lica (schody muszą tylko objąć to miejsce), a pełne schody mają pierwszeństwo przed
  wąskimi także przy mniejszym zapasie przy końcach. Zapisane mapy generują się od nowa (`MAP_CACHE_VERSION` 2).
- Walka: wrogowie mieli w walce HP losowane ±8 % (np. boss 700 -> do 756); teraz każdy ma dokładnie swoje maks. HP —
  statystyki wynikają z poziomu, ten sam wróg na tym samym poziomie jest zawsze taki sam.
- Kroki prawie niesłyszalne (−22 dB przy cichych próbkach): teraz 0 dB, ok. 9 dB poniżej kliknięcia w menu; dwa kroki
  mogą brzmieć naraz (nie ucinają się).
- Bohater: przy krótkim stuknięciu ruchu animacja chodu ruszała dopiero po pierwszej klatce (poza stojąca) i postać
  sunęła; teraz chód z bezruchu zaczyna się od wykroku, a zmiana kierunku zachowuje fazę kroku. Kroki na wykrokach
  (¼ i ¾ pętli), pierwszy od razu.
- Walka: po wygranej z wrogiem bez tabeli łupu (np. samouczek) błąd „Array[Dictionary]” przerywał losowanie łupu —
  nie wypadał klucz tieru 1. To samo w łupie przedmiotów w niszach jaskiń.
- Ścieki: na części map (ok. 1/3 seedów) wejście albo wyjście nie miało drabiny — pokój wybrany na przejście nie miał
  północnej ściany (np. otwarty na kanał). Generator bierze kolejny pokój z tej samej kolejności, w którym drabina się
  mieści; mapy, które miały obie drabiny, są bez zmian. Zapisane mapy ścieków generują się od nowa (zmieniony `sewer.json`).

## [0.8.0-alpha] — 2026-10-24

Pierwsza wersjonowana Alpha — punkt odniesienia. Opisuje stan gry, nie zmiany względem poprzedniego wydania
(wcześniej moduł miał zastępczy numer `0.1.0`).

### Zawartość
- **Ścieżka:** samouczek → generowana jaskinia → miasto → generowane ścieki → boss ścieków (Szczurzy Król) → ekran końca.
  Powrót do poprzednich map; po wizycie w mieście w jaskini pojawia się boss powrotny (Matka Nietoperzy).
- **Generator map:** jaskinie (pokoje, płaskowyże ze schodami, nisze, sekretne pokoje i krypta z reliktem) i ścieki
  (kanały, kładki, platformy, winiety); obiekty jako sceny (grzyby, stalagmity, skrzynie, beczki do zniszczenia, gruz);
  jeden seed na zapis, mapy liczone z wyprzedzeniem i zapisywane na dysk.
- **Walka:** turowa z pytaniami quizowymi, kolejność wg AGI, okna jak w RPG Makerze, statusy, zaskoczenie,
  losowe spotkania (rosnąca szansa z krokami).
- **Drużyna:** bohater + towarzysze Kael, Eldon, Selene; klasy, umiejętności klasowe, sloty umiejętności wg tieru.
- **Postęp:** poziomy i XP, ekwipunek (skala jak FNaFB1), bronie z potencjałem ulepszane u kowala, mikstury wg tieru,
  skrzynie i klucze wg tieru, tabele łupu w `.tres`, złoto (dukaty).
- **Miasto i NPC:** sklepy (asortyment rośnie z postępem fabularnym), kowal, nauczyciel umiejętności, karczma (odpoczynek),
  zadania NPC z dziennikiem w menu Esc; przedmioty pośrednie odblokowywane zadaniami.
- **Interfejs:** minimapa z mgłą wojny i znacznikami (róg / pełna mapa pod M / wyłączona), menu Esc, ekran ładowania,
  ekran śmierci drużyny, sloty zapisu (zapis w punktach zapisu), skala UI, PL / EN.
- **Pytania:** zestawy modułu + edytor pytań hosta, wybór aktywnych pytań.

### Kompatybilność
- Wymaga hosta Artefakt Wiedzy z `I18nService` i `SessionResults` (host `0.8.0-alpha`); działa też samodzielnie (`_host/`).
- Format zapisu: `SAVE_VERSION` 2 (zapisy v1 migrowane przy wczytaniu). Zapisane mapy: `MAP_CACHE_VERSION` 1.

### Znane ograniczenia
- Mapa miasta w budowie (warstwa Walls, część obiektów, domki); wnętrz budynków nie ma — NPC stoją przed domami.
- **Tymczasowo:** etap 1 → 2 broni z potencjałem odblokowuje Matka Nietoperzy + jej kieł (docelowo boss ścieków).
- Zakończenie jest krótkie (ekran końca po bossie ścieków; od [Unreleased] — po wyjściu ze ścieków); dalsza kampania to zakres 2.0.
- Lista znanych problemów: `docs/znane_problemy.md` w repo hosta.
