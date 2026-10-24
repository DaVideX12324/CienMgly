# Changelog — Cień Mgły

Istotne zmiany widoczne dla gracza i zmiany kompatybilności. Zasady numerów i etapów: `docs/wersjonowanie.md`
w repo hosta (Artefakt Wiedzy). Plany są w roadmapie / zakresie inżynierki, nie tutaj.

## [Unreleased]

### Dodano
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
- Wrogowie: gdy cel leży poza siatką nawigacji (wąski pas pod licem płaskowyżu, przy ścianie, między obiektami),
  wróg dochodzi do końca ścieżki, a ostatni odcinek idzie wprost, jeśli jego ciało przejdzie (test ruchu fizyki).
  Wcześniej stał na krawędzi siatki.
- Zakończenie: ekran końca gry pojawia się po wyjściu ze ścieków na cmentarzysko (drabina wyjścia), a nie zaraz po
  pokonaniu bossa ścieków — boss tylko otwiera wyjście (companion-JSON `"exit_ends_game": true`). „Graj dalej” wraca do
  ścieków; ponowne wejście w wyjście znów pokazuje ekran końca. Nowy tekst ekranu końca (PL / EN).
- Ścieki: wyjście zamknięte do pokonania bossa (Szczurzy Król) — obszar wyjścia nie działa, a snop światła nad drabiną
  wyjścia pojawia się dopiero po walce (companion-JSON `"boss": {"locks_exit": true}`).

### Naprawiono
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
