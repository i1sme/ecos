IDENTIFICATION DIVISION.
PROGRAM-ID. WORLD-GEN.
AUTHOR. ECOS-ENGINE.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
*>  Phase 24 — Этап 1: world.dat расщеплён на regions.dat (геофон,
*>  статичен) и polities.dat (политический слой, переписывается каждый ход).
    SELECT REGIONS-FILE  ASSIGN TO "cobol/regions.dat"
        ORGANIZATION IS LINE SEQUENTIAL.
    SELECT POLITIES-FILE ASSIGN TO "cobol/polities.dat"
        ORGANIZATION IS LINE SEQUENTIAL.

DATA DIVISION.
FILE SECTION.
FD REGIONS-FILE.
01 REGION-RECORD  PIC X(80).
FD POLITIES-FILE.
01 POLITY-RECORD  PIC X(200).

WORKING-STORAGE SECTION.

*> Phase 24 — Этап 1. Структура расщеплена на Region (геофон,
*> постоянный) и Polity (политический слой, динамичный). На Этапе 1
*> 1 полития на регион, индексы совпадают, WS-POLITY-NAME = WS-NAME.
01 WS-REGIONS OCCURS 10 TIMES.
   05 WS-NAME              PIC X(20).
   05 WS-TERRAIN           PIC X(10).
   05 WS-CLIMATE           PIC X(10).
   05 WS-PRIMARY-GOOD      PIC X(15).
   05 WS-NEIGHBOR-1        PIC 99.
   05 WS-NEIGHBOR-2        PIC 99.
   05 WS-NEIGHBOR-3        PIC 99.

*> Phase 24 / Этап 2B: 30 слотов политий (10 стартовых живых +
*> 20 резервных EXTINCT для будущего spawn'а наследников).
*> WS-REGION-ID — в каком регионе живёт полития (0 = не размещена).
01 WS-POLITIES OCCURS 30 TIMES.
   05 WS-POLITY-NAME       PIC X(20).
   05 WS-REGION-ID         PIC 99.
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
*> Phase 21 — счётчик лет в эпохе (стартуем с 0)
   05 WS-MODE-YEARS        PIC 9(4).
*> Phase 25 — резервная армия труда (доля безработных, 0..100).
   05 WS-UNEMPLOYMENT-PCT  PIC 9(3).

*> Пул имён правителей (20 фэнтезийных). Используется при генерации/наследовании.
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

01 WS-IDX               PIC 99.
01 WS-RAND-RAW          PIC 9(9)V9(9).
01 WS-RAND-INT          PIC 99.
01 WS-OUT-LINE          PIC X(204).

01 WS-BASE-ART          PIC S9(3).
01 WS-BASE-MERCH        PIC S9(3).
01 WS-BASE-NOB          PIC S9(3).
01 WS-BASE-CLER         PIC S9(3).
01 WS-BASE-PEAS         PIC S9(3).
01 WS-BASE-POP          PIC 9(8).
01 WS-CLASS-TOTAL       PIC 9(3).

PROCEDURE DIVISION.
MAIN-PARA.
*>  Phase 24 / Этап 2B: 10 живых стартовых политий + 20 EXTINCT-резервов.
*>  Резервы пишутся как пустые слоты в polities.dat — simulate их видит
*>  как dormant (фильтр POLITY-DORMANT) и при коллапсе крупной политии
*>  может оживить один из них как наследника.
    PERFORM INIT-REGION VARYING WS-IDX FROM 1 BY 1
        UNTIL WS-IDX > 10
    PERFORM INIT-EXTINCT-SLOT VARYING WS-IDX FROM 11 BY 1
        UNTIL WS-IDX > 30

    PERFORM ASSIGN-NEIGHBORS

*>  regions.dat (геофон) — 10 строк, статика.
*>  polities.dat — 30 строк (10 живых + 20 EXTINCT), переписывается
*>  simulate'ом каждый ход.
    OPEN OUTPUT REGIONS-FILE
    PERFORM WRITE-REGION-ROW VARYING WS-IDX FROM 1 BY 1
        UNTIL WS-IDX > 10
    CLOSE REGIONS-FILE

    OPEN OUTPUT POLITIES-FILE
    PERFORM WRITE-POLITY-ROW VARYING WS-IDX FROM 1 BY 1
        UNTIL WS-IDX > 30
    CLOSE POLITIES-FILE
    STOP RUN.

INIT-REGION.
    MOVE FUNCTION RANDOM(WS-IDX) TO WS-RAND-RAW

    EVALUATE WS-IDX
        WHEN 1
            MOVE "Ironmarch          " TO WS-NAME(WS-IDX)
            MOVE "PLAINS    "          TO WS-TERRAIN(WS-IDX)
            MOVE "TEMPERATE "          TO WS-CLIMATE(WS-IDX)
            MOVE "GRAIN          "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 2
            MOVE "Ashvale            " TO WS-NAME(WS-IDX)
            MOVE "FOREST    "          TO WS-TERRAIN(WS-IDX)
            MOVE "TEMPERATE "          TO WS-CLIMATE(WS-IDX)
            MOVE "TIMBER         "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 3
            MOVE "Stonehold          " TO WS-NAME(WS-IDX)
            MOVE "MOUNTAINS "          TO WS-TERRAIN(WS-IDX)
            MOVE "COLD      "          TO WS-CLIMATE(WS-IDX)
            MOVE "ORE            "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 4
            MOVE "Frostfen           " TO WS-NAME(WS-IDX)
            MOVE "SWAMP     "          TO WS-TERRAIN(WS-IDX)
            MOVE "COLD      "          TO WS-CLIMATE(WS-IDX)
            MOVE "PEAT           "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 5
            MOVE "Goldgate           " TO WS-NAME(WS-IDX)
            MOVE "COAST     "          TO WS-TERRAIN(WS-IDX)
            MOVE "MILD      "          TO WS-CLIMATE(WS-IDX)
            MOVE "FISH           "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 6
            MOVE "Duskveil           " TO WS-NAME(WS-IDX)
            MOVE "DESERT    "          TO WS-TERRAIN(WS-IDX)
            MOVE "HOT       "          TO WS-CLIMATE(WS-IDX)
            MOVE "SPICES         "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 7
            MOVE "Thornwall          " TO WS-NAME(WS-IDX)
            MOVE "PLAINS    "          TO WS-TERRAIN(WS-IDX)
            MOVE "TEMPERATE "          TO WS-CLIMATE(WS-IDX)
            MOVE "GRAIN          "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 8
            MOVE "Saltmere           " TO WS-NAME(WS-IDX)
            MOVE "COAST     "          TO WS-TERRAIN(WS-IDX)
            MOVE "MILD      "          TO WS-CLIMATE(WS-IDX)
            MOVE "SALT           "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 9
            MOVE "Embervast          " TO WS-NAME(WS-IDX)
            MOVE "FOREST    "          TO WS-TERRAIN(WS-IDX)
            MOVE "TEMPERATE "          TO WS-CLIMATE(WS-IDX)
            MOVE "TIMBER         "     TO WS-PRIMARY-GOOD(WS-IDX)
        WHEN 10
            MOVE "Cinderkeep         " TO WS-NAME(WS-IDX)
            MOVE "MOUNTAINS "          TO WS-TERRAIN(WS-IDX)
            MOVE "COLD      "          TO WS-CLIMATE(WS-IDX)
            MOVE "COAL           "     TO WS-PRIMARY-GOOD(WS-IDX)
    END-EVALUATE

*> -- Базовый классовый состав по рельефу --
    EVALUATE WS-TERRAIN(WS-IDX)
        WHEN "PLAINS    "
            MOVE 18 TO WS-BASE-ART
            MOVE 10 TO WS-BASE-MERCH
            MOVE 07 TO WS-BASE-NOB
            MOVE 03 TO WS-BASE-CLER
            MOVE 1200000 TO WS-BASE-POP
        WHEN "FOREST    "
            MOVE 22 TO WS-BASE-ART
            MOVE 10 TO WS-BASE-MERCH
            MOVE 06 TO WS-BASE-NOB
            MOVE 03 TO WS-BASE-CLER
            MOVE 800000 TO WS-BASE-POP
        WHEN "MOUNTAINS "
            MOVE 26 TO WS-BASE-ART
            MOVE 07 TO WS-BASE-MERCH
            MOVE 07 TO WS-BASE-NOB
            MOVE 03 TO WS-BASE-CLER
            MOVE 600000 TO WS-BASE-POP
        WHEN "COAST     "
            MOVE 17 TO WS-BASE-ART
            MOVE 18 TO WS-BASE-MERCH
            MOVE 06 TO WS-BASE-NOB
            MOVE 03 TO WS-BASE-CLER
            MOVE 900000 TO WS-BASE-POP
        WHEN "SWAMP     "
            MOVE 14 TO WS-BASE-ART
            MOVE 07 TO WS-BASE-MERCH
            MOVE 07 TO WS-BASE-NOB
            MOVE 04 TO WS-BASE-CLER
            MOVE 500000 TO WS-BASE-POP
        WHEN "DESERT    "
            MOVE 14 TO WS-BASE-ART
            MOVE 22 TO WS-BASE-MERCH
            MOVE 08 TO WS-BASE-NOB
            MOVE 03 TO WS-BASE-CLER
            MOVE 400000 TO WS-BASE-POP
        WHEN OTHER
            MOVE 20 TO WS-BASE-ART
            MOVE 10 TO WS-BASE-MERCH
            MOVE 07 TO WS-BASE-NOB
            MOVE 03 TO WS-BASE-CLER
            MOVE 800000 TO WS-BASE-POP
    END-EVALUATE

*> -- Случайные отклонения (seed уже задан выше через RANDOM(WS-IDX)) --
*> ART ±4, MERCH ±3, NOB ±2, CLER ±1
    COMPUTE WS-BASE-ART   = WS-BASE-ART
        + FUNCTION INTEGER(FUNCTION RANDOM * 9) - 4
    COMPUTE WS-BASE-MERCH = WS-BASE-MERCH
        + FUNCTION INTEGER(FUNCTION RANDOM * 7) - 3
    COMPUTE WS-BASE-NOB   = WS-BASE-NOB
        + FUNCTION INTEGER(FUNCTION RANDOM * 5) - 2
    COMPUTE WS-BASE-CLER  = WS-BASE-CLER
        + FUNCTION INTEGER(FUNCTION RANDOM * 3) - 1

*> -- Нижние границы --
    IF WS-BASE-ART   < 5 MOVE 5 TO WS-BASE-ART   END-IF
    IF WS-BASE-MERCH < 3 MOVE 3 TO WS-BASE-MERCH END-IF
    IF WS-BASE-NOB   < 3 MOVE 3 TO WS-BASE-NOB   END-IF
    IF WS-BASE-CLER  < 1 MOVE 1 TO WS-BASE-CLER  END-IF

*> -- Крестьяне заполняют остаток до 100 --
    COMPUTE WS-CLASS-TOTAL = WS-BASE-ART + WS-BASE-MERCH
                           + WS-BASE-NOB + WS-BASE-CLER
    COMPUTE WS-BASE-PEAS   = 100 - WS-CLASS-TOTAL
    IF WS-BASE-PEAS < 35
        MOVE 35 TO WS-BASE-PEAS
        COMPUTE WS-BASE-ART = 100 - 35
            - WS-BASE-MERCH - WS-BASE-NOB - WS-BASE-CLER
        IF WS-BASE-ART < 5 MOVE 5 TO WS-BASE-ART END-IF
    END-IF

    MOVE WS-BASE-PEAS  TO WS-PEASANTS-PCT(WS-IDX)
    MOVE WS-BASE-ART   TO WS-ARTISANS-PCT(WS-IDX)
    MOVE WS-BASE-MERCH TO WS-MERCHANTS-PCT(WS-IDX)
    MOVE WS-BASE-NOB   TO WS-NOBILITY-PCT(WS-IDX)
    MOVE WS-BASE-CLER  TO WS-CLERGY-PCT(WS-IDX)

*> -- Население ±20% --
    COMPUTE WS-RAND-INT = FUNCTION INTEGER(FUNCTION RANDOM * 5)
    EVALUATE WS-RAND-INT
        WHEN 0 COMPUTE WS-BASE-POP = WS-BASE-POP * 80 / 100
        WHEN 1 COMPUTE WS-BASE-POP = WS-BASE-POP * 90 / 100
        WHEN 3 COMPUTE WS-BASE-POP = WS-BASE-POP * 110 / 100
        WHEN 4 COMPUTE WS-BASE-POP = WS-BASE-POP * 120 / 100
        WHEN OTHER CONTINUE
    END-EVALUATE
    MOVE WS-BASE-POP TO WS-POPULATION(WS-IDX)

*> -- Производство (Phase 11) --
*> Стартовый модус по terrain: суровые регионы — PRIMITIVE, остальные — SLAVE.
*> «Всё начинается с малого» — мир не появляется сразу феодальным.
    EVALUATE WS-TERRAIN(WS-IDX)
        WHEN "DESERT    "
        WHEN "SWAMP     "
            MOVE "PRIMITIVE      " TO WS-PROD-MODE(WS-IDX)
        WHEN OTHER
            MOVE "SLAVE          " TO WS-PROD-MODE(WS-IDX)
    END-EVALUATE
    COMPUTE WS-LABOUR-HOURS(WS-IDX) = WS-BASE-POP * 5

    MOVE 0000000000.00       TO WS-OUTPUT-VALUE(WS-IDX)
    MOVE 030.00              TO WS-SURPLUS-RATE(WS-IDX)
*>  Низкий стартовый капитал — чтобы PRIMITIVE→SLAVE→FEUDAL было заметным.
    MOVE 0000000500.00       TO WS-CAPITAL-STOCK(WS-IDX)
    MOVE 0000000500.00       TO WS-WAGE-FUND(WS-IDX)
    MOVE +00000000.00        TO WS-TRADE-BALANCE(WS-IDX)

*> -- Классовое напряжение: выше в суровых регионах --
    EVALUATE WS-TERRAIN(WS-IDX)
        WHEN "SWAMP     " MOVE 35 TO WS-CLASS-TENSION(WS-IDX)
        WHEN "DESERT    " MOVE 30 TO WS-CLASS-TENSION(WS-IDX)
        WHEN "MOUNTAINS " MOVE 25 TO WS-CLASS-TENSION(WS-IDX)
        WHEN OTHER        MOVE 20 TO WS-CLASS-TENSION(WS-IDX)
    END-EVALUATE

    MOVE 00500               TO WS-MILITARY-STRENGTH(WS-IDX)
    MOVE 00                  TO WS-AT-WAR-WITH(WS-IDX)
    MOVE 000                 TO WS-COLLAPSE-TIMER(WS-IDX)
    MOVE 000                 TO WS-WAR-YEAR(WS-IDX)
    MOVE "PEACE     "        TO WS-WAR-TYPE(WS-IDX)

    MOVE 00                  TO WS-NEIGHBOR-1(WS-IDX)
    MOVE 00                  TO WS-NEIGHBOR-2(WS-IDX)
    MOVE 00                  TO WS-NEIGHBOR-3(WS-IDX)

*> -- Phase 9: правитель и сознание (Phase 10: имя случайное из пула) --
    COMPUTE WS-NAME-IDX = FUNCTION INTEGER(FUNCTION RANDOM * 20) + 1
    MOVE WS-NAME-ENTRY(WS-NAME-IDX) TO WS-RULER-NAME(WS-IDX)
    COMPUTE WS-RAND-INT = FUNCTION INTEGER(FUNCTION RANDOM * 31) + 25
    MOVE WS-RAND-INT TO WS-RULER-AGE(WS-IDX)
    COMPUTE WS-TRAIT-IDX = FUNCTION INTEGER(FUNCTION RANDOM * 5) + 1
    MOVE WS-TRAIT-ENTRY(WS-TRAIT-IDX) TO WS-RULER-TRAIT(WS-IDX)
    COMPUTE WS-RAND-INT = FUNCTION INTEGER(FUNCTION RANDOM * 15) + 1
    MOVE WS-RAND-INT TO WS-RULER-REIGN(WS-IDX)
*>  Phase 22 — стартовое сознание варьируется 5..15. Чтобы регионы
*>  не были синхронизированы с самого начала, у каждого свой «уровень».
    COMPUTE WS-RAND-INT = FUNCTION INTEGER(FUNCTION RANDOM * 11) + 5
    MOVE WS-RAND-INT         TO WS-CONSCIOUSNESS(WS-IDX)
*>  Стартовая культура: первобытно-родовое — религия и мелкие стычки.
*>  Энгельс «Происхождение семьи»: ритуал и кровный строй есть на старте.
*>  Меркантильная культура накапливается через торговлю, не дана сразу.
    MOVE 002                 TO WS-CULT-MIL(WS-IDX)
    MOVE 000                 TO WS-CULT-MERC(WS-IDX)
    MOVE 008                 TO WS-CULT-REL(WS-IDX)
*>  Phase 21 — стартуем «новой» эпохой
    MOVE 0000                TO WS-MODE-YEARS(WS-IDX)
*>  Phase 24 — Этап 1: имя политии = имя региона на старте.
*>  В будущем (Этап 2+) при спавне новой политии в существующем регионе
*>  WS-POLITY-NAME будет отличаться от WS-NAME.
    MOVE WS-NAME(WS-IDX)     TO WS-POLITY-NAME(WS-IDX)
*>  Phase 24 / Этап 2B: на старте polity[i] живёт в region[i] (1:1).
    MOVE WS-IDX              TO WS-REGION-ID(WS-IDX)
*>  Phase 25 — стартовая безработица отсутствует.
    MOVE 0                  TO WS-UNEMPLOYMENT-PCT(WS-IDX).

INIT-EXTINCT-SLOT.
*>  Phase 24 / Этап 2B — резервный слот политии (11..30).
*>  Изначально EXTINCT, не размещён в регионе. simulate.cob может
*>  оживить такой слот при распаде большой политии (SPAWN-HEIR).
    MOVE SPACES              TO WS-POLITY-NAME(WS-IDX)
    MOVE 0                   TO WS-REGION-ID(WS-IDX)
    MOVE 0                   TO WS-POPULATION(WS-IDX)
    MOVE 0                   TO WS-PEASANTS-PCT(WS-IDX)
    MOVE 0                   TO WS-ARTISANS-PCT(WS-IDX)
    MOVE 0                   TO WS-MERCHANTS-PCT(WS-IDX)
    MOVE 0                   TO WS-NOBILITY-PCT(WS-IDX)
    MOVE 0                   TO WS-CLERGY-PCT(WS-IDX)
    MOVE "EXTINCT        "   TO WS-PROD-MODE(WS-IDX)
    MOVE 0                   TO WS-LABOUR-HOURS(WS-IDX)
    MOVE 0                   TO WS-SURPLUS-RATE(WS-IDX)
    MOVE 0                   TO WS-CAPITAL-STOCK(WS-IDX)
    MOVE 0                   TO WS-CLASS-TENSION(WS-IDX)
    MOVE 0                   TO WS-MILITARY-STRENGTH(WS-IDX)
    MOVE 0                   TO WS-AT-WAR-WITH(WS-IDX)
    MOVE 0                   TO WS-COLLAPSE-TIMER(WS-IDX)
    MOVE 0                   TO WS-WAR-YEAR(WS-IDX)
    MOVE "PEACE     "        TO WS-WAR-TYPE(WS-IDX)
    MOVE SPACES              TO WS-RULER-NAME(WS-IDX)
    MOVE 0                   TO WS-RULER-AGE(WS-IDX)
    MOVE SPACES              TO WS-RULER-TRAIT(WS-IDX)
    MOVE 0                   TO WS-RULER-REIGN(WS-IDX)
    MOVE 0                   TO WS-CONSCIOUSNESS(WS-IDX)
    MOVE 0                   TO WS-CULT-MIL(WS-IDX)
    MOVE 0                   TO WS-CULT-MERC(WS-IDX)
    MOVE 0                   TO WS-CULT-REL(WS-IDX)
    MOVE 0                   TO WS-MODE-YEARS(WS-IDX)
    MOVE 0                   TO WS-UNEMPLOYMENT-PCT(WS-IDX).

ASSIGN-NEIGHBORS.
*> Фиксированная топология: кольцо + диагональные связи.
*> Каждый регион имеет ровно 3 соседа. Граф симметричен.
*>
*>  1-Ironmarch   — 2, 4, 7
*>  2-Ashvale     — 1, 3, 5
*>  3-Stonehold   — 2, 6,10
*>  4-Frostfen    — 1, 7, 8
*>  5-Goldgate    — 2, 6, 8
*>  6-Duskveil    — 3, 5, 9
*>  7-Thornwall   — 1, 4, 9
*>  8-Saltmere    — 4, 5,10
*>  9-Embervast   — 6, 7,10
*> 10-Cinderkeep  — 3, 8, 9

    MOVE 02 TO WS-NEIGHBOR-1(1)
    MOVE 04 TO WS-NEIGHBOR-2(1)
    MOVE 07 TO WS-NEIGHBOR-3(1)

    MOVE 01 TO WS-NEIGHBOR-1(2)
    MOVE 03 TO WS-NEIGHBOR-2(2)
    MOVE 05 TO WS-NEIGHBOR-3(2)

    MOVE 02 TO WS-NEIGHBOR-1(3)
    MOVE 06 TO WS-NEIGHBOR-2(3)
    MOVE 10 TO WS-NEIGHBOR-3(3)

    MOVE 01 TO WS-NEIGHBOR-1(4)
    MOVE 07 TO WS-NEIGHBOR-2(4)
    MOVE 08 TO WS-NEIGHBOR-3(4)

    MOVE 02 TO WS-NEIGHBOR-1(5)
    MOVE 06 TO WS-NEIGHBOR-2(5)
    MOVE 08 TO WS-NEIGHBOR-3(5)

    MOVE 03 TO WS-NEIGHBOR-1(6)
    MOVE 05 TO WS-NEIGHBOR-2(6)
    MOVE 09 TO WS-NEIGHBOR-3(6)

    MOVE 01 TO WS-NEIGHBOR-1(7)
    MOVE 04 TO WS-NEIGHBOR-2(7)
    MOVE 09 TO WS-NEIGHBOR-3(7)

    MOVE 04 TO WS-NEIGHBOR-1(8)
    MOVE 05 TO WS-NEIGHBOR-2(8)
    MOVE 10 TO WS-NEIGHBOR-3(8)

    MOVE 06 TO WS-NEIGHBOR-1(9)
    MOVE 07 TO WS-NEIGHBOR-2(9)
    MOVE 10 TO WS-NEIGHBOR-3(9)

    MOVE 03 TO WS-NEIGHBOR-1(10)
    MOVE 08 TO WS-NEIGHBOR-2(10)
    MOVE 09 TO WS-NEIGHBOR-3(10).

WRITE-REGION-ROW.
*>  Геофон. Layout regions.dat (1-indexed COBOL смещения):
*>    NAME(20) | TERRAIN(10) | CLIMATE(10) | PRIMARY-GOOD(15) |
*>    NEIGHBOR-1(2) | NEIGHBOR-2(2) | NEIGHBOR-3(2)  = 61 байт
    MOVE SPACES TO WS-OUT-LINE
    STRING
        WS-NAME(WS-IDX)             DELIMITED SIZE
        WS-TERRAIN(WS-IDX)          DELIMITED SIZE
        WS-CLIMATE(WS-IDX)          DELIMITED SIZE
        WS-PRIMARY-GOOD(WS-IDX)     DELIMITED SIZE
        WS-NEIGHBOR-1(WS-IDX)       DELIMITED SIZE
        WS-NEIGHBOR-2(WS-IDX)       DELIMITED SIZE
        WS-NEIGHBOR-3(WS-IDX)       DELIMITED SIZE
        INTO WS-OUT-LINE
    END-STRING
    WRITE REGION-RECORD FROM WS-OUT-LINE.

WRITE-POLITY-ROW.
*>  Политический слой. Layout polities.dat (1-indexed COBOL):
*>    POLITY-NAME(20) | REGION-ID(2) | POPULATION(8) | PEASANTS(3) | ARTISANS(3) |
*>    MERCHANTS(3) | NOBILITY(3) | CLERGY(3) | PROD-MODE(15) |
*>    LABOUR-HOURS(10) | SURPLUS-RATE(5) | CAPITAL-STOCK(12) |
*>    CLASS-TENSION(3) | MILITARY-STR(5) | AT-WAR-WITH(2) |
*>    COLLAPSE-TIMER(3) | WAR-YEAR(3) | WAR-TYPE(10) | RULER-NAME(20) |
*>    RULER-AGE(2) | RULER-TRAIT(10) | RULER-REIGN(3) | CONSCIOUSNESS(3) |
*>    CULT-MIL(3) | CULT-MERC(3) | CULT-REL(3) | MODE-YEARS(4)  = 160 байт
*>    Phase 24/Этап 2B: добавлен REGION-ID после POLITY-NAME (+2 байта).
    MOVE SPACES TO WS-OUT-LINE
    STRING
        WS-POLITY-NAME(WS-IDX)      DELIMITED SIZE
        WS-REGION-ID(WS-IDX)        DELIMITED SIZE
        WS-POPULATION(WS-IDX)       DELIMITED SIZE
        WS-PEASANTS-PCT(WS-IDX)     DELIMITED SIZE
        WS-ARTISANS-PCT(WS-IDX)     DELIMITED SIZE
        WS-MERCHANTS-PCT(WS-IDX)    DELIMITED SIZE
        WS-NOBILITY-PCT(WS-IDX)     DELIMITED SIZE
        WS-CLERGY-PCT(WS-IDX)       DELIMITED SIZE
        WS-PROD-MODE(WS-IDX)        DELIMITED SIZE
        WS-LABOUR-HOURS(WS-IDX)     DELIMITED SIZE
        WS-SURPLUS-RATE(WS-IDX)     DELIMITED SIZE
        WS-CAPITAL-STOCK(WS-IDX)    DELIMITED SIZE
        WS-CLASS-TENSION(WS-IDX)    DELIMITED SIZE
        WS-MILITARY-STRENGTH(WS-IDX) DELIMITED SIZE
        WS-AT-WAR-WITH(WS-IDX)      DELIMITED SIZE
        WS-COLLAPSE-TIMER(WS-IDX)   DELIMITED SIZE
        WS-WAR-YEAR(WS-IDX)         DELIMITED SIZE
        WS-WAR-TYPE(WS-IDX)         DELIMITED SIZE
        WS-RULER-NAME(WS-IDX)       DELIMITED SIZE
        WS-RULER-AGE(WS-IDX)        DELIMITED SIZE
        WS-RULER-TRAIT(WS-IDX)      DELIMITED SIZE
        WS-RULER-REIGN(WS-IDX)      DELIMITED SIZE
        WS-CONSCIOUSNESS(WS-IDX)    DELIMITED SIZE
        WS-CULT-MIL(WS-IDX)         DELIMITED SIZE
        WS-CULT-MERC(WS-IDX)        DELIMITED SIZE
        WS-CULT-REL(WS-IDX)         DELIMITED SIZE
        WS-MODE-YEARS(WS-IDX)       DELIMITED SIZE
        WS-UNEMPLOYMENT-PCT(WS-IDX) DELIMITED SIZE
        INTO WS-OUT-LINE
    END-STRING

    WRITE POLITY-RECORD FROM WS-OUT-LINE.
