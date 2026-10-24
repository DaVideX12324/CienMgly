# Changelog — Cień Mgły

Istotne zmiany widoczne dla gracza i zmiany kompatybilności. Zasady numerów i etapów: `docs/wersjonowanie.md`
w repo hosta (Artefakt Wiedzy). Plany są w roadmapie / zakresie inżynierki, nie tutaj.

## [Unreleased]

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
- Zakończenie jest krótkie (ekran końca po bossie ścieków); dalsza kampania to zakres 2.0.
- Lista znanych problemów: `docs/znane_problemy.md` w repo hosta.
