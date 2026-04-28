IDENTIFICATION DIVISION.
PROGRAM-ID. SIMULATE.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
*>  Phase 24 — Этап 1: world.dat расщеплён на regions.dat (геофон) и
*>  polities.dat (политический слой). Регионы статичны и читаются один
*>  раз; полития переписывается каждый ход.
    SELECT REGIONS-FILE   ASSIGN TO "cobol/regions.dat"
        ORGANIZATION IS LINE SEQUENTIAL.
    SELECT POLITIES-FILE  ASSIGN TO "cobol/polities.dat"
        ORGANIZATION IS LINE SEQUENTIAL.
    SELECT YEAR-FILE      ASSIGN TO "cobol/year.dat"
        ORGANIZATION IS LINE SEQUENTIAL.
    SELECT CHRONICLE-FILE ASSIGN TO "cobol/chronicle.dat"
        ORGANIZATION IS LINE SEQUENTIAL.
    SELECT MARKET-FILE    ASSIGN TO "cobol/market.dat"
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-MKT-FILE-STATUS.
    SELECT RELATIONS-FILE ASSIGN TO "cobol/relations.dat"
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-REL-FILE-STATUS.
    SELECT TECH-FILE ASSIGN TO "cobol/tech.dat"
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-TECH-FILE-STATUS.

DATA DIVISION.
FILE SECTION.
FD REGIONS-FILE.
01 WS-REGION-REC  PIC X(80).
FD POLITIES-FILE.
01 WS-POLITY-REC  PIC X(180).

FD YEAR-FILE.
01 WS-YEAR-REC    PIC X(10).

FD CHRONICLE-FILE.
01 WS-CHRON-REC   PIC X(99).

FD MARKET-FILE.
01 WS-MARKET-REC  PIC X(60).

FD RELATIONS-FILE.
01 WS-RELATIONS-REC PIC X(60).

FD TECH-FILE.
01 WS-TECH-REC PIC X(40).

WORKING-STORAGE SECTION.

*> ====================================================================
*> Параметры симуляции (балансировка). Меняй здесь, не в логике.
*> ====================================================================

*> Размерности
78 REGION-COUNT             VALUE 10.
78 MARKET-COUNT             VALUE 8.
*> Phase 24 — Этап 1: WORLD-REC-LEN убрана. Файл расщеплён, новые
*> длины записей (ориентировочно 80 для regions, 160 для polities)
*> регулируются объявлениями WS-REGION-REC и WS-POLITY-REC.
78 MARKET-REC-LEN            VALUE 51.

*> ====================================================================
*> Phase 8 — Вероятности (отказ от строгих триггеров).
*> Все значения в промилле (‰): 1000 = гарантировано, 0 = никогда.
*> Условия БИАСЯТ вероятность, не отменяют её.
*> ====================================================================

*> Войны
78 DYNASTIC-WAR-BASE-PERMIL  VALUE 200.
78 DYNASTIC-WAR-CAP-PERMIL   VALUE 350.
78 CRISIS-WAR-BASE-PERMIL    VALUE 400.
78 CRISIS-WAR-CAP-PERMIL     VALUE 600.
78 CLASS-WAR-BASE-PERMIL     VALUE 500.
78 CLASS-WAR-CAP-PERMIL      VALUE 850.

*> Революция: 0% при tension≤70, +25‰ за каждый пункт сверху, 100% на 100
78 REVOLUTION-MIN-TENSION    VALUE 70.
78 REVOLUTION-SCALE-PERMIL   VALUE 25.

*> Mode-shift: 30% базовая при условиях
*> Phase 21 — base 300→60, cap 700→200 (×5 замедление эпох)
78 MODE-SHIFT-BASE-PERMIL    VALUE 60.
78 MODE-SHIFT-CAP-PERMIL     VALUE 200.

*> Рыночный кризис: 0 при ratio=1.0, 30% при 1.2, 80% при 1.5+
78 CRISIS-PROB-CAP-PERMIL    VALUE 800.

*> Военный шум на исход войны: ±20%
78 MILITARY-NOISE-RANGE      VALUE 41.
78 MILITARY-NOISE-OFFSET     VALUE 80.

*> Climate hazards (‰ / ход)
78 SWAMP-EPIDEMIC-PERMIL     VALUE 40.
78 DESERT-DROUGHT-PERMIL     VALUE 50.
78 MOUNTAIN-CAVEIN-PERMIL    VALUE 25.
78 PLAINS-HARVEST-PERMIL     VALUE 70.
78 COAST-STORM-PERMIL        VALUE 35.
78 EPIDEMIC-POP-PCT          VALUE 85.
78 EPIDEMIC-TENSION-DELTA    VALUE 10.
78 DROUGHT-LABOUR-PCT        VALUE 60.
78 DROUGHT-TENSION-DELTA     VALUE 8.
78 CAVEIN-CAPITAL-PCT        VALUE 92.
78 STORM-LABOUR-PCT          VALUE 95.
78 BAD-HARVEST-LABOUR-PCT    VALUE 75.
78 BAD-HARVEST-TENSION       VALUE 5.
78 GOOD-HARVEST-CAPITAL-PCT  VALUE 120.
78 GOOD-HARVEST-TENSION-DROP VALUE 5.

*> Famine severity (заменяет бинарный flag)
78 FAMINE-SEVERE-THRESHOLD   VALUE 70.
78 FAMINE-MILD-POP-PCT       VALUE 98.
78 FAMINE-SEVERE-POP-PCT     VALUE 92.
78 FAMINE-MILD-TENSION       VALUE 5.
78 FAMINE-SEVERE-TENSION     VALUE 15.

*> Шум на tension delta: ±2
78 TENSION-NOISE-RANGE       VALUE 5.

*> Phase 10 — class drift: медленный демографический сдвиг между классами.
*> Каждый переход — 1 пп в год при срабатывании. Все вероятности в промилле.
78 DRIFT-URBANIZE-PERMIL     VALUE 80.    *> peasants → artisans (MERCANTILE+)
78 DRIFT-URBAN-MIN-PEAS      VALUE 35.
78 DRIFT-COMMERCE-PERMIL     VALUE 30.    *> artisans → merchants
78 DRIFT-COMMERCE-COAST      VALUE 30.    *> +30‰ при COAST
78 DRIFT-COMMERCE-MERCANT    VALUE 30.    *> +30‰ при MERCANT-правителе
78 DRIFT-COMMERCE-MIN-ART    VALUE 25.
78 DRIFT-DECLINE-PERMIL      VALUE 40.    *> nobility → peasants (MERCANTILE+)
78 DRIFT-DECLINE-MIN-NOB     VALUE 4.
78 DRIFT-CLERGY-PERMIL       VALUE 15.    *> peasants → clergy
78 DRIFT-CLERGY-PIOUS        VALUE 50.    *> +50‰ при PIOUS-правителе
78 DRIFT-CLERGY-MAX          VALUE 20.
78 DRIFT-RURAL-PERMIL        VALUE 200.   *> artisans → peasants на severe famine
78 DRIFT-RURAL-MIN-ART       VALUE 15.

*> Phase 10 — миграция при коллапсе
78 MIGRATION-COLLAPSE-PCT    VALUE 30.    *> 30% pop → беженцы по соседям
78 MIGRATION-TENSION-DELTA   VALUE 5.     *> +5 tension у принимающих

*> Phase 13 — древо технологий. 4 ветви × 3 уровня = 12 техов.
*> Ветви: 1=PROD (производительные), 2=ORG (организационные),
*>        3=KNOW (знание), 4=POW (власть).
78 TECH-BRANCH-COUNT         VALUE 4.
78 TECH-MAX-LEVEL            VALUE 4.    *> Phase 18: 4 уровня глубины
78 TECH-PROGRESS-FULL        VALUE 100.
78 TECH-RESEARCH-BASE        VALUE 2.    *> +2 прогресса/ход base (медленный фон)
78 TECH-MODE-BONUS           VALUE 1.    *> +1 если MERCANTILE+
78 TECH-CLASS-BONUS          VALUE 2.    *> +2 если профильный класс высок
78 TECH-CLASS-MIN            VALUE 20.   *> минимальный % профильного класса
78 TECH-TERRAIN-BONUS-PERMIL VALUE 1500. *> ×1.5 (промилле от base) для terrain match
78 TECH-EMPIRIC-BONUS-PERMIL VALUE 1500. *> ×1.5 при empiricism (KNOW L3)
78 TECH-REC-LEN              VALUE 24.    *> Phase 18: 20 + 4 (L4 choice/branch)
78 TECH-ALT-COUNT            VALUE 3.     *> 3 альтернативы на L3 в каждой ветви
78 TECH-L4-ALT-COUNT         VALUE 2.     *> 2 sub-tech на каждую L3 alt

*> Phase 15 — культурные векторы и инновации
78 CULTURE-MAX               VALUE 100.
78 CULTURE-WAR-WIN-DELTA     VALUE 5.   *> +5 mil за победу в войне
78 CULTURE-WAR-START-DELTA   VALUE 1.   *> +1 mil за объявление войны
78 CULTURE-MERCANT-DELTA     VALUE 1.   *> +1 merc/ход при MERCANT-правителе
78 CULTURE-PIOUS-DELTA       VALUE 1.   *> +1 rel/ход при PIOUS-правителе
78 CULTURE-DISASTER-DELTA    VALUE 3.   *> +3 rel после эпидемии/неурожая
78 CULTURE-DECAY-INTERVAL    VALUE 5.   *> каждые 5 ходов −1 без подкрепления
78 CULTURE-STRONG-THRESHOLD  VALUE 50.  *> сильная культура — биас наследников
78 CULTURE-INHERIT-PERMIL    VALUE 700. *> 70% шанс взять трейт по культуре
*> Phase 19 — культурный темп эпох (МЭЛС + Дэн/Си/Ван Хуэй)
78 CULTURE-LABOUR-INTERVAL   VALUE 10.   *> «дрейф труда»: каждые 10 ходов
78 CULTURE-DIFFUSION-MIN     VALUE 30.   *> Δ соседа ≥ 30 → диффузия (Ленин)
78 CULTURE-MULT-BASE         VALUE 50.   *> множитель = (50 + culture)/150
78 CULTURE-MULT-DIVISOR      VALUE 150.  *> диапазон 0.33..2.33
78 INNOVATION-CHECK-PERMIL   VALUE 5.   *> 0.5%/регион/ход на проверку
78 INNOVATION-CAPITAL-MIN    VALUE 100000.

*> Phase 9 — правители
78 RULER-DEATH-MIN-AGE       VALUE 50.
78 RULER-DEATH-SCALE-PERMIL  VALUE 30.    *> 30‰ за каждый год сверх 50
78 RULER-DEATH-OLD-AGE       VALUE 70.
78 RULER-DEATH-OLD-SCALE     VALUE 50.    *> 50‰ за каждый год сверх 70
78 RULER-NEW-AGE-MIN         VALUE 25.
78 RULER-NEW-AGE-RANGE       VALUE 11.    *> 25..35 при наследовании
78 RULER-INHERIT-PERMIL      VALUE 600.   *> 60% шанс унаследовать трейт

*> Сознание
78 CONSCIOUSNESS-MAX         VALUE 100.
78 CONSCIOUSNESS-INIT        VALUE 10.
*> Phase 22 — рост сознания замедлен в 2-3×.
*> Маркс: классовое сознание формируется десятилетиями через борьбу,
*> а не «само собой растёт» от смены способа производства. Более того,
*> без active носителя (artisans+merchants ≥ 30%) рост не возможен —
*> крестьянские империи не имеют пролетариата чтобы вырастить сознание.
78 CONSCIOUSNESS-MERCANTILE  VALUE 0.     *> mode сам по себе уже не растит
78 CONSCIOUSNESS-PROTO-IND   VALUE 1.
78 CONSCIOUSNESS-INDUSTRIAL  VALUE 1.
78 CONSCIOUSNESS-IMPERIAL    VALUE 1.
78 CONSCIOUSNESS-URBAN-MIN   VALUE 30.    *> artisans+merchants ≥ 30 → +1
78 CONSCIOUSNESS-SPREAD      VALUE 1.     *> +1 за соседа (было +3)
78 CONSCIOUSNESS-SPREAD-MIN  VALUE 20.    *> своё ≥ 20 чтобы быть восприимчивым
78 CONSCIOUSNESS-DECAY-INTERVAL VALUE 5.  *> каждые 5 ходов −1 без подкрепления
78 CONSCIOUSNESS-AFTER-REV   VALUE 25.    *> -25 после своей революции
78 CONSCIOUSNESS-AFTER-CLASS VALUE 5.     *> -5 после class-war (репрессия)

*> Отношения
78 RELATIONS-WAR-START       VALUE 30.    *> -30 при объявлении войны
78 RELATIONS-WAR-VICTORY     VALUE 20.    *> -20 при победе/поражении
78 RELATIONS-TRADE-GAIN      VALUE 1.     *> +1 за ход активной торговли
78 RELATIONS-DECAY-STEP      VALUE 1.     *> приближение к 0 на 1/ход
78 RELATIONS-ALLIANCE        VALUE 60.    *> от +60 — союз
78 RELATIONS-VENDETTA        VALUE 60.    *> от -60 — вендетта (по модулю)
78 RELATIONS-MAX             VALUE 100.

*> Производство (множители × 1000 для интегральной арифметики)
*> Phase 11 — расширение лестницы эпох до 7 ступеней.
78 EFF-PRIMITIVE-X1000      VALUE 400.
78 EFF-SLAVE-X1000          VALUE 750.
78 EFF-FEUDAL-X1000         VALUE 1000.
78 EFF-MERCANTILE-X1000     VALUE 1100.
78 EFF-PROTO-IND-X1000      VALUE 1375.
78 EFF-INDUSTRIAL-X1000     VALUE 1700.
78 EFF-IMPERIAL-X1000       VALUE 2200.
78 EFF-SOCIALIST-X1000      VALUE 1900.

*> Прибавочная стоимость и накопление
78 SURPLUS-EQUILIBRIUM      VALUE 15.
78 SURPLUS-DELTA-DIVISOR    VALUE 3.
78 CLERGY-PACIFY-DIVISOR    VALUE 3.
78 MERCHANT-PACIFY-DIVISOR  VALUE 5.
78 CAPITAL-ACC-DIVISOR      VALUE 10.

*> Распределение
78 SUBSIST-PER-WORKER       VALUE 4.
78 SUBSIST-FAMINE-PCT       VALUE 80.
78 FAMINE-TENSION-DELTA     VALUE 15.

*> Революция
78 REVOLUTION-SURPLUS-PCT   VALUE 60.
78 REVOLUTION-NEW-TENSION   VALUE 20.
78 REVOLUTION-CLASS-BONUS   VALUE 10.
78 REVOLUTION-CLASS-CAP     VALUE 50.
78 PEASANT-FLOOR            VALUE 30.

*> Война — общие
78 WAR-DURATION             VALUE 5.
78 WAR-MILITARY-CAP         VALUE 99999.
78 NOBILITY-WEIGHT          VALUE 3.

*> Война — Dynastic
78 DYNASTIC-CAPITAL-MIN     VALUE 8000.
78 DYNASTIC-MAX-TENSION     VALUE 52.
78 DYNASTIC-NEIGHBOR-MIN    VALUE 55.

*> Война — Class
78 CLASS-WAR-MIN-TENSION    VALUE 90.
78 CLASS-WAR-NOBILITY-MIN   VALUE 5.
78 CLASS-WAR-PEASANT-LOSS   VALUE 5.
78 CLASS-WAR-LABOUR-PCT     VALUE 90.
78 CLASS-WAR-TENSION-DROP   VALUE 45.

*> Война — Crisis
78 CRISIS-WAR-CAPITAL-MIN   VALUE 3000.
78 CRISIS-WAR-MIN-TENSION   VALUE 60.
78 CRISIS-WAR-LABOUR-PCT    VALUE 85.
78 CRISIS-WAR-TENSION-DROP  VALUE 20.

*> Война — последствия победы
78 WAR-CAPITAL-SEIZE-PCT    VALUE 40.
78 WAR-LABOUR-ABSORB-PCT    VALUE 5.
78 WAR-WINNER-SURPLUS-DELTA VALUE 2.
78 WAR-WINNER-SURPLUS-CAP   VALUE 60.
78 WAR-LOSER-POP-PCT        VALUE 80.
78 WAR-TRIBUTE-DELTA        VALUE 8.
78 WAR-LOSER-SURPLUS-CAP    VALUE 70.
78 WAR-WINNER-TENSION-COST  VALUE 25.
78 WAR-LOSER-TENSION-COST   VALUE 30.
78 LABOUR-PER-CAPITA        VALUE 5.

*> Коллапс/возрождение
78 COLLAPSE-CAPITAL-FLOOR   VALUE 100000.
78 COLLAPSE-POP-FLOOR       VALUE 80000.
78 REBIRTH-DURATION         VALUE 8.
78 REBIRTH-POP              VALUE 150000.
78 REBIRTH-LABOUR           VALUE 750000.
78 REBIRTH-CAPITAL          VALUE 2000.
78 REBIRTH-SURPLUS          VALUE 30.
78 REBIRTH-TENSION          VALUE 30.
78 REBIRTH-PEASANT-PCT      VALUE 65.
78 REBIRTH-ARTISAN-PCT      VALUE 15.
78 REBIRTH-MERCHANT-PCT     VALUE 8.
78 REBIRTH-NOBILITY-PCT     VALUE 9.
78 REBIRTH-CLERGY-PCT       VALUE 3.
78 COLLAPSED-POP            VALUE 10000.
78 COLLAPSED-LABOUR         VALUE 50000.

*> Накопление → переход способа производства (расширено в Phase 11)
*> Phase 21 — базовые ставки понижены в 3-5×, добавлены минимальные
*> длительности эпох (ходы в текущем модусе перед попыткой перехода).
*> Цель: эпоха ощущается, а не пробегает за 5 ходов.
78 SLAVE-POP-MIN            VALUE 200000.
78 SLAVE-CAPITAL-MIN        VALUE 5000.
78 SLAVE-BASE-PERMIL        VALUE 10.
78 FEUDAL-CAPITAL-MIN       VALUE 50000.
78 FEUDAL-NOBILITY-MIN      VALUE 5.
78 FEUDAL-BASE-PERMIL       VALUE 15.
78 MERCANTILE-CAPITAL-MIN   VALUE 1000000.
78 MERCANTILE-MERCHANT-MIN  VALUE 10.
78 MERCANTILE-ARTISAN-ALT   VALUE 25.
78 MERCANTILE-BASE-PERMIL   VALUE 60.
78 PROTO-IND-CAPITAL-MIN    VALUE 5000000.
78 PROTO-IND-ARTISAN-MIN    VALUE 20.
78 PROTO-IND-BASE-PERMIL    VALUE 60.
78 INDUSTRIAL-CAPITAL-MIN   VALUE 20000000.
78 INDUSTRIAL-ARTISAN-MIN   VALUE 30.
78 INDUSTRIAL-BASE-PERMIL   VALUE 50.
78 IMPERIAL-CAPITAL-MIN     VALUE 100000000.
78 IMPERIAL-MERCHANT-MIN    VALUE 15.
78 IMPERIAL-BASE-PERMIL     VALUE 40.

*> Phase 22 — EPOCH-MIN-* убраны: «выдержка эпохи» создавала ощущение
*> принуждения. Темп задают сознание (revolution-путь) и накопление
*> капитала (organic-путь). WS-MODE-YEARS остаётся как информационный
*> счётчик в UI и как референс для будущих механик (post-rev cooldown).
78 IMPERIAL-WAR-BASE-PERMIL VALUE 350.
78 IMPERIAL-WAR-CAP-PERMIL  VALUE 600.
78 IMPERIAL-WAR-TRADE-MIN   VALUE 500.   *> |trade_balance| > 500 (negative)

*> Демография
78 GROWTH-RATE-PERMIL       VALUE 1015.
78 FAMINE-RATE-PCT          VALUE 96.
78 POP-FLOOR                VALUE 10000.

*> Рынок
78 MARKET-CRISIS-MULT       VALUE 12.
78 MARKET-RECOVERY-MULT     VALUE 8.
78 MARKET-PRICE-DROP-PCT    VALUE 90.
78 MARKET-PRICE-RISE-PCT    VALUE 110.
78 TRADE-EXPORT-PCT         VALUE 15.

*> Тэги способов производства (Phase 11 — все 7 ступеней)
01 WS-MODE-PRIMITIVE   PIC X(15) VALUE "PRIMITIVE      ".
01 WS-MODE-SLAVE       PIC X(15) VALUE "SLAVE          ".
01 WS-MODE-FEUDAL      PIC X(15) VALUE "FEUDAL         ".
01 WS-MODE-MERCANTILE  PIC X(15) VALUE "MERCANTILE     ".
01 WS-MODE-PROTO-IND   PIC X(15) VALUE "PROTO-INDUSTRL ".
01 WS-MODE-INDUSTRIAL  PIC X(15) VALUE "INDUSTRIAL     ".
01 WS-MODE-IMPERIAL    PIC X(15) VALUE "IMPERIAL       ".
01 WS-MODE-SOCIALIST   PIC X(15) VALUE "SOCIALIST      ".
01 WS-MODE-COLLAPSED   PIC X(15) VALUE "COLLAPSED      ".
01 WS-WAR-PEACE        PIC X(10) VALUE "PEACE     ".
01 WS-WAR-DYNASTIC     PIC X(10) VALUE "DYNASTIC  ".
01 WS-WAR-CRISIS       PIC X(10) VALUE "CRISIS    ".
01 WS-WAR-IMPERIAL     PIC X(10) VALUE "IMPERIAL  ".

*> ====================================================================
*> Рабочие переменные
*> ====================================================================

01 WS-YEAR            PIC 9(4) VALUE 0001.
01 WS-EOF             PIC 9    VALUE 0.
01 WS-IDX             PIC 99.
*> Phase 24 / Этап 1: резервные имена индексов. На Этапе 1 polity и
*> region 1:1, всё ещё адресуются через WS-IDX. WS-PIDX/WS-RIDX —
*> задел на Этап 2, когда политий станет больше регионов.
01 WS-PIDX            PIC 99.
01 WS-RIDX            PIC 99.
01 WS-NIDX            PIC 9.
01 WS-MIDX            PIC 99.
01 WS-NBREG           PIC 99.
01 WS-WIN-IDX         PIC 99.
01 WS-LOSE-IDX        PIC 99.
01 WS-COLLAPSE-CANDIDATE PIC 99.
01 WS-CLAMP-IDX       PIC 99.
01 WS-FOUND           PIC 9.

*> Parsing temporaries для decimal полей
01 WS-TMP5            PIC 9(5).
01 WS-TMP12           PIC 9(12).

*> Signed temps для арифметики
01 WS-OUTPUT-VAL      PIC S9(12)V99.
01 WS-SURPLUS-VAL     PIC S9(12)V99.
01 WS-NB-EXPORT       PIC S9(12)V99.

01 WS-OUT-LINE        PIC X(204).

*> Chronicle builder
01 WS-CHRON-YEAR      PIC 9(4).
01 WS-CHRON-TYPE      PIC X(15).
01 WS-CHRON-RGON      PIC X(20).
01 WS-CHRON-DESC      PIC X(60).
01 WS-CHRON-OUT       PIC X(99).

*> Социальная динамика
01 WS-HUNGER-FLAGS    OCCURS 10 TIMES PIC 9.   *> 0=ok, 1=mild, 2=severe
01 WS-WORKERS         PIC 9(10).
01 WS-WORKER-PCT      PIC 9(3).      *> artisans+merchants для consciousness
01 WS-SUBSIST-NEED    PIC 9(12).
01 WS-TENSION-DELTA   PIC S9(3).
01 WS-NEW-TENSION     PIC S9(3).
01 WS-PEASANT-CALC    PIC S9(4).
01 WS-PEASANT-OVERFLOW PIC S9(4).

*> Вероятностное ядро (Phase 8)
01 WS-RAND-RAW        PIC 9(9)V9(9).      *> для seed
01 WS-RAND-VAL        PIC 9(9)V9(9).      *> очередное случайное 0..1
01 WS-RAND-INT        PIC 9(4).           *> 0..999 промилле-roll
01 WS-PROB-PERMIL     PIC S9(4).          *> рассчитанная вероятность 0..1000
01 WS-EVENT-FIRES     PIC 9.              *> результат ROLL-EVENT
01 WS-NOISE-IDX       PIC 9(3).           *> 80..120 для military noise
01 WS-NOISE-NBR       PIC 9(3).
01 WS-MIL-IDX-NOISY   PIC 9(8).
01 WS-MIL-NBR-NOISY   PIC 9(8).
01 WS-RATIO-PERMIL    PIC S9(5).          *> для расчёта crisis prob

*> Военная механика
01 WS-CRISIS-FLAGS    OCCURS 10 TIMES PIC 9.
01 WS-CAPITAL-SEIZED  PIC S9(12)V99.

*> Структура региона. Производные поля (efficiency, stability) считаем на лету.
01 WS-REGIONS OCCURS 10 TIMES.
   05 WS-NAME              PIC X(20).
   05 WS-TERRAIN           PIC X(10).
   05 WS-CLIMATE           PIC X(10).
   05 WS-PRIMARY-GOOD      PIC X(15).
   05 WS-NEIGHBOR-1        PIC 99.
   05 WS-NEIGHBOR-2        PIC 99.
   05 WS-NEIGHBOR-3        PIC 99.

*> Phase 24 — Этап 1. WS-POLITIES — политический слой, отделён от
*> географии. На Этапе 1 polity[i] всегда живёт в region[i], имена
*> синхронизированы (WS-POLITY-NAME = WS-NAME).
01 WS-POLITIES OCCURS 10 TIMES.
   05 WS-POLITY-NAME       PIC X(20).
   05 WS-POPULATION        PIC 9(8).
   05 WS-PEASANTS-PCT      PIC 9(3).
   05 WS-ARTISANS-PCT      PIC 9(3).
   05 WS-MERCHANTS-PCT     PIC 9(3).
   05 WS-NOBILITY-PCT      PIC 9(3).
   05 WS-CLERGY-PCT        PIC 9(3).
   05 WS-PROD-MODE         PIC X(15).
   05 WS-LABOUR-HOURS      PIC 9(10).
   05 WS-OUTPUT-VALUE      PIC 9(10)V99.
   05 WS-SURPLUS-RATE      PIC 9(3)V99.
   05 WS-CAPITAL-STOCK     PIC 9(10)V99.
   05 WS-WAGE-FUND         PIC 9(10)V99.
   05 WS-TRADE-BALANCE     PIC S9(8)V99.
   05 WS-CLASS-TENSION     PIC 9(3).
   05 WS-MILITARY-STRENGTH PIC 9(5).
   05 WS-AT-WAR-WITH       PIC 99.
   05 WS-COLLAPSE-TIMER    PIC 9(3).
   05 WS-WAR-YEAR          PIC 9(3).
   05 WS-WAR-TYPE          PIC X(10).
*> Phase 9 — лица и сознание
   05 WS-RULER-NAME        PIC X(20).
   05 WS-RULER-AGE         PIC 9(2).
   05 WS-RULER-TRAIT       PIC X(10).
   05 WS-RULER-REIGN       PIC 9(3).
   05 WS-CONSCIOUSNESS     PIC 9(3).
*> Phase 15 — культурные векторы 0..100
   05 WS-CULT-MIL          PIC 9(3).
   05 WS-CULT-MERC         PIC 9(3).
   05 WS-CULT-REL          PIC 9(3).
*> Phase 21 — счётчик ходов в текущем модусе.
*> Сбрасывается на 0 при каждом mode-shift, COLLAPSE, REBIRTH.
*> Используется как минимальная «выдержка» эпохи перед возможностью перехода.
   05 WS-MODE-YEARS        PIC 9(4).

*> Пул имён правителей и трейтов (общий с world.cob)
01 WS-NAME-POOL.
   05 FILLER PIC X(20) VALUE "Aegon               ".
   05 FILLER PIC X(20) VALUE "Bjorn               ".
   05 FILLER PIC X(20) VALUE "Cassio              ".
   05 FILLER PIC X(20) VALUE "Drago               ".
   05 FILLER PIC X(20) VALUE "Erik                ".
   05 FILLER PIC X(20) VALUE "Finn                ".
   05 FILLER PIC X(20) VALUE "Gareth              ".
   05 FILLER PIC X(20) VALUE "Hakon               ".
   05 FILLER PIC X(20) VALUE "Ivar                ".
   05 FILLER PIC X(20) VALUE "Jorah               ".
   05 FILLER PIC X(20) VALUE "Kael                ".
   05 FILLER PIC X(20) VALUE "Lothar              ".
   05 FILLER PIC X(20) VALUE "Maric               ".
   05 FILLER PIC X(20) VALUE "Nikos               ".
   05 FILLER PIC X(20) VALUE "Orin                ".
   05 FILLER PIC X(20) VALUE "Petyr               ".
   05 FILLER PIC X(20) VALUE "Roland              ".
   05 FILLER PIC X(20) VALUE "Sigurd              ".
   05 FILLER PIC X(20) VALUE "Theron              ".
   05 FILLER PIC X(20) VALUE "Ulf                 ".
01 WS-NAMES REDEFINES WS-NAME-POOL.
   05 WS-NAME-ENTRY OCCURS 20 TIMES PIC X(20).

01 WS-TRAITS-POOL.
   05 FILLER PIC X(10) VALUE "AMBITIOUS ".
   05 FILLER PIC X(10) VALUE "CAUTIOUS  ".
   05 FILLER PIC X(10) VALUE "CRUEL     ".
   05 FILLER PIC X(10) VALUE "PIOUS     ".
   05 FILLER PIC X(10) VALUE "MERCANT   ".
01 WS-TRAITS REDEFINES WS-TRAITS-POOL.
   05 WS-TRAIT-ENTRY OCCURS 5 TIMES PIC X(10).

01 WS-NAME-IDX          PIC 99.
01 WS-TRAIT-IDX         PIC 9.

*> Phase 10 — миграция при коллапсе
01 WS-LIVING-NEIGHBORS  PIC 9.
01 WS-MIGRATION-POOL    PIC 9(8).
01 WS-REFUGEE-SHARE     PIC 9(8).

*> Phase 13 — древо; Phase 17 — L3 choice; Phase 18 — L4 sub-tech choice.
*> level: 0..4 — глубина в ветви (0 = ничего, 4 = вышел на L4 sub-tech)
*> progress: 0..100 — прогресс к следующему уровню
*> l3-choice: 0 = ещё не выбрано, 1/2/3 = какая из L3 альтернатив
*> l4-choice: 0 = ещё не выбрано, 1/2 = какой sub-tech внутри L3 alt
01 WS-TECH OCCURS 10 TIMES.
   05 WS-TECH-LEVEL     OCCURS 4 TIMES PIC 9.
   05 WS-TECH-PROGRESS  OCCURS 4 TIMES PIC 9(3).
   05 WS-TECH-L3-CHOICE OCCURS 4 TIMES PIC 9.
   05 WS-TECH-L4-CHOICE OCCURS 4 TIMES PIC 9.

01 WS-TECH-FILE-STATUS PIC XX.
01 WS-BIDX             PIC 9.        *> branch index 1..4
01 WS-TECH-INC         PIC S9(4).    *> прогресс инкремент в ход
01 WS-CLASS-PCT        PIC 9(3).     *> профильный класс для ветви
01 WS-DIFFUSION-FOUND  PIC 9.        *> 1 если у соседа есть тех >= нашего уровня
01 WS-LOOT-BRANCH      PIC 9.        *> ветвь, по которой можно ограбить
01 WS-LOOT-LEVEL       PIC 9.        *> уровень, до которого подтягиваем
01 WS-LOOT-NAME        PIC X(20).    *> имя награбленной технологии

*> Phase 17 — взвешенный выбор L3 альтернативы
01 WS-ALT-WEIGHT-1     PIC 9(3).
01 WS-ALT-WEIGHT-2     PIC 9(3).
01 WS-ALT-WEIGHT-3     PIC 9(3).
01 WS-ALT-WEIGHT-TOTAL PIC 9(4).
01 WS-ALT-CUMULATIVE   PIC 9(4).
01 WS-ALT-ROLL         PIC 9(4).
01 WS-ALT-CHOICE       PIC 9.

*> Матрица отношений 10×10 + рабочие переменные
01 WS-RELATIONS         OCCURS 10 TIMES.
   05 WS-REL-ROW        OCCURS 10 TIMES PIC S9(3).
01 WS-REL-FILE-STATUS   PIC XX.
01 WS-REL-LINE          PIC X(60).
01 WS-REL-OUT           PIC 9(4).
01 WS-REL-IN            PIC 9(4).
01 WS-REL-TMP           PIC S9(4).
01 WS-RJ                PIC 99.
01 WS-RK                PIC 99.

*> Глобальный рынок: 8 товаров
01 WS-MARKET.
   05 WS-MKT OCCURS 8 TIMES.
      10 WS-MKT-NAME    PIC X(15).
      10 WS-MKT-SUPPLY  PIC S9(12)V99.
      10 WS-MKT-DEMAND  PIC S9(12)V99.
      10 WS-MKT-PRICE   PIC 9(5)V99.
      10 WS-MKT-CRISIS  PIC 9.

*> Эталонные цены: floor 50%, ceiling 300%. Не эволюционируют, нужны для clamp.
01 WS-MKT-DEFAULTS.
   05 WS-MKT-DFLT OCCURS 8 TIMES PIC 9(5)V99.

*> Беззнаковые буферы для записи market.dat (STRING без overpunch-знака)
01 WS-MKT-OUT-SUPPLY  PIC 9(12)V99.
01 WS-MKT-OUT-DEMAND  PIC 9(12)V99.
01 WS-MARKET-OUT-LINE PIC X(60).

*> Чтение market.dat от прошлого хода для персистенции цен
01 WS-MKT-FILE-STATUS PIC XX.
01 WS-MKT-PRICE-RAW   PIC 9(7).

*> Debug: переменная окружения ECOS_DEBUG=1 включает лог вероятностей в stderr
01 WS-DEBUG-FLAG      PIC X(10) VALUE SPACES.
01 WS-DEBUG-LABEL     PIC X(15).

PROCEDURE DIVISION.
MAIN-PARA.
    PERFORM READ-YEAR
    ACCEPT WS-DEBUG-FLAG FROM ENVIRONMENT "ECOS_DEBUG"
*> Сидим RANDOM от номера года: одинаковый мир воспроизводим внутри запуска,
*> но события распределены по всему диапазону вероятностей по годам.
    MOVE FUNCTION RANDOM(WS-YEAR) TO WS-RAND-RAW
    PERFORM INIT-MARKET
    PERFORM READ-WORLD
    PERFORM LOAD-RELATIONS
    PERFORM LOAD-TECH
    OPEN EXTEND CHRONICLE-FILE
*>  Phase 21 — каждый ход: возраст эпохи у живых регионов растёт на 1.
    PERFORM TICK-MODE-YEARS
    PERFORM PRODUCE-ALL
    PERFORM MARKET-AGGREGATE
    PERFORM CHECK-CRISIS
    PERFORM PROPAGATE-CRISIS
    PERFORM WRITE-MARKET
    PERFORM TRADE-ALL
    PERFORM WAR-CHECK-ALL
    PERFORM WAR-RESOLVE-ALL
    PERFORM DISTRIBUTE-ALL
    PERFORM DEMOGRAPHY-ALL
    PERFORM CLIMATE-EVENTS-ALL
    PERFORM CONSCIOUSNESS-ALL
    PERFORM CLASS-DRIFT-ALL
    PERFORM SOCIAL-ALL
    PERFORM ACCUMULATE-ALL
    PERFORM TECH-RESEARCH-ALL
    PERFORM CULTURE-DRIFT-ALL
    PERFORM INNOVATION-CHECK-ALL
    PERFORM CALC-MILITARY
    PERFORM AGE-RULERS
    PERFORM RELATIONS-DECAY
    PERFORM CLAMP-ALL-TENSIONS
    CLOSE CHRONICLE-FILE
    PERFORM WRITE-WORLD
    PERFORM WRITE-RELATIONS
    PERFORM WRITE-TECH
    STOP RUN.

READ-YEAR.
    OPEN INPUT YEAR-FILE
    READ YEAR-FILE INTO WS-YEAR-REC
        AT END     MOVE 1 TO WS-YEAR
        NOT AT END MOVE FUNCTION NUMVAL(
                       FUNCTION TRIM(WS-YEAR-REC)) TO WS-YEAR
    END-READ
    CLOSE YEAR-FILE.

INIT-MARKET.
    MOVE "GRAIN          " TO WS-MKT-NAME(1)
    MOVE 12000000.00       TO WS-MKT-DEMAND(1)
    MOVE 1.00              TO WS-MKT-PRICE(1)
    MOVE 1.00              TO WS-MKT-DFLT(1)

    MOVE "TIMBER         " TO WS-MKT-NAME(2)
    MOVE 12000000.00       TO WS-MKT-DEMAND(2)
    MOVE 1.20              TO WS-MKT-PRICE(2)
    MOVE 1.20              TO WS-MKT-DFLT(2)

    MOVE "ORE            " TO WS-MKT-NAME(3)
    MOVE 6000000.00        TO WS-MKT-DEMAND(3)
    MOVE 2.00              TO WS-MKT-PRICE(3)
    MOVE 2.00              TO WS-MKT-DFLT(3)

    MOVE "PEAT           " TO WS-MKT-NAME(4)
    MOVE 3000000.00        TO WS-MKT-DEMAND(4)
    MOVE 0.80              TO WS-MKT-PRICE(4)
    MOVE 0.80              TO WS-MKT-DFLT(4)

    MOVE "FISH           " TO WS-MKT-NAME(5)
    MOVE 6000000.00        TO WS-MKT-DEMAND(5)
    MOVE 1.00              TO WS-MKT-PRICE(5)
    MOVE 1.00              TO WS-MKT-DFLT(5)

    MOVE "SPICES         " TO WS-MKT-NAME(6)
    MOVE 3000000.00        TO WS-MKT-DEMAND(6)
    MOVE 4.00              TO WS-MKT-PRICE(6)
    MOVE 4.00              TO WS-MKT-DFLT(6)

    MOVE "SALT           " TO WS-MKT-NAME(7)
    MOVE 5000000.00        TO WS-MKT-DEMAND(7)
    MOVE 1.50              TO WS-MKT-PRICE(7)
    MOVE 1.50              TO WS-MKT-DFLT(7)

    MOVE "COAL           " TO WS-MKT-NAME(8)
    MOVE 4000000.00        TO WS-MKT-DEMAND(8)
    MOVE 2.50              TO WS-MKT-PRICE(8)
    MOVE 2.50              TO WS-MKT-DFLT(8)

*>  Цены могут уже быть на диске от прошлого хода — перезатираем дефолт.
    PERFORM LOAD-PERSISTED-PRICES

    PERFORM VARYING WS-MIDX FROM 1 BY 1 UNTIL WS-MIDX > MARKET-COUNT
        MOVE 0 TO WS-MKT-SUPPLY(WS-MIDX)
        MOVE 0 TO WS-MKT-CRISIS(WS-MIDX)
    END-PERFORM.

LOAD-PERSISTED-PRICES.
*> Если market.dat содержит 8 валидных строк — используем оттуда цены.
*> Иначе оставляем defaults (первый запуск или повреждённый файл).
*> Demand остаётся из defaults (это структурная константа, не эволюционирует).
    MOVE "00" TO WS-MKT-FILE-STATUS
    OPEN INPUT MARKET-FILE
    IF WS-MKT-FILE-STATUS = "00"
        MOVE 0 TO WS-EOF
        PERFORM VARYING WS-MIDX FROM 1 BY 1
                UNTIL WS-MIDX > MARKET-COUNT OR WS-EOF = 1
            READ MARKET-FILE INTO WS-MARKET-REC
                AT END
                    MOVE 1 TO WS-EOF
                NOT AT END
*>                  price на оффсете 44, длина 7 (1-indexed COBOL)
                    MOVE FUNCTION NUMVAL(WS-MARKET-REC(44:7))
                        TO WS-MKT-PRICE-RAW
                    COMPUTE WS-MKT-PRICE(WS-MIDX) = WS-MKT-PRICE-RAW / 100
            END-READ
        END-PERFORM
        CLOSE MARKET-FILE
    END-IF.

READ-WORLD.
*>  Phase 24 — Этап 1: чтение двух файлов параллельно (regions.dat
*>  и polities.dat). Цикл общий — на Этапе 1 индекс politiy = индекс
*>  region. На Этапе 2+ цикл по политиям расщепится отдельно.
    OPEN INPUT REGIONS-FILE
    OPEN INPUT POLITIES-FILE
    MOVE 0 TO WS-EOF
    PERFORM VARYING WS-IDX FROM 1 BY 1
            UNTIL WS-IDX > REGION-COUNT OR WS-EOF = 1
        READ REGIONS-FILE INTO WS-REGION-REC
            AT END     MOVE 1 TO WS-EOF
            NOT AT END PERFORM PARSE-REGION-RECORD
        END-READ
        IF WS-EOF = 0
            READ POLITIES-FILE INTO WS-POLITY-REC
                AT END     MOVE 1 TO WS-EOF
                NOT AT END PERFORM PARSE-POLITY-RECORD
            END-READ
        END-IF
    END-PERFORM
    CLOSE REGIONS-FILE
    CLOSE POLITIES-FILE.

PARSE-REGION-RECORD.
*>  Геофон. Layout regions.dat (1-indexed COBOL):
*>    NAME        @ 1   len 20
*>    TERRAIN     @ 21  len 10
*>    CLIMATE     @ 31  len 10
*>    PRIMARY-GOOD @ 41 len 15
*>    NEIGHBOR-1  @ 56  len 2
*>    NEIGHBOR-2  @ 58  len 2
*>    NEIGHBOR-3  @ 60  len 2
    MOVE WS-REGION-REC(1:20)                   TO WS-NAME(WS-IDX)
    MOVE WS-REGION-REC(21:10)                  TO WS-TERRAIN(WS-IDX)
    MOVE WS-REGION-REC(31:10)                  TO WS-CLIMATE(WS-IDX)
    MOVE WS-REGION-REC(41:15)                  TO WS-PRIMARY-GOOD(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-REGION-REC(56:2))  TO WS-NEIGHBOR-1(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-REGION-REC(58:2))  TO WS-NEIGHBOR-2(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-REGION-REC(60:2))  TO WS-NEIGHBOR-3(WS-IDX).

PARSE-POLITY-RECORD.
*>  Политический слой. Layout polities.dat (1-indexed COBOL):
*>    POLITY-NAME    @ 1   len 20
*>    POPULATION     @ 21  len 8
*>    PEASANTS-PCT   @ 29  len 3
*>    ARTISANS-PCT   @ 32  len 3
*>    MERCHANTS-PCT  @ 35  len 3
*>    NOBILITY-PCT   @ 38  len 3
*>    CLERGY-PCT     @ 41  len 3
*>    PROD-MODE      @ 44  len 15
*>    LABOUR-HOURS   @ 59  len 10
*>    SURPLUS-RATE   @ 69  len 5    (×100, делим)
*>    CAPITAL-STOCK  @ 74  len 12   (×100, делим)
*>    CLASS-TENSION  @ 86  len 3
*>    MILITARY-STR   @ 89  len 5
*>    AT-WAR-WITH    @ 94  len 2
*>    COLLAPSE-TIMER @ 96  len 3
*>    WAR-YEAR       @ 99  len 3
*>    WAR-TYPE       @ 102 len 10
*>    RULER-NAME     @ 112 len 20
*>    RULER-AGE      @ 132 len 2
*>    RULER-TRAIT    @ 134 len 10
*>    RULER-REIGN    @ 144 len 3
*>    CONSCIOUSNESS  @ 147 len 3
*>    CULT-MIL       @ 150 len 3
*>    CULT-MERC      @ 153 len 3
*>    CULT-REL       @ 156 len 3
*>    MODE-YEARS     @ 159 len 4   = 162 байт (запись)
    MOVE WS-POLITY-REC(1:20)                   TO WS-POLITY-NAME(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(21:8))  TO WS-POPULATION(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(29:3))  TO WS-PEASANTS-PCT(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(32:3))  TO WS-ARTISANS-PCT(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(35:3))  TO WS-MERCHANTS-PCT(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(38:3))  TO WS-NOBILITY-PCT(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(41:3))  TO WS-CLERGY-PCT(WS-IDX)
    MOVE WS-POLITY-REC(44:15)                  TO WS-PROD-MODE(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(59:10)) TO WS-LABOUR-HOURS(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(69:5))  TO WS-TMP5
    COMPUTE WS-SURPLUS-RATE(WS-IDX)  = WS-TMP5 / 100
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(74:12)) TO WS-TMP12
    COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-TMP12 / 100
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(86:3))  TO WS-CLASS-TENSION(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(89:5))  TO WS-MILITARY-STRENGTH(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(94:2))  TO WS-AT-WAR-WITH(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(96:3))  TO WS-COLLAPSE-TIMER(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(99:3))  TO WS-WAR-YEAR(WS-IDX)
    MOVE WS-POLITY-REC(102:10)                 TO WS-WAR-TYPE(WS-IDX)
    MOVE WS-POLITY-REC(112:20)                 TO WS-RULER-NAME(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(132:2)) TO WS-RULER-AGE(WS-IDX)
    MOVE WS-POLITY-REC(134:10)                 TO WS-RULER-TRAIT(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(144:3)) TO WS-RULER-REIGN(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(147:3)) TO WS-CONSCIOUSNESS(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(150:3)) TO WS-CULT-MIL(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(153:3)) TO WS-CULT-MERC(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(156:3)) TO WS-CULT-REL(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(159:4)) TO WS-MODE-YEARS(WS-IDX).

    MOVE 0         TO WS-OUTPUT-VALUE(WS-IDX)
    MOVE 0         TO WS-WAGE-FUND(WS-IDX)
    MOVE 0         TO WS-TRADE-BALANCE(WS-IDX).

PRODUCE-ALL.
*> Шаг 1: производство — трудовая стоимость через рабочие часы.
*> Производительность выводится из способа производства (на лету, не хранится).
*> Phase 11 — 7 эпох: PRIMITIVE/SLAVE/FEUDAL/MERCANTILE/PROTO-IND/INDUSTRIAL/IMPERIAL.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            EVALUATE WS-PROD-MODE(WS-IDX)
                WHEN WS-MODE-PRIMITIVE
                    COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX)
                                          * EFF-PRIMITIVE-X1000 / 1000
                WHEN WS-MODE-SLAVE
                    COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX)
                                          * EFF-SLAVE-X1000 / 1000
                WHEN WS-MODE-MERCANTILE
                    COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX)
                                          * EFF-MERCANTILE-X1000 / 1000
                WHEN WS-MODE-PROTO-IND
                    COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX)
                                          * EFF-PROTO-IND-X1000 / 1000
                WHEN WS-MODE-INDUSTRIAL
                    COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX)
                                          * EFF-INDUSTRIAL-X1000 / 1000
                WHEN WS-MODE-IMPERIAL
                    COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX)
                                          * EFF-IMPERIAL-X1000 / 1000
                WHEN WS-MODE-SOCIALIST
                    COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX)
                                          * EFF-SOCIALIST-X1000 / 1000
                WHEN OTHER
                    COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX)
                                          * EFF-FEUDAL-X1000 / 1000
            END-EVALUATE
*>          Phase 13: Bronze (L1) ×1.05. Phase 17: L3 alternatives расходятся.
            IF WS-TECH-LEVEL(WS-IDX, 1) >= 1
                COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 105 / 100
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 1) >= 3
                EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 1)
                    WHEN 1
*>                      Steam — индустриальный output ×1.20
                        COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 120 / 100
                    WHEN 2
*>                      Forging — на output не влияет (military в CALC-MILITARY)
                        CONTINUE
                    WHEN 3
*>                      Hydraulics — устойчивая ×1.15
                        COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 115 / 100
                END-EVALUATE
            END-IF
*>          Phase 18 PROD L4: Gasoline +output 10%, WindTurb/Tidal +5%, Crossbow +5%
            IF WS-TECH-LEVEL(WS-IDX, 1) >= 4
                EVALUATE TRUE
                    WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 1
                         AND WS-TECH-L4-CHOICE(WS-IDX, 1) = 1
*>                      Gasoline engines — массовая мобильность
                        COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 110 / 100
                    WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 3
                        COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 105 / 100
                    WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 2
                         AND WS-TECH-L4-CHOICE(WS-IDX, 1) = 2
*>                      Crossbow mass production — slight output boost
                        COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 105 / 100
                END-EVALUATE
            END-IF
            MOVE WS-OUTPUT-VAL TO WS-OUTPUT-VALUE(WS-IDX)
*>          Прибавочная стоимость: изъятие правящим классом
            COMPUTE WS-SURPLUS-VAL = WS-OUTPUT-VAL
                                   * WS-SURPLUS-RATE(WS-IDX) / 100
*>          1/CAPITAL-ACC-DIVISOR прибавочной стоимости → накопление капитала
            COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
                + WS-SURPLUS-VAL / CAPITAL-ACC-DIVISOR
*>          Phase 13: Banking (ORG L2) ×1.3.
*>          Phase 17: ORG L3 расходится — Joint-Stock дальше ускоряет accum,
*>          Cooperatives стабилизирует tension, Cartels работает через trade.
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 2
                COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
                    + WS-SURPLUS-VAL / CAPITAL-ACC-DIVISOR * 30 / 100
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 3
                EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 2)
                    WHEN 1
                        COMPUTE WS-CAPITAL-STOCK(WS-IDX) =
                            WS-CAPITAL-STOCK(WS-IDX)
                            + WS-SURPLUS-VAL / CAPITAL-ACC-DIVISOR * 20 / 100
                    WHEN 2
                        CONTINUE
                    WHEN 3
                        COMPUTE WS-CAPITAL-STOCK(WS-IDX) =
                            WS-CAPITAL-STOCK(WS-IDX)
                            + WS-SURPLUS-VAL / CAPITAL-ACC-DIVISOR * 10 / 100
                END-EVALUATE
            END-IF
*>          Phase 18 ORG L4: StockMkt/LimLiab/Trusts/VertInt — каждый +10% к accum.
*>          MutAid/WorkOwn → эффект на tension в SOCIAL-ALL.
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 4
                EVALUATE TRUE
                    WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 1
                        COMPUTE WS-CAPITAL-STOCK(WS-IDX) =
                            WS-CAPITAL-STOCK(WS-IDX)
                            + WS-SURPLUS-VAL / CAPITAL-ACC-DIVISOR * 10 / 100
                    WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 3
                        COMPUTE WS-CAPITAL-STOCK(WS-IDX) =
                            WS-CAPITAL-STOCK(WS-IDX)
                            + WS-SURPLUS-VAL / CAPITAL-ACC-DIVISOR * 10 / 100
                END-EVALUATE
            END-IF
*>          Зарплатный фонд = output − surplus (воспроизводство рабочей силы)
            COMPUTE WS-WAGE-FUND(WS-IDX) = WS-OUTPUT-VAL - WS-SURPLUS-VAL
        ELSE
            MOVE 0 TO WS-OUTPUT-VALUE(WS-IDX)
            MOVE 0 TO WS-WAGE-FUND(WS-IDX)
        END-IF
    END-PERFORM.

MARKET-AGGREGATE.
*> Шаг 2: агрегация предложения по товарам
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        MOVE 0 TO WS-FOUND
        PERFORM VARYING WS-MIDX FROM 1 BY 1
                UNTIL WS-MIDX > MARKET-COUNT OR WS-FOUND = 1
            IF FUNCTION TRIM(WS-MKT-NAME(WS-MIDX)) =
               FUNCTION TRIM(WS-PRIMARY-GOOD(WS-IDX))
                ADD WS-OUTPUT-VALUE(WS-IDX) TO WS-MKT-SUPPLY(WS-MIDX)
                MOVE 1 TO WS-FOUND
            END-IF
        END-PERFORM
    END-PERFORM.

CHECK-CRISIS.
*> Кризис перепроизводства: цены корректируются, но кризис-флаг — вероятностный.
*> После каждой коррекции цена зажимается в [50%, 300%] от default,
*> чтобы не уходить в нерелистичные значения 0.05 или 50.00.
    PERFORM VARYING WS-MIDX FROM 1 BY 1 UNTIL WS-MIDX > MARKET-COUNT
        IF WS-MKT-SUPPLY(WS-MIDX) >
           WS-MKT-DEMAND(WS-MIDX) * MARKET-CRISIS-MULT / 10
            IF WS-MKT-DEMAND(WS-MIDX) > 0
                COMPUTE WS-RATIO-PERMIL =
                    WS-MKT-SUPPLY(WS-MIDX) * 1000
                    / WS-MKT-DEMAND(WS-MIDX) - 1000
            ELSE
                MOVE 1000 TO WS-RATIO-PERMIL
            END-IF
            COMPUTE WS-PROB-PERMIL = WS-RATIO-PERMIL * 15 / 10
            IF WS-PROB-PERMIL > CRISIS-PROB-CAP-PERMIL
                MOVE CRISIS-PROB-CAP-PERMIL TO WS-PROB-PERMIL
            END-IF
            COMPUTE WS-MKT-PRICE(WS-MIDX) =
                WS-MKT-PRICE(WS-MIDX) * MARKET-PRICE-DROP-PCT / 100
            PERFORM CLAMP-PRICE
            MOVE "MARKET-CRISIS " TO WS-DEBUG-LABEL
            PERFORM ROLL-EVENT
            IF WS-EVENT-FIRES = 1
                MOVE 1 TO WS-MKT-CRISIS(WS-MIDX)
                MOVE WS-YEAR              TO WS-CHRON-YEAR
                MOVE "CRISIS         "    TO WS-CHRON-TYPE
                MOVE "GLOBAL              " TO WS-CHRON-RGON
                STRING FUNCTION TRIM(WS-MKT-NAME(WS-MIDX)) DELIMITED SIZE
                       " overproduction. Price collapsed." DELIMITED SIZE
                       INTO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            ELSE
                MOVE 0 TO WS-MKT-CRISIS(WS-MIDX)
            END-IF
        ELSE IF WS-MKT-SUPPLY(WS-MIDX) > 0 AND
                WS-MKT-SUPPLY(WS-MIDX) <
                WS-MKT-DEMAND(WS-MIDX) * MARKET-RECOVERY-MULT / 10
            COMPUTE WS-MKT-PRICE(WS-MIDX) =
                WS-MKT-PRICE(WS-MIDX) * MARKET-PRICE-RISE-PCT / 100
            PERFORM CLAMP-PRICE
            MOVE 0 TO WS-MKT-CRISIS(WS-MIDX)
        ELSE
            MOVE 0 TO WS-MKT-CRISIS(WS-MIDX)
        END-IF
    END-PERFORM.

CLAMP-PRICE.
*> Зажимаем WS-MKT-PRICE(WS-MIDX) в [50%, 300%] от default.
    IF WS-MKT-PRICE(WS-MIDX) < WS-MKT-DFLT(WS-MIDX) / 2
        COMPUTE WS-MKT-PRICE(WS-MIDX) = WS-MKT-DFLT(WS-MIDX) / 2
    END-IF
    IF WS-MKT-PRICE(WS-MIDX) > WS-MKT-DFLT(WS-MIDX) * 3
        COMPUTE WS-MKT-PRICE(WS-MIDX) = WS-MKT-DFLT(WS-MIDX) * 3
    END-IF.

CLAMP-TENSION.
*> Caller выставляет WS-CLAMP-IDX. Зажимает WS-CLASS-TENSION в [0, 100].
*> Заменяет повторяющийся блок IF > 100 MOVE 100 в десятке мест.
    IF WS-CLASS-TENSION(WS-CLAMP-IDX) > 100
        MOVE 100 TO WS-CLASS-TENSION(WS-CLAMP-IDX)
    END-IF.

CLAMP-ALL-TENSIONS.
*> Финальная защитная зачистка перед WRITE-WORLD: гарантия инварианта 0..100.
*> Дешёвая страховка от любого бага в логике начисления tension.
    PERFORM VARYING WS-CLAMP-IDX FROM 1 BY 1
            UNTIL WS-CLAMP-IDX > REGION-COUNT
        PERFORM CLAMP-TENSION
    END-PERFORM.

CONSCIOUSNESS-ALL.
*> Phase 22 — переписан под марксистскую логику классового сознания:
*>  • без active носителя (artisans+merchants ≥ 30%) сознание не растёт;
*>  • базовые ставки уменьшены вдвое-втрое относительно Phase 15;
*>  • decay −1 каждые 5 ходов без подкрепления (как у culture);
*>  • заражение от соседей слабее (+1 вместо +3) и требует своей основы.
*> COLLAPSED регионы пропускаем — у них преемственность сломана.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
*>          Структурное условие: без рабочего класса (artisans+merchants
*>          ≥ CONSCIOUSNESS-URBAN-MIN) сознание не накапливается.
*>          В крестьянских империях оно остаётся на нуле.
            COMPUTE WS-WORKER-PCT =
                WS-ARTISANS-PCT(WS-IDX) + WS-MERCHANTS-PCT(WS-IDX)
            IF WS-WORKER-PCT >= CONSCIOUSNESS-URBAN-MIN
*>              Бонус от способа производства — теперь только начиная с
*>              PROTO-IND (мануфактура создаёт скопление пролетариата).
*>              MERCANTILE сама по себе сознание не растит — для торгового
*>              капитала сознание не его задача.
                EVALUATE WS-PROD-MODE(WS-IDX)
                    WHEN WS-MODE-PROTO-IND
                        ADD CONSCIOUSNESS-PROTO-IND
                            TO WS-CONSCIOUSNESS(WS-IDX)
                    WHEN WS-MODE-INDUSTRIAL
                        ADD CONSCIOUSNESS-INDUSTRIAL
                            TO WS-CONSCIOUSNESS(WS-IDX)
                    WHEN WS-MODE-IMPERIAL
                        ADD CONSCIOUSNESS-IMPERIAL
                            TO WS-CONSCIOUSNESS(WS-IDX)
                END-EVALUATE
*>              Knowledge tech даёт сознанию материал — но в разы слабее
*>              чем до Phase 22. Books и наука помогают, но не «капают»
*>              сознание сами.
                EVALUATE TRUE
                    WHEN WS-TECH-LEVEL(WS-IDX, 3) >= 3
                        EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 3)
                            WHEN 1 ADD 1 TO WS-CONSCIOUSNESS(WS-IDX)
                            WHEN 2 ADD 1 TO WS-CONSCIOUSNESS(WS-IDX)
                            WHEN 3 ADD 0 TO WS-CONSCIOUSNESS(WS-IDX)
                            WHEN OTHER ADD 1 TO WS-CONSCIOUSNESS(WS-IDX)
                        END-EVALUATE
                    WHEN WS-TECH-LEVEL(WS-IDX, 3) >= 2
*>                      Printing — раз в 2 хода даёт +1 (MOD трюк)
                        IF FUNCTION MOD(WS-YEAR, 2) = 0
                            ADD 1 TO WS-CONSCIOUSNESS(WS-IDX)
                        END-IF
                END-EVALUATE
*>              L4 KNOW: только SciMethod даёт сознательный edge,
*>              Theology — обратное (легитимация — снижение давления).
                IF WS-TECH-LEVEL(WS-IDX, 3) >= 4
                   AND WS-TECH-L3-CHOICE(WS-IDX, 3) = 1
                   AND WS-TECH-L4-CHOICE(WS-IDX, 3) = 1
                   AND FUNCTION MOD(WS-YEAR, 2) = 0
                    ADD 1 TO WS-CONSCIOUSNESS(WS-IDX)
                END-IF
*>              Заражение от соседей с революционной обстановкой —
*>              слабее (+1) и требует своей основы (без класса нет
*>              восприимчивости).
                IF WS-CONSCIOUSNESS(WS-IDX) >= CONSCIOUSNESS-SPREAD-MIN
                    PERFORM CONSCIOUSNESS-CONTAGION
                        VARYING WS-NIDX FROM 1 BY 1
                        UNTIL WS-NIDX > 3
                END-IF
            END-IF
*>          Decay — каждые N ходов −1 у всех ненулевых.
*>          Без active поддержки сознание угасает (период реакции,
*>          смена поколений, забвение опыта борьбы).
            IF FUNCTION MOD(WS-YEAR, CONSCIOUSNESS-DECAY-INTERVAL) = 0
                IF WS-CONSCIOUSNESS(WS-IDX) > 0
                    SUBTRACT 1 FROM WS-CONSCIOUSNESS(WS-IDX)
                END-IF
            END-IF
*>          Cap
            IF WS-CONSCIOUSNESS(WS-IDX) > CONSCIOUSNESS-MAX
                MOVE CONSCIOUSNESS-MAX TO WS-CONSCIOUSNESS(WS-IDX)
            END-IF
        END-IF
    END-PERFORM.

CONSCIOUSNESS-CONTAGION.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-IDX) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-IDX) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-IDX) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-CLASS-TENSION(WS-NBREG) >= 90
        ADD CONSCIOUSNESS-SPREAD TO WS-CONSCIOUSNESS(WS-IDX)
    END-IF.

CLASS-DRIFT-ALL.
*> Phase 10. Медленный демографический сдвиг между классами каждый ход.
*> 5 микро-переходов: урбанизация, коммерциализация, аристократический упадок,
*> религиозное возрождение, рурализация в голод.
*> Каждый — 1 пп при срабатывании, общая сумма классов сохраняется.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            PERFORM DRIFT-URBANIZATION
            PERFORM DRIFT-COMMERCE
            PERFORM DRIFT-DECLINE
            PERFORM DRIFT-CLERGY
            PERFORM DRIFT-RURAL
        END-IF
    END-PERFORM.

DRIFT-URBANIZATION.
*> peasants → artisans в MERCANTILE+. Городская революция: рабочие тянутся
*> в мануфактурные центры.
    IF (WS-PROD-MODE(WS-IDX) = WS-MODE-MERCANTILE
        OR WS-PROD-MODE(WS-IDX) = WS-MODE-PROTO-IND)
       AND WS-PEASANTS-PCT(WS-IDX) > DRIFT-URBAN-MIN-PEAS
       AND WS-ARTISANS-PCT(WS-IDX) < REVOLUTION-CLASS-CAP
        MOVE DRIFT-URBANIZE-PERMIL TO WS-PROB-PERMIL
        MOVE "DRIFT-URBANIZE" TO WS-DEBUG-LABEL
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
            SUBTRACT 1 FROM WS-PEASANTS-PCT(WS-IDX)
            ADD 1 TO WS-ARTISANS-PCT(WS-IDX)
        END-IF
    END-IF.

DRIFT-COMMERCE.
*> artisans → merchants. Усиливается на побережье и при MERCANT-правителе.
*> Успешные ремесленники перерастают в мелких торговцев.
    IF WS-ARTISANS-PCT(WS-IDX) > DRIFT-COMMERCE-MIN-ART
       AND WS-MERCHANTS-PCT(WS-IDX) < REVOLUTION-CLASS-CAP
        MOVE DRIFT-COMMERCE-PERMIL TO WS-PROB-PERMIL
        IF WS-TERRAIN(WS-IDX) = "COAST     "
            ADD DRIFT-COMMERCE-COAST TO WS-PROB-PERMIL
        END-IF
        IF WS-RULER-TRAIT(WS-IDX) = "MERCANT   "
            ADD DRIFT-COMMERCE-MERCANT TO WS-PROB-PERMIL
        END-IF
        MOVE "DRIFT-COMMERCE" TO WS-DEBUG-LABEL
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
            SUBTRACT 1 FROM WS-ARTISANS-PCT(WS-IDX)
            ADD 1 TO WS-MERCHANTS-PCT(WS-IDX)
        END-IF
    END-IF.

DRIFT-DECLINE.
*> nobility → peasants в MERCANTILE+. Буржуазия теснит аристократию,
*> младшие сыновья, лишившиеся земли, вливаются в массу.
    IF (WS-PROD-MODE(WS-IDX) = WS-MODE-MERCANTILE
        OR WS-PROD-MODE(WS-IDX) = WS-MODE-PROTO-IND)
       AND WS-NOBILITY-PCT(WS-IDX) > DRIFT-DECLINE-MIN-NOB
        MOVE DRIFT-DECLINE-PERMIL TO WS-PROB-PERMIL
        MOVE "DRIFT-DECLINE " TO WS-DEBUG-LABEL
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
            SUBTRACT 1 FROM WS-NOBILITY-PCT(WS-IDX)
            ADD 1 TO WS-PEASANTS-PCT(WS-IDX)
        END-IF
    END-IF.

DRIFT-CLERGY.
*> peasants → clergy. PIOUS-правитель сильно усиливает.
    IF WS-CLERGY-PCT(WS-IDX) < DRIFT-CLERGY-MAX
       AND WS-PEASANTS-PCT(WS-IDX) > DRIFT-URBAN-MIN-PEAS
        MOVE DRIFT-CLERGY-PERMIL TO WS-PROB-PERMIL
        IF WS-RULER-TRAIT(WS-IDX) = "PIOUS     "
            ADD DRIFT-CLERGY-PIOUS TO WS-PROB-PERMIL
        END-IF
        MOVE "DRIFT-CLERGY  " TO WS-DEBUG-LABEL
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
            SUBTRACT 1 FROM WS-PEASANTS-PCT(WS-IDX)
            ADD 1 TO WS-CLERGY-PCT(WS-IDX)
        END-IF
    END-IF.

DRIFT-RURAL.
*> artisans → peasants на severe famine. Город опустошается, рабочие
*> бегут к земле. Заодно разгружает SUBSIST-NEED — путь к восстановлению.
    IF WS-HUNGER-FLAGS(WS-IDX) = 2
       AND WS-ARTISANS-PCT(WS-IDX) > DRIFT-RURAL-MIN-ART
        MOVE DRIFT-RURAL-PERMIL TO WS-PROB-PERMIL
        MOVE "DRIFT-RURAL   " TO WS-DEBUG-LABEL
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
            SUBTRACT 1 FROM WS-ARTISANS-PCT(WS-IDX)
            ADD 1 TO WS-PEASANTS-PCT(WS-IDX)
        END-IF
    END-IF.

PROPAGATE-CRISIS.
*> Переносим рыночный кризис в региональный флаг для WAR-CHECK
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        MOVE 0 TO WS-CRISIS-FLAGS(WS-IDX)
        PERFORM VARYING WS-MIDX FROM 1 BY 1
                UNTIL WS-MIDX > MARKET-COUNT OR WS-CRISIS-FLAGS(WS-IDX) = 1
            IF WS-MKT-CRISIS(WS-MIDX) = 1
               AND FUNCTION TRIM(WS-MKT-NAME(WS-MIDX)) =
                   FUNCTION TRIM(WS-PRIMARY-GOOD(WS-IDX))
                MOVE 1 TO WS-CRISIS-FLAGS(WS-IDX)
            END-IF
        END-PERFORM
    END-PERFORM.

TRADE-ALL.
*> Шаг 3: торговля — обмен овеществлённым трудом между соседями
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        MOVE 0 TO WS-NB-EXPORT
        PERFORM TRADE-ADD-NEIGHBOR VARYING WS-NIDX FROM 1 BY 1
            UNTIL WS-NIDX > 3
        COMPUTE WS-TRADE-BALANCE(WS-IDX) =
            WS-OUTPUT-VALUE(WS-IDX) * TRADE-EXPORT-PCT / 100 - WS-NB-EXPORT
    END-PERFORM.

TRADE-ADD-NEIGHBOR.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-IDX) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-IDX) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-IDX) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
        COMPUTE WS-OUTPUT-VAL =
            WS-OUTPUT-VALUE(WS-NBREG) * TRADE-EXPORT-PCT / 100 / 3
        ADD WS-OUTPUT-VAL TO WS-NB-EXPORT
*>      Активная торговля медленно укрепляет отношения (только без войны).
        IF WS-OUTPUT-VAL > 0 AND WS-AT-WAR-WITH(WS-IDX) NOT = WS-NBREG
            MOVE RELATIONS-TRADE-GAIN TO WS-REL-TMP
            PERFORM REL-DELTA-PAIR
        END-IF
    END-IF.

WAR-CHECK-ALL.
*> Шаг 4: проверка триггеров всех типов войн
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-AT-WAR-WITH(WS-IDX) = 0
           AND WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            PERFORM CLASS-WAR-CHECK
            PERFORM DYNASTIC-WAR-CHECK
            PERFORM CRISIS-WAR-CHECK
            PERFORM IMPERIAL-WAR-CHECK
        END-IF
    END-PERFORM.

CLASS-WAR-CHECK.
*> Внутренняя репрессия: аристократия подавляет восстание.
*> Вероятностно: чем выше tension над 90, тем выше шанс репрессии.
*> Условие nobility>5 жёсткое (без знати некому подавлять).
    IF WS-CLASS-TENSION(WS-IDX) >= CLASS-WAR-MIN-TENSION
       AND WS-NOBILITY-PCT(WS-IDX) > CLASS-WAR-NOBILITY-MIN
*>      base 500‰ при tension=90, +35‰ за каждый пункт сверху, cap 850‰
        COMPUTE WS-PROB-PERMIL = CLASS-WAR-BASE-PERMIL
            + (WS-CLASS-TENSION(WS-IDX) - CLASS-WAR-MIN-TENSION) * 35
        MOVE "CLASS-WAR     " TO WS-DEBUG-LABEL
        PERFORM APPLY-TRAIT-BIAS
        IF WS-PROB-PERMIL > CLASS-WAR-CAP-PERMIL
            MOVE CLASS-WAR-CAP-PERMIL TO WS-PROB-PERMIL
        END-IF
        IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
*>          Репрессия убивает массу (пропорции классов сохраняются),
*>          а не размывает peasants_pct безвозвратно (старый баг).
            COMPUTE WS-POPULATION(WS-IDX) =
                WS-POPULATION(WS-IDX) * 95 / 100
            IF WS-POPULATION(WS-IDX) < POP-FLOOR
                MOVE POP-FLOOR TO WS-POPULATION(WS-IDX)
            END-IF
            COMPUTE WS-LABOUR-HOURS(WS-IDX) =
                WS-LABOUR-HOURS(WS-IDX) * CLASS-WAR-LABOUR-PCT / 100
            COMPUTE WS-CLASS-TENSION(WS-IDX) =
                WS-CLASS-TENSION(WS-IDX) - CLASS-WAR-TENSION-DROP
            IF WS-CLASS-TENSION(WS-IDX) < 0
                MOVE 0 TO WS-CLASS-TENSION(WS-IDX)
            END-IF
            MOVE WS-YEAR           TO WS-CHRON-YEAR
            MOVE "CLASS-WAR      " TO WS-CHRON-TYPE
            MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
            MOVE "Nobility represses revolt. Workers crushed." TO WS-CHRON-DESC
            PERFORM WRITE-CHRONICLE
*>          Репрессия гасит классовое сознание.
            IF WS-CONSCIOUSNESS(WS-IDX) >= CONSCIOUSNESS-AFTER-CLASS
                SUBTRACT CONSCIOUSNESS-AFTER-CLASS
                    FROM WS-CONSCIOUSNESS(WS-IDX)
            ELSE
                MOVE 0 TO WS-CONSCIOUSNESS(WS-IDX)
            END-IF
        END-IF
    END-IF.

DYNASTIC-WAR-CHECK.
*> Война правящих классов. Жёсткое условие: достаточно капитала.
*> Дальше — вероятность, биасированная собственным tension и tension соседа.
    IF WS-CAPITAL-STOCK(WS-IDX) > DYNASTIC-CAPITAL-MIN
        PERFORM DYNASTIC-WAR-NEIGHBOR VARYING WS-NIDX FROM 1 BY 1
            UNTIL WS-NIDX > 3 OR WS-AT-WAR-WITH(WS-IDX) > 0
    END-IF.

DYNASTIC-WAR-NEIGHBOR.
*> Вероятность: 200‰ × (100−own_tension)/100 × nb_tension/100, cap 350‰.
*> Чем стабильнее агрессор и чем нестабильнее сосед — тем вероятнее.
*> Но даже у напряжённого агрессора и спокойного соседа есть ненулевой шанс.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-IDX) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-IDX) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-IDX) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-AT-WAR-WITH(WS-NBREG) = 0
       AND WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED
*>      Альянс полностью блокирует атаку (relation > +60).
*>      Иначе базовая вероятность биасится отношениями: вражда +%, дружба -%.
        IF WS-REL-ROW(WS-IDX, WS-NBREG)
           > RELATIONS-ALLIANCE
            MOVE 0 TO WS-PROB-PERMIL
        ELSE
            COMPUTE WS-PROB-PERMIL = DYNASTIC-WAR-BASE-PERMIL
                * (100 - WS-CLASS-TENSION(WS-IDX)) / 100
                * WS-CLASS-TENSION(WS-NBREG) / 100
            IF WS-REL-ROW(WS-IDX, WS-NBREG) < 0
                COMPUTE WS-PROB-PERMIL = WS-PROB-PERMIL
                    * (100 - WS-REL-ROW(WS-IDX, WS-NBREG))
                    / 100
            ELSE IF WS-REL-ROW(WS-IDX, WS-NBREG) > 0
                COMPUTE WS-PROB-PERMIL = WS-PROB-PERMIL
                    * (100 - WS-REL-ROW(WS-IDX, WS-NBREG))
                    / 100
            END-IF
            PERFORM APPLY-TRAIT-BIAS
            IF WS-PROB-PERMIL > DYNASTIC-WAR-CAP-PERMIL
                MOVE DYNASTIC-WAR-CAP-PERMIL TO WS-PROB-PERMIL
            END-IF
            IF WS-PROB-PERMIL < 0
                MOVE 0 TO WS-PROB-PERMIL
            END-IF
        END-IF
        MOVE "DYNASTIC-WAR  " TO WS-DEBUG-LABEL
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
            MOVE WS-NBREG        TO WS-AT-WAR-WITH(WS-IDX)
            MOVE WS-IDX          TO WS-AT-WAR-WITH(WS-NBREG)
            MOVE 1               TO WS-WAR-YEAR(WS-IDX)
            MOVE 1               TO WS-WAR-YEAR(WS-NBREG)
            MOVE WS-WAR-DYNASTIC TO WS-WAR-TYPE(WS-IDX)
            MOVE WS-WAR-DYNASTIC TO WS-WAR-TYPE(WS-NBREG)
            MOVE WS-YEAR           TO WS-CHRON-YEAR
            MOVE "WAR-START      "  TO WS-CHRON-TYPE
            MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
            STRING FUNCTION TRIM(WS-RULER-NAME(WS-IDX)) DELIMITED SIZE
                   " of "                                DELIMITED SIZE
                   FUNCTION TRIM(WS-NAME(WS-IDX))       DELIMITED SIZE
                   " attacks "                           DELIMITED SIZE
                   FUNCTION TRIM(WS-NAME(WS-NBREG))     DELIMITED SIZE
                   " (dynastic)."                        DELIMITED SIZE
                   INTO WS-CHRON-DESC
            PERFORM WRITE-CHRONICLE
            COMPUTE WS-REL-TMP = - RELATIONS-WAR-START
            PERFORM REL-DELTA-PAIR
        END-IF
    END-IF.

CRISIS-WAR-CHECK.
*> Война как выход из кризиса перепроизводства.
*> Условия: кризис + достаточно капитала. Дальше — вероятность, биасированная tension.
    IF WS-CRISIS-FLAGS(WS-IDX) = 1
       AND WS-CAPITAL-STOCK(WS-IDX) > CRISIS-WAR-CAPITAL-MIN
        PERFORM CRISIS-WAR-FIND-TARGET VARYING WS-NIDX FROM 1 BY 1
            UNTIL WS-NIDX > 3 OR WS-AT-WAR-WITH(WS-IDX) > 0
    END-IF.

CRISIS-WAR-FIND-TARGET.
*> Вероятность: 400‰ × tension/100, cap 600‰.
*> Высокий tension усиливает потребность правящего класса в внешнем враге.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-IDX) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-IDX) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-IDX) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-AT-WAR-WITH(WS-NBREG) = 0
       AND WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED
        COMPUTE WS-PROB-PERMIL = CRISIS-WAR-BASE-PERMIL
            * WS-CLASS-TENSION(WS-IDX) / 100
        MOVE "CRISIS-WAR    " TO WS-DEBUG-LABEL
        PERFORM APPLY-TRAIT-BIAS
        IF WS-PROB-PERMIL > CRISIS-WAR-CAP-PERMIL
            MOVE CRISIS-WAR-CAP-PERMIL TO WS-PROB-PERMIL
        END-IF
        IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
            MOVE WS-NBREG      TO WS-AT-WAR-WITH(WS-IDX)
            MOVE WS-IDX        TO WS-AT-WAR-WITH(WS-NBREG)
            MOVE 1             TO WS-WAR-YEAR(WS-IDX)
            MOVE 1             TO WS-WAR-YEAR(WS-NBREG)
            MOVE WS-WAR-CRISIS TO WS-WAR-TYPE(WS-IDX)
            MOVE WS-WAR-CRISIS TO WS-WAR-TYPE(WS-NBREG)
            COMPUTE WS-CLASS-TENSION(WS-IDX) =
                WS-CLASS-TENSION(WS-IDX) - CRISIS-WAR-TENSION-DROP
            IF WS-CLASS-TENSION(WS-IDX) < 0
                MOVE 0 TO WS-CLASS-TENSION(WS-IDX)
            END-IF
            COMPUTE WS-LABOUR-HOURS(WS-IDX) =
                WS-LABOUR-HOURS(WS-IDX) * CRISIS-WAR-LABOUR-PCT / 100
            MOVE WS-YEAR           TO WS-CHRON-YEAR
            MOVE "WAR-START      "  TO WS-CHRON-TYPE
            MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
            STRING FUNCTION TRIM(WS-RULER-NAME(WS-IDX)) DELIMITED SIZE
                   " of "                                DELIMITED SIZE
                   FUNCTION TRIM(WS-NAME(WS-IDX))       DELIMITED SIZE
                   " strikes "                           DELIMITED SIZE
                   FUNCTION TRIM(WS-NAME(WS-NBREG))     DELIMITED SIZE
                   ". Ruling class deflects unrest."     DELIMITED SIZE
                   INTO WS-CHRON-DESC
            PERFORM WRITE-CHRONICLE
            COMPUTE WS-REL-TMP = - RELATIONS-WAR-START
            PERFORM REL-DELTA-PAIR
        END-IF
    END-IF.

IMPERIAL-WAR-CHECK.
*> Phase 11. 4-й тип: империалистическая война (Lenin's stage).
*> Триггер: INDUSTRIAL+ модус с отрицательным торговым балансом.
*> Логика: империя нуждается в ресурсах извне → война за контроль.
    IF (WS-PROD-MODE(WS-IDX) = WS-MODE-INDUSTRIAL
        OR WS-PROD-MODE(WS-IDX) = WS-MODE-IMPERIAL)
       AND WS-TRADE-BALANCE(WS-IDX) < 0
*>      Дефицит торгового баланса в положительной форме (использует S9(12)V99)
        COMPUTE WS-OUTPUT-VAL = - WS-TRADE-BALANCE(WS-IDX)
        IF WS-OUTPUT-VAL > IMPERIAL-WAR-TRADE-MIN
            PERFORM IMPERIAL-WAR-TARGET VARYING WS-NIDX FROM 1 BY 1
                UNTIL WS-NIDX > 3 OR WS-AT-WAR-WITH(WS-IDX) > 0
        END-IF
    END-IF.

IMPERIAL-WAR-TARGET.
*> Вероятность: base 350‰ × |trade_deficit|/1000, cap 600‰.
*> Альянс блокирует. Trait биас через APPLY-TRAIT-BIAS.
*> WS-OUTPUT-VAL уже содержит положительный дефицит из CHECK.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-IDX) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-IDX) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-IDX) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-AT-WAR-WITH(WS-NBREG) = 0
       AND WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED
       AND WS-REL-ROW(WS-IDX, WS-NBREG) <= RELATIONS-ALLIANCE
*>      Cap deficit при расчёте вероятности — иначе IMPERIAL-WAR-BASE * deficit
*>      может переполниться при больших дефицитах (миллионы).
        IF WS-OUTPUT-VAL > 3000
            MOVE IMPERIAL-WAR-CAP-PERMIL TO WS-PROB-PERMIL
        ELSE
            COMPUTE WS-PROB-PERMIL = IMPERIAL-WAR-BASE-PERMIL
                * WS-OUTPUT-VAL / 1000
        END-IF
        MOVE "IMPERIAL-WAR  " TO WS-DEBUG-LABEL
        PERFORM APPLY-TRAIT-BIAS
        IF WS-PROB-PERMIL > IMPERIAL-WAR-CAP-PERMIL
            MOVE IMPERIAL-WAR-CAP-PERMIL TO WS-PROB-PERMIL
        END-IF
        IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
        PERFORM ROLL-EVENT
        IF WS-EVENT-FIRES = 1
            MOVE WS-NBREG        TO WS-AT-WAR-WITH(WS-IDX)
            MOVE WS-IDX          TO WS-AT-WAR-WITH(WS-NBREG)
            MOVE 1               TO WS-WAR-YEAR(WS-IDX)
            MOVE 1               TO WS-WAR-YEAR(WS-NBREG)
            MOVE WS-WAR-IMPERIAL TO WS-WAR-TYPE(WS-IDX)
            MOVE WS-WAR-IMPERIAL TO WS-WAR-TYPE(WS-NBREG)
            MOVE WS-YEAR           TO WS-CHRON-YEAR
            MOVE "WAR-START      "  TO WS-CHRON-TYPE
            MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
            STRING FUNCTION TRIM(WS-RULER-NAME(WS-IDX)) DELIMITED SIZE
                   " of "                                DELIMITED SIZE
                   FUNCTION TRIM(WS-NAME(WS-IDX))       DELIMITED SIZE
                   " declares imperial war on "         DELIMITED SIZE
                   FUNCTION TRIM(WS-NAME(WS-NBREG))     DELIMITED SIZE
                   "."                                   DELIMITED SIZE
                   INTO WS-CHRON-DESC
            PERFORM WRITE-CHRONICLE
            COMPUTE WS-REL-TMP = - RELATIONS-WAR-START
            PERFORM REL-DELTA-PAIR
        END-IF
    END-IF.

WAR-RESOLVE-ALL.
*> Шаг 5: через WAR-DURATION лет война разрешается
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-AT-WAR-WITH(WS-IDX) > 0
            ADD 1 TO WS-WAR-YEAR(WS-IDX)
            MOVE WS-AT-WAR-WITH(WS-IDX) TO WS-NBREG
            IF WS-WAR-YEAR(WS-IDX) >= WAR-DURATION
               AND WS-IDX < WS-NBREG
                PERFORM RESOLVE-WAR
                PERFORM COLLAPSE-CHECK
            END-IF
        END-IF
    END-PERFORM.

RESOLVE-WAR.
*> Военная сила: капитал × знать × стабильность, плюс шум ±20%.
*> Туман войны: даже сильнейший командир может проиграть. Слабая сторона иногда побеждает.
    PERFORM CALC-MIL-FOR-IDX
    PERFORM CALC-MIL-FOR-NBREG

*>  Шум: 80..120 % к каждой стороне независимо
    MOVE FUNCTION RANDOM TO WS-RAND-VAL
    COMPUTE WS-NOISE-IDX = MILITARY-NOISE-OFFSET
        + WS-RAND-VAL * MILITARY-NOISE-RANGE
    MOVE FUNCTION RANDOM TO WS-RAND-VAL
    COMPUTE WS-NOISE-NBR = MILITARY-NOISE-OFFSET
        + WS-RAND-VAL * MILITARY-NOISE-RANGE
    COMPUTE WS-MIL-IDX-NOISY =
        WS-MILITARY-STRENGTH(WS-IDX) * WS-NOISE-IDX / 100
    COMPUTE WS-MIL-NBR-NOISY =
        WS-MILITARY-STRENGTH(WS-NBREG) * WS-NOISE-NBR / 100

    IF WS-MIL-IDX-NOISY >= WS-MIL-NBR-NOISY
        MOVE WS-IDX   TO WS-WIN-IDX
        MOVE WS-NBREG TO WS-LOSE-IDX
    ELSE
        MOVE WS-NBREG TO WS-WIN-IDX
        MOVE WS-IDX   TO WS-LOSE-IDX
    END-IF
    PERFORM WAR-VICTORY

    MOVE 0          TO WS-AT-WAR-WITH(WS-IDX)
    MOVE 0          TO WS-AT-WAR-WITH(WS-NBREG)
    MOVE 0          TO WS-WAR-YEAR(WS-IDX)
    MOVE 0          TO WS-WAR-YEAR(WS-NBREG)
    MOVE WS-WAR-PEACE TO WS-WAR-TYPE(WS-IDX)
    MOVE WS-WAR-PEACE TO WS-WAR-TYPE(WS-NBREG).

CALC-MIL-FOR-IDX.
    COMPUTE WS-OUTPUT-VAL = WS-CAPITAL-STOCK(WS-IDX) / 10
                          * WS-NOBILITY-PCT(WS-IDX) * NOBILITY-WEIGHT / 100
                          * (100 - WS-CLASS-TENSION(WS-IDX)) / 100
    EVALUATE TRUE
        WHEN WS-OUTPUT-VAL < 0
            MOVE 0 TO WS-MILITARY-STRENGTH(WS-IDX)
        WHEN WS-OUTPUT-VAL > WAR-MILITARY-CAP
            MOVE WAR-MILITARY-CAP TO WS-MILITARY-STRENGTH(WS-IDX)
        WHEN OTHER
            MOVE WS-OUTPUT-VAL TO WS-MILITARY-STRENGTH(WS-IDX)
    END-EVALUATE.

CALC-MIL-FOR-NBREG.
    COMPUTE WS-OUTPUT-VAL = WS-CAPITAL-STOCK(WS-NBREG) / 10
                          * WS-NOBILITY-PCT(WS-NBREG) * NOBILITY-WEIGHT / 100
                          * (100 - WS-CLASS-TENSION(WS-NBREG)) / 100
    EVALUATE TRUE
        WHEN WS-OUTPUT-VAL < 0
            MOVE 0 TO WS-MILITARY-STRENGTH(WS-NBREG)
        WHEN WS-OUTPUT-VAL > WAR-MILITARY-CAP
            MOVE WAR-MILITARY-CAP TO WS-MILITARY-STRENGTH(WS-NBREG)
        WHEN OTHER
            MOVE WS-OUTPUT-VAL TO WS-MILITARY-STRENGTH(WS-NBREG)
    END-EVALUATE.

WAR-VICTORY.
*> Победитель — WS-WIN-IDX, проигравший — WS-LOSE-IDX. Один параграф на оба исхода.
    COMPUTE WS-CAPITAL-SEIZED =
        WS-CAPITAL-STOCK(WS-LOSE-IDX) * WAR-CAPITAL-SEIZE-PCT / 100
    COMPUTE WS-CAPITAL-STOCK(WS-WIN-IDX) =
        WS-CAPITAL-STOCK(WS-WIN-IDX) + WS-CAPITAL-SEIZED
    COMPUTE WS-CAPITAL-STOCK(WS-LOSE-IDX) =
        WS-CAPITAL-STOCK(WS-LOSE-IDX) - WS-CAPITAL-SEIZED

    COMPUTE WS-LABOUR-HOURS(WS-WIN-IDX) =
        WS-LABOUR-HOURS(WS-WIN-IDX)
        + WS-LABOUR-HOURS(WS-LOSE-IDX) * WAR-LABOUR-ABSORB-PCT / 100

    COMPUTE WS-SURPLUS-RATE(WS-WIN-IDX) =
        WS-SURPLUS-RATE(WS-WIN-IDX) + WAR-WINNER-SURPLUS-DELTA
    IF WS-SURPLUS-RATE(WS-WIN-IDX) > WAR-WINNER-SURPLUS-CAP
        MOVE WAR-WINNER-SURPLUS-CAP TO WS-SURPLUS-RATE(WS-WIN-IDX)
    END-IF

*>  Потери проигравшего: население и трибут
    COMPUTE WS-POPULATION(WS-LOSE-IDX) =
        WS-POPULATION(WS-LOSE-IDX) * WAR-LOSER-POP-PCT / 100
    COMPUTE WS-LABOUR-HOURS(WS-LOSE-IDX) =
        WS-POPULATION(WS-LOSE-IDX) * LABOUR-PER-CAPITA
    COMPUTE WS-SURPLUS-RATE(WS-LOSE-IDX) =
        WS-SURPLUS-RATE(WS-LOSE-IDX) + WAR-TRIBUTE-DELTA
    IF WS-SURPLUS-RATE(WS-LOSE-IDX) > WAR-LOSER-SURPLUS-CAP
        MOVE WAR-LOSER-SURPLUS-CAP TO WS-SURPLUS-RATE(WS-LOSE-IDX)
    END-IF

    ADD WAR-WINNER-TENSION-COST TO WS-CLASS-TENSION(WS-WIN-IDX)
    ADD WAR-LOSER-TENSION-COST  TO WS-CLASS-TENSION(WS-LOSE-IDX)
    MOVE WS-WIN-IDX  TO WS-CLAMP-IDX  PERFORM CLAMP-TENSION
    MOVE WS-LOSE-IDX TO WS-CLAMP-IDX  PERFORM CLAMP-TENSION

    MOVE WS-YEAR             TO WS-CHRON-YEAR
    MOVE "WAR-END        "   TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-WIN-IDX) TO WS-CHRON-RGON
    STRING FUNCTION TRIM(WS-RULER-NAME(WS-WIN-IDX)) DELIMITED SIZE
           " of "                                    DELIMITED SIZE
           FUNCTION TRIM(WS-NAME(WS-WIN-IDX))       DELIMITED SIZE
           " defeats "                               DELIMITED SIZE
           FUNCTION TRIM(WS-NAME(WS-LOSE-IDX))      DELIMITED SIZE
           ". Capital seized."                       DELIMITED SIZE
           INTO WS-CHRON-DESC
    PERFORM WRITE-CHRONICLE
*>  Победа закрепляет вражду
    MOVE WS-WIN-IDX  TO WS-IDX
    MOVE WS-LOSE-IDX TO WS-NBREG
    COMPUTE WS-REL-TMP = - RELATIONS-WAR-VICTORY
    PERFORM REL-DELTA-PAIR
*>  Phase 14 — военный грабёж технологий: первая ветвь, где проигравший
*>  опередил победителя, копируется. Имитирует захват архивов/инженеров.
    PERFORM WAR-TECH-LOOT
*>  Phase 15 — победа усиливает militaristic culture
    ADD CULTURE-WAR-WIN-DELTA TO WS-CULT-MIL(WS-WIN-IDX)
    IF WS-CULT-MIL(WS-WIN-IDX) > CULTURE-MAX
        MOVE CULTURE-MAX TO WS-CULT-MIL(WS-WIN-IDX)
    END-IF.

WAR-TECH-LOOT.
*> Caller: WS-WIN-IDX (победитель), WS-LOSE-IDX (проигравший).
*> Ищем первую ветвь, в которой LOSE > WIN. Если такая есть, WIN получает
*> +1 к этой ветви (но не выше LOSE level и не выше TECH-MAX-LEVEL).
*> Хроника: TECH-LOOT с описанием.
    MOVE 0 TO WS-LOOT-BRANCH
    PERFORM VARYING WS-BIDX FROM 1 BY 1
            UNTIL WS-BIDX > TECH-BRANCH-COUNT OR WS-LOOT-BRANCH > 0
        IF WS-TECH-LEVEL(WS-LOSE-IDX, WS-BIDX)
           > WS-TECH-LEVEL(WS-WIN-IDX, WS-BIDX)
            MOVE WS-BIDX TO WS-LOOT-BRANCH
        END-IF
    END-PERFORM
    IF WS-LOOT-BRANCH > 0
        ADD 1 TO WS-TECH-LEVEL(WS-WIN-IDX, WS-LOOT-BRANCH)
        MOVE 0 TO WS-TECH-PROGRESS(WS-WIN-IDX, WS-LOOT-BRANCH)
*>      Phase 17/18: если грабёж довёл до L3/L4 — pick choice (копируем у
*>      проигравшего, иначе случайный). До Phase 18 это была одна проверка
*>      на TECH-MAX-LEVEL; после расширения до 4 уровней нужны обе:
*>      L3 (level=3) и L4 (level=4).
        IF WS-TECH-LEVEL(WS-WIN-IDX, WS-LOOT-BRANCH) >= 3
           AND WS-TECH-L3-CHOICE(WS-WIN-IDX, WS-LOOT-BRANCH) = 0
            IF WS-TECH-L3-CHOICE(WS-LOSE-IDX, WS-LOOT-BRANCH) > 0
                MOVE WS-TECH-L3-CHOICE(WS-LOSE-IDX, WS-LOOT-BRANCH)
                    TO WS-TECH-L3-CHOICE(WS-WIN-IDX, WS-LOOT-BRANCH)
            ELSE
                MOVE WS-WIN-IDX TO WS-IDX
                MOVE WS-LOOT-BRANCH TO WS-BIDX
                PERFORM PICK-L3-ALTERNATIVE
            END-IF
        END-IF
        IF WS-TECH-LEVEL(WS-WIN-IDX, WS-LOOT-BRANCH) = 4
           AND WS-TECH-L4-CHOICE(WS-WIN-IDX, WS-LOOT-BRANCH) = 0
            IF WS-TECH-L4-CHOICE(WS-LOSE-IDX, WS-LOOT-BRANCH) > 0
               AND WS-TECH-L3-CHOICE(WS-LOSE-IDX, WS-LOOT-BRANCH) =
                   WS-TECH-L3-CHOICE(WS-WIN-IDX, WS-LOOT-BRANCH)
*>              L4 sub-tech копируем только если L3 совпадает у обеих сторон
*>              (иначе у нас, например, Steam, а у проигравшего Forging — и
*>              его «Damascus» нерелевантен).
                MOVE WS-TECH-L4-CHOICE(WS-LOSE-IDX, WS-LOOT-BRANCH)
                    TO WS-TECH-L4-CHOICE(WS-WIN-IDX, WS-LOOT-BRANCH)
            ELSE
                MOVE WS-WIN-IDX TO WS-IDX
                MOVE WS-LOOT-BRANCH TO WS-BIDX
                PERFORM PICK-L4-SUBTECH
            END-IF
        END-IF
*>      Определяем имя тех'а по новому уровню (LEVEL уже инкрементирован)
        MOVE SPACES TO WS-LOOT-NAME
        EVALUATE TRUE
            WHEN WS-LOOT-BRANCH = 1 AND WS-TECH-LEVEL(WS-WIN-IDX, 1) = 1
                MOVE "Bronze."             TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 1 AND WS-TECH-LEVEL(WS-WIN-IDX, 1) = 2
                MOVE "Iron."               TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 1 AND WS-TECH-LEVEL(WS-WIN-IDX, 1) = 3
                MOVE "Steam tech."         TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 2 AND WS-TECH-LEVEL(WS-WIN-IDX, 2) = 1
                MOVE "Coinage."            TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 2 AND WS-TECH-LEVEL(WS-WIN-IDX, 2) = 2
                MOVE "Banking."            TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 2 AND WS-TECH-LEVEL(WS-WIN-IDX, 2) = 3
                MOVE "Joint-Stock."        TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 3 AND WS-TECH-LEVEL(WS-WIN-IDX, 3) = 1
                MOVE "Writing."            TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 3 AND WS-TECH-LEVEL(WS-WIN-IDX, 3) = 2
                MOVE "Printing."           TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 3 AND WS-TECH-LEVEL(WS-WIN-IDX, 3) = 3
                MOVE "Empiric methods."    TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 4 AND WS-TECH-LEVEL(WS-WIN-IDX, 4) = 1
                MOVE "Standing army."      TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 4 AND WS-TECH-LEVEL(WS-WIN-IDX, 4) = 2
                MOVE "Bureaucracy."        TO WS-LOOT-NAME
            WHEN WS-LOOT-BRANCH = 4 AND WS-TECH-LEVEL(WS-WIN-IDX, 4) = 3
                MOVE "Mass conscription."  TO WS-LOOT-NAME
            WHEN OTHER
                MOVE "knowledge."          TO WS-LOOT-NAME
        END-EVALUATE
        MOVE WS-YEAR             TO WS-CHRON-YEAR
        MOVE "TECH-LOOT      "   TO WS-CHRON-TYPE
        MOVE WS-NAME(WS-WIN-IDX) TO WS-CHRON-RGON
        STRING FUNCTION TRIM(WS-NAME(WS-WIN-IDX))   DELIMITED SIZE
               " seizes "                            DELIMITED SIZE
               FUNCTION TRIM(WS-NAME(WS-LOSE-IDX))   DELIMITED SIZE
               "'s "                                 DELIMITED SIZE
               FUNCTION TRIM(WS-LOOT-NAME)           DELIMITED SIZE
               INTO WS-CHRON-DESC
        PERFORM WRITE-CHRONICLE
    END-IF.

COLLAPSE-CHECK.
*> Проверяем обе стороны после войны через единый параграф COLLAPSE-ONE
    MOVE WS-IDX   TO WS-COLLAPSE-CANDIDATE
    PERFORM COLLAPSE-ONE
    MOVE WS-NBREG TO WS-COLLAPSE-CANDIDATE
    PERFORM COLLAPSE-ONE.

COLLAPSE-ONE.
*> Параметризуется через WS-COLLAPSE-CANDIDATE.
*> Phase 10: перед сбросом популяции — миграция беженцев к соседям (30%).
    IF WS-PROD-MODE(WS-COLLAPSE-CANDIDATE) NOT = WS-MODE-COLLAPSED
       AND (WS-CAPITAL-STOCK(WS-COLLAPSE-CANDIDATE) < COLLAPSE-CAPITAL-FLOOR
            OR WS-POPULATION(WS-COLLAPSE-CANDIDATE) < COLLAPSE-POP-FLOOR)
*>      Беженцы: 30% оставшегося населения распределяются по живым соседям.
        COMPUTE WS-MIGRATION-POOL =
            WS-POPULATION(WS-COLLAPSE-CANDIDATE) * MIGRATION-COLLAPSE-PCT
            / 100
        PERFORM DISTRIBUTE-REFUGEES
        MOVE WS-MODE-COLLAPSED TO WS-PROD-MODE(WS-COLLAPSE-CANDIDATE)
        MOVE 0                 TO WS-MODE-YEARS(WS-COLLAPSE-CANDIDATE)
        MOVE COLLAPSED-POP     TO WS-POPULATION(WS-COLLAPSE-CANDIDATE)
        MOVE COLLAPSED-LABOUR  TO WS-LABOUR-HOURS(WS-COLLAPSE-CANDIDATE)
        MOVE 0                 TO WS-CAPITAL-STOCK(WS-COLLAPSE-CANDIDATE)
        MOVE 1                 TO WS-COLLAPSE-TIMER(WS-COLLAPSE-CANDIDATE)
        MOVE 0                 TO WS-CLASS-TENSION(WS-COLLAPSE-CANDIDATE)
        MOVE 0                 TO WS-NOBILITY-PCT(WS-COLLAPSE-CANDIDATE)
        MOVE 0                 TO WS-MILITARY-STRENGTH(WS-COLLAPSE-CANDIDATE)
        MOVE WS-YEAR           TO WS-CHRON-YEAR
        MOVE "COLLAPSE       " TO WS-CHRON-TYPE
        MOVE WS-NAME(WS-COLLAPSE-CANDIDATE) TO WS-CHRON-RGON
        MOVE "State collapses. Dark age begins." TO WS-CHRON-DESC
        PERFORM WRITE-CHRONICLE
    END-IF.

DISTRIBUTE-REFUGEES.
*> Caller: WS-COLLAPSE-CANDIDATE, WS-MIGRATION-POOL.
*> Считает живых соседей и поровну распределяет pool. Каждый принимающий
*> получает порцию населения, +5 tension и запись в хронику.
    MOVE 0 TO WS-LIVING-NEIGHBORS
    PERFORM REFUGEE-COUNT-NB VARYING WS-NIDX FROM 1 BY 1 UNTIL WS-NIDX > 3
    IF WS-LIVING-NEIGHBORS > 0
        COMPUTE WS-REFUGEE-SHARE =
            WS-MIGRATION-POOL / WS-LIVING-NEIGHBORS
        PERFORM REFUGEE-ABSORB-NB VARYING WS-NIDX FROM 1 BY 1 UNTIL WS-NIDX > 3
    END-IF.

REFUGEE-COUNT-NB.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-COLLAPSE-CANDIDATE) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-COLLAPSE-CANDIDATE) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-COLLAPSE-CANDIDATE) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED
        ADD 1 TO WS-LIVING-NEIGHBORS
    END-IF.

REFUGEE-ABSORB-NB.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-COLLAPSE-CANDIDATE) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-COLLAPSE-CANDIDATE) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-COLLAPSE-CANDIDATE) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED
        ADD WS-REFUGEE-SHARE TO WS-POPULATION(WS-NBREG)
        ADD MIGRATION-TENSION-DELTA TO WS-CLASS-TENSION(WS-NBREG)
        MOVE WS-NBREG TO WS-CLAMP-IDX
        PERFORM CLAMP-TENSION
        MOVE WS-YEAR              TO WS-CHRON-YEAR
        MOVE "REFUGEES       "    TO WS-CHRON-TYPE
        MOVE WS-NAME(WS-NBREG)    TO WS-CHRON-RGON
        STRING "Refugees from "                                DELIMITED SIZE
               FUNCTION TRIM(WS-NAME(WS-COLLAPSE-CANDIDATE))   DELIMITED SIZE
               " arrive. Pop +"                                DELIMITED SIZE
               WS-REFUGEE-SHARE                                DELIMITED SIZE
               INTO WS-CHRON-DESC
        PERFORM WRITE-CHRONICLE
    END-IF.

DISTRIBUTE-ALL.
*> Шаг 6: распределение — степень голода (0=ok, 1=mild, 2=severe).
*> Бинарного "famine flag" больше нет — серьёзность зависит от глубины дефицита.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            COMPUTE WS-WORKERS = WS-POPULATION(WS-IDX)
                * (WS-PEASANTS-PCT(WS-IDX) + WS-ARTISANS-PCT(WS-IDX)) / 100
            COMPUTE WS-SUBSIST-NEED = WS-WORKERS * SUBSIST-PER-WORKER
            EVALUATE TRUE
                WHEN WS-WAGE-FUND(WS-IDX) >= WS-SUBSIST-NEED
                    MOVE 0 TO WS-HUNGER-FLAGS(WS-IDX)
                WHEN WS-WAGE-FUND(WS-IDX) <
                     WS-SUBSIST-NEED * FAMINE-SEVERE-THRESHOLD / 100
*>                  Острый голод: < 70% потребности
                    MOVE 2 TO WS-HUNGER-FLAGS(WS-IDX)
                    MOVE WS-YEAR TO WS-CHRON-YEAR
                    MOVE "FAMINE         " TO WS-CHRON-TYPE
                    MOVE WS-NAME(WS-IDX)  TO WS-CHRON-RGON
                    MOVE "Severe famine. Wage fund collapses below 70%."
                        TO WS-CHRON-DESC
                    PERFORM WRITE-CHRONICLE
                WHEN OTHER
*>                  Лёгкий голод: 70-100% потребности — без события в хронике
                    MOVE 1 TO WS-HUNGER-FLAGS(WS-IDX)
            END-EVALUATE
        ELSE
            MOVE 0 TO WS-HUNGER-FLAGS(WS-IDX)
        END-IF
    END-PERFORM.

DEMOGRAPHY-ALL.
*> Рост: +1.5%/ход норма, -2% мягкий голод, -8% острый, COLLAPSED — таймер возрождения.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) = WS-MODE-COLLAPSED
            ADD 1 TO WS-COLLAPSE-TIMER(WS-IDX)
        ELSE
            EVALUATE WS-HUNGER-FLAGS(WS-IDX)
                WHEN 2
                    COMPUTE WS-POPULATION(WS-IDX) =
                        WS-POPULATION(WS-IDX) * FAMINE-SEVERE-POP-PCT / 100
                WHEN 1
                    COMPUTE WS-POPULATION(WS-IDX) =
                        WS-POPULATION(WS-IDX) * FAMINE-MILD-POP-PCT / 100
                WHEN OTHER
                    COMPUTE WS-POPULATION(WS-IDX) =
                        WS-POPULATION(WS-IDX) * GROWTH-RATE-PERMIL / 1000
            END-EVALUATE
            IF WS-POPULATION(WS-IDX) < POP-FLOOR
                MOVE POP-FLOOR TO WS-POPULATION(WS-IDX)
            END-IF
            COMPUTE WS-LABOUR-HOURS(WS-IDX) =
                WS-POPULATION(WS-IDX) * LABOUR-PER-CAPITA
        END-IF
    END-PERFORM.

SOCIAL-ALL.
*> Шаг 7: классовое напряжение = эксплуатация − легитимация.
*> Равновесие при surplus=15%: DELTA ≈ 0. Выше → напряжение растёт.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            COMPUTE WS-TENSION-DELTA =
                (WS-SURPLUS-RATE(WS-IDX) - SURPLUS-EQUILIBRIUM)
                    / SURPLUS-DELTA-DIVISOR
                - WS-CLERGY-PCT(WS-IDX) / CLERGY-PACIFY-DIVISOR
                - WS-MERCHANTS-PCT(WS-IDX) / MERCHANT-PACIFY-DIVISOR

*>          Голод по уровню тяжести
            EVALUATE WS-HUNGER-FLAGS(WS-IDX)
                WHEN 1 ADD FAMINE-MILD-TENSION   TO WS-TENSION-DELTA
                WHEN 2 ADD FAMINE-SEVERE-TENSION TO WS-TENSION-DELTA
            END-EVALUATE

*>          Шум tension: ±2 пункта в каждом ходу — индивидуальные настроения,
*>          харизматичные смутьяны, слухи, культурные приливы.
            MOVE FUNCTION RANDOM TO WS-RAND-VAL
            COMPUTE WS-RAND-INT = WS-RAND-VAL * TENSION-NOISE-RANGE
            COMPUTE WS-TENSION-DELTA = WS-TENSION-DELTA + WS-RAND-INT - 2

*>          Phase 13: Bureaucracy (POW L2) гасит tension delta.
*>          Phase 17: Cooperatives (ORG L3 alt 2) — рабочие довольнее, ×0.5.
*>                    Scholasticism (KNOW L3 alt 2) — легитимация, ×0.7.
*>                    Militia (POW L3 alt 3) — гражданская оборона, −2.
            IF WS-TECH-LEVEL(WS-IDX, 4) >= 2 AND WS-TENSION-DELTA > 0
                COMPUTE WS-TENSION-DELTA = WS-TENSION-DELTA * 2 / 3
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 3
               AND WS-TECH-L3-CHOICE(WS-IDX, 2) = 2
               AND WS-TENSION-DELTA > 0
                COMPUTE WS-TENSION-DELTA = WS-TENSION-DELTA / 2
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 3) >= 3
               AND WS-TECH-L3-CHOICE(WS-IDX, 3) = 2
               AND WS-TENSION-DELTA > 0
                COMPUTE WS-TENSION-DELTA = WS-TENSION-DELTA * 7 / 10
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 4) >= 3
               AND WS-TECH-L3-CHOICE(WS-IDX, 4) = 3
                SUBTRACT 2 FROM WS-TENSION-DELTA
            END-IF
*>          Phase 18 L4 — углубление tension-эффектов:
*>          WorkerOwned (ORG L3=2 L4=2) — ещё /2 (рабочие хозяева)
*>          ComLaw (KNOW L3=2 L4=2) — ещё ×0.8 (правовая стабильность)
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 4
               AND WS-TECH-L3-CHOICE(WS-IDX, 2) = 2
               AND WS-TECH-L4-CHOICE(WS-IDX, 2) = 2
               AND WS-TENSION-DELTA > 0
                COMPUTE WS-TENSION-DELTA = WS-TENSION-DELTA / 2
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 3) >= 4
               AND WS-TECH-L3-CHOICE(WS-IDX, 3) = 2
               AND WS-TECH-L4-CHOICE(WS-IDX, 3) = 2
               AND WS-TENSION-DELTA > 0
                COMPUTE WS-TENSION-DELTA = WS-TENSION-DELTA * 4 / 5
            END-IF

            COMPUTE WS-NEW-TENSION =
                WS-CLASS-TENSION(WS-IDX) + WS-TENSION-DELTA

            EVALUATE TRUE
                WHEN WS-NEW-TENSION < 0
                    MOVE 0   TO WS-CLASS-TENSION(WS-IDX)
                WHEN WS-NEW-TENSION >= 100
                    MOVE 100 TO WS-CLASS-TENSION(WS-IDX)
                WHEN OTHER
                    MOVE WS-NEW-TENSION TO WS-CLASS-TENSION(WS-IDX)
            END-EVALUATE

*>          Революция: tension создаёт давление, но прорыв требует сознания.
*>          Без consciousness крестьянские империи терпят. С ним пролетарские взрываются.
            IF WS-CLASS-TENSION(WS-IDX) >= 100
                MOVE 1000 TO WS-PROB-PERMIL
            ELSE IF WS-CLASS-TENSION(WS-IDX) > REVOLUTION-MIN-TENSION
                COMPUTE WS-PROB-PERMIL =
                    (WS-CLASS-TENSION(WS-IDX) - REVOLUTION-MIN-TENSION)
                    * REVOLUTION-SCALE-PERMIL
            ELSE
                MOVE 0 TO WS-PROB-PERMIL
            END-IF
            MOVE "REVOLUTION    " TO WS-DEBUG-LABEL
            PERFORM APPLY-TRAIT-BIAS
*>          Сознание масс — критический множитель. 0% сознания → 0% революции.
            COMPUTE WS-PROB-PERMIL =
                WS-PROB-PERMIL * WS-CONSCIOUSNESS(WS-IDX) / 100
            IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
            PERFORM ROLL-EVENT
            IF WS-EVENT-FIRES = 1
                PERFORM REVOLUTION
            END-IF
        END-IF
    END-PERFORM.

REVOLUTION.
*> Шаг 8: революция — смена правящего класса. Phase 9: + смена правителя,
*> сброс сознания (цикл переустанавливается).
    MOVE WS-YEAR             TO WS-CHRON-YEAR
    MOVE "REVOLUTION     "   TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON

    MOVE 0 TO WS-NOBILITY-PCT(WS-IDX)

    IF WS-MERCHANTS-PCT(WS-IDX) > WS-ARTISANS-PCT(WS-IDX)
        IF WS-MERCHANTS-PCT(WS-IDX) < REVOLUTION-CLASS-CAP
            ADD REVOLUTION-CLASS-BONUS TO WS-MERCHANTS-PCT(WS-IDX)
            IF WS-MERCHANTS-PCT(WS-IDX) > REVOLUTION-CLASS-CAP
                MOVE REVOLUTION-CLASS-CAP TO WS-MERCHANTS-PCT(WS-IDX)
            END-IF
        END-IF
        MOVE "Merchants seize power. Feudal nobility expelled."
            TO WS-CHRON-DESC
    ELSE
        IF WS-ARTISANS-PCT(WS-IDX) < REVOLUTION-CLASS-CAP
            ADD REVOLUTION-CLASS-BONUS TO WS-ARTISANS-PCT(WS-IDX)
            IF WS-ARTISANS-PCT(WS-IDX) > REVOLUTION-CLASS-CAP
                MOVE REVOLUTION-CLASS-CAP TO WS-ARTISANS-PCT(WS-IDX)
            END-IF
        END-IF
        MOVE "Artisans seize means of production. New order."
            TO WS-CHRON-DESC
    END-IF

*>  Крестьяне восполняют сумму до 100%. Если расчёт даёт меньше PEASANT-FLOOR —
*>  забираем разницу из других классов (сначала artisans, потом merchants,
*>  потом clergy), чтобы инвариант sum = 100 не нарушался.
    COMPUTE WS-PEASANT-CALC = 100
        - WS-ARTISANS-PCT(WS-IDX)
        - WS-MERCHANTS-PCT(WS-IDX)
        - WS-CLERGY-PCT(WS-IDX)
    IF WS-PEASANT-CALC < PEASANT-FLOOR
        COMPUTE WS-PEASANT-OVERFLOW = PEASANT-FLOOR - WS-PEASANT-CALC
        MOVE PEASANT-FLOOR TO WS-PEASANTS-PCT(WS-IDX)
        IF WS-ARTISANS-PCT(WS-IDX) >= WS-PEASANT-OVERFLOW
            SUBTRACT WS-PEASANT-OVERFLOW FROM WS-ARTISANS-PCT(WS-IDX)
        ELSE
            SUBTRACT WS-ARTISANS-PCT(WS-IDX) FROM WS-PEASANT-OVERFLOW
            MOVE 0 TO WS-ARTISANS-PCT(WS-IDX)
            IF WS-MERCHANTS-PCT(WS-IDX) >= WS-PEASANT-OVERFLOW
                SUBTRACT WS-PEASANT-OVERFLOW FROM WS-MERCHANTS-PCT(WS-IDX)
            ELSE
                SUBTRACT WS-MERCHANTS-PCT(WS-IDX) FROM WS-PEASANT-OVERFLOW
                MOVE 0 TO WS-MERCHANTS-PCT(WS-IDX)
                SUBTRACT WS-PEASANT-OVERFLOW FROM WS-CLERGY-PCT(WS-IDX)
            END-IF
        END-IF
    ELSE
        MOVE WS-PEASANT-CALC TO WS-PEASANTS-PCT(WS-IDX)
    END-IF

*>  Норма прибавочной стоимости падает — эксплуатация ослабевает
    COMPUTE WS-SURPLUS-RATE(WS-IDX) =
        WS-SURPLUS-RATE(WS-IDX) * REVOLUTION-SURPLUS-PCT / 100

    MOVE REVOLUTION-NEW-TENSION TO WS-CLASS-TENSION(WS-IDX)

*>  Запись REVOLUTION-события до возможной смены модуса —
*>  иначе WS-CHRON-TYPE/DESC будут перезатёрты IMPERIAL→SOCIALIST блоком
*>  и фантомная пустая MODE-SHIFT запись попадёт в хронику.
    PERFORM WRITE-CHRONICLE

*>  Phase 23 — революция = прорывной путь mode-shift через классовое
*>  сознание (наряду с органическим путём через ACCUMULATE-ALL/капитал).
*>  Каждая революция в созревшем регионе двигает эпоху на ступень.
*>  Условия класса требуются — без рабочего ядра прорыв не закрепляется.
    EVALUATE WS-PROD-MODE(WS-IDX)
        WHEN WS-MODE-SLAVE
*>          Античная революция: восстание рабов и колонов, отмена
*>          рабовладения. Требование — есть зачаточное городское ядро.
            IF WS-ARTISANS-PCT(WS-IDX) + WS-MERCHANTS-PCT(WS-IDX) >= 20
                MOVE WS-MODE-FEUDAL    TO WS-PROD-MODE(WS-IDX)
                MOVE 0                 TO WS-MODE-YEARS(WS-IDX)
                MOVE WS-YEAR           TO WS-CHRON-YEAR
                MOVE "MODE-SHIFT     " TO WS-CHRON-TYPE
                MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
                MOVE "Slave -> Feudal. Slaves rise, antiquity falls."
                    TO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            END-IF
        WHEN WS-MODE-FEUDAL
*>          Буржуазная революция первой волны: торговцы у власти.
            IF WS-MERCHANTS-PCT(WS-IDX) > WS-ARTISANS-PCT(WS-IDX)
                MOVE WS-MODE-MERCANTILE TO WS-PROD-MODE(WS-IDX)
                MOVE 0 TO WS-MODE-YEARS(WS-IDX)
            END-IF
        WHEN WS-MODE-MERCANTILE
*>          Буржуазная революция мануфактурного типа — 1789, 1848.
*>          Артизаны (городские мастеровые) ведущая сила, но плодами
*>          пользуется торговый капитал → переходим в PROTO-IND.
            IF WS-ARTISANS-PCT(WS-IDX) >= 25
                MOVE WS-MODE-PROTO-IND TO WS-PROD-MODE(WS-IDX)
                MOVE 0                 TO WS-MODE-YEARS(WS-IDX)
                MOVE WS-YEAR           TO WS-CHRON-YEAR
                MOVE "MODE-SHIFT     " TO WS-CHRON-TYPE
                MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
                MOVE "Mercantile -> Proto-Industrial. Bourgeois revolution."
                    TO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            END-IF
        WHEN WS-MODE-PROTO-IND
*>          Рабочее движение XIX в.: фабричный пролетариат прорывает
*>          мануфактурный потолок → INDUSTRIAL.
            IF WS-ARTISANS-PCT(WS-IDX) >= 30
                MOVE WS-MODE-INDUSTRIAL TO WS-PROD-MODE(WS-IDX)
                MOVE 0                  TO WS-MODE-YEARS(WS-IDX)
                MOVE WS-YEAR            TO WS-CHRON-YEAR
                MOVE "MODE-SHIFT     "  TO WS-CHRON-TYPE
                MOVE WS-NAME(WS-IDX)    TO WS-CHRON-RGON
                MOVE "Proto-Ind -> Industrial. Workers' movement breaks through."
                    TO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            END-IF
        WHEN WS-MODE-IMPERIAL
*>          Социалистическая революция (Phase 15) — пролетариат свергает
*>          финансовый капитал. SOCIALIST с пониженной нормой прибавочной.
            MOVE WS-MODE-SOCIALIST  TO WS-PROD-MODE(WS-IDX)
            MOVE 0                  TO WS-MODE-YEARS(WS-IDX)
            MOVE 5.00               TO WS-SURPLUS-RATE(WS-IDX)
            MOVE WS-YEAR            TO WS-CHRON-YEAR
            MOVE "MODE-SHIFT     "  TO WS-CHRON-TYPE
            MOVE WS-NAME(WS-IDX)    TO WS-CHRON-RGON
            MOVE "Imperial -> Socialist. Workers control means of production."
                TO WS-CHRON-DESC
            PERFORM WRITE-CHRONICLE
*>      INDUSTRIAL → IMPERIAL не делается через революцию. Империализм
*>      по Ленину — органический исход концентрации финансового капитала,
*>      а не классовый прорыв.
    END-EVALUATE

*>  Сознание сбрасывается — цикл начинается заново.
    IF WS-CONSCIOUSNESS(WS-IDX) >= CONSCIOUSNESS-AFTER-REV
        SUBTRACT CONSCIOUSNESS-AFTER-REV
            FROM WS-CONSCIOUSNESS(WS-IDX)
    ELSE
        MOVE 0 TO WS-CONSCIOUSNESS(WS-IDX)
    END-IF

*>  Старый правитель свергнут — новый, со случайным трейтом
    PERFORM SUCCESSION.

ACCUMULATE-ALL.
*> Шаг 9: накопление капитала → переход способа производства.
*> Для COLLAPSED — таймер возрождения.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        EVALUATE WS-PROD-MODE(WS-IDX)
            WHEN WS-MODE-PRIMITIVE
*>              PRIMITIVE → SLAVE. Phase 22: убрана искусственная EPOCH-MIN
*>              выдержка — темп задают сознание, культура и накопление.
                IF WS-POPULATION(WS-IDX) > SLAVE-POP-MIN
                   AND WS-CAPITAL-STOCK(WS-IDX) > SLAVE-CAPITAL-MIN
                    MOVE SLAVE-BASE-PERMIL TO WS-PROB-PERMIL
                    MOVE "MODE-SLAVE    " TO WS-DEBUG-LABEL
                    PERFORM APPLY-TRAIT-BIAS
*>                  Phase 19: культурный множитель. Кровно-родовое +
*>                  мелкие стычки кланов готовят почву для рабовладения.
                    COMPUTE WS-PROB-PERMIL = WS-PROB-PERMIL
                        * (CULTURE-MULT-BASE
                           + WS-CULT-REL(WS-IDX)
                           + WS-CULT-MIL(WS-IDX))
                        / CULTURE-MULT-DIVISOR
                    IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1
                        MOVE WS-MODE-SLAVE   TO WS-PROD-MODE(WS-IDX)
                        MOVE 0               TO WS-MODE-YEARS(WS-IDX)
                        MOVE WS-YEAR         TO WS-CHRON-YEAR
                        MOVE "MODE-SHIFT     " TO WS-CHRON-TYPE
                        MOVE WS-NAME(WS-IDX) TO WS-CHRON-RGON
                        MOVE "Primitive -> Slave. First city-state forms."
                            TO WS-CHRON-DESC
                        PERFORM WRITE-CHRONICLE
                    END-IF
                END-IF
            WHEN WS-MODE-SLAVE
*>              SLAVE → FEUDAL. Условия: capital + знать.
                IF WS-CAPITAL-STOCK(WS-IDX) > FEUDAL-CAPITAL-MIN
                   AND WS-NOBILITY-PCT(WS-IDX) >= FEUDAL-NOBILITY-MIN
                    MOVE FEUDAL-BASE-PERMIL TO WS-PROB-PERMIL
                    MOVE "MODE-FEUDAL   " TO WS-DEBUG-LABEL
                    PERFORM APPLY-TRAIT-BIAS
*>                  Phase 19: религиозная культура легитимирует феодальный
*>                  порядок (церковь как опора манориальной аграрности).
                    COMPUTE WS-PROB-PERMIL = WS-PROB-PERMIL
                        * (CULTURE-MULT-BASE + WS-CULT-REL(WS-IDX) * 2)
                        / CULTURE-MULT-DIVISOR
                    IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1
                        MOVE WS-MODE-FEUDAL  TO WS-PROD-MODE(WS-IDX)
                        MOVE 0               TO WS-MODE-YEARS(WS-IDX)
                        MOVE WS-YEAR         TO WS-CHRON-YEAR
                        MOVE "MODE-SHIFT     " TO WS-CHRON-TYPE
                        MOVE WS-NAME(WS-IDX) TO WS-CHRON-RGON
                        MOVE "Slave -> Feudal. Manorial order replaces antiquity."
                            TO WS-CHRON-DESC
                        PERFORM WRITE-CHRONICLE
                    END-IF
                END-IF
            WHEN WS-MODE-FEUDAL
*>              FEUDAL → MERCANTILE. Условия (capital + класс) необходимы.
                IF WS-CAPITAL-STOCK(WS-IDX) > MERCANTILE-CAPITAL-MIN
                   AND (WS-MERCHANTS-PCT(WS-IDX) >= MERCANTILE-MERCHANT-MIN
                        OR WS-ARTISANS-PCT(WS-IDX) >= MERCANTILE-ARTISAN-ALT)
                    COMPUTE WS-PROB-PERMIL = MODE-SHIFT-BASE-PERMIL
                        + WS-CAPITAL-STOCK(WS-IDX) * 100
                          / MERCANTILE-CAPITAL-MIN
                    MOVE "MODE-MERCANTILE" TO WS-DEBUG-LABEL
                    PERFORM APPLY-TRAIT-BIAS
*>                  Phase 19: коммерческая культура — необходимая надстройка
*>                  для перехода к торговому капиталу.
                    COMPUTE WS-PROB-PERMIL = WS-PROB-PERMIL
                        * (CULTURE-MULT-BASE + WS-CULT-MERC(WS-IDX) * 2)
                        / CULTURE-MULT-DIVISOR
                    IF WS-PROB-PERMIL > MODE-SHIFT-CAP-PERMIL
                        MOVE MODE-SHIFT-CAP-PERMIL TO WS-PROB-PERMIL
                    END-IF
                    IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1
                        MOVE WS-MODE-MERCANTILE TO WS-PROD-MODE(WS-IDX)
                        MOVE 0                TO WS-MODE-YEARS(WS-IDX)
                        MOVE WS-YEAR          TO WS-CHRON-YEAR
                        MOVE "MODE-SHIFT     " TO WS-CHRON-TYPE
                        MOVE WS-NAME(WS-IDX)  TO WS-CHRON-RGON
                        MOVE "Feudal -> Mercantile. Trade capital accumulated."
                            TO WS-CHRON-DESC
                        PERFORM WRITE-CHRONICLE
                    END-IF
                END-IF
            WHEN WS-MODE-MERCANTILE
*>              MERC → PROTO-IND. Условия: capital + ремесленники.
                IF WS-CAPITAL-STOCK(WS-IDX) > PROTO-IND-CAPITAL-MIN
                   AND WS-ARTISANS-PCT(WS-IDX) > PROTO-IND-ARTISAN-MIN
                    COMPUTE WS-PROB-PERMIL = MODE-SHIFT-BASE-PERMIL
                        + WS-CAPITAL-STOCK(WS-IDX) * 100
                          / PROTO-IND-CAPITAL-MIN
                    MOVE "MODE-PROTO-IND" TO WS-DEBUG-LABEL
                    PERFORM APPLY-TRAIT-BIAS
*>                  Phase 19: коммерческая культура — мануфактура опирается
*>                  на торговую инфраструктуру и предпринимательский этос.
                    COMPUTE WS-PROB-PERMIL = WS-PROB-PERMIL
                        * (CULTURE-MULT-BASE + WS-CULT-MERC(WS-IDX) * 2)
                        / CULTURE-MULT-DIVISOR
                    IF WS-PROB-PERMIL > MODE-SHIFT-CAP-PERMIL
                        MOVE MODE-SHIFT-CAP-PERMIL TO WS-PROB-PERMIL
                    END-IF
                    IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1
                        MOVE WS-MODE-PROTO-IND TO WS-PROD-MODE(WS-IDX)
                        MOVE 0                TO WS-MODE-YEARS(WS-IDX)
                        MOVE WS-YEAR          TO WS-CHRON-YEAR
                        MOVE "MODE-SHIFT     " TO WS-CHRON-TYPE
                        MOVE WS-NAME(WS-IDX)  TO WS-CHRON-RGON
                        MOVE "Mercantile -> Proto-Industrial. Manufactures rise."
                            TO WS-CHRON-DESC
                        PERFORM WRITE-CHRONICLE
                    END-IF
                END-IF
            WHEN WS-MODE-PROTO-IND
*>              PROTO-IND → INDUSTRIAL. Фабрика, наёмный труд как доминанта.
                IF WS-CAPITAL-STOCK(WS-IDX) > INDUSTRIAL-CAPITAL-MIN
                   AND WS-ARTISANS-PCT(WS-IDX) > INDUSTRIAL-ARTISAN-MIN
                    MOVE INDUSTRIAL-BASE-PERMIL TO WS-PROB-PERMIL
                    MOVE "MODE-INDUSTRIAL" TO WS-DEBUG-LABEL
                    PERFORM APPLY-TRAIT-BIAS
*>                  Phase 19: коммерческая культура — заводской капитал
*>                  растёт из той же предпринимательской почвы.
                    COMPUTE WS-PROB-PERMIL = WS-PROB-PERMIL
                        * (CULTURE-MULT-BASE + WS-CULT-MERC(WS-IDX) * 2)
                        / CULTURE-MULT-DIVISOR
                    IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1
                        MOVE WS-MODE-INDUSTRIAL TO WS-PROD-MODE(WS-IDX)
                        MOVE 0                TO WS-MODE-YEARS(WS-IDX)
                        MOVE WS-YEAR          TO WS-CHRON-YEAR
                        MOVE "MODE-SHIFT     " TO WS-CHRON-TYPE
                        MOVE WS-NAME(WS-IDX)  TO WS-CHRON-RGON
                        MOVE "Proto-Ind -> Industrial. Factory wage labour wins."
                            TO WS-CHRON-DESC
                        PERFORM WRITE-CHRONICLE
                    END-IF
                END-IF
            WHEN WS-MODE-INDUSTRIAL
*>              INDUSTRIAL → IMPERIAL. Поздняя стадия (Lenin): финансовый
*>              капитал, монополии, экспорт капитала.
                IF WS-CAPITAL-STOCK(WS-IDX) > IMPERIAL-CAPITAL-MIN
                   AND WS-MERCHANTS-PCT(WS-IDX) >= IMPERIAL-MERCHANT-MIN
                    MOVE IMPERIAL-BASE-PERMIL TO WS-PROB-PERMIL
                    MOVE "MODE-IMPERIAL " TO WS-DEBUG-LABEL
                    PERFORM APPLY-TRAIT-BIAS
*>                  Phase 19: империалистический поворот требует и
*>                  милитаристской, и коммерческой культурной базы
*>                  (Ленин: финансовый капитал + военный экспансионизм).
                    COMPUTE WS-PROB-PERMIL = WS-PROB-PERMIL
                        * (CULTURE-MULT-BASE
                           + WS-CULT-MIL(WS-IDX)
                           + WS-CULT-MERC(WS-IDX))
                        / CULTURE-MULT-DIVISOR
                    IF WS-PROB-PERMIL < 0 MOVE 0 TO WS-PROB-PERMIL END-IF
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1
                        MOVE WS-MODE-IMPERIAL TO WS-PROD-MODE(WS-IDX)
                        MOVE 0                TO WS-MODE-YEARS(WS-IDX)
                        MOVE WS-YEAR          TO WS-CHRON-YEAR
                        MOVE "MODE-SHIFT     " TO WS-CHRON-TYPE
                        MOVE WS-NAME(WS-IDX)  TO WS-CHRON-RGON
                        MOVE "Industrial -> Imperial. Finance capital and monopoly."
                            TO WS-CHRON-DESC
                        PERFORM WRITE-CHRONICLE
                    END-IF
                END-IF
            WHEN WS-MODE-COLLAPSED
*>          Возрождение через REBIRTH-DURATION ходов
                IF WS-COLLAPSE-TIMER(WS-IDX) >= REBIRTH-DURATION
                    MOVE WS-MODE-FEUDAL   TO WS-PROD-MODE(WS-IDX)
                    MOVE 0                TO WS-MODE-YEARS(WS-IDX)
                    MOVE REBIRTH-POP      TO WS-POPULATION(WS-IDX)
                    MOVE REBIRTH-LABOUR   TO WS-LABOUR-HOURS(WS-IDX)
                    MOVE REBIRTH-CAPITAL  TO WS-CAPITAL-STOCK(WS-IDX)
                    MOVE REBIRTH-SURPLUS  TO WS-SURPLUS-RATE(WS-IDX)
                    MOVE REBIRTH-TENSION  TO WS-CLASS-TENSION(WS-IDX)
                    MOVE REBIRTH-PEASANT-PCT  TO WS-PEASANTS-PCT(WS-IDX)
                    MOVE REBIRTH-ARTISAN-PCT  TO WS-ARTISANS-PCT(WS-IDX)
                    MOVE REBIRTH-MERCHANT-PCT TO WS-MERCHANTS-PCT(WS-IDX)
                    MOVE REBIRTH-NOBILITY-PCT TO WS-NOBILITY-PCT(WS-IDX)
                    MOVE REBIRTH-CLERGY-PCT   TO WS-CLERGY-PCT(WS-IDX)
                    MOVE 0                TO WS-COLLAPSE-TIMER(WS-IDX)
                    MOVE 0                TO WS-WAR-YEAR(WS-IDX)
                    MOVE WS-WAR-PEACE     TO WS-WAR-TYPE(WS-IDX)
                    MOVE 0                TO WS-AT-WAR-WITH(WS-IDX)
                    MOVE CONSCIOUSNESS-INIT TO WS-CONSCIOUSNESS(WS-IDX)
*>                  Phase 24 — Этап 1: возрождение использует то же имя
*>                  что у региона (пока polity=region 1:1).
                    MOVE WS-NAME(WS-IDX)  TO WS-POLITY-NAME(WS-IDX)
                    MOVE WS-YEAR          TO WS-CHRON-YEAR
                    MOVE "REBIRTH        " TO WS-CHRON-TYPE
                    MOVE WS-NAME(WS-IDX)  TO WS-CHRON-RGON
                    MOVE "New state rises from the ashes. Feudal order restored."
                        TO WS-CHRON-DESC
                    PERFORM WRITE-CHRONICLE
*>                  Новый правитель в новом мире
                    PERFORM SUCCESSION
                END-IF
        END-EVALUATE
    END-PERFORM.

CALC-MILITARY.
*> Обновляем военную силу в конце хода для сохранения в world.dat.
*> Phase 13: tech-эффекты — Iron (PROD L2) ×1.3, Standing-Army (POW L1) +1000,
*> Bureaucracy (POW L2) +500, Mass-Conscription (POW L3) ×2.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        COMPUTE WS-OUTPUT-VAL = WS-CAPITAL-STOCK(WS-IDX) / 10
                              * WS-NOBILITY-PCT(WS-IDX)
                                * NOBILITY-WEIGHT / 100
                              * (100 - WS-CLASS-TENSION(WS-IDX)) / 100
*>      Iron — увеличивает военный потенциал
        IF WS-TECH-LEVEL(WS-IDX, 1) >= 2
            COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 130 / 100
        END-IF
*>      Phase 17: PROD L3 alt 2 (Forging) — ещё ×1.3 поверх Iron
        IF WS-TECH-LEVEL(WS-IDX, 1) >= 3 AND WS-TECH-L3-CHOICE(WS-IDX, 1) = 2
            COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 130 / 100
        END-IF
*>      Phase 18 PROD L4: Damascus/Crossbow дают +10/15% к military
        IF WS-TECH-LEVEL(WS-IDX, 1) >= 4
           AND WS-TECH-L3-CHOICE(WS-IDX, 1) = 2
            EVALUATE WS-TECH-L4-CHOICE(WS-IDX, 1)
                WHEN 1
                    COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 115 / 100
                WHEN 2
                    COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 110 / 100
            END-EVALUATE
        END-IF
*>      Phase 18 POW L4: каждый sub даёт небольшой бонус military
        IF WS-TECH-LEVEL(WS-IDX, 4) >= 4
            EVALUATE TRUE
                WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 1
                     AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 1
*>                  Total War — ещё ×1.2 поверх Mass Conscription
                    COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 120 / 100
                WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 1
                     AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 2
*>                  Reserves — +3000 фикс (мобилизация на демонстрации)
                    ADD 3000 TO WS-OUTPUT-VAL
                WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 2
                     AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 1
*>                  Officer Corps — +5000
                    ADD 5000 TO WS-OUTPUT-VAL
                WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 2
                     AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 2
*>                  Special Forces — +3000 (элита, не толпа)
                    ADD 3000 TO WS-OUTPUT-VAL
                WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 3
                     AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 2
*>                  Guerrilla — +2000 в обороне
                    ADD 2000 TO WS-OUTPUT-VAL
            END-EVALUATE
        END-IF
*>      Standing-Army — постоянная армия с базовой силой 1000
        IF WS-TECH-LEVEL(WS-IDX, 4) >= 1
            ADD 1000 TO WS-OUTPUT-VAL
        END-IF
*>      Bureaucracy — +500 (государство мобилизует ресурсы на войну эффективнее)
        IF WS-TECH-LEVEL(WS-IDX, 4) >= 2
            ADD 500 TO WS-OUTPUT-VAL
        END-IF
*>      Phase 17: POW L3 — три альтернативы.
        IF WS-TECH-LEVEL(WS-IDX, 4) >= 3
            EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 4)
                WHEN 1
*>                  Mass-Conscription — призыв всего, ×2 (как было)
                    COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 2
                WHEN 2
*>                  Professional Army — +8000 фикс (постоянное преимущество)
                    ADD 8000 TO WS-OUTPUT-VAL
                WHEN 3
*>                  Militia — +3000 (защитная сила, меньше наступательной)
                    ADD 3000 TO WS-OUTPUT-VAL
                WHEN OTHER
                    COMPUTE WS-OUTPUT-VAL = WS-OUTPUT-VAL * 2
            END-EVALUATE
        END-IF
        EVALUATE TRUE
            WHEN WS-OUTPUT-VAL < 0
                MOVE 0 TO WS-MILITARY-STRENGTH(WS-IDX)
            WHEN WS-OUTPUT-VAL > WAR-MILITARY-CAP
                MOVE WAR-MILITARY-CAP TO WS-MILITARY-STRENGTH(WS-IDX)
            WHEN OTHER
                MOVE WS-OUTPUT-VAL TO WS-MILITARY-STRENGTH(WS-IDX)
        END-EVALUATE
    END-PERFORM.

WRITE-WORLD.
*>  Phase 24 — Этап 1: simulate переписывает только polities.dat.
*>  regions.dat статичен — пишется один раз при world-gen и больше не
*>  меняется (terrain/climate/neighbors не эволюционируют). Это убирает
*>  один disk-IO/turn и явно отделяет геофон от политики.
    OPEN OUTPUT POLITIES-FILE
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        MOVE SPACES TO WS-OUT-LINE
        STRING
            WS-POLITY-NAME(WS-IDX)       DELIMITED SIZE
            WS-POPULATION(WS-IDX)        DELIMITED SIZE
            WS-PEASANTS-PCT(WS-IDX)      DELIMITED SIZE
            WS-ARTISANS-PCT(WS-IDX)      DELIMITED SIZE
            WS-MERCHANTS-PCT(WS-IDX)     DELIMITED SIZE
            WS-NOBILITY-PCT(WS-IDX)      DELIMITED SIZE
            WS-CLERGY-PCT(WS-IDX)        DELIMITED SIZE
            WS-PROD-MODE(WS-IDX)         DELIMITED SIZE
            WS-LABOUR-HOURS(WS-IDX)      DELIMITED SIZE
            WS-SURPLUS-RATE(WS-IDX)      DELIMITED SIZE
            WS-CAPITAL-STOCK(WS-IDX)     DELIMITED SIZE
            WS-CLASS-TENSION(WS-IDX)     DELIMITED SIZE
            WS-MILITARY-STRENGTH(WS-IDX) DELIMITED SIZE
            WS-AT-WAR-WITH(WS-IDX)       DELIMITED SIZE
            WS-COLLAPSE-TIMER(WS-IDX)    DELIMITED SIZE
            WS-WAR-YEAR(WS-IDX)          DELIMITED SIZE
            WS-WAR-TYPE(WS-IDX)          DELIMITED SIZE
            WS-RULER-NAME(WS-IDX)        DELIMITED SIZE
            WS-RULER-AGE(WS-IDX)         DELIMITED SIZE
            WS-RULER-TRAIT(WS-IDX)       DELIMITED SIZE
            WS-RULER-REIGN(WS-IDX)       DELIMITED SIZE
            WS-CONSCIOUSNESS(WS-IDX)     DELIMITED SIZE
            WS-CULT-MIL(WS-IDX)          DELIMITED SIZE
            WS-CULT-MERC(WS-IDX)         DELIMITED SIZE
            WS-CULT-REL(WS-IDX)          DELIMITED SIZE
            WS-MODE-YEARS(WS-IDX)        DELIMITED SIZE
            INTO WS-OUT-LINE
        END-STRING
        WRITE WS-POLITY-REC FROM WS-OUT-LINE
    END-PERFORM
    CLOSE POLITIES-FILE.

WRITE-CHRONICLE.
*> Очищаем буфера ПЕРЕД STRING, иначе хвост старого сообщения протекает.
    MOVE SPACES TO WS-CHRON-OUT
    STRING
        WS-CHRON-YEAR DELIMITED SIZE
        WS-CHRON-TYPE DELIMITED SIZE
        WS-CHRON-RGON DELIMITED SIZE
        WS-CHRON-DESC DELIMITED SIZE
        INTO WS-CHRON-OUT
    END-STRING
    WRITE WS-CHRON-REC FROM WS-CHRON-OUT
    MOVE SPACES TO WS-CHRON-DESC.

TICK-MODE-YEARS.
*> Phase 21. Каждый ход: счётчик ходов в текущей эпохе у живых регионов
*> растёт на 1. COLLAPSED не считает — у них «нет эпохи» в обычном смысле,
*> восстановление через REBIRTH сбросит счётчик в 0 заново.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            ADD 1 TO WS-MODE-YEARS(WS-IDX)
        END-IF
    END-PERFORM.

AGE-RULERS.
*> Каждый ход: правитель стареет на 1, продолжительность правления +1.
*> На age >= 50 — нарастающая вероятность смерти. После 70 — резко выше.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            ADD 1 TO WS-RULER-AGE(WS-IDX)
            ADD 1 TO WS-RULER-REIGN(WS-IDX)
            EVALUATE TRUE
                WHEN WS-RULER-AGE(WS-IDX) >= RULER-DEATH-OLD-AGE
                    COMPUTE WS-PROB-PERMIL =
                        (WS-RULER-AGE(WS-IDX) - RULER-DEATH-MIN-AGE)
                        * RULER-DEATH-OLD-SCALE
                WHEN WS-RULER-AGE(WS-IDX) >= RULER-DEATH-MIN-AGE
                    COMPUTE WS-PROB-PERMIL =
                        (WS-RULER-AGE(WS-IDX) - RULER-DEATH-MIN-AGE)
                        * RULER-DEATH-SCALE-PERMIL
                WHEN OTHER
                    MOVE 0 TO WS-PROB-PERMIL
            END-EVALUATE
            IF WS-PROB-PERMIL > 1000
                MOVE 1000 TO WS-PROB-PERMIL
            END-IF
            MOVE "RULER-AGE     " TO WS-DEBUG-LABEL
            PERFORM ROLL-EVENT
            IF WS-EVENT-FIRES = 1
                PERFORM CHRON-RULER-DEATH
                PERFORM SUCCESSION
            END-IF
        END-IF
    END-PERFORM.

CHRON-RULER-DEATH.
*> Записывает смерть текущего правителя в хронику.
    MOVE WS-YEAR             TO WS-CHRON-YEAR
    MOVE "RULER-DEATH    "   TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON
    STRING FUNCTION TRIM(WS-RULER-NAME(WS-IDX))   DELIMITED SIZE
           " of "                                  DELIMITED SIZE
           FUNCTION TRIM(WS-NAME(WS-IDX))         DELIMITED SIZE
           " dies. Reign of "                      DELIMITED SIZE
           WS-RULER-REIGN(WS-IDX)                  DELIMITED SIZE
           " years ends."                          DELIMITED SIZE
           INTO WS-CHRON-DESC
    PERFORM WRITE-CHRONICLE.

SUCCESSION.
*> Новый правитель: имя из пула, возраст 25..35, трейт зависит от культуры/наследия.
*> Phase 15: сильная культура биасит выбор трейта в наследниках.
    COMPUTE WS-NAME-IDX =
        FUNCTION INTEGER(FUNCTION RANDOM * 20) + 1
    MOVE WS-NAME-ENTRY(WS-NAME-IDX) TO WS-RULER-NAME(WS-IDX)

    COMPUTE WS-RAND-INT =
        FUNCTION INTEGER(FUNCTION RANDOM * RULER-NEW-AGE-RANGE)
        + RULER-NEW-AGE-MIN
    MOVE WS-RAND-INT TO WS-RULER-AGE(WS-IDX)

*>  Наследование трейта: 3-уровневая логика.
*>  1) Если есть сильная культура (≥50) — 70% берём профильный трейт.
*>  2) Иначе 60% наследуется от предшественника.
*>  3) Иначе случайный.
    MOVE FUNCTION RANDOM TO WS-RAND-VAL
    COMPUTE WS-RAND-INT = WS-RAND-VAL * 1000
    EVALUATE TRUE
        WHEN WS-CULT-MIL(WS-IDX)  >= CULTURE-STRONG-THRESHOLD
             AND WS-RAND-INT < CULTURE-INHERIT-PERMIL
*>          Милитаризм → AMBITIOUS или CRUEL (50/50)
            MOVE FUNCTION RANDOM TO WS-RAND-VAL
            IF WS-RAND-VAL > 0.5
                MOVE WS-TRAIT-ENTRY(1) TO WS-RULER-TRAIT(WS-IDX)
            ELSE
                MOVE WS-TRAIT-ENTRY(3) TO WS-RULER-TRAIT(WS-IDX)
            END-IF
        WHEN WS-CULT-MERC(WS-IDX) >= CULTURE-STRONG-THRESHOLD
             AND WS-RAND-INT < CULTURE-INHERIT-PERMIL
            MOVE WS-TRAIT-ENTRY(5) TO WS-RULER-TRAIT(WS-IDX)
        WHEN WS-CULT-REL(WS-IDX)  >= CULTURE-STRONG-THRESHOLD
             AND WS-RAND-INT < CULTURE-INHERIT-PERMIL
            MOVE WS-TRAIT-ENTRY(4) TO WS-RULER-TRAIT(WS-IDX)
        WHEN WS-RAND-INT >= RULER-INHERIT-PERMIL
*>          Случайный трейт (когда не наследуется и культура слаба)
            COMPUTE WS-TRAIT-IDX =
                FUNCTION INTEGER(FUNCTION RANDOM * 5) + 1
            MOVE WS-TRAIT-ENTRY(WS-TRAIT-IDX) TO WS-RULER-TRAIT(WS-IDX)
        WHEN OTHER
*>          Наследуется (текущий трейт остаётся)
            CONTINUE
    END-EVALUATE

    MOVE 0 TO WS-RULER-REIGN(WS-IDX)

    MOVE WS-YEAR             TO WS-CHRON-YEAR
    MOVE "RULER-RISE     "   TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON
    STRING FUNCTION TRIM(WS-RULER-NAME(WS-IDX))    DELIMITED SIZE
           " ascends in "                           DELIMITED SIZE
           FUNCTION TRIM(WS-NAME(WS-IDX))          DELIMITED SIZE
           ". Trait: "                              DELIMITED SIZE
           FUNCTION TRIM(WS-RULER-TRAIT(WS-IDX))   DELIMITED SIZE
           "."                                      DELIMITED SIZE
           INTO WS-CHRON-DESC
    PERFORM WRITE-CHRONICLE.

LOAD-RELATIONS.
*> Читает relations.dat. Если нет/пустой — все нули.
*> Формат строки: 10 × S9(3) SIGN LEADING SEPARATE = 40 чаров.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        PERFORM VARYING WS-RJ FROM 1 BY 1 UNTIL WS-RJ > REGION-COUNT
            MOVE 0 TO WS-REL-ROW(WS-IDX, WS-RJ)
        END-PERFORM
    END-PERFORM
    MOVE "00" TO WS-REL-FILE-STATUS
    OPEN INPUT RELATIONS-FILE
    IF WS-REL-FILE-STATUS = "00"
        MOVE 0 TO WS-EOF
        PERFORM VARYING WS-IDX FROM 1 BY 1
                UNTIL WS-IDX > REGION-COUNT OR WS-EOF = 1
            READ RELATIONS-FILE INTO WS-RELATIONS-REC
                AT END
                    MOVE 1 TO WS-EOF
                NOT AT END
                    PERFORM VARYING WS-RJ FROM 1 BY 1
                            UNTIL WS-RJ > REGION-COUNT
                        COMPUTE WS-RK = (WS-RJ - 1) * 4 + 1
                        MOVE FUNCTION NUMVAL(WS-RELATIONS-REC(WS-RK:4))
                            TO WS-REL-IN
                        COMPUTE WS-REL-ROW(WS-IDX, WS-RJ) =
                            WS-REL-IN - 500
                    END-PERFORM
            END-READ
        END-PERFORM
        CLOSE RELATIONS-FILE
    END-IF.

WRITE-RELATIONS.
*> Записывает 10 строк — одну на регион. Симметричная матрица.
    OPEN OUTPUT RELATIONS-FILE
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        MOVE SPACES TO WS-RELATIONS-REC
        PERFORM VARYING WS-RJ FROM 1 BY 1 UNTIL WS-RJ > REGION-COUNT
            COMPUTE WS-REL-OUT = WS-REL-ROW(WS-IDX, WS-RJ) + 500
            COMPUTE WS-RK = (WS-RJ - 1) * 4 + 1
            MOVE WS-REL-OUT TO WS-RELATIONS-REC(WS-RK:4)
        END-PERFORM
        WRITE WS-RELATIONS-REC
    END-PERFORM
    CLOSE RELATIONS-FILE.

LOAD-TECH.
*> Phase 13/17/18. Читает tech.dat. Layout (24 байта):
*>   1-4   = level каждой ветви
*>   5-16  = progress по 3 цифры × 4 ветви
*>   17-20 = L3 choice каждой ветви (Phase 17)
*>   21-24 = L4 choice каждой ветви (Phase 18)
*> Backwards compat: 16-байт старый формат (без L3/L4), 20-байт Phase 17 (без L4).
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        PERFORM VARYING WS-BIDX FROM 1 BY 1
                UNTIL WS-BIDX > TECH-BRANCH-COUNT
            MOVE 0 TO WS-TECH-LEVEL(WS-IDX, WS-BIDX)
            MOVE 0 TO WS-TECH-PROGRESS(WS-IDX, WS-BIDX)
            MOVE 0 TO WS-TECH-L3-CHOICE(WS-IDX, WS-BIDX)
            MOVE 0 TO WS-TECH-L4-CHOICE(WS-IDX, WS-BIDX)
        END-PERFORM
    END-PERFORM
    MOVE "00" TO WS-TECH-FILE-STATUS
    OPEN INPUT TECH-FILE
    IF WS-TECH-FILE-STATUS = "00"
        MOVE 0 TO WS-EOF
        PERFORM VARYING WS-IDX FROM 1 BY 1
                UNTIL WS-IDX > REGION-COUNT OR WS-EOF = 1
            READ TECH-FILE INTO WS-TECH-REC
                AT END
                    MOVE 1 TO WS-EOF
                NOT AT END
                    PERFORM VARYING WS-BIDX FROM 1 BY 1
                            UNTIL WS-BIDX > TECH-BRANCH-COUNT
                        MOVE FUNCTION NUMVAL(WS-TECH-REC(WS-BIDX:1))
                            TO WS-TECH-LEVEL(WS-IDX, WS-BIDX)
                    END-PERFORM
                    MOVE FUNCTION NUMVAL(WS-TECH-REC(5:3))
                        TO WS-TECH-PROGRESS(WS-IDX, 1)
                    MOVE FUNCTION NUMVAL(WS-TECH-REC(8:3))
                        TO WS-TECH-PROGRESS(WS-IDX, 2)
                    MOVE FUNCTION NUMVAL(WS-TECH-REC(11:3))
                        TO WS-TECH-PROGRESS(WS-IDX, 3)
                    MOVE FUNCTION NUMVAL(WS-TECH-REC(14:3))
                        TO WS-TECH-PROGRESS(WS-IDX, 4)
                    IF FUNCTION LENGTH(FUNCTION TRIM(WS-TECH-REC)) >= 20
                        PERFORM VARYING WS-BIDX FROM 1 BY 1
                                UNTIL WS-BIDX > TECH-BRANCH-COUNT
                            COMPUTE WS-RK = 16 + WS-BIDX
                            MOVE FUNCTION NUMVAL(WS-TECH-REC(WS-RK:1))
                                TO WS-TECH-L3-CHOICE(WS-IDX, WS-BIDX)
                        END-PERFORM
                    END-IF
                    IF FUNCTION LENGTH(FUNCTION TRIM(WS-TECH-REC)) >= 24
                        PERFORM VARYING WS-BIDX FROM 1 BY 1
                                UNTIL WS-BIDX > TECH-BRANCH-COUNT
                            COMPUTE WS-RK = 20 + WS-BIDX
                            MOVE FUNCTION NUMVAL(WS-TECH-REC(WS-RK:1))
                                TO WS-TECH-L4-CHOICE(WS-IDX, WS-BIDX)
                        END-PERFORM
                    END-IF
            END-READ
        END-PERFORM
        CLOSE TECH-FILE
    END-IF.

TECH-RESEARCH-ALL.
*> Phase 13. Каждый ход регион двигает прогресс по 4 ветвям.
*> Скорость: base + mode-bonus + class-match + terrain-multiplier + empiric.
*> COLLAPSED регионы пропускаем — наука разрушена.
*> Когда progress >= 100, level++, progress сбрасывается, тех «изучен».
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            PERFORM VARYING WS-BIDX FROM 1 BY 1
                    UNTIL WS-BIDX > TECH-BRANCH-COUNT
                IF WS-TECH-LEVEL(WS-IDX, WS-BIDX) < TECH-MAX-LEVEL
                    PERFORM TECH-COMPUTE-INC
                    ADD WS-TECH-INC
                        TO WS-TECH-PROGRESS(WS-IDX, WS-BIDX)
                    IF WS-TECH-PROGRESS(WS-IDX, WS-BIDX)
                       >= TECH-PROGRESS-FULL
                        ADD 1 TO WS-TECH-LEVEL(WS-IDX, WS-BIDX)
                        MOVE 0 TO WS-TECH-PROGRESS(WS-IDX, WS-BIDX)
*>                      Phase 17: при достижении L3 выбираем L3 альтернативу.
                        IF WS-TECH-LEVEL(WS-IDX, WS-BIDX) = 3
                           AND WS-TECH-L3-CHOICE(WS-IDX, WS-BIDX) = 0
                            PERFORM PICK-L3-ALTERNATIVE
                        END-IF
*>                      Phase 18: при достижении L4 выбираем sub-tech.
                        IF WS-TECH-LEVEL(WS-IDX, WS-BIDX) = 4
                           AND WS-TECH-L4-CHOICE(WS-IDX, WS-BIDX) = 0
                            PERFORM PICK-L4-SUBTECH
                        END-IF
                        PERFORM CHRON-TECH-LEARNED
                    END-IF
                END-IF
            END-PERFORM
        END-IF
    END-PERFORM.

TECH-COMPUTE-INC.
*> Caller: WS-IDX, WS-BIDX. Вычисляет WS-TECH-INC для текущей ветви.
*> Базовая скорость + бонусы за условия. Поддерживает мерж эффектов.
    MOVE TECH-RESEARCH-BASE TO WS-TECH-INC
*>  Mode bonus: MERCANTILE и выше дают +2
    EVALUATE WS-PROD-MODE(WS-IDX)
        WHEN WS-MODE-MERCANTILE     ADD TECH-MODE-BONUS TO WS-TECH-INC
        WHEN WS-MODE-PROTO-IND      ADD TECH-MODE-BONUS TO WS-TECH-INC
        WHEN WS-MODE-INDUSTRIAL     ADD TECH-MODE-BONUS TO WS-TECH-INC
        WHEN WS-MODE-IMPERIAL       ADD TECH-MODE-BONUS TO WS-TECH-INC
    END-EVALUATE
*>  Профильный класс: PROD ↔ artisans, ORG ↔ merchants,
*>                    KNOW ↔ clergy, POW ↔ nobility
    MOVE 0 TO WS-CLASS-PCT
    EVALUATE WS-BIDX
        WHEN 1 MOVE WS-ARTISANS-PCT(WS-IDX)  TO WS-CLASS-PCT
        WHEN 2 MOVE WS-MERCHANTS-PCT(WS-IDX) TO WS-CLASS-PCT
        WHEN 3 MOVE WS-CLERGY-PCT(WS-IDX)    TO WS-CLASS-PCT
        WHEN 4 MOVE WS-NOBILITY-PCT(WS-IDX)  TO WS-CLASS-PCT
    END-EVALUATE
    IF WS-CLASS-PCT >= TECH-CLASS-MIN
        ADD TECH-CLASS-BONUS TO WS-TECH-INC
    END-IF
*>  Terrain match: MOUNTAINS↔PROD, COAST↔ORG, PLAINS↔KNOW, FOREST↔POW
*>  Применяется как ×1.5 (не +) — структурное преимущество.
    EVALUATE TRUE
        WHEN WS-BIDX = 1 AND WS-TERRAIN(WS-IDX) = "MOUNTAINS "
            COMPUTE WS-TECH-INC = WS-TECH-INC * 3 / 2
        WHEN WS-BIDX = 2 AND WS-TERRAIN(WS-IDX) = "COAST     "
            COMPUTE WS-TECH-INC = WS-TECH-INC * 3 / 2
        WHEN WS-BIDX = 3 AND WS-TERRAIN(WS-IDX) = "PLAINS    "
            COMPUTE WS-TECH-INC = WS-TECH-INC * 3 / 2
        WHEN WS-BIDX = 4 AND WS-TERRAIN(WS-IDX) = "FOREST    "
            COMPUTE WS-TECH-INC = WS-TECH-INC * 3 / 2
    END-EVALUATE
*>  Empiricism (KNOW L3 alt 1) — глобальный множитель скорости ×1.5.
*>  Phase 17: только если выбран Empiricism, не Scholasticism/Folk Wisdom.
    IF WS-TECH-LEVEL(WS-IDX, 3) >= TECH-MAX-LEVEL
       AND WS-TECH-L3-CHOICE(WS-IDX, 3) = 1
        COMPUTE WS-TECH-INC = WS-TECH-INC * 3 / 2
    END-IF
*>  Phase 14 — диффузия: если у любого соседа эта ветвь на нашем уровне или
*>  выше, мы можем «перенять» опыт. +50% к скорости.
    MOVE 0 TO WS-DIFFUSION-FOUND
    PERFORM TECH-DIFFUSION-NB VARYING WS-NIDX FROM 1 BY 1
        UNTIL WS-NIDX > 3 OR WS-DIFFUSION-FOUND = 1
    IF WS-DIFFUSION-FOUND = 1
        COMPUTE WS-TECH-INC = WS-TECH-INC * 3 / 2
    END-IF
*>  Phase 14 — синергии и конфликты между ветвями.
*>  Знание ускоряет производство и торговлю. Государство замедляет торговлю и знание.
*>  Производство усиливает власть. Капитал/банки замедляют милитаризм.
    EVALUATE WS-BIDX
        WHEN 1
*>          PROD: +Knowledge L1+, +Org L1+, -Power L2+
            IF WS-TECH-LEVEL(WS-IDX, 3) >= 1
                COMPUTE WS-TECH-INC = WS-TECH-INC * 110 / 100
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 1
                COMPUTE WS-TECH-INC = WS-TECH-INC * 115 / 100
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 4) >= 2
                COMPUTE WS-TECH-INC = WS-TECH-INC * 90 / 100
            END-IF
        WHEN 2
*>          ORG: +Knowledge L2+, -Power L1+
            IF WS-TECH-LEVEL(WS-IDX, 3) >= 2
                COMPUTE WS-TECH-INC = WS-TECH-INC * 115 / 100
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 4) >= 1
                COMPUTE WS-TECH-INC = WS-TECH-INC * 80 / 100
            END-IF
        WHEN 3
*>          KNOW: +Org L1+, -Power L1+
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 1
                COMPUTE WS-TECH-INC = WS-TECH-INC * 115 / 100
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 4) >= 1
                COMPUTE WS-TECH-INC = WS-TECH-INC * 85 / 100
            END-IF
        WHEN 4
*>          POW: +Prod L1+, -Org L2+
            IF WS-TECH-LEVEL(WS-IDX, 1) >= 1
                COMPUTE WS-TECH-INC = WS-TECH-INC * 120 / 100
            END-IF
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 2
                COMPUTE WS-TECH-INC = WS-TECH-INC * 85 / 100
            END-IF
    END-EVALUATE
*>  Phase 19: культурный множитель. Сумма всех трёх векторов (0..300)
*>  даёт мульт (50+sum)/150 → диапазон 0.33..2.33.
*>  Си: культура — обратное воздействие на материальную базу. Молодые
*>  бескультурные регионы исследуют медленно; зрелые цивилизации с
*>  накопленным наследием прорывают потолки.
    COMPUTE WS-TECH-INC = WS-TECH-INC
        * (CULTURE-MULT-BASE
           + WS-CULT-MIL(WS-IDX)
           + WS-CULT-MERC(WS-IDX)
           + WS-CULT-REL(WS-IDX))
        / CULTURE-MULT-DIVISOR
*>  Минимум 1 прогресс/ход чтобы избежать стагнации
    IF WS-TECH-INC < 1
        MOVE 1 TO WS-TECH-INC
    END-IF.

TECH-DIFFUSION-NB.
*> Caller: WS-IDX, WS-BIDX, WS-NIDX. Если у соседа n тех уровень >= наш +1
*> (т.е. нам ещё не достигнуто), ставим WS-DIFFUSION-FOUND = 1.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-IDX) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-IDX) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-IDX) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED
       AND WS-TECH-LEVEL(WS-NBREG, WS-BIDX) > WS-TECH-LEVEL(WS-IDX, WS-BIDX)
        MOVE 1 TO WS-DIFFUSION-FOUND
    END-IF.

PICK-L3-ALTERNATIVE.
*> Phase 17. Caller: WS-IDX, WS-BIDX. Level just transitioned 2→3.
*> Считаем веса 3 альтернатив по условиям региона, делаем взвешенный roll,
*> сохраняем choice 1/2/3 в WS-TECH-L3-CHOICE.
    EVALUATE WS-BIDX
        WHEN 1 PERFORM PICK-PROD-L3
        WHEN 2 PERFORM PICK-ORG-L3
        WHEN 3 PERFORM PICK-KNOW-L3
        WHEN 4 PERFORM PICK-POW-L3
    END-EVALUATE
*>  Выполняем взвешенный random выбор по WS-ALT-WEIGHT-1/2/3
    COMPUTE WS-ALT-WEIGHT-TOTAL =
        WS-ALT-WEIGHT-1 + WS-ALT-WEIGHT-2 + WS-ALT-WEIGHT-3
    IF WS-ALT-WEIGHT-TOTAL = 0
        MOVE 1 TO WS-TECH-L3-CHOICE(WS-IDX, WS-BIDX)
    ELSE
        MOVE FUNCTION RANDOM TO WS-RAND-VAL
        COMPUTE WS-ALT-ROLL = WS-RAND-VAL * WS-ALT-WEIGHT-TOTAL
        EVALUATE TRUE
            WHEN WS-ALT-ROLL < WS-ALT-WEIGHT-1
                MOVE 1 TO WS-TECH-L3-CHOICE(WS-IDX, WS-BIDX)
            WHEN WS-ALT-ROLL < WS-ALT-WEIGHT-1 + WS-ALT-WEIGHT-2
                MOVE 2 TO WS-TECH-L3-CHOICE(WS-IDX, WS-BIDX)
            WHEN OTHER
                MOVE 3 TO WS-TECH-L3-CHOICE(WS-IDX, WS-BIDX)
        END-EVALUATE
    END-IF.

PICK-PROD-L3.
*> PROD L3 alternatives:
*>   1=Steam (industrial coal), 2=Forging (military quality), 3=Hydraulics (water/wind)
    MOVE 50 TO WS-ALT-WEIGHT-1
    MOVE 30 TO WS-ALT-WEIGHT-2
    MOVE 20 TO WS-ALT-WEIGHT-3
*>  Steam требует капитала и индустриальной базы
    IF WS-CAPITAL-STOCK(WS-IDX) > 5000000
        ADD 30 TO WS-ALT-WEIGHT-1
    END-IF
    IF WS-PROD-MODE(WS-IDX) = WS-MODE-INDUSTRIAL
       OR WS-PROD-MODE(WS-IDX) = WS-MODE-IMPERIAL
        ADD 20 TO WS-ALT-WEIGHT-1
    END-IF
*>  Forging — горы или военная знать
    IF WS-TERRAIN(WS-IDX) = "MOUNTAINS "
        ADD 30 TO WS-ALT-WEIGHT-2
    END-IF
    IF WS-NOBILITY-PCT(WS-IDX) >= 5
        ADD 20 TO WS-ALT-WEIGHT-2
    END-IF
*>  Hydraulics — равнины или побережье, мерчантильный режим
    IF WS-TERRAIN(WS-IDX) = "PLAINS    "
       OR WS-TERRAIN(WS-IDX) = "COAST     "
        ADD 30 TO WS-ALT-WEIGHT-3
    END-IF
    IF WS-PROD-MODE(WS-IDX) = WS-MODE-MERCANTILE
        ADD 20 TO WS-ALT-WEIGHT-3
    END-IF.

PICK-ORG-L3.
*> ORG L3:
*>   1=Joint-Stock (capitalist core), 2=Cooperatives (mutual), 3=Cartels (monopoly)
    MOVE 50 TO WS-ALT-WEIGHT-1
    MOVE 30 TO WS-ALT-WEIGHT-2
    MOVE 20 TO WS-ALT-WEIGHT-3
*>  Joint-Stock — мерчанты, MERCANTILE+
    IF WS-MERCHANTS-PCT(WS-IDX) >= 15
        ADD 30 TO WS-ALT-WEIGHT-1
    END-IF
    IF WS-PROD-MODE(WS-IDX) = WS-MODE-MERCANTILE
       OR WS-PROD-MODE(WS-IDX) = WS-MODE-PROTO-IND
       OR WS-PROD-MODE(WS-IDX) = WS-MODE-INDUSTRIAL
        ADD 20 TO WS-ALT-WEIGHT-1
    END-IF
*>  Cooperatives — социализм или высокое сознание
    IF WS-PROD-MODE(WS-IDX) = WS-MODE-SOCIALIST
        ADD 50 TO WS-ALT-WEIGHT-2
    END-IF
    IF WS-CONSCIOUSNESS(WS-IDX) >= 70
        ADD 30 TO WS-ALT-WEIGHT-2
    END-IF
*>  Cartels — много капитала, MERCANT-правитель
    IF WS-CAPITAL-STOCK(WS-IDX) > 5000000
        ADD 30 TO WS-ALT-WEIGHT-3
    END-IF
    IF WS-RULER-TRAIT(WS-IDX) = "MERCANT   "
        ADD 20 TO WS-ALT-WEIGHT-3
    END-IF.

PICK-KNOW-L3.
*> KNOW L3:
*>   1=Empiricism (science), 2=Scholasticism (religious/legal), 3=Folk Wisdom (practical)
    MOVE 50 TO WS-ALT-WEIGHT-1
    MOVE 30 TO WS-ALT-WEIGHT-2
    MOVE 20 TO WS-ALT-WEIGHT-3
*>  Empiricism — другие тех развиты, высокое сознание
    IF WS-TECH-LEVEL(WS-IDX, 1) >= 2
       OR WS-TECH-LEVEL(WS-IDX, 2) >= 2
        ADD 30 TO WS-ALT-WEIGHT-1
    END-IF
    IF WS-CONSCIOUSNESS(WS-IDX) >= 50
        ADD 20 TO WS-ALT-WEIGHT-1
    END-IF
*>  Scholasticism — PIOUS-правитель, религиозная культура
    IF WS-RULER-TRAIT(WS-IDX) = "PIOUS     "
        ADD 30 TO WS-ALT-WEIGHT-2
    END-IF
    IF WS-CULT-REL(WS-IDX) >= 50
        ADD 30 TO WS-ALT-WEIGHT-2
    END-IF
*>  Folk Wisdom — много ремесленников, ранний режим
    IF WS-ARTISANS-PCT(WS-IDX) >= 30
        ADD 30 TO WS-ALT-WEIGHT-3
    END-IF
    IF WS-PROD-MODE(WS-IDX) = WS-MODE-PRIMITIVE
       OR WS-PROD-MODE(WS-IDX) = WS-MODE-SLAVE
       OR WS-PROD-MODE(WS-IDX) = WS-MODE-FEUDAL
        ADD 20 TO WS-ALT-WEIGHT-3
    END-IF.

PICK-POW-L3.
*> POW L3:
*>   1=Mass Conscription, 2=Professional Army, 3=Militia
    MOVE 50 TO WS-ALT-WEIGHT-1
    MOVE 40 TO WS-ALT-WEIGHT-2
    MOVE 20 TO WS-ALT-WEIGHT-3
*>  Mass Conscription — крупное население, индустрия, агрессивные трейты
    IF WS-POPULATION(WS-IDX) > 1000000
        ADD 30 TO WS-ALT-WEIGHT-1
    END-IF
    IF WS-PROD-MODE(WS-IDX) = WS-MODE-INDUSTRIAL
       OR WS-PROD-MODE(WS-IDX) = WS-MODE-IMPERIAL
        ADD 20 TO WS-ALT-WEIGHT-1
    END-IF
    IF WS-RULER-TRAIT(WS-IDX) = "AMBITIOUS "
       OR WS-RULER-TRAIT(WS-IDX) = "CRUEL     "
        ADD 20 TO WS-ALT-WEIGHT-1
    END-IF
*>  Professional Army — знать, капитал
    IF WS-NOBILITY-PCT(WS-IDX) >= 5
        ADD 30 TO WS-ALT-WEIGHT-2
    END-IF
    IF WS-CAPITAL-STOCK(WS-IDX) > 5000000
        ADD 20 TO WS-ALT-WEIGHT-2
    END-IF
*>  Militia — социализм, военная культура
    IF WS-PROD-MODE(WS-IDX) = WS-MODE-SOCIALIST
        ADD 30 TO WS-ALT-WEIGHT-3
    END-IF
    IF WS-CULT-MIL(WS-IDX) >= 50
        ADD 20 TO WS-ALT-WEIGHT-3
    END-IF.

PICK-L4-SUBTECH.
*> Phase 18. Caller: WS-IDX, WS-BIDX. Level 3→4 transition.
*> Условия зависят от того, какой L3 alt выбран в этой ветви.
*> 2 sub-tech на каждый L3 alt → веса для 2 alternatives.
*> Используем WS-ALT-WEIGHT-1/2 (третий не нужен).
    MOVE 0 TO WS-ALT-WEIGHT-3
    EVALUATE WS-BIDX
        WHEN 1 PERFORM PICK-PROD-L4
        WHEN 2 PERFORM PICK-ORG-L4
        WHEN 3 PERFORM PICK-KNOW-L4
        WHEN 4 PERFORM PICK-POW-L4
    END-EVALUATE
    COMPUTE WS-ALT-WEIGHT-TOTAL =
        WS-ALT-WEIGHT-1 + WS-ALT-WEIGHT-2
    IF WS-ALT-WEIGHT-TOTAL = 0
        MOVE 1 TO WS-TECH-L4-CHOICE(WS-IDX, WS-BIDX)
    ELSE
        MOVE FUNCTION RANDOM TO WS-RAND-VAL
        COMPUTE WS-ALT-ROLL = WS-RAND-VAL * WS-ALT-WEIGHT-TOTAL
        IF WS-ALT-ROLL < WS-ALT-WEIGHT-1
            MOVE 1 TO WS-TECH-L4-CHOICE(WS-IDX, WS-BIDX)
        ELSE
            MOVE 2 TO WS-TECH-L4-CHOICE(WS-IDX, WS-BIDX)
        END-IF
    END-IF.

PICK-PROD-L4.
*> PROD L3 → L4 sub-techs:
*>   Steam(1) → Gasoline(1) | Turbine(2)
*>   Forging(2) → Damascus(1) | Crossbow(2)
*>   Hydraulics(3) → WindTurb(1) | TidalMl(2)
    MOVE 50 TO WS-ALT-WEIGHT-1
    MOVE 50 TO WS-ALT-WEIGHT-2
    EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 1)
        WHEN 1
*>          Steam: Gasoline (mass-market) vs Turbine (heavy industry)
            IF WS-MERCHANTS-PCT(WS-IDX) >= 15
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-PROD-MODE(WS-IDX) = WS-MODE-INDUSTRIAL
               OR WS-PROD-MODE(WS-IDX) = WS-MODE-IMPERIAL
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
        WHEN 2
*>          Forging: Damascus (elite weapons) vs Crossbow (mass production)
            IF WS-NOBILITY-PCT(WS-IDX) >= 5
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-CULT-MIL(WS-IDX) >= 50
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
        WHEN 3
*>          Hydraulics: Wind (coast) vs Tidal (also coast)
            IF WS-TERRAIN(WS-IDX) = "PLAINS    "
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-TERRAIN(WS-IDX) = "COAST     "
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
    END-EVALUATE.

PICK-ORG-L4.
*> ORG L3 → L4:
*>   JointStk(1) → StockMkt(1) | LimLiab(2)
*>   Coopers(2) → MutAid(1) | WorkOwn(2)
*>   Cartels(3) → Trusts(1) | VertInt(2)
    MOVE 50 TO WS-ALT-WEIGHT-1
    MOVE 50 TO WS-ALT-WEIGHT-2
    EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 2)
        WHEN 1
            IF WS-CAPITAL-STOCK(WS-IDX) > 50000000
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-MERCHANTS-PCT(WS-IDX) >= 25
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
        WHEN 2
            IF WS-CULT-REL(WS-IDX) >= 30
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-PROD-MODE(WS-IDX) = WS-MODE-SOCIALIST
                ADD 50 TO WS-ALT-WEIGHT-2
            END-IF
        WHEN 3
            IF WS-RULER-TRAIT(WS-IDX) = "CRUEL     "
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-PROD-MODE(WS-IDX) = WS-MODE-IMPERIAL
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
    END-EVALUATE.

PICK-KNOW-L4.
*> KNOW L3 → L4:
*>   Empiric(1) → SciMethod(1) | Specialization(2)
*>   Scholast(2) → Theology(1) | ComLaw(2)
*>   FolkWis(3) → OralTrad(1) | PracCrft(2)
    MOVE 50 TO WS-ALT-WEIGHT-1
    MOVE 50 TO WS-ALT-WEIGHT-2
    EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 3)
        WHEN 1
            IF WS-CONSCIOUSNESS(WS-IDX) >= 70
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-ARTISANS-PCT(WS-IDX) >= 30
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
        WHEN 2
            IF WS-CULT-REL(WS-IDX) >= 50
                ADD 50 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-RULER-TRAIT(WS-IDX) = "CAUTIOUS  "
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
        WHEN 3
            IF WS-PROD-MODE(WS-IDX) = WS-MODE-PRIMITIVE
               OR WS-PROD-MODE(WS-IDX) = WS-MODE-SLAVE
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-ARTISANS-PCT(WS-IDX) >= 30
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
    END-EVALUATE.

PICK-POW-L4.
*> POW L3 → L4:
*>   MassCons(1) → TotalWar(1) | Reserves(2)
*>   ProfArmy(2) → OffCorps(1) | SpecOps(2)
*>   Militia(3) → CitArmy(1) | Guerrilla(2)
    MOVE 50 TO WS-ALT-WEIGHT-1
    MOVE 50 TO WS-ALT-WEIGHT-2
    EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 4)
        WHEN 1
            IF WS-CULT-MIL(WS-IDX) >= 70
                ADD 50 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-CULT-MIL(WS-IDX) < 50
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
        WHEN 2
            IF WS-NOBILITY-PCT(WS-IDX) >= 7
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-CAPITAL-STOCK(WS-IDX) > 100000000
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
        WHEN 3
            IF WS-PROD-MODE(WS-IDX) = WS-MODE-SOCIALIST
                ADD 30 TO WS-ALT-WEIGHT-1
            END-IF
            IF WS-TERRAIN(WS-IDX) = "MOUNTAINS "
               OR WS-TERRAIN(WS-IDX) = "FOREST    "
                ADD 30 TO WS-ALT-WEIGHT-2
            END-IF
    END-EVALUATE.

CHRON-TECH-LEARNED.
*> Caller: WS-IDX, WS-BIDX, level just incremented.
*> Записывает событие в хронику с правильным именем тех'а.
    MOVE WS-YEAR             TO WS-CHRON-YEAR
    MOVE "TECH-LEARNED   "   TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON
    EVALUATE TRUE
        WHEN WS-BIDX = 1 AND WS-TECH-LEVEL(WS-IDX, 1) = 1
            MOVE "Bronze discovered. Military strengthens."
                TO WS-CHRON-DESC
        WHEN WS-BIDX = 1 AND WS-TECH-LEVEL(WS-IDX, 1) = 2
            MOVE "Iron worked. Output and arms improve."
                TO WS-CHRON-DESC
*>      Phase 17: для L3 берём конкретную альтернативу через L3-CHOICE
        WHEN WS-BIDX = 1 AND WS-TECH-LEVEL(WS-IDX, 1) = 3
            EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 1)
                WHEN 1 MOVE "Steam engine harnessed. Coal-fired industry."
                       TO WS-CHRON-DESC
                WHEN 2 MOVE "Forging mastery. Quality arms revolution."
                       TO WS-CHRON-DESC
                WHEN 3 MOVE "Hydraulics built. Water and wind drive mills."
                       TO WS-CHRON-DESC
                WHEN OTHER MOVE "Production tech advanced." TO WS-CHRON-DESC
            END-EVALUATE
        WHEN WS-BIDX = 2 AND WS-TECH-LEVEL(WS-IDX, 2) = 1
            MOVE "Coinage adopted. Trade circulates faster."
                TO WS-CHRON-DESC
        WHEN WS-BIDX = 2 AND WS-TECH-LEVEL(WS-IDX, 2) = 2
            MOVE "Banking emerges. Capital accumulates faster."
                TO WS-CHRON-DESC
        WHEN WS-BIDX = 2 AND WS-TECH-LEVEL(WS-IDX, 2) = 3
            EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 2)
                WHEN 1 MOVE "Joint-stock companies form. Investment flows."
                       TO WS-CHRON-DESC
                WHEN 2 MOVE "Cooperatives form. Workers own their shops."
                       TO WS-CHRON-DESC
                WHEN 3 MOVE "Cartels formed. Monopolies fix the prices."
                       TO WS-CHRON-DESC
                WHEN OTHER MOVE "Organization advanced." TO WS-CHRON-DESC
            END-EVALUATE
        WHEN WS-BIDX = 3 AND WS-TECH-LEVEL(WS-IDX, 3) = 1
            MOVE "Writing spreads. Knowledge persists across generations."
                TO WS-CHRON-DESC
        WHEN WS-BIDX = 3 AND WS-TECH-LEVEL(WS-IDX, 3) = 2
            MOVE "Printing press. Ideas multiply."
                TO WS-CHRON-DESC
        WHEN WS-BIDX = 3 AND WS-TECH-LEVEL(WS-IDX, 3) = 3
            EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 3)
                WHEN 1 MOVE "Empiricism takes root. Research accelerates."
                       TO WS-CHRON-DESC
                WHEN 2 MOVE "Scholasticism — sacred texts and law dominate."
                       TO WS-CHRON-DESC
                WHEN 3 MOVE "Folk wisdom canonized. Crafts pass through generations."
                       TO WS-CHRON-DESC
                WHEN OTHER MOVE "Knowledge advanced." TO WS-CHRON-DESC
            END-EVALUATE
        WHEN WS-BIDX = 4 AND WS-TECH-LEVEL(WS-IDX, 4) = 1
            MOVE "Standing army formed. Military force base rises."
                TO WS-CHRON-DESC
        WHEN WS-BIDX = 4 AND WS-TECH-LEVEL(WS-IDX, 4) = 2
            MOVE "Bureaucracy organized. Tension dampens."
                TO WS-CHRON-DESC
        WHEN WS-BIDX = 4 AND WS-TECH-LEVEL(WS-IDX, 4) = 3
            EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 4)
                WHEN 1 MOVE "Mass conscription. Whole population mobilized."
                       TO WS-CHRON-DESC
                WHEN 2 MOVE "Professional army. Officer corps trained."
                       TO WS-CHRON-DESC
                WHEN 3 MOVE "Citizen militia organized. Defense by all."
                       TO WS-CHRON-DESC
                WHEN OTHER MOVE "Power advanced." TO WS-CHRON-DESC
            END-EVALUATE
*>      Phase 18 — L4 sub-techs: специфичный текст по (L3-CHOICE, L4-CHOICE)
        WHEN WS-BIDX = 1 AND WS-TECH-LEVEL(WS-IDX, 1) = 4
            PERFORM CHRON-PROD-L4
        WHEN WS-BIDX = 2 AND WS-TECH-LEVEL(WS-IDX, 2) = 4
            PERFORM CHRON-ORG-L4
        WHEN WS-BIDX = 3 AND WS-TECH-LEVEL(WS-IDX, 3) = 4
            PERFORM CHRON-KNOW-L4
        WHEN WS-BIDX = 4 AND WS-TECH-LEVEL(WS-IDX, 4) = 4
            PERFORM CHRON-POW-L4
        WHEN OTHER
            MOVE "Tech advance." TO WS-CHRON-DESC
    END-EVALUATE
    PERFORM WRITE-CHRONICLE.

CHRON-PROD-L4.
*> Phase 18: имена 6 PROD L4 sub-techs зависят от (L3-CHOICE, L4-CHOICE).
    EVALUATE TRUE
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 1 AND WS-TECH-L4-CHOICE(WS-IDX, 1) = 1
            MOVE "Gasoline engines. Mass mobility achieved." TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 1 AND WS-TECH-L4-CHOICE(WS-IDX, 1) = 2
            MOVE "Steam turbines. Naval and heavy industry."  TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 2 AND WS-TECH-L4-CHOICE(WS-IDX, 1) = 1
            MOVE "Damascus steel. Elite weapons unmatched."   TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 2 AND WS-TECH-L4-CHOICE(WS-IDX, 1) = 2
            MOVE "Crossbow workshops. Mass-produced arms."     TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 3 AND WS-TECH-L4-CHOICE(WS-IDX, 1) = 1
            MOVE "Wind turbines spread across the plains."     TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 1) = 3 AND WS-TECH-L4-CHOICE(WS-IDX, 1) = 2
            MOVE "Tidal mills harness the coastal sea."        TO WS-CHRON-DESC
        WHEN OTHER
            MOVE "Production refined further." TO WS-CHRON-DESC
    END-EVALUATE.

CHRON-ORG-L4.
    EVALUATE TRUE
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 1 AND WS-TECH-L4-CHOICE(WS-IDX, 2) = 1
            MOVE "Stock markets open. Speculation as institution." TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 1 AND WS-TECH-L4-CHOICE(WS-IDX, 2) = 2
            MOVE "Limited liability. Capital risks absorbed."     TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 2 AND WS-TECH-L4-CHOICE(WS-IDX, 2) = 1
            MOVE "Mutual aid societies organize the workers."     TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 2 AND WS-TECH-L4-CHOICE(WS-IDX, 2) = 2
            MOVE "Worker-owned factories. No more hired labour."  TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 3 AND WS-TECH-L4-CHOICE(WS-IDX, 2) = 1
            MOVE "Trusts dominate. Few firms own everything."     TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 3 AND WS-TECH-L4-CHOICE(WS-IDX, 2) = 2
            MOVE "Vertical integration. Supply chains owned end-to-end." TO WS-CHRON-DESC
        WHEN OTHER
            MOVE "Organization deepened." TO WS-CHRON-DESC
    END-EVALUATE.

CHRON-KNOW-L4.
    EVALUATE TRUE
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 3) = 1 AND WS-TECH-L4-CHOICE(WS-IDX, 3) = 1
            MOVE "Scientific method codified. Hypothesis and proof." TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 3) = 1 AND WS-TECH-L4-CHOICE(WS-IDX, 3) = 2
            MOVE "Specialization. Each scholar a narrow expert."     TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 3) = 2 AND WS-TECH-L4-CHOICE(WS-IDX, 3) = 1
            MOVE "Theology systematized. Sacred logic."              TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 3) = 2 AND WS-TECH-L4-CHOICE(WS-IDX, 3) = 2
            MOVE "Common law. Precedent over decree."                TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 3) = 3 AND WS-TECH-L4-CHOICE(WS-IDX, 3) = 1
            MOVE "Oral tradition canonized. Ancestors remembered."   TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 3) = 3 AND WS-TECH-L4-CHOICE(WS-IDX, 3) = 2
            MOVE "Practical crafts mastered through generations."    TO WS-CHRON-DESC
        WHEN OTHER
            MOVE "Knowledge deepened." TO WS-CHRON-DESC
    END-EVALUATE.

CHRON-POW-L4.
    EVALUATE TRUE
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 1 AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 1
            MOVE "Total war doctrine. Society fully militarized."    TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 1 AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 2
            MOVE "Reserve system. Mobilization on demand."           TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 2 AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 1
            MOVE "Officer corps formalized. Career soldiers."        TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 2 AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 2
            MOVE "Special forces. Elite shock troops trained."       TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 3 AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 1
            MOVE "Citizen army. Defense by community."               TO WS-CHRON-DESC
        WHEN WS-TECH-L3-CHOICE(WS-IDX, 4) = 3 AND WS-TECH-L4-CHOICE(WS-IDX, 4) = 2
            MOVE "Guerrilla doctrine. Asymmetric defense mastered."  TO WS-CHRON-DESC
        WHEN OTHER
            MOVE "Power refined." TO WS-CHRON-DESC
    END-EVALUATE.

WRITE-TECH.
*> Записывает tech.dat. 10 строк по 24 байта (Phase 18 формат).
    OPEN OUTPUT TECH-FILE
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        MOVE SPACES TO WS-TECH-REC
        PERFORM VARYING WS-BIDX FROM 1 BY 1
                UNTIL WS-BIDX > TECH-BRANCH-COUNT
            MOVE WS-TECH-LEVEL(WS-IDX, WS-BIDX)
                TO WS-TECH-REC(WS-BIDX:1)
        END-PERFORM
        MOVE WS-TECH-PROGRESS(WS-IDX, 1) TO WS-TECH-REC(5:3)
        MOVE WS-TECH-PROGRESS(WS-IDX, 2) TO WS-TECH-REC(8:3)
        MOVE WS-TECH-PROGRESS(WS-IDX, 3) TO WS-TECH-REC(11:3)
        MOVE WS-TECH-PROGRESS(WS-IDX, 4) TO WS-TECH-REC(14:3)
        PERFORM VARYING WS-BIDX FROM 1 BY 1
                UNTIL WS-BIDX > TECH-BRANCH-COUNT
            COMPUTE WS-RK = 16 + WS-BIDX
            MOVE WS-TECH-L3-CHOICE(WS-IDX, WS-BIDX)
                TO WS-TECH-REC(WS-RK:1)
            COMPUTE WS-RK = 20 + WS-BIDX
            MOVE WS-TECH-L4-CHOICE(WS-IDX, WS-BIDX)
                TO WS-TECH-REC(WS-RK:1)
        END-PERFORM
        WRITE WS-TECH-REC
    END-PERFORM
    CLOSE TECH-FILE.

CULTURE-DRIFT-ALL.
*> Phase 15. Каждый ход региональные культурные векторы дрейфуют:
*> mil = накопление от воин, merc = от MERCANT-правителей, rel = от PIOUS.
*> Каждые CULTURE-DECAY-INTERVAL ходов всё медленно стирается на 1 (без подкрепления).
*> COLLAPSED регионы пропускаем — у них культурная преемственность сломана.
*>
*> Phase 19. Расширение по линии МЭЛС:
*>  • дрейф труда (Маркс): каждые 10 ходов сама форма производства
*>    производит свою культуру у региона (rel в аграрных, merc в торговых,
*>    mil в имперских — без вмешательства правителя);
*>  • культурная диффузия (Ленин/Троцкий: combined and uneven development):
*>    отстающие регионы перенимают культурные элементы от соседей с
*>    разрывом ≥ 30 пунктов, как «культурная волна».
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
*>          MERCANT-правитель → коммерческая культура
            IF WS-RULER-TRAIT(WS-IDX) = "MERCANT   "
               AND WS-CULT-MERC(WS-IDX) < CULTURE-MAX
                ADD CULTURE-MERCANT-DELTA TO WS-CULT-MERC(WS-IDX)
            END-IF
*>          PIOUS-правитель → религиозная культура
            IF WS-RULER-TRAIT(WS-IDX) = "PIOUS     "
               AND WS-CULT-REL(WS-IDX) < CULTURE-MAX
                ADD CULTURE-PIOUS-DELTA TO WS-CULT-REL(WS-IDX)
            END-IF
*>          Phase 19: дрейф труда — мода производит культуру каждые 10 ходов
            IF FUNCTION MOD(WS-YEAR, CULTURE-LABOUR-INTERVAL) = 0
                EVALUATE TRUE
                    WHEN WS-PROD-MODE(WS-IDX) = WS-MODE-PRIMITIVE
                    WHEN WS-PROD-MODE(WS-IDX) = WS-MODE-SLAVE
                    WHEN WS-PROD-MODE(WS-IDX) = WS-MODE-FEUDAL
*>                      Аграрно-родовое общество → религиозная культура
                        IF WS-CULT-REL(WS-IDX) < CULTURE-MAX
                            ADD 1 TO WS-CULT-REL(WS-IDX)
                        END-IF
                    WHEN WS-PROD-MODE(WS-IDX) = WS-MODE-MERCANTILE
                    WHEN WS-PROD-MODE(WS-IDX) = WS-MODE-PROTO-IND
                    WHEN WS-PROD-MODE(WS-IDX) = WS-MODE-INDUSTRIAL
*>                      Торгово-промышленный труд → коммерческая культура
                        IF WS-CULT-MERC(WS-IDX) < CULTURE-MAX
                            ADD 1 TO WS-CULT-MERC(WS-IDX)
                        END-IF
                    WHEN WS-PROD-MODE(WS-IDX) = WS-MODE-IMPERIAL
*>                      Финансовый капитал нуждается в внешней силе → mil
                        IF WS-CULT-MIL(WS-IDX) < CULTURE-MAX
                            ADD 1 TO WS-CULT-MIL(WS-IDX)
                        END-IF
                    WHEN WS-PROD-MODE(WS-IDX) = WS-MODE-SOCIALIST
*>                      Социализм опирается на трудовую/коммерческую базу
                        IF WS-CULT-MERC(WS-IDX) < CULTURE-MAX
                            ADD 1 TO WS-CULT-MERC(WS-IDX)
                        END-IF
                END-EVALUATE
            END-IF
*>          Phase 19: культурная диффузия от соседей
            PERFORM CULTURE-DIFFUSE-NEIGHBOR VARYING WS-NIDX FROM 1 BY 1
                UNTIL WS-NIDX > 3
*>          Cap всех векторов
            IF WS-CULT-MIL(WS-IDX)  > CULTURE-MAX
                MOVE CULTURE-MAX TO WS-CULT-MIL(WS-IDX)
            END-IF
            IF WS-CULT-MERC(WS-IDX) > CULTURE-MAX
                MOVE CULTURE-MAX TO WS-CULT-MERC(WS-IDX)
            END-IF
            IF WS-CULT-REL(WS-IDX)  > CULTURE-MAX
                MOVE CULTURE-MAX TO WS-CULT-REL(WS-IDX)
            END-IF
*>          Распад: каждые 5 ходов −1 на каждый ненулевой вектор
            IF FUNCTION MOD(WS-YEAR, CULTURE-DECAY-INTERVAL) = 0
                IF WS-CULT-MIL(WS-IDX) > 0
                    SUBTRACT 1 FROM WS-CULT-MIL(WS-IDX)
                END-IF
                IF WS-CULT-MERC(WS-IDX) > 0
                    SUBTRACT 1 FROM WS-CULT-MERC(WS-IDX)
                END-IF
                IF WS-CULT-REL(WS-IDX) > 0
                    SUBTRACT 1 FROM WS-CULT-REL(WS-IDX)
                END-IF
            END-IF
        END-IF
    END-PERFORM.

CULTURE-DIFFUSE-NEIGHBOR.
*> Caller: WS-IDX, WS-NIDX. Phase 19. Диффузия культурных элементов от
*> соседа: если у соседа какой-то вектор больше нашего на ≥30, наш +1.
*> COLLAPSED-сосед не передаёт — связь оборвана.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-IDX) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-IDX) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-IDX) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED
        IF WS-CULT-MIL(WS-NBREG) >=
              WS-CULT-MIL(WS-IDX) + CULTURE-DIFFUSION-MIN
           AND WS-CULT-MIL(WS-IDX) < CULTURE-MAX
            ADD 1 TO WS-CULT-MIL(WS-IDX)
        END-IF
        IF WS-CULT-MERC(WS-NBREG) >=
              WS-CULT-MERC(WS-IDX) + CULTURE-DIFFUSION-MIN
           AND WS-CULT-MERC(WS-IDX) < CULTURE-MAX
            ADD 1 TO WS-CULT-MERC(WS-IDX)
        END-IF
        IF WS-CULT-REL(WS-NBREG) >=
              WS-CULT-REL(WS-IDX) + CULTURE-DIFFUSION-MIN
           AND WS-CULT-REL(WS-IDX) < CULTURE-MAX
            ADD 1 TO WS-CULT-REL(WS-IDX)
        END-IF
    END-IF.

INNOVATION-CHECK-ALL.
*> Phase 15. Раз в N ходов на регион случается «изобретение» с уникальным
*> эффектом и записью в хронике. Условия каждой инновации индивидуальны.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
           AND WS-CAPITAL-STOCK(WS-IDX) > INNOVATION-CAPITAL-MIN
            MOVE INNOVATION-CHECK-PERMIL TO WS-PROB-PERMIL
            MOVE "INNOVATION    " TO WS-DEBUG-LABEL
            PERFORM ROLL-EVENT
            IF WS-EVENT-FIRES = 1
                PERFORM PICK-INNOVATION
            END-IF
        END-IF
    END-PERFORM.

PICK-INNOVATION.
*> Caller: WS-IDX. Выбираем инновацию по предусловиям + случай.
*> Если ни одна не подходит — тихо ничего не делаем.
*> 5 инноваций: IRON-PLOW, PRINTING-PRESS, DOUBLE-ENTRY, COMPASS, GUNPOWDER
    MOVE FUNCTION RANDOM TO WS-RAND-VAL
    COMPUTE WS-RAND-INT = WS-RAND-VAL * 1000
    EVALUATE TRUE
        WHEN WS-RAND-INT < 200
*>          IRON-PLOW: PRIMARY GRAIN/TIMBER + PROD ≥ 1 → labour ×1.20
            IF WS-TECH-LEVEL(WS-IDX, 1) >= 1
               AND (WS-PRIMARY-GOOD(WS-IDX) = "GRAIN          "
                    OR WS-PRIMARY-GOOD(WS-IDX) = "TIMBER         ")
                COMPUTE WS-LABOUR-HOURS(WS-IDX) =
                    WS-LABOUR-HOURS(WS-IDX) * 12 / 10
                MOVE WS-YEAR             TO WS-CHRON-YEAR
                MOVE "INNOVATION     "   TO WS-CHRON-TYPE
                MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON
                MOVE "Iron plow! Agriculture transformed."
                    TO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            END-IF
        WHEN WS-RAND-INT < 400
*>          PRINTING-PRESS: KNOW ≥ 2 → +8 consciousness, +2 каждому соседу
*>          (Phase 22: одноразовый buff не должен разрушать новый темп.)
            IF WS-TECH-LEVEL(WS-IDX, 3) >= 2
                ADD 8 TO WS-CONSCIOUSNESS(WS-IDX)
                IF WS-CONSCIOUSNESS(WS-IDX) > CONSCIOUSNESS-MAX
                    MOVE CONSCIOUSNESS-MAX TO WS-CONSCIOUSNESS(WS-IDX)
                END-IF
                PERFORM PRINTING-NB-SPREAD VARYING WS-NIDX FROM 1 BY 1
                    UNTIL WS-NIDX > 3
                MOVE WS-YEAR             TO WS-CHRON-YEAR
                MOVE "INNOVATION     "   TO WS-CHRON-TYPE
                MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON
                MOVE "Printing press! Ideas multiply."
                    TO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            END-IF
        WHEN WS-RAND-INT < 600
*>          DOUBLE-ENTRY: ORG ≥ 1 ∧ merchants ≥ 15 → capital +200K
            IF WS-TECH-LEVEL(WS-IDX, 2) >= 1
               AND WS-MERCHANTS-PCT(WS-IDX) >= 15
                ADD 200000 TO WS-CAPITAL-STOCK(WS-IDX)
                MOVE WS-YEAR             TO WS-CHRON-YEAR
                MOVE "INNOVATION     "   TO WS-CHRON-TYPE
                MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON
                MOVE "Double-entry bookkeeping! Capital books accelerate."
                    TO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            END-IF
        WHEN WS-RAND-INT < 800
*>          COMPASS: COAST + ORG ≥ 1 → trade_balance +500
            IF WS-TERRAIN(WS-IDX) = "COAST     "
               AND WS-TECH-LEVEL(WS-IDX, 2) >= 1
                ADD 500 TO WS-TRADE-BALANCE(WS-IDX)
                MOVE WS-YEAR             TO WS-CHRON-YEAR
                MOVE "INNOVATION     "   TO WS-CHRON-TYPE
                MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON
                MOVE "Compass! Maritime trade extends across horizons."
                    TO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            END-IF
        WHEN OTHER
*>          GUNPOWDER: PROD ≥ 1 ∧ POW ≥ 1 → military +5000
            IF WS-TECH-LEVEL(WS-IDX, 1) >= 1
               AND WS-TECH-LEVEL(WS-IDX, 4) >= 1
                ADD 5000 TO WS-MILITARY-STRENGTH(WS-IDX)
                IF WS-MILITARY-STRENGTH(WS-IDX) > WAR-MILITARY-CAP
                    MOVE WAR-MILITARY-CAP TO WS-MILITARY-STRENGTH(WS-IDX)
                END-IF
                ADD CULTURE-WAR-WIN-DELTA TO WS-CULT-MIL(WS-IDX)
                MOVE WS-YEAR             TO WS-CHRON-YEAR
                MOVE "INNOVATION     "   TO WS-CHRON-TYPE
                MOVE WS-NAME(WS-IDX)     TO WS-CHRON-RGON
                MOVE "Gunpowder! Battlefields transformed."
                    TO WS-CHRON-DESC
                PERFORM WRITE-CHRONICLE
            END-IF
    END-EVALUATE.

PRINTING-NB-SPREAD.
*> Caller: WS-IDX, WS-NIDX. +5 consciousness соседу при печатном станке.
    EVALUATE WS-NIDX
        WHEN 1 MOVE WS-NEIGHBOR-1(WS-IDX) TO WS-NBREG
        WHEN 2 MOVE WS-NEIGHBOR-2(WS-IDX) TO WS-NBREG
        WHEN 3 MOVE WS-NEIGHBOR-3(WS-IDX) TO WS-NBREG
    END-EVALUATE
    IF WS-NBREG > 0 AND WS-NBREG <= REGION-COUNT
       AND WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED
        ADD 2 TO WS-CONSCIOUSNESS(WS-NBREG)
        IF WS-CONSCIOUSNESS(WS-NBREG) > CONSCIOUSNESS-MAX
            MOVE CONSCIOUSNESS-MAX TO WS-CONSCIOUSNESS(WS-NBREG)
        END-IF
    END-IF.

RELATIONS-DECAY.
*> Каждое отношение приближается к 0 на 1 в год — память сглаживается.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        PERFORM VARYING WS-RJ FROM 1 BY 1 UNTIL WS-RJ > REGION-COUNT
            IF WS-IDX NOT = WS-RJ
                IF WS-REL-ROW(WS-IDX, WS-RJ) > 0
                    SUBTRACT RELATIONS-DECAY-STEP
                        FROM WS-REL-ROW(WS-IDX, WS-RJ)
                ELSE IF WS-REL-ROW(WS-IDX, WS-RJ) < 0
                    ADD RELATIONS-DECAY-STEP
                        TO WS-REL-ROW(WS-IDX, WS-RJ)
                END-IF
            END-IF
        END-PERFORM
    END-PERFORM.

APPLY-TRAIT-BIAS.
*> Caller: WS-PROB-PERMIL вычислена, WS-DEBUG-LABEL указывает событие, WS-IDX — регион.
*> Биасим WS-PROB-PERMIL по WS-RULER-TRAIT(WS-IDX). Промилле абсолютные (+/- к итогу).
*> Не зажимаем здесь — это делает caller через свой CAP.
    EVALUATE WS-RULER-TRAIT(WS-IDX)
        WHEN "AMBITIOUS "
            EVALUATE WS-DEBUG-LABEL
                WHEN "DYNASTIC-WAR  " ADD 30 TO WS-PROB-PERMIL
                WHEN "CRISIS-WAR    " ADD 20 TO WS-PROB-PERMIL
                WHEN "IMPERIAL-WAR  " ADD 40 TO WS-PROB-PERMIL
                WHEN "MODE-SLAVE    " ADD 30 TO WS-PROB-PERMIL
                WHEN "MODE-IMPERIAL " ADD 30 TO WS-PROB-PERMIL
            END-EVALUATE
        WHEN "CAUTIOUS  "
            EVALUATE WS-DEBUG-LABEL
                WHEN "DYNASTIC-WAR  " SUBTRACT 40 FROM WS-PROB-PERMIL
                WHEN "CRISIS-WAR    " SUBTRACT 40 FROM WS-PROB-PERMIL
                WHEN "CLASS-WAR     " SUBTRACT 40 FROM WS-PROB-PERMIL
                WHEN "IMPERIAL-WAR  " SUBTRACT 40 FROM WS-PROB-PERMIL
            END-EVALUATE
        WHEN "CRUEL     "
            EVALUATE WS-DEBUG-LABEL
                WHEN "CLASS-WAR     " ADD 60 TO WS-PROB-PERMIL
                WHEN "DYNASTIC-WAR  " ADD 10 TO WS-PROB-PERMIL
                WHEN "IMPERIAL-WAR  " ADD 30 TO WS-PROB-PERMIL
                WHEN "MODE-SLAVE    " ADD 30 TO WS-PROB-PERMIL
                WHEN "MODE-IMPERIAL " ADD 30 TO WS-PROB-PERMIL
            END-EVALUATE
        WHEN "PIOUS     "
            EVALUATE WS-DEBUG-LABEL
                WHEN "DYNASTIC-WAR  " SUBTRACT 30 FROM WS-PROB-PERMIL
                WHEN "CRISIS-WAR    " SUBTRACT 30 FROM WS-PROB-PERMIL
                WHEN "CLASS-WAR     " SUBTRACT 30 FROM WS-PROB-PERMIL
                WHEN "IMPERIAL-WAR  " SUBTRACT 30 FROM WS-PROB-PERMIL
                WHEN "REVOLUTION    " SUBTRACT 10 FROM WS-PROB-PERMIL
                WHEN "MODE-FEUDAL   " ADD 30 TO WS-PROB-PERMIL
            END-EVALUATE
        WHEN "MERCANT   "
            EVALUATE WS-DEBUG-LABEL
                WHEN "MODE-MERCANTILE" ADD 30 TO WS-PROB-PERMIL
                WHEN "MODE-PROTO-IND " ADD 30 TO WS-PROB-PERMIL
                WHEN "MODE-INDUSTRIAL" ADD 30 TO WS-PROB-PERMIL
                WHEN "DYNASTIC-WAR  " SUBTRACT 30 FROM WS-PROB-PERMIL
                WHEN "CRISIS-WAR    " SUBTRACT 30 FROM WS-PROB-PERMIL
                WHEN "CLASS-WAR     " SUBTRACT 30 FROM WS-PROB-PERMIL
                WHEN "IMPERIAL-WAR  " SUBTRACT 20 FROM WS-PROB-PERMIL
            END-EVALUATE
    END-EVALUATE.

REL-DELTA-PAIR.
*> Caller: WS-IDX, WS-NBREG, WS-REL-TMP (delta, signed).
*> Симметрично применяет delta к relations(IDX, NBREG) и (NBREG, IDX),
*> с зажимом в [-RELATIONS-MAX, +RELATIONS-MAX].
    ADD WS-REL-TMP
        TO WS-REL-ROW(WS-IDX, WS-NBREG)
    ADD WS-REL-TMP
        TO WS-REL-ROW(WS-NBREG, WS-IDX)
    COMPUTE WS-REL-TMP = - RELATIONS-MAX
    IF WS-REL-ROW(WS-IDX, WS-NBREG) > RELATIONS-MAX
        MOVE RELATIONS-MAX
            TO WS-REL-ROW(WS-IDX, WS-NBREG)
    END-IF
    IF WS-REL-ROW(WS-IDX, WS-NBREG) < WS-REL-TMP
        MOVE WS-REL-TMP
            TO WS-REL-ROW(WS-IDX, WS-NBREG)
    END-IF
    IF WS-REL-ROW(WS-NBREG, WS-IDX) > RELATIONS-MAX
        MOVE RELATIONS-MAX
            TO WS-REL-ROW(WS-NBREG, WS-IDX)
    END-IF
    IF WS-REL-ROW(WS-NBREG, WS-IDX) < WS-REL-TMP
        MOVE WS-REL-TMP
            TO WS-REL-ROW(WS-NBREG, WS-IDX)
    END-IF.

ROLL-EVENT.
*> На входе: WS-PROB-PERMIL (0..1000), WS-DEBUG-LABEL (имя события).
*> На выходе: WS-EVENT-FIRES (0/1). При ECOS_DEBUG=1 пишем строку в stderr.
    IF WS-PROB-PERMIL <= 0
        MOVE 0 TO WS-EVENT-FIRES
        MOVE 0 TO WS-RAND-INT
    ELSE
        MOVE FUNCTION RANDOM TO WS-RAND-VAL
        COMPUTE WS-RAND-INT = WS-RAND-VAL * 1000
        IF WS-RAND-INT < WS-PROB-PERMIL
            MOVE 1 TO WS-EVENT-FIRES
        ELSE
            MOVE 0 TO WS-EVENT-FIRES
        END-IF
    END-IF
    IF WS-DEBUG-FLAG = "1"
        DISPLAY "[" WS-YEAR "] " WS-DEBUG-LABEL
                " idx="   WS-IDX
                " p="     WS-PROB-PERMIL
                " roll="  WS-RAND-INT
                " fired=" WS-EVENT-FIRES
                UPON SYSERR
    END-IF.

CLIMATE-EVENTS-ALL.
*> Природные и культурные шоки, привязанные к рельефу.
*> Хаос в стиле Dwarf Fortress: историю двигают не только классы, но и засухи.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED
            EVALUATE WS-TERRAIN(WS-IDX)
                WHEN "SWAMP     "
                    MOVE SWAMP-EPIDEMIC-PERMIL TO WS-PROB-PERMIL
                    MOVE "CLIMATE-EPIDEM" TO WS-DEBUG-LABEL
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1 PERFORM EVT-EPIDEMIC END-IF
                WHEN "DESERT    "
                    MOVE DESERT-DROUGHT-PERMIL TO WS-PROB-PERMIL
                    MOVE "CLIMATE-DROUGH" TO WS-DEBUG-LABEL
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1 PERFORM EVT-DROUGHT END-IF
                WHEN "MOUNTAINS "
                    MOVE MOUNTAIN-CAVEIN-PERMIL TO WS-PROB-PERMIL
                    MOVE "CLIMATE-CAVEIN" TO WS-DEBUG-LABEL
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1 PERFORM EVT-CAVEIN END-IF
                WHEN "PLAINS    "
                    MOVE PLAINS-HARVEST-PERMIL TO WS-PROB-PERMIL
                    MOVE "CLIMATE-HARVES" TO WS-DEBUG-LABEL
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1 PERFORM EVT-HARVEST END-IF
                WHEN "COAST     "
                    MOVE COAST-STORM-PERMIL TO WS-PROB-PERMIL
                    MOVE "CLIMATE-STORM " TO WS-DEBUG-LABEL
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1 PERFORM EVT-STORM END-IF
                WHEN "FOREST    "
                    MOVE 30 TO WS-PROB-PERMIL
                    MOVE "CLIMATE-BLIGHT" TO WS-DEBUG-LABEL
                    PERFORM ROLL-EVENT
                    IF WS-EVENT-FIRES = 1 PERFORM EVT-BLIGHT END-IF
            END-EVALUATE
        END-IF
    END-PERFORM.

EVT-EPIDEMIC.
*> Эпидемия: население *= 0.85, tension += 10.
    COMPUTE WS-POPULATION(WS-IDX) =
        WS-POPULATION(WS-IDX) * EPIDEMIC-POP-PCT / 100
    IF WS-POPULATION(WS-IDX) < POP-FLOOR
        MOVE POP-FLOOR TO WS-POPULATION(WS-IDX)
    END-IF
    COMPUTE WS-LABOUR-HOURS(WS-IDX) =
        WS-POPULATION(WS-IDX) * LABOUR-PER-CAPITA
    ADD EPIDEMIC-TENSION-DELTA TO WS-CLASS-TENSION(WS-IDX)
    MOVE WS-IDX TO WS-CLAMP-IDX  PERFORM CLAMP-TENSION
*>  Phase 15 — катастрофа усиливает религиозную культуру (поиск утешения)
    ADD CULTURE-DISASTER-DELTA TO WS-CULT-REL(WS-IDX)
    IF WS-CULT-REL(WS-IDX) > CULTURE-MAX
        MOVE CULTURE-MAX TO WS-CULT-REL(WS-IDX)
    END-IF
    MOVE WS-YEAR           TO WS-CHRON-YEAR
    MOVE "EPIDEMIC       " TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
    MOVE "Plague strikes the swamps. Workers die in droves." TO WS-CHRON-DESC
    PERFORM WRITE-CHRONICLE.

EVT-DROUGHT.
*> Засуха: labour -40% на этот ход (восстановится в DEMOGRAPHY следующего хода).
    COMPUTE WS-LABOUR-HOURS(WS-IDX) =
        WS-LABOUR-HOURS(WS-IDX) * DROUGHT-LABOUR-PCT / 100
    ADD DROUGHT-TENSION-DELTA TO WS-CLASS-TENSION(WS-IDX)
    MOVE WS-IDX TO WS-CLAMP-IDX  PERFORM CLAMP-TENSION
    MOVE WS-YEAR           TO WS-CHRON-YEAR
    MOVE "DROUGHT        " TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
    MOVE "Drought ravages the desert. Wells run dry." TO WS-CHRON-DESC
    PERFORM WRITE-CHRONICLE.

EVT-CAVEIN.
*> Обвал шахты: capital -8%, минимальная травма репутации.
    COMPUTE WS-CAPITAL-STOCK(WS-IDX) =
        WS-CAPITAL-STOCK(WS-IDX) * CAVEIN-CAPITAL-PCT / 100
    MOVE WS-YEAR           TO WS-CHRON-YEAR
    MOVE "CAVE-IN        " TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
    MOVE "Mountain mine collapses. Capital stock damaged." TO WS-CHRON-DESC
    PERFORM WRITE-CHRONICLE.

EVT-HARVEST.
*> Урожайный/неурожайный год — броском монеты.
    MOVE FUNCTION RANDOM TO WS-RAND-VAL
    IF WS-RAND-VAL > 0.5
*>      Хороший урожай: capital +20%, tension -5
        COMPUTE WS-CAPITAL-STOCK(WS-IDX) =
            WS-CAPITAL-STOCK(WS-IDX) * GOOD-HARVEST-CAPITAL-PCT / 100
        IF WS-CLASS-TENSION(WS-IDX) >= GOOD-HARVEST-TENSION-DROP
            COMPUTE WS-CLASS-TENSION(WS-IDX) =
                WS-CLASS-TENSION(WS-IDX) - GOOD-HARVEST-TENSION-DROP
        END-IF
        MOVE "BUMPER-CROP    " TO WS-CHRON-TYPE
        MOVE "Bumper harvest fills the granaries." TO WS-CHRON-DESC
    ELSE
*>      Неурожай: labour -25%, tension +5
        COMPUTE WS-LABOUR-HOURS(WS-IDX) =
            WS-LABOUR-HOURS(WS-IDX) * BAD-HARVEST-LABOUR-PCT / 100
        ADD BAD-HARVEST-TENSION TO WS-CLASS-TENSION(WS-IDX)
        MOVE WS-IDX TO WS-CLAMP-IDX  PERFORM CLAMP-TENSION
        MOVE "BAD-HARVEST    " TO WS-CHRON-TYPE
        MOVE "Crops fail. Workers tighten their belts." TO WS-CHRON-DESC
    END-IF
    MOVE WS-YEAR           TO WS-CHRON-YEAR
    MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
    PERFORM WRITE-CHRONICLE.

EVT-STORM.
*> Шторм на побережье: labour -5%, чисто косметика, но добавляет шум.
    COMPUTE WS-LABOUR-HOURS(WS-IDX) =
        WS-LABOUR-HOURS(WS-IDX) * STORM-LABOUR-PCT / 100
    MOVE WS-YEAR           TO WS-CHRON-YEAR
    MOVE "STORM          " TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
    MOVE "Coastal storm wrecks the docks." TO WS-CHRON-DESC
    PERFORM WRITE-CHRONICLE.

EVT-BLIGHT.
*> Лесное заболевание: labour -10%, медленный шок без жертв.
    COMPUTE WS-LABOUR-HOURS(WS-IDX) =
        WS-LABOUR-HOURS(WS-IDX) * 90 / 100
    MOVE WS-YEAR           TO WS-CHRON-YEAR
    MOVE "BLIGHT         " TO WS-CHRON-TYPE
    MOVE WS-NAME(WS-IDX)   TO WS-CHRON-RGON
    MOVE "Forest blight spreads through the timber stands." TO WS-CHRON-DESC
    PERFORM WRITE-CHRONICLE.

WRITE-MARKET.
*> Снимок рынка для TUI. Перезаписываем market.dat целиком (51 байт/строка).
*> Layout: name X(15) | supply 9(12)V99 | demand 9(12)V99 | price 9(5)V99 | crisis 9
*> Десятичные пишутся без точки — Rust делит на 100.0 при чтении.
    OPEN OUTPUT MARKET-FILE
    PERFORM VARYING WS-MIDX FROM 1 BY 1 UNTIL WS-MIDX > MARKET-COUNT
*>      Supply/demand хранятся как S9(12)V99; копируем в беззнаковые буферы,
*>      чтобы STRING выдавал чистые цифры без overpunch-знака.
        IF WS-MKT-SUPPLY(WS-MIDX) >= 0
            MOVE WS-MKT-SUPPLY(WS-MIDX) TO WS-MKT-OUT-SUPPLY
        ELSE
            MOVE 0 TO WS-MKT-OUT-SUPPLY
        END-IF
        IF WS-MKT-DEMAND(WS-MIDX) >= 0
            MOVE WS-MKT-DEMAND(WS-MIDX) TO WS-MKT-OUT-DEMAND
        ELSE
            MOVE 0 TO WS-MKT-OUT-DEMAND
        END-IF
        STRING
            WS-MKT-NAME(WS-MIDX)    DELIMITED SIZE
            WS-MKT-OUT-SUPPLY       DELIMITED SIZE
            WS-MKT-OUT-DEMAND       DELIMITED SIZE
            WS-MKT-PRICE(WS-MIDX)   DELIMITED SIZE
            WS-MKT-CRISIS(WS-MIDX)  DELIMITED SIZE
            INTO WS-MARKET-OUT-LINE
        END-STRING
        IF FUNCTION LENGTH(FUNCTION TRIM(WS-MARKET-OUT-LINE)) > MARKET-REC-LEN
            DISPLAY "WARN: market.dat record drift" UPON SYSERR
        END-IF
        WRITE WS-MARKET-REC FROM WS-MARKET-OUT-LINE
    END-PERFORM
    CLOSE MARKET-FILE.
