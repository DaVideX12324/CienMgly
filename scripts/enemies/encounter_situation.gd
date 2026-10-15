## Sytuacja na mapie przy starcie walki (EnemyBase.start_combat -> ekran walki: szansa na przewagę / zaskoczenie wg AGI).
## Osobny plik bez zależności — ekran walki nie odwołuje się do EnemyBase (EnemyBase wczytuje scenę walki: cykl).
const NORMAL := 0
const UNSEEN := 1       # wróg nie zauważył gracza, gracz zwrócony do niego — szansa na przewagę drużyny
const FROM_BEHIND := 2  # goniący wróg dopadł gracza od tyłu — szansa na zaskoczenie drużyny
