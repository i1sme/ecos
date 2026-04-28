
## [Phase 24 / Этап 2B — расширение слотов до 30 + spawn наследников] 2026-04-28

### Зачем

Этап 2A научил политии вымирать (EXTINCT навсегда), но без механизма «откуда берутся новые государства» карта мира неуклонно пустела. Этап 2B даёт ответ: при распаде крупной империи на её земле возникает наследник — новое государство с другим именем, новым правителем, частью унаследованных ресурсов. Это исторично: на месте Рима — варварские королевства; на месте Византии — османы; на месте Российской империи — СССР.

### Что сделано

**A. Расширение слотов: 10 → 30 политий.** `WS-POLITIES OCCURS 30 TIMES`. Стартовых 10 живых; 11..30 — EXTINCT-резервы для будущего spawn'а. Регионов по-прежнему 10 — это **геофон**, постоянный.

**B. Поле `WS-REGION-ID`** в политии (PIC 99): «на каком регионе живёт эта полития». Для активных = 1..10, для EXTINCT-резерва = 0. polities.dat layout: добавлено 2 байта после `POLITY-NAME` (теперь 164 байт/строка). Rust парсер обновлён (offsets сдвинулись на 2).

**C. Mapping `WS-REGION-OCCUPANT(10)`**: «кто сейчас живёт в регионе X». Заполняется параграфом `BUILD-OCCUPANT-MAP` сразу после `READ-WORLD` каждый ход — реконструируется из region_id'ов политий.

**D. Соседство через region_id.** Все neighbor-проверки переписаны на двухшаговый lookup:
```
1. WS-NEIGHBOR-X(WS-REGION-ID(WS-IDX)) → WS-NB-REGION-ID  (индекс соседнего региона)
2. EVAL-NB-OCCUPANT → WS-NBREG  (индекс политии в этом регионе или 0)
3. IF WS-NBREG > 0 AND NOT POLITY-DORMANT(WS-NBREG) THEN ...
```
Это даёт обратную совместимость на B.1 (когда polity_id == region_id) и работает корректно после spawn'а наследников в slots 11..30.

**E. SPAWN-HEIR + третья ветка коллапса.** В `COLLAPSE-ONE` теперь три пути:

| pop на момент коллапса | путь | что происходит |
|---|---|---|
| ≥ 70k (`LARGE-COLLAPSE-THRESHOLD`) | **FRAGMENT** | родитель → EXTINCT, наследник spawn'ится в свободном слоте, занимает тот же регион. Имя «Neo-<region>», новый правитель, 1/3 pop, 1/4 capital. |
| 20-69k | COLLAPSED → REBIRTH (как в 2A) | тёмные века, через 8 ходов восстанет |
| < 20k | EXTINCT (как в 2A) | окончательное вымирание |

Параграф `FIND-EXTINCT-SLOT` ищет первый slot 11..30 с EXTINCT и region_id=0. Если все 30 заняты — fallback: «Empire fragments. No successor — slots exhausted.»

**F. Подкрутка порогов:** EXTINCT 30k → 20k (только реально вымершие); FRAGMENT 70k (узкий диапазон у границы триггера). Это даёт **все три ветки активны** в стресс-тесте.

**G. Имена наследников.** Берутся из имени **территории** (`WS-NAME(WS-REGION-ID)`), а не имени родительской политии. Иначе серия распадов копит рекурсивный префикс «Neo-Neo-Neo-X».

**H. Глобальная замена `WS-NAME(WS-IDX)` → `WS-POLITY-NAME(WS-IDX)`** для всех CHRONICLE-RGON и war-message stringings. WS-NAME OCCURS 10 — для slot > 10 это out-of-bounds, что вызывало `libcob status=71`. WS-POLITY-NAME OCCURS 30 — корректно. Аналогично `WS-TERRAIN/CLIMATE/PRIMARY-GOOD(WS-IDX)` заменены на `(WS-REGION-ID(WS-IDX))` в полит-loop'ах.

**I. UI переписан через `occupant_of`.** Главная таблица: `regions.iter().enumerate().map(|(i, r)| world.occupant_of(i))` — для каждого региона показываем текущего хозяина. Если регион пуст (vacant) — серая «✗ vacant» строка. Detail panel: `occupant_of(selected)` вместо `polities[selected]`.

**J. WorldHistory индексируется per-region** через occupant. Callback теперь принимает `(idx, &R)` — позволяет искать `world.occupant_of(idx)`. При смене политии в регионе (FRAGMENT/EXTINCT/spawn) trends начинаются заново — это корректно, мы трекаем «текущую политию региона», не slot.

### Стресс-тест 1500 ходов

```
FRAGMENT:   21    ← новое: империи распадаются на наследников
EXTINCT:     6
COLLAPSE:   51
REBIRTH:    50    ← все три ветки коллапса работают
REVOLUTION:  9
MODE-SHIFT: 14
```

End-state на год 1500 (4 живых полит из 10 регионов):
- **Ironmarch** (slot 1) — FEUDAL 776k pop (стартовая, не распадалась за 1500 лет)
- **Goldgate** (slot 5) — IMPERIAL 59M pop (стартовая, выросла в супер-империю)
- **Neo-Embervast** (slot 4) — FEUDAL 97k pop (наследник, регион Embervast)
- **Neo-Cinderkeep** (slot 2) — COLLAPSED 10k pop (наследник, в тёмных веках)

Vacant regions: Ashvale, Stonehold, Frostfen, Duskveil, Thornwall, Saltmere — 6/10 опустели. Этап 2C (3 ячейки на регион + spawn в соседних свободных) ответит на этот.

Также видно эффект каскадных распадов: «Neo-Neo-» имена больше не накапливаются (после фикса) — каждый наследник называется заново «Neo-<имя территории>».

### Какие файлы затронуты

- `cobol/simulate.cob` — POLITY-COUNT=30, WS-REGION-ID в WS-POLITIES, WS-REGION-OCCUPANT таблица, BUILD-OCCUPANT-MAP, EVAL-NB-OCCUPANT helper, переписаны все neighbor-проверки на 2-шаговый lookup, FIND-EXTINCT-SLOT + SPAWN-HEIR параграфы, третья ветка в COLLAPSE-ONE; глобальные замены WS-NAME→WS-POLITY-NAME (chronicle/war), WS-TERRAIN/CLIMATE/PRIMARY-GOOD через WS-REGION-ID
- `cobol/world.cob` — WS-POLITIES OCCURS 30, WS-REGION-ID, INIT-EXTINCT-SLOT для slots 11..30
- `src/world.rs` — Polity.region_id, обновлены layout offsets, новый метод `World::occupant_of(region_idx)`
- `src/saves.rs` — миграция legacy world.dat теперь генерирует 30 строк polities.dat (10 живых из legacy + 20 EXTINCT-резервов) с region_id
- `src/ui.rs` — таблица регионов через `occupant_of`, vacant-row для пустых, detail panel через occupant
- `src/history.rs` — record_if_new_year принимает callback с (idx, &R)

### Регрессия

`scripts/baseline.sh check` зелёный (новый baseline снят после Этапа 2B). Поведение детерминированно при фиксированной последовательности RANDOM-вызовов. Unit-тест миграции legacy slot — зелёный.

### Что не делалось (Этап 2C+)

- 3 ячейки на регион (полная мозаика — несколько политий на одной территории)
- Spawn наследников в **соседних** регионах (сейчас только в том же)
- STATELESS как mode + spawn из беженцев в пустых ячейках
- Аннексия ячейки в WAR-VICTORY
- Балансировка демографических порогов так чтобы все три ветки коллапса срабатывали одинаково часто (сейчас FRAGMENT редкий)

### Замечания / возможные тюны

- 21 FRAGMENT за 1500 ходов = ~1 распад на 70 лет — редкое драматичное событие. Если хочется чаще — повысить LARGE-COLLAPSE-THRESHOLD до 60k (расширить FRAGMENT-полосу).
- К году 1500 6/10 регионов vacant. Это known: spawn только при распаде, нет «прихода» политий извне региона. Этап 2C решит.
- Если все 30 слотов заняты (теоретически) — FRAGMENT не может spawn'ить, fallback на pure EXTINCT. В стресс-тесте этого не наблюдалось — typically 4-10 политий живых одновременно, ≥20 слотов всегда свободны.

## [Phase 24 / Этап 2A — EXTINCT для малых политий] 2026-04-28

### Зачем

Этап 1 разделил Region/Polity, но все коллапсы по-прежнему шли в `COLLAPSED → REBIRTH через 8 ходов`. Государство «не могло пропасть» — карта мира навсегда фиксированная. Это было дальше от истории чем хотелось: в реальности страны вымирают, поглощаются соседями, исчезают навсегда (Урарту, Карфаген, Византия — все ушли).

Этап 2A добавляет третье состояние политии — **EXTINCT** (окончательно вымершая). Без расширения количества слотов, без spawn'а наследников. Минимальная конфигурация которая даёт визуальный эффект «карта мира редеет».

### Что сделано

**A. Структура состояний:**
- ALIVE — обычная (любой PROD-MODE кроме COLLAPSED/EXTINCT)
- COLLAPSED — тёмные века; через `REBIRTH-DURATION = 8` ходов восстанавливается как FEUDAL
- **EXTINCT** (новое) — окончательно вымершая; не возрождается, слот остаётся в массиве как «пустая территория»

**B. Хранение:** новое значение `WS-MODE-EXTINCT VALUE "EXTINCT        "` в существующем `WS-PROD-MODE`. Никаких новых байт в структуре. 88-level conditions:
```cobol
05 WS-PROD-MODE PIC X(15).
   88 POLITY-COLLAPSED VALUE "COLLAPSED      ".
   88 POLITY-EXTINCT   VALUE "EXTINCT        ".
   88 POLITY-DORMANT   VALUES "COLLAPSED      ", "EXTINCT        ".
```
Это позволяет писать `IF NOT POLITY-DORMANT(WS-IDX)` — лаконичный фильтр для активной политии.

**C. Триггер EXTINCT vs COLLAPSED** — в `COLLAPSE-ONE` после миграции беженцев:
```
IF pop < EXTINCT-POP-THRESHOLD (= 30000)
    → EXTINCT (демографический коллапс необратим)
ELSE
    → COLLAPSED (экономический коллапс — есть надежда восстать)
```
30k взято после стресс-теста: 80k был слишком высокий, 100% коллапсов сразу шли в EXTINCT и REBIRTH-ветка была мёртвой. 30k оставляет «коридор» для тёмных веков.

**D. Что делает EXTINCT:**
- mode = EXTINCT, pop = 0, labour = 0, capital = 0, collapse_timer = 0
- Беженцы 30% pop успели уйти соседям (общая часть COLLAPSE-ONE)
- Остальные 70% растворяются в общинах соседей или вымирают
- Хроника: `EXTINCT  Polity ceases to exist. Region falls silent.`

**E. Фильтры в *-ALL параграфах:** все 12 циклов `IF WS-PROD-MODE(WS-IDX) NOT = WS-MODE-COLLAPSED` заменены на `IF NOT POLITY-DORMANT(WS-IDX)` (исключают и COLLAPSED, и EXTINCT). Затронуты: PRODUCE-ALL, MARKET-AGGREGATE, TRADE-ALL, WAR-CHECK-ALL, SOCIAL-ALL, CLASS-DRIFT-ALL, ACCUMULATE-ALL, TECH-RESEARCH-ALL, CULTURE-DRIFT-ALL, INNOVATION-CHECK-ALL, AGE-RULERS, CALC-MILITARY, RELATIONS-DECAY, CLAMP-ALL-TENSIONS, TICK-MODE-YEARS, CONSCIOUSNESS-ALL.

**F. Neighbor-фильтры:** все 8 проверок `WS-PROD-MODE(WS-NBREG) NOT = WS-MODE-COLLAPSED` заменены на `NOT POLITY-DORMANT(WS-NBREG)`. EXTINCT-сосед не получает беженцев, не вызывает торговлю, не цель войны, не источник CONSCIOUSNESS-CONTAGION.

**G. DEMOGRAPHY-ALL ветка для COLLAPSED:** раньше там увеличивался `COLLAPSE-TIMER`. Теперь:
```
IF NOT POLITY-EXTINCT(WS-IDX)        -- EXTINCT — ничего, слот мёртв
    IF POLITY-COLLAPSED(WS-IDX)
        ADD 1 TO WS-COLLAPSE-TIMER
    ELSE
        -- обычная демография
```

**H. Rust UI** (`src/ui.rs`):
- `fn is_extinct(mode)` + `fn is_dormant(mode)` хелперы
- `mode_color`: EXTINCT → DarkGray (как COLLAPSED)
- Таблица регионов: extinct row показывается серым с пометкой `✗ EXTINCT`, поле населения и tension — `—`
- Detail panel: для EXTINCT региона укороченный вид «Region: X / ✗ EXTINCT / Polity has ceased to exist. Population scattered.»
- Dashboard: фильтр `is_dormant` (не `is_collapsed`) для «Most warlike/rebellious/oldest ruler» — мёртвые политии исключаются. Era distribution получил SOCIALIST и EXTINCT в порядок отображения.

### Стресс-тест 1500 ходов (с порогом 30k)

```
EXTINCT:    6        (за 1500 ходов 6 политий ушли навсегда)
COLLAPSE:   86
REBIRTH:    83       (тёмные века с восстановлением — главный путь)
REVOLUTION: 17
MODE-SHIFT: 12
WAR-START:  334
```

End-state на год 1500 (драматичная история циклов цивилизаций):
- Embervast — FEUDAL 25y (молодая, единственная живая после нескольких COLLAPSE→REBIRTH)
- Ashvale, Goldgate, Cinderkeep — COLLAPSED (в тёмных веках, восстанут через ~6 ходов)
- Ironmarch, Stonehold, Frostfen, Duskveil, Thornwall, Saltmere — **EXTINCT** (исчезли в годах 40-308)

Сравнение порогов:

| Порог | EXTINCT | COLLAPSE | REBIRTH |
|---|---|---|---|
| 80k (первая попытка) | 6 | **0** | **0** |
| 30k (финал) | 6 | 86 | 83 |

С 80k EXTINCT-ветка съедала все коллапсы; с 30k обе ветки живы и дополняют друг друга.

### Какие файлы затронуты

- `cobol/simulate.cob` — `WS-MODE-EXTINCT` константа, 88-level conditions, разветвление `COLLAPSE-ONE`, 12 *-ALL фильтров, 8 neighbor-фильтров, DEMOGRAPHY-ALL переписан с двумя ветками; константа `EXTINCT-POP-THRESHOLD = 30000`
- `src/ui.rs` — `is_extinct`, `is_dormant`, рендер EXTINCT-row в таблице, укороченный detail для EXTINCT, Dashboard фильтр + EXTINCT/SOCIALIST в era order
- `cobol/baseline_chronicle.dat` и др. — новый baseline (старый из Этапа 1 устарел т.к. поведение изменилось)

### Регрессия

Новый baseline зафиксирован после Этапа 2A. `scripts/baseline.sh check` зелёный (детерминированность сохраняется при фиксированной последовательности RANDOM-вызовов).

### Что не делалось (Этапы 2B/2C)

- Расширение слотов до 30 (3 ячейки на регион) — сейчас 1 полития на регион
- Spawn наследников при распаде большой политии — пустая ячейка остаётся пустой
- STATELESS как mode (беженцы не оседают как ядро новой политии)
- Аннексия ячейки в WAR-VICTORY (война пока работает как раньше)

После Этапа 2A карта может полностью опустеть к концу долгой истории — это known. Этап 2B (spawn) ответит на вопрос «откуда берутся новые государства».

### Замечания / возможные тюны

- К году 1500 уже 6 EXTINCT (60% мира). Если хочется чтобы мир жил дольше без новых политий — поднять `EXTINCT-POP-THRESHOLD` до 10-20k или ослабить агрессию войны/беженцев. Но это палка о двух концах: если порог слишком низкий, EXTINCT почти никогда не срабатывает.
- 0 COLLAPSE/REBIRTH было при 80k — это указывает что в текущем балансе войны+миграции pop падает быстрее capital. На Этапе 2B (когда добавим spawn) это можно будет компенсировать новыми политиями взамен EXTINCT.
- Все ранние EXTINCT (годы 30-308) случились в первые 1/5 истории. Возможно стоит ввести «грейс-период» для молодых политий (`mode_years < N` immune to EXTINCT). Это эстетический тюн, оставлен на будущее.

## [Phase 24 / Этап 1 — Region/Polity split (рефакторинг без новой логики)] 2026-04-28

### Зачем

Структура `WS-REGIONS OCCURS 10 TIMES` смешивала географию (terrain, climate, neighbors, name территории) с политикой (mode, классы, правитель, capital, культура, mode_years). Из-за этого государство «не может пропасть» — слот в массиве это и территория, и страна одновременно. Все попытки сделать коллапс реалистичным упирались в это допущение.

Этап 1 — фундаментальный архитектурный шаг **без новой логики**: структура расщеплена на Region (геофон, постоянный) + Polity (политический слой, динамичный). На этом этапе строго 1 полития на регион, индексы совпадают, имена синхронизированы. Поведение симуляции **байт-в-байт идентично** baseline до рефакторинга. Этапы 2-4 (3 ячейки/регион, EXTINCT, спавн наследников при распаде, STATELESS, аннексия в войне) — отдельные планы поверх готового фундамента.

### Что сделано

**A. Регрессионный baseline** (`scripts/baseline.sh`):
- `capture` — записывает эталон `cobol/baseline_*.dat` после 500 ходов на свежем мире
- `check` — прогоняет 500 ходов и `diff`-ит против эталона
- GnuCOBOL `FUNCTION RANDOM(seed)` детерминирован при фиксированной последовательности вызовов → побайтовый match гарантирован при идентичной логике

**B. Split структур данных в COBOL** (атомарно, в обоих `.cob` файлах):
- `WS-REGIONS OCCURS 10` — теперь только геофон: NAME, TERRAIN, CLIMATE, PRIMARY-GOOD, NEIGHBOR-1/2/3
- `WS-POLITIES OCCURS 10` — политический слой: POLITY-NAME (синхронизирован с NAME на Этапе 1), POPULATION, классы, PROD-MODE, ruler, consciousness, культура, mode_years и runtime-only поля
- Резервные имена `WS-PIDX`/`WS-RIDX` объявлены рядом с `WS-IDX` — задел на Этап 2, когда индексы политии и региона разойдутся

**C. Расщепление файлов**:
- `world.dat` (203 байта/строка) → `regions.dat` (61 байт/строка, статика) + `polities.dat` (162 байта/строка, динамика)
- `world.cob` пишет оба файла при генерации мира
- `simulate.cob` читает оба, переписывает только `polities.dat` каждый ход (regions неизменны → один лишний disk-IO/ход устранён)
- В `READ-WORLD`: `READ REGIONS-FILE` и `READ POLITIES-FILE` параллельно одним циклом VARYING WS-IDX
- Удалён `WORLD-REC-LEN`, заменён двумя decl `WS-REGION-REC PIC X(80)` и `WS-POLITY-REC PIC X(180)`

**D. Rust-структуры** (`src/world.rs`):
- `pub struct Region { name, terrain, climate, primary_good, neighbors }`
- `pub struct Polity { name, population, классы, prod_mode, labour_hours, surplus_rate, capital_stock, class_tension, military_strength, at_war_with, war_year, war_type, ruler_*, consciousness, culture_*, mode_years }`
- `pub struct World { regions, polities }` с методом `polity_of(idx)` (зарезервировано для Этапа 2)
- `parse_regions()` и `parse_polities()` — отдельные функции по новым layout'ам
- `parse_world()` — единая точка входа, читает оба файла

**E. UI адаптация** (`src/ui.rs`, ~10 мест):
- Главный loop: `let world = parse_world(); let regions = &world.regions; let polities = &world.polities;`
- Таблица регионов: `regions.iter().zip(polities.iter())` — каждая строка показывает имя/terrain из Region, mode/pop/tension из Polity
- Detail panel: иерархия «Region: Ironmarch  PLAINS TEMPERATE / Polity: Ironmarch» с разделителем — на Этапе 1 имена одинаковы, на Этапе 2+ разойдутся когда полития сменится
- `render_dashboard(regions, polities, year)` — суммирует по `polities`, имена территорий тянет из `regions` через индекс (lookup для «Most warlike: <region_name>»)
- `WorldHistory` — индексирует per-polity (sparkline'ы tension/pop/capital политии)

**F. Saves migration** (`src/saves.rs`):
- `SAVE_FILES` обновлён на 7 файлов: `regions.dat`, `polities.dat`, `year.dat`, `chronicle.dat`, `market.dat`, `relations.dat`, `tech.dat`
- Новая функция `migrate_legacy_slot(slot_dir)` — расщепляет legacy `world.dat` по Phase 21 offsets'ам в `regions.dat` + `polities.dat`. Идемпотентна (skip если regions.dat уже есть)
- Оригинал legacy переименовывается в `world.dat.legacy` (для возможности отката, не удаляется)
- `load_from_slot` вызывает миграцию первым делом, перед копированием live-файлов
- `list_slots` распознаёт slot как «существующий» если есть `regions.dat` ИЛИ legacy `world.dat`
- Unit-тест `legacy_migration_splits_world_dat` — генерирует sample 203-байтную строку Phase 21, прогоняет миграцию, проверяет что regions/polities содержат правильные имена/поля и legacy переименован

### Файлы под изменение

- `cobol/world.cob` — split structure, два FD (regions/polities), `WRITE-REGION-ROW` + `WRITE-POLITY-ROW`, инициализация `WS-POLITY-NAME = WS-NAME`
- `cobol/simulate.cob` — split structure, два SELECT/FD, `READ-WORLD` параллельно читает оба файла, `WRITE-WORLD` пишет только polities.dat, `PARSE-REGION-RECORD` + `PARSE-POLITY-RECORD`, REBIRTH восстанавливает имя политии = имя региона
- `src/world.rs` — переписан с двумя структурами Region и Polity, `World` обёртка, новые `parse_regions/parse_polities/parse_world`
- `src/ui.rs` — ~10 callsites: разделение r.X (геофон) и polities[i].X (политика), иерархия в detail, render_dashboard принимает оба слайса
- `src/saves.rs` — `migrate_legacy_slot`, новые `SAVE_FILES`, обновлён `list_slots`/`load_from_slot`/`new_game`
- `scripts/baseline.sh` — новый: capture/check регрессия 500 ходов

### Регрессия (Шаг 7)

```
==> Checking against baseline (500 turns)...
  OK   cobol/chronicle.dat matches baseline
  OK   cobol/tech.dat matches baseline
  OK   cobol/relations.dat matches baseline
  OK   cobol/market.dat matches baseline
All matched.
```

Поведение симуляции **байт-в-байт идентично** до и после рефакторинга. Это подтверждает, что Этап 1 — чистая структурная работа без сдвигов поведения.

Sanity для новых файлов:
- `regions.dat`: 10 строк × 61 байт (статика, не меняется на симуляции)
- `polities.dat`: 10 строк × 162 байта (переписывается каждый ход)

Unit-тест миграции:
```
test saves::tests::legacy_migration_splits_world_dat ... ok
```

### Что НЕ делается (резерв на Этапы 2-4)

- 3 ячейки на регион (`cell_count = 1` фиксированно)
- EXTINCT флаг и спавн новых политий
- Распад больших политий на наследников
- STATELESS как отдельный mode
- Аннексия ячейки в WAR-VICTORY
- Переименование chronicle filter «region» → «polity» (на Этапе 1 имена совпадают — нет смысла путать пользователя)
- Хранилище истории «мёртвых» политий после extinct
- WAR-CHECK через географию (сейчас 1:1, не нужно)

### Замечания

- `WS-POLITY-NAME` объявлено и инициализируется = `WS-NAME`, но **в логике simulate.cob не используется** на Этапе 1 (все хроники продолжают писать `WS-NAME(WS-IDX)`, что одно и то же). Миграция references на `WS-POLITY-NAME` где это политическое имя — задача Этапа 2
- `polity_of()` метод объявлен но `#[allow(dead_code)]` — UI работает с двумя векторами параллельно; метод оставлен для миграции на индексирование через polity_id когда индексы разойдутся
- collapse_timer не вынесен в Polity-структуру Rust (нужен только COBOL для отсчёта REBIRTH-DURATION, UI не отображает); комментарий в layout-таблице сохранён

## [Phase 22+23 — Естественный темп через сознание; revolution двигает эпоху] 2026-04-27

### Постановка проблемы

Phase 21 решал «эпохи проскакивают за 5 ходов» через жёсткое EPOCH-MIN-* + понижение базовых ставок. Но возникли два новых симптома:
- **Революции происходят, но «ничего не меняется»** — в SLAVE/MERCANTILE/PROTO-IND/INDUSTRIAL revolution просто менял правителя и пересчитывал классы, mode оставался прежним. Только FEUDAL→MERC и IMPERIAL→SOC реагировали.
- **Когда меняется — у всех почти одновременно** — `CONSCIOUSNESS-CONTAGION = +3` от соседа с tension≥90 + рост сознания +2-6/ход в MERCANTILE+ + отсутствие decay → положительная обратная связь синхронизировала все 10 регионов на ~30 ходов.

EPOCH-MIN тоже ощущался как принуждающий механизм («эпоха обязана выдержать 150 ходов»), а не естественный.

### Корневая диагностика по Марксу/Ленину

Сознание у нас тикало само собой как часы — без классовой борьбы. Но классовое сознание формируется десятилетиями через **опыт борьбы**, а без active носителя (рабочего класса) спит. Также революция в марксистской теории — это **способ перехода в новую формацию**, а не следствие достижения формацией каких-то порогов.

### Решение

**A. Откат EPOCH-MIN из Phase 21.** Все 6 веток `ACCUMULATE-ALL` больше не проверяют `WS-MODE-YEARS >= EPOCH-MIN-X`. Константы убраны. Поле `WS-MODE-YEARS` оставлено — оно полезно как информация в UI («эпоха идёт N лет») и как референс для будущих механик.

**B. Phase 22 — медленное и структурное сознание** (`CONSCIOUSNESS-ALL` переписан):

| Изменение | Было | Стало |
|---|---|---|
| `CONSCIOUSNESS-MERCANTILE` | +1/turn | +0 (mode сам не растит) |
| `CONSCIOUSNESS-PROTO-IND` | +2/turn | +1/turn |
| Новые: INDUSTRIAL/IMPERIAL | — | +1/turn каждый |
| Бонус KNOW L2 (Printing) | +2/turn | +1 раз в 2 хода |
| Бонус KNOW L3 (Empiric/Scholast/FolkWis) | +2/+3/+1 | +1/+1/+0 |
| Бонус KNOW L4 (SciMethod) | +1/turn | +1 раз в 2 хода |
| `CONSCIOUSNESS-SPREAD` (контагия) | +3/соседа | +1/соседа |
| Условие контагии | — | своё `cons ≥ 20` |
| Условие любого роста | `artisans ≥ 30` | `artisans + merchants ≥ 30` |
| Decay | — | каждые 5 ходов −1 без подкрепления |
| `CONSCIOUSNESS-AFTER-REV` | −5 | −25 (после своей революции) |
| `CONSCIOUSNESS-AFTER-CLASS` | −2 | −5 (после class-war) |
| Innovation Printing-Press | +20 (+5 соседям) | +8 (+2 соседям) |

Структурный множитель: **без рабочего класса (artisans+merchants ≥ 30%) сознание не растёт вообще**. Крестьянские империи остаются на нуле. `world.cob` теперь рандомизирует стартовое сознание 5..15 (вместо фиксированного 10) — регионы изначально не синхронизированы.

**C. Phase 23 — революция = прорывной путь mode-shift.** В `REVOLUTION` теперь `EVALUATE WS-PROD-MODE`:

| До революции | Условие | После | Историческая аналогия |
|---|---|---|---|
| SLAVE | artisans+merchants ≥ 20 | FEUDAL | падение Рима |
| FEUDAL | merchants > artisans | MERCANTILE | (было) |
| MERCANTILE | artisans ≥ 25 | PROTO-INDUSTRL | 1789, 1848 |
| PROTO-IND | artisans ≥ 30 | INDUSTRIAL | рабочее движение XIX в. |
| IMPERIAL | — | SOCIALIST | (было) |

`INDUSTRIAL → IMPERIAL` намеренно не делается через революцию (империализм по Ленину — органический исход концентрации финансового капитала, а не классовый прорыв).

### Стресс-тест 2500 ходов

```
Mode-shifts: 40 total (vs 444 до Phase 21, vs 28 в Phase 21)
  16× Feudal → Mercantile
  11× Mercantile → Proto-Industrial
   4× Proto-Ind → Industrial
   3× Slave → Feudal           ← Phase 23 заработала
   3× Industrial → Imperial
   3× Imperial → Socialist

Revolutions: 98 (vs 731 до Phase 22)
Class-wars:  1707 (буфер репрессий в FEUDAL — реалистично)
Years with 3+ simultaneous revolutions: 0  (vs многие до Phase 22)
```

**Все 7 эпох достигнуты** через комбинацию органического (ACCUMULATE) и революционного пути.

End-state на год 2500:
- Goldgate — PROTO-INDUSTRL 20y, cons=84 (близок к следующей революции)
- Ashvale — MERCANTILE 33y, cons=3 (свежий перенос)
- Ironmarch / Stonehold / Thornwall — FEUDAL 40-140y, cons=0 (стагнация в феодальных репрессиях)
- Frostfen / Saltmere — FEUDAL 15-20y, cons=6-7 (молодые)

Регионы **асинхронны** — каждый идёт своим путём, революции распределены по 25 столетиям равномерно (1-10 на век).

### Какие файлы затронуты

- `cobol/simulate.cob` — 6 веток ACCUMULATE-ALL без EPOCH-MIN, удалены константы EPOCH-MIN-*, переписан CONSCIOUSNESS-ALL (структурный gating + decay), CONSCIOUSNESS-CONTAGION с условием своей основы, REVOLUTION содержит полный EVALUATE по PROD-MODE на 5 веток, понижены innovation Printing-Press и PRINTING-NB-SPREAD, изменены CONSCIOUSNESS-* константы
- `cobol/world.cob` — стартовое сознание рандомизировано 5..15

### Результат компиляции

- COBOL: OK
- Rust: OK без warnings
- 2500-turn smoke OK, integrity 10/10 (классы=100, length=203)

### Что НЕ меняли

- WS-MODE-YEARS поле и TICK-MODE-YEARS — оставлены как «информация для пользователя» в detail panel. Жёсткое gating убрано, но счётчик полезен.
- Базовые ставки `MODE-SHIFT-BASE 60`, `CAP 200` (Phase 21) — оставлены пониженными. Сейчас органический темп задают culture multiplier + capital scale, а революция = альтернативный путь снизу.
- ACCUMULATE-ALL не трогался кроме удаления EPOCH-MIN.

## [Phase 21 — Темп эпох: WS-MODE-YEARS + минимальная выдержка] 2026-04-27

### Проблема

Пользователь: «переход между фазами развития происходит за несколько ходов».

Анализ показал две причины:
1. **Слишком высокие базовые ставки.** FEUDAL→MERCANTILE base 300‰ (30%/ход), cap 700‰ (70%/ход!). MERC→PROTO 300‰. Даже с культурным множителем 0.33-0.5 это давало 100-150‰ — переход за 7-10 ходов.
2. **Нет минимальной длительности эпохи.** Как только `capital ≥ threshold` и `class >= min`, переход мог произойти на следующий же ход. Эпоха не «зрела» — она просто отмечала пройденный порог.

### Решение

**Новое поле `WS-MODE-YEARS PIC 9(4)`** в структуре `WS-REGION` — счётчик ходов в текущей эпохе. world.dat 199→203 байт (поле в 1-indexed COBOL смещении 200..203).

Жизненный цикл:
- `world.cob`: инициализация = 0 при создании мира.
- `simulate.cob` → новый параграф `TICK-MODE-YEARS` запускается каждый ход в начале (после LOAD-WORLD): `WS-MODE-YEARS += 1` для всех живых регионов; COLLAPSED не тикает.
- Сброс на 0: при каждом mode-shift в `ACCUMULATE-ALL`, при революции (FEUDAL→MERCANTILE и IMPERIAL→SOCIALIST в `REVOLUTION`), при коллапсе в `COLLAPSE-ONE`, при возрождении в `ACCUMULATE-ALL` (REBIRTH ветка).
- Backwards-compat при загрузке старых world.dat (длина < 203): поле = 0.

**Минимальная выдержка эпохи** — каждая ветка `ACCUMULATE-ALL` теперь начинается с проверки:
```cobol
IF WS-MODE-YEARS(WS-IDX) >= EPOCH-MIN-X
   AND <старые условия capital + классы>
    ...
```
Константы: `EPOCH-MIN-PRIMITIVE 30`, `EPOCH-MIN-SLAVE 80`, `EPOCH-MIN-FEUDAL 150`, `EPOCH-MIN-MERCANTILE 100`, `EPOCH-MIN-PROTO-IND 80`, `EPOCH-MIN-INDUSTRIAL 50`. Поздние эпохи короче — отражает Ленинскую идею «империализм как высшая, нестабильная стадия».

**Снижение базовых ставок** в 3-5 раз:
- `MODE-SHIFT-BASE-PERMIL`: 300 → 60
- `MODE-SHIFT-CAP-PERMIL`: 700 → 200
- `SLAVE-BASE-PERMIL`: 30 → 10
- `FEUDAL-BASE-PERMIL`: 50 → 15
- `INDUSTRIAL-BASE-PERMIL`: 250 → 50
- `IMPERIAL-BASE-PERMIL`: 200 → 40
- Добавлены `MERCANTILE-BASE-PERMIL 60` и `PROTO-IND-BASE-PERMIL 60` (зарезервированы; пока FEUDAL→MERC и MERC→PROTO используют общий MODE-SHIFT-BASE-PERMIL).

**UI**: в detail panel рядом с `Mode:` выводится `(NNNy)` — возраст эпохи. Серым цветом, без выделения. Пользователь видит «эпоха зреет» вживую: счётчик ходит до сотен лет прежде чем регион начинает примеряться к следующему модусу.

### Результат стресс-теста (1500 ходов)

| Метрика | До Phase 21 (2500 turns) | После Phase 21 (1500 turns) |
|---|---|---|
| Mode-shift events | 444 | **28** |
| Avg per region | 44.4 / 10 = 4.4 | 2.8 / 10 = **0.28** |
| Avg epoch duration | ~50 лет | **179 лет** (медиана 103, max 655) |
| Первый mode-shift | год 1-13 (SLAVE→FEUDAL) | **год 213** (FEUDAL→MERCANTILE) |

**End-state на год 1500:**
- Ironmarch — SOCIALIST 984y (лидер, прошёл всю лестницу)
- Goldgate — PROTO-INDUSTRL 694y (стабильная мануфактура)
- Stonehold/Cinderkeep/Thornwall — FEUDAL по 100-135y
- Ashvale/Saltmere — FEUDAL 65-99y (молодые феодальные)
- Frostfen/Duskveil/Embervast — FEUDAL 11-34y (только что переродились)

Регионы ощутимо различаются по темпу — каждый идёт своим путём, как пользователь и хотел.

### Какие файлы затронуты

- `cobol/simulate.cob` — `WS-MODE-YEARS` в структуре, `WS-WORLD-REC` 200→204, `WS-OUT-LINE` 200→204, `WORLD-REC-LEN` 199→203, `READ-WORLD` парсинг, `WRITE-WORLD` запись, новый `TICK-MODE-YEARS` параграф, обновлены 6 веток `ACCUMULATE-ALL` + `REVOLUTION` + `COLLAPSE-ONE` + `REBIRTH` (сбросы), новые константы EPOCH-MIN-*, понижены базовые ставки
- `cobol/world.cob` — `WS-MODE-YEARS` в структуре, `WS-OUT-LINE` 200→204, инициализация = 0, запись в STRING
- `src/world.rs` — поле `mode_years: u16`, парсинг с offset 199 / 4 байта, обновлена таблица смещений в комментарии
- `src/ui.rs` — рендер `(NNNy)` рядом с Mode в detail panel

### Результат компиляции

- COBOL: OK
- Rust: OK без warnings

### Замечания на будущее

- В стресс-тесте за 1500 ходов 0 переходов SLAVE→FEUDAL: стартовые SLAVE-регионы либо коллапсировали (REBIRTH ставит FEUDAL), либо революции FEUDAL→MERC проскакивали SLAVE-этап через class-tension. EPOCH-MIN-SLAVE = 80 ходов — может быть слишком долгим относительно стартовых условий (capital=500). Если хочется чтобы SLAVE→FEUDAL действительно фиксировался — снизить EPOCH-MIN-SLAVE до 40 или повысить стартовый capital. Пока оставляем — динамика «коллапсов античности» исторически правдоподобна.
- Старые сейвы (199-байт world.dat из Phase 19/20) загрузятся, поле прочитается как 0 — после первого хода `TICK-MODE-YEARS` начнёт считать. Это означает: первая эпоха после загрузки старого сейва закончится через `EPOCH-MIN-X` ходов от момента загрузки, не от исторической точки. Допустимый компромисс.

## [Phase 20 — Save/load механика, фикс tech-DONE отображения, .gitignore] 2026-04-27

### Что сделано

**Save/load** (новый модуль `src/saves.rs`):
- 5 фиксированных слотов в `saves/slot1..slot5/`. Каждый слот = снимок всех `cobol/*.dat` (world, year, chronicle, market, relations, tech).
- `list_slots()` возвращает `SlotInfo { idx, year }` — в меню видно какой год сохранён в каждом слоте.
- `save_to_slot(idx)` копирует live-файлы в slot. Если каких-то нет — стирает их в slot, чтобы snapshot был консистентным.
- `load_from_slot(idx)` копирует обратно. Файлы которых нет в slot — стираются из live (чтобы остатки прошлой игры не «протекли»).
- `new_game()` стирает все live-файлы → следующий `world.cob` создаст свежий мир.
- `current_year()` читает `cobol/year.dat` — Rust подхватывает год при загрузке.

**Стартовое меню** (`run_start_menu` в `ui.rs`):
- Показывается перед основным циклом. Опции: New game, Load slot 1..5 (с указанием года), Quit.
- Навигация ↑↓+Enter или прямые клавиши N / 1-5 / Q.
- Выбор Load с пустым slot'ом игнорируется.

**Save/Load в игре**:
- `[S]` открывает overlay-диалог «Save to slot». Выбор 1-5 → сохранение, Esc/Q закрыть.
- `[L]` открывает «Load slot». Выбор слота с данными → загрузка с обнулением `last_sim` и `WorldHistory` (sparkline'ы стартуют заново — корректно для нового мира).
- Краткий статус («✓ saved to slot 3», «✓ loaded slot 1 (year 0247)») показывается в header'е жёлтым.
- Диалог модальный: пока открыт, остальные клавиши не реагируют.

**Год при загрузке**:
- В header UI всегда видно текущий год (`Year 0247`). До Phase 20 при перезапуске `cargo run` мир продолжался с диска, но Rust-год был 0 — диссонанс. Теперь year persistуется.

**Фикс tech-tree DONE**:
- `src/ui.rs:tech_line` показывал `DONE` при `lvl >= 3` — но после Phase 18 max level = 4. На L3 рендерилось «закончено», создавая ложное впечатление «уже всё развито» с самого старта (если регион уже был на L3). Исправлено: `DONE` только при `lvl >= 4`.
- Это объясняет жалобу пользователя «развитие не происходит постепенно с малого» — на самом деле progression идёт корректно (свежий мир: turn 1 → progress=1, turn 25 → progress=25, level=0 у всех; turn 100 → level 1-3 mix), но UI на L3 рисовал «DONE» и создавал ощущение готовности.

**dead_code warning**:
- `Region.labour_hours` парсится из world.dat но в UI не отображается. Добавил `#[allow(dead_code)]` с комментарием — поле остаётся для полноты модели, warning исчезает.

**.gitignore** (новый файл):
- Игнорим: `target/`, бинарники COBOL (`cobol/world`, `cobol/simulate`), все `cobol/*.dat` (рантайм-состояние), `saves/`, `.DS_Store`, `.claude/settings.local.json`.
- В коммит идёт только: исходники (`src/*.rs`, `cobol/*.cob`), документация (`CLAUDE.md`, `DEVLOG.md`), манифест (`Cargo.toml`, `Cargo.lock`, `Makefile`), `.gitignore`.

### Какие файлы затронуты

- `src/saves.rs` — новый модуль (save/load, list_slots, current_year, new_game)
- `src/main.rs` — `mod saves`
- `src/ui.rs` — `StartChoice` enum, `run_start_menu`, `SlotDialog` enum, `render_slot_dialog`, обработка S/L клавиш с модальным режимом, фикс `tech_line` DONE-condition
- `src/world.rs` — `#[allow(dead_code)]` на `labour_hours`
- `.gitignore` — новый

### Результат компиляции

- COBOL: OK (без изменений в .cob, бинарники не пересобирались)
- Rust: OK, без warnings

### Smoke-test

- `saves/slot1/` создаётся, копируются все 6 файлов, year.dat сохраняет 0100
- После `new_game` (rm -rf cobol/*.dat) и `load_from_slot(1)` — мир восстановлен, regions=10, year=0100
- `./cobol/simulate` после load корректно продолжает с year=0101, хроника растёт

### Что не делалось

- Без переименования слотов: имя слота фиксировано (Slot 1..5). Можно добавить переименование позже через text-input widget, но это заметная сложность ради косметики.
- Без auto-save: пользователь явно просил «механические» сохранения. `Q` без `S` теряет прогресс — это by design.
- Без удаления слота: пользователь может удалить `saves/slotN/` руками.

## [Phase 19.1 — Bug-fixes найденные на 2500-ходовом стресс-тесте] 2026-04-27

Стресс-тест 2500 ходов после Phase 19 выявил два структурных бага, оба сидят в коде давно (с Phase 15 и Phase 18 соответственно). Не относятся к новой логике культуры — обнаружились благодаря большему объёму данных.

### Bug #1 — пустые MODE-SHIFT записи в хронике

**Симптом.** При IMPERIAL → SOCIALIST (революция в империалистическом регионе) в `cobol/chronicle.dat` появлялись две записи: правильная `0133 MODE-SHIFT Ironmarch Imperial -> Socialist. Workers control means of production.` и фантомная `0133 MODE-SHIFT Ironmarch` с пустым описанием.

**Причина.** В параграфе `REVOLUTION` (simulate.cob:1812):
1. На входе ставится `WS-CHRON-TYPE = "REVOLUTION"`, `WS-CHRON-DESC = "Merchants/Artisans seize ..."`.
2. Если регион в IMPERIAL, выполняется внутренний блок: TYPE/DESC перезаписываются на MODE-SHIFT/Imperial→Socialist, выполняется `WRITE-CHRONICLE`. После записи `WRITE-CHRONICLE` обнуляет `WS-CHRON-DESC` (там есть `MOVE SPACES TO WS-CHRON-DESC`).
3. После выхода из IF в конце параграфа стоит ещё один `WRITE-CHRONICLE` для основной REVOLUTION-записи. Но TYPE остался "MODE-SHIFT", DESC уже пустой → в файл уходит пустышка.

**Фикс.** Перенёс основной `PERFORM WRITE-CHRONICLE` ВЫШЕ блока изменения модуса — революция пишется первой, потом mode-shift (если есть). Никаких state-leakов между записями.

### Bug #2 — WAR-TECH-LOOT не выбирает L3/L4 при грабеже

**Симптом.** В `tech.dat` после длительного теста встречались регионы с `level=4, l3_choice=0` или `level=4, l4_choice=0`. Это «сломанное» состояние — UI рендерит `?` вместо имени тех'а, эффекты в производстве/военке не активируются.

**Причина.** В `WAR-TECH-LOOT` (simulate.cob:1511) после `ADD 1 TO WS-TECH-LEVEL` стояла одна проверка:
```cobol
IF WS-TECH-LEVEL(WIN, BRANCH) = TECH-MAX-LEVEL
   AND L3-CHOICE(WIN, BRANCH) = 0
    [pick L3]
END-IF
```
Это писалось в Phase 17 когда `TECH-MAX-LEVEL = 3`. В Phase 18 константа стала `4`, и условие теперь проверяется не на L3 (level=3), а на L4 (level=4). При этом проверки L4-choice вообще нет.

В нормальной `PROGRESS-TECH-ALL` (simulate.cob:2462) каждое повышение уровня имеет свою проверку (`level=3 → pick L3`, `level=4 → pick L4`), но war-loot этот путь обходил.

**Фикс.** В `WAR-TECH-LOOT` теперь две независимые проверки: L3 при `level >= 3 AND l3_choice = 0`; L4 при `level = 4 AND l4_choice = 0`. L4 копируется у проигравшего только если у него тот же L3-choice (иначе sub-tech нерелевантен).

### Что проверено

- Compile: COBOL OK, Rust release build OK (с одним warning о dead-code `labour_hours` в `src/world.rs` — не блокирующий)
- Стресс-тест 2500 ходов после фиксов:
  - Empty MODE-SHIFT entries: **0** (было ≥5 за такой же интервал)
  - Tech invariant violations: **0/10** регионов (было 2-3)
  - Class invariant `sum = 100`: **0** нарушений у всех 10 регионов
  - 7 эпох достигнуты (PRIMITIVE/SLAVE на старте → SOCIALIST в финале)
  - End-state: SOCIALIST 2 / INDUSTRIAL 2 / MERCANTILE 3 / PROTO-INDUSTRL 1 / FEUDAL 1 / COLLAPSED 1

### Какие файлы затронуты

- `cobol/simulate.cob` — REVOLUTION (перенос WRITE-CHRONICLE), WAR-TECH-LOOT (две проверки L3/L4 вместо одной на TECH-MAX-LEVEL)

### Наблюдения, не баги (на будущее)

- **War-type tag в хронике непоследователен.** Только DYNASTIC войны имеют `(dynastic).` суффикс. CRISIS пишет `Ruling class deflects unrest.`, IMPERIAL — `declares imperial war on X.`, CLASS-WAR — отдельный TYPE без suffix'а. Для UI-фильтрации это работает (по `WS-CHRON-TYPE`), но грепнуть `(crisis)` нельзя.
- **Religion vector decay'ит к нулю** в долгоживущих MERCANTILE+ регионах. Decay −1 каждые 5 ходов работает у всех трёх векторов; в MERC+ дрейф труда пополняет только merc, drift'ы PIOUS-правителя редки. К 2500 ходу почти у всех `rel = 0` кроме отстающих в FEUDAL. Это можно считать отражением секуляризации (Маркс: «религия — опиум народа», уходит с развитием базиса), но если хочется сохранить религиозный след истории — стоит понизить decay rel в MERC+ или добавить периодический «religious revival».
- **Tech tree saturates at 16/16** к 2500 ходу у всех живых регионов. Пост-tech-tree механики нет — после 4-го уровня progress'у некуда расти. Можно подумать о Phase 20: пост-tech идёт через innovation chains или соц.-научные революции.
- **REBIRTH не сбрасывает tech и культуру**. Можно интерпретировать как «Восточный Рим выжил» — знание сохраняется, государство восстанавливается. Это design choice; в случае «римское знание утрачено» нужно reset'ить, что мы пока не делаем. Так же не сбрасывается культура — что согласуется с continuity.
- **Cargo warning** `field labour_hours is never read`. Поле парсится из world.dat в `src/world.rs:113` но никем не читается. Можно либо удалить из структуры, либо завести `#[allow(dead_code)]`.

## [Phase 19 — Культурный темп эпох (МЭЛС + современный марксизм)] 2026-04-25

### Что сделано

**Постановка проблемы.** До Phase 19 культурные векторы (mil/merc/rel) накапливались через события (войны, трейты правителей, катастрофы), но **не влияли** на скорость mode-shift и tech research. Это создавало ощущение «развитого старта»: с турна 1 все регионы уже могут перейти к капитализму — наблюдатель не видит постепенного вызревания. Проблема: цивилизации стартуют слишком готовыми. Решение должно быть органическим, не игровым.

**Теоретическая база** (по результатам обращения к классикам):
- Маркс/Энгельс: производство **производит** свою культуру (базис → надстройка); первобытное общество имеет ритуально-родовую культуру (Энгельс «Происхождение семьи»).
- Ленин/Троцкий: combined and uneven development — отстающие нации перенимают культурные элементы от передовых соседей.
- Дэн Сяопин: производительные силы **первичны** — культура замедляет/ускоряет, но не блокирует.
- Си Цзиньпин: культурная уверенность как обратное воздействие на материальную базу.
- Ван Хуэй: множественность модернити — каждая цивилизация идёт своим путём.

**Реализация (только косвенные эффекты, никаких новых правил):**

1. **`cobol/world.cob`** — стартовая культура не нулевая: `rel=8, mil=2, merc=0` (родоплеменная религия + мелкие стычки кланов; меркантильное накапливается через торговлю).

2. **`cobol/simulate.cob` → `CULTURE-DRIFT-ALL`** расширен:
   - **Дрейф труда** (Маркс): каждые `CULTURE-LABOUR-INTERVAL = 10` ходов сама форма производства производит свою культуру:
     - PRIMITIVE/SLAVE/FEUDAL → +1 rel (аграрно-родовое)
     - MERCANTILE/PROTO-IND/INDUSTRIAL → +1 merc (торгово-промышленный труд)
     - IMPERIAL → +1 mil (финансовый капитал нуждается в военной экспансии)
     - SOCIALIST → +1 merc (трудовая база)
   - **Культурная диффузия** (Ленин): новый параграф `CULTURE-DIFFUSE-NEIGHBOR`. Если у соседа какой-то вектор ≥ нашего + `CULTURE-DIFFUSION-MIN = 30`, наш +1 (cap 100). COLLAPSED-сосед не передаёт — связь оборвана.

3. **`ACCUMULATE-ALL`** — каждый mode-shift получил **культурный множитель** (после `APPLY-TRAIT-BIAS`, до cap):
   - PRIMITIVE→SLAVE: rel + mil (родовое + межклановые стычки)
   - SLAVE→FEUDAL: rel*2 (религия легитимирует манориальный порядок)
   - FEUDAL→MERCANTILE: merc*2
   - MERCANTILE→PROTO-IND: merc*2
   - PROTO-IND→INDUSTRIAL: merc*2
   - INDUSTRIAL→IMPERIAL: mil + merc (Ленин)
   - Формула одинарной культуры: `prob × (50 + culture×2) / 150` → диапазон 0.33×..1.67×
   - Формула двойной: `prob × (50 + cA + cB) / 150` → тот же диапазон при сумме 0..200

4. **`TECH-COMPUTE-INC`** — финальный множитель от суммы всех трёх векторов:
   `inc × (50 + mil + merc + rel) / 150` → 0.33×..2.33× (Си: культура ускоряет науку).
   Применяется **после** всех остальных модификаторов, **до** floor=1. Молодой бескультурный регион исследует медленно, зрелая цивилизация прорывает потолки.

**Новые константы в WORKING-STORAGE:**
```
CULTURE-LABOUR-INTERVAL    VALUE 10.
CULTURE-DIFFUSION-MIN      VALUE 30.
CULTURE-MULT-BASE          VALUE 50.
CULTURE-MULT-DIVISOR       VALUE 150.
```

### Stress test (500 ходов)

```
Modes at end:    SOCIALIST 2  INDUSTRIAL 2  PROTO-INDUSTRL 3  FEUDAL 3
Mode shifts:     76 total
                 29× Feudal → Mercantile
                 25× Mercantile → Proto-Ind
                 13× Proto-Ind → Industrial
                  3× Slave → Feudal
                  2× Industrial → Imperial
                  2× Imperial → Socialist
```

Достигнуто 7 эпох (PRIMITIVE/SLAVE на старте → ... → SOCIALIST в финале).

Культурные векторы регионов в конце разошлись по архетипам:
- Cinderkeep INDUSTRIAL: merc=99/mil=41/rel=60 → буржуазный путь
- Frostfen FEUDAL: mil=97/rel=70/merc=41 → консервативно-милитаристский
- Stonehold FEUDAL: rel=70/merc=92/mil=70 → сбалансированный
- Goldgate SOCIALIST: mil=99/merc=42/rel=36 → послевоенно-революционный

Никаких хардкоженных «архетипов» — это эмерджентный результат истории каждого региона (правители, войны, торговля, мода производства).

**Наблюдение:** SLAVE→FEUDAL фиксируется уже на годах 1-13 — переход слишком быстрый, потому что начальный capital=500 + культурный множитель 0.44 даёт 22‰ ×8 регионов = около 1 события за ~5 ходов. Если станет визуальной проблемой — поднимем `FEUDAL-CAPITAL-MIN` или снизим `SLAVE-BASE-PERMIL`. Пока оставляем — наблюдатель сможет посмотреть, как именно эти ранние SLAVE-регионы расходятся в последующих 400 ходах.

### Какие файлы затронуты

- `cobol/world.cob` — стартовая культура (mil=2/merc=0/rel=8)
- `cobol/simulate.cob` — 4 константы Phase 19, расширен `CULTURE-DRIFT-ALL` (дрейф труда + диффузия), новый параграф `CULTURE-DIFFUSE-NEIGHBOR`, культурный множитель в 6 переходах `ACCUMULATE-ALL`, культурный множитель в `TECH-COMPUTE-INC`

### Результат компиляции

- COBOL: OK (`cobc -x -free` для обоих)
- 500 ходов прогнано без сбоев

### Что дальше

- Возможная Phase 20: **класс composition по эпохе при PRIMITIVE/SLAVE** — сейчас на старте все регионы P65/A18/M10/N7/C3, что годится для FEUDAL, но не для SLAVE (там рабовладельческая знать должна быть выше). Drift сейчас выравнивает за десятки ходов, но для аутентичности можно стартовать соответственно эпохе.
- Возможная Phase 20+: **revolutionary path к SOCIALIST как ответ** на класс-войну в IMPERIAL (сейчас он происходит, но через те же ROLL — можно сделать осознанным переходом).

## [Фаза 3-6 — Population/Collapse/Rebirth fixes] 2026-04-23

### Что сделано
- WAR-VICTORY-NBREG обновлён: изъятие капитала 30%→40%, потери населения -13%→-20%, трибут +5%→+8%, потолок surplus 60→70
- Исправлен критический баг: RESOLVE-WAR сбрасывал WAR-YEAR=0 после COLLAPSE-CHECK, уничтожая таймер возрождения. Теперь WAR-YEAR/WAR-TYPE сбрасываются только для не-коллапсированных регионов
- Проверено на 100 ходах: коллапсы и возрождения работают (Duskveil: коллапс 70→возрождение 74; Cinderkeep: коллапс 82→возрождение 88)

### Какие файлы затронуты
- `cobol/simulate.cob` — WAR-VICTORY-NBREG, RESOLVE-WAR (условный сброс WAR-YEAR)

### Результат компиляции
- COBOL: OK

### Что дальше
- Все три фичи работают: население меняется, государства коллапсируют, возрождаются

## [Phase 7 — Уборка и фиксы] 2026-04-26

### Что сделано

**COBOL уборка (simulate.cob, world.cob):**
- Добавлен блок 78-level констант в начале simulate.cob — все балансировочные числа (пороги войн, размеры коллапса, скорости роста, мультипликаторы рынка) вынесены в имена. Магических чисел в логике больше нет.
- Разделены `WAR-YEAR` (счётчик войны) и `COLLAPSE-TIMER` (таймер возрождения) — устранена двойная семантика, из-за которой был молчаливый баг с `MOVE 0 TO WAR-YEAR` в RESOLVE-WAR. Теперь WAR-YEAR обнуляется безусловно.
- Объединены `WAR-VICTORY-IDX` и `WAR-VICTORY-NBREG` в один параграф `WAR-VICTORY` с `WS-WIN-IDX`/`WS-LOSE-IDX`. Удалено ≈55 строк дублирования.
- Объединены две ветки `COLLAPSE-CHECK` в `COLLAPSE-ONE` (параметр через `WS-COLLAPSE-CANDIDATE`).
- Удалены производные поля `WS-PROD-EFFICIENCY` и `WS-STABILITY-IDX` из структуры региона. Эффективность считается на лету в PRODUCE-ALL через EVALUATE.
- Добавлена константа `WORLD-REC-LEN VALUE 152` и guard в WRITE-WORLD: `DISPLAY "WARN: world.dat record drift" UPON SYSERR` ловит дрейф формата.

**Rust уборка (engine.rs, ui.rs, world.rs):**
- `engine.rs`: новая функция `run_cobol(bin)` возвращает `Result<(), String>` с захватом stderr+stdout. Игрок видит реальное сообщение COBOL вместо безликого `✗ sim failed`.
- `ui.rs`: `last_sim: Option<Result<(), String>>`. При ошибке заголовок становится красным и показывает первые 60 символов stderr.
- `world.rs`: смещения сдвинуты для нового COLLAPSE_TIMER (длина строки 149→152, NEIGHBOR_1=146, NEIGHBOR_2=148, NEIGHBOR_3=150).

**Файл данных:**
- world.dat: вставлено поле COLLAPSE_TIMER (3 байта) на смещение 130, между AT_WAR_WITH и WAR_YEAR.
- Старые сохранения world.dat несовместимы — мир перегенерируется.

### Какие файлы затронуты
- `cobol/simulate.cob` — полная переписка с новым WORKING-STORAGE и упрощёнными параграфами
- `cobol/world.cob` — добавление COLLAPSE-TIMER, удаление PROD-EFFICIENCY и STABILITY-IDX
- `src/world.rs` — обновлённая таблица смещений
- `src/engine.rs` — Result<(), String> + захват stderr
- `src/ui.rs` — отображение конкретной ошибки в заголовке

### Результат компиляции
- COBOL: OK (cobc -x -free, оба файла без warning)
- Rust: OK (cargo build, 1 предсуществующий warning о неиспользуемом labour_hours)

### Регрессия
Сравнение 100 ходов до/после на свежесгенерированных мирах:
- WAR-END: 68 = 68
- REVOLUTION: 41 = 41
- MODE-SHIFT: 19 = 19
- COLLAPSE: 2 = 2 (Duskveil@70, Cinderkeep@82)
- REBIRTH: 2 = 2
- Качественное поведение сохранено.

Захват stderr проверен отдельным бинарём: `run_cobol("/no/such/file")` → `Err("spawn /no/such/file: No such file or directory")`, `run_cobol("./cobol/simulate")` без year.dat → `Err("libcob: error: file does not exist (status = 35) for file YEAR-FILE")`.

### Что дальше
Следующая итерация — фичи из «Фазы 7 расширения»: рынок в TUI, эффекты climate/terrain, империалистические войны, миграция.

## [Phase 7+ — Рынок в TUI] 2026-04-26

### Что сделано
- `cobol/simulate.cob`: добавлены SELECT/FD MARKET-FILE (`cobol/market.dat`), параграф `WRITE-MARKET`, вызов в MAIN-PARA после PROPAGATE-CRISIS. Беззнаковые буферы `WS-MKT-OUT-SUPPLY/DEMAND` для записи без overpunch. Guard `IF FUNCTION LENGTH > MARKET-REC-LEN DISPLAY ... UPON SYSERR`.
- `src/market.rs`: новый модуль с `Commodity { name, supply, demand, price, crisis }` и `parse_market(path)` — fixed-width 51 байт.
- `src/main.rs`: подключён `mod market`.
- `src/ui.rs`:
  - Добавлены хелперы `humanize` (12.6M/14.0K/750) и `market_status_color` (green/yellow/red по supply/demand).
  - Layout сменился с 4 на 5 секций: header(1) | body min(10) | market(11) | chronicle(7) | footer(1).
  - Новая таблица `Market` с колонками Good/Supply/Demand/Price/Status. CRISIS — красный жирный «⚠ CRISIS», иначе scarcity / surplus / balanced.
  - Цена теперь видна, кризисы перепроизводства больше не невидимы.

### Файлы затронуты
- `cobol/simulate.cob` — +SELECT/FD/WRITE-MARKET (~40 строк)
- `src/market.rs` — новый файл (~40 строк)
- `src/main.rs` — +1 строка `mod market;`
- `src/ui.rs` — +helpers, +market render, layout сдвинул индексы chronicle/footer

### Результат компиляции
- COBOL: OK
- Rust: OK (тот же предсуществующий warning о неиспользуемом labour_hours)

### Smoke-тест
20 ходов на свежем мире:
```
GRAIN     supply=15.5M  demand=12.0M  price=0.90  ⚠ CRISIS  (ratio 1.30)
PEAT      supply= 2.1M  demand= 3.0M  price=0.88  scarcity (ratio 0.71)
TIMBER    supply=14.0M  demand=12.0M  price=1.20  balanced
...
```
Видно структурную динамику: GRAIN перепроизводится (PLAINS → 2 региона = Ironmarch + Thornwall), PEAT в дефиците (только Frostfen, SWAMP).

### Регрессия
100 ходов: 68 WAR-END / 41 REVOLUTION / 19 MODE-SHIFT / 2 COLLAPSE / 2 REBIRTH — биткой совпадает с эталоном Phase 7. Рынок только экспонирует данные, не меняет симуляцию.

### Известное (не в скоупе)
`INIT-MARKET` сбрасывает цены к дефолтным каждый ход. Снимок показывает скорректированную цену внутри хода, но между ходами она не накапливается. Реальная ценовая динамика требует переноса инициализации цен из INIT-MARKET в первый запуск через сохранение price в world.dat. — отдельная задача.

### Что дальше
Climate/terrain эффекты, империалистические войны, миграция, save/load, auto-step. Из самого важного по гайду — climate/terrain (поля заполнены, но не используются в логике).

## [Phase 7+ — Тесты + критфикс REVOLUTION class overflow] 2026-04-26

### Что нашёл при тестировании
Пользователь заметил, что в Stonehold не меняется население. Прогон 300 ходов показал систематический баг в 6 из 10 регионов.

### Корень бага
В параграфе `REVOLUTION` класс растёт безусловно:
```cobol
COMPUTE WS-ARTISANS-PCT(WS-IDX) = WS-ARTISANS-PCT(WS-IDX) + REVOLUTION-CLASS-BONUS
```
Без верхней границы. После ~20 революций artisans_pct становился >100 (Stonehold к ходу 300: artisans=259, peasants=171, сумма=442%).

`peasants = 100 - artisans - merchants - clergy` идёт в отрицательное, в `PIC 9(3)` (unsigned) сохраняется по модулю. Раздутые проценты → раздутый `WS-WORKERS = pop × (peasants+artisans)/100` → раздутый `SUBSIST-NEED` → permanent FAMINE → pop *= 0.96 каждый ход → клин в `POP-FLOOR=10000`.

Stonehold к ходу 300: pop=10,000 fixed, FAMINE каждый ход с 240+, REVOLUTION каждые 10 ходов в бесконечном цикле.

### Фикс
- Добавлена константа `78 REVOLUTION-CLASS-CAP VALUE 50.`
- Добавлен буфер `01 WS-PEASANT-CALC PIC S9(4)` (signed) для безопасного расчёта крестьян
- В `REVOLUTION` теперь:
  ```cobol
  IF WS-ARTISANS-PCT(WS-IDX) < REVOLUTION-CLASS-CAP
      ADD REVOLUTION-CLASS-BONUS TO WS-ARTISANS-PCT(WS-IDX)
      IF WS-ARTISANS-PCT(WS-IDX) > REVOLUTION-CLASS-CAP
          MOVE REVOLUTION-CLASS-CAP TO WS-ARTISANS-PCT(WS-IDX)
      END-IF
  END-IF
  ```
- Расчёт крестьян идёт через `WS-PEASANT-CALC` (S9(4)), затем clamp к `PEASANT-FLOOR`
- То же для merchants

### Проверка
300 ходов после фикса: классы во всех 10 регионах = ровно 100%, нет ни одного перелива. Stonehold восстановился до 2.7M. FAMINE-событий за 100 ходов: 0 (было 3 в эталоне — все они были артефактом этого бага).

### Регрессия
Изменилась незначительно: WAR-END 66 (было 68), REVOLUTION 40 (было 41). Меньше потому, что цикл «голод→революция→война» больше не самозатягивается.

Качественно — те же события, те же регионы коллапсируют (Duskveil@70, Cinderkeep@82), те же mode-shifts.

### Также
- Подчищены 2 clippy warning (`collapsible_match`) в ui.rs — `KeyCode::Down if selected + 1 < n => ...` вместо вложенного if
- Остался единственный pre-existing warning о неиспользуемом `labour_hours` поле — не критично, поле может пригодиться для будущих фич

### Файлы затронуты
- `cobol/simulate.cob` — `REVOLUTION-CLASS-CAP`, `WS-PEASANT-CALC`, безопасный REVOLUTION
- `src/ui.rs` — 2 collapsible match

## [Phase 8 — Радикальный отказ от детерминизма] 2026-04-26

### Философия
Раньше все триггеры были жёсткими порогами: `IF capital>8000 AND tension<52 AND nb_tension>55 → война`. Из-за этого мир вёл себя как часы: Cinderkeep коллапсировал ровно на 82-м ходу каждый раз. Игрок выучивал паттерн и переставал удивляться.

Phase 8 — фундаментальное изменение: **условия больше не разрешают событие, а биасят его вероятность**. Если факторы благоприятны — событие *скорее всего* произойдёт. Если нет — *скорее всего* нет. Но всегда есть хвост распределения.

### Что осталось строгим (правильно)
Арифметические тождества: класс % сумма = 100, output = labour × eff, capital += surplus/10, growth = pop × 1.015, WAR-YEAR ++ каждый ход войны. Случайность тут была бы шумом.

### Что стало вероятностным
| Событие | Раньше | Теперь |
|---------|--------|--------|
| Dynastic war | 3 жёстких условия | base 200‰ × (1−own_ten) × nb_ten, cap 350‰ |
| Class war | tension≥90 ∧ nob>5 → 100% | base 500‰ +35‰/пункт сверху, cap 850‰ |
| Crisis war | crisis ∧ ten>60 ∧ cap>3000 → 100% | base 400‰ × tension/100, cap 600‰ |
| Revolution | tension=100 → 100% | 0% при ≤70, +25‰/пункт, 100% на 100 |
| Mode-shift | условия → 100% мгновенно | base 300‰, scale by capital, cap 700‰ — растягивается на 2-4 хода |
| Crisis (рынок) | supply>1.2×demand → 100% | (ratio−1)×1500, cap 800‰. Цены падают всегда, но «паника» вероятностна. |
| War outcome | детерминистский по military | military × (80..120%) шум — слабые иногда побеждают |

### Climate hazards (новое)
Привязаны к terrain. Раньше эти поля просто декорировали мир.
- SWAMP: эпидемия 4%/ход (pop×0.85, +10 tension)
- DESERT: засуха 5%/ход (labour×0.60, +8 tension)
- MOUNTAINS: обвал шахты 2.5%/ход (capital×0.92)
- PLAINS: урожайное событие 7%/ход (50/50: bumper crop +20% capital / bad harvest labour×0.75)
- COAST: шторм 3.5%/ход (labour×0.95)
- FOREST: blight 3%/ход (labour×0.90)

### Famine: бинарное → severity
- severity 0 = ok
- severity 1 (mild, 70-100% потребности) = pop×0.98, +5 tension, без записи в хронику
- severity 2 (severe, <70% потребности) = pop×0.92, +15 tension, запись «Severe famine»

### Tension noise
В SOCIAL-ALL добавлен шум ±2 пункта в каждом ходу (харизматичные смутьяны, слухи, культурные приливы). Тензии больше не следуют чистой формуле.

### Технически
- `MOVE FUNCTION RANDOM(WS-YEAR) TO WS-RAND-RAW` в начале MAIN-PARA — детерминированный seed по году → один и тот же мир выдаёт одни и те же события (replay-safe для тестов, можно переиграть мир).
- Новый параграф `ROLL-EVENT`: на входе `WS-PROB-PERMIL` (0..1000), на выходе `WS-EVENT-FIRES` (0/1). Унифицированная точка для всех вероятностных проверок.
- ~30 новых 78-level констант для всех вероятностных параметров (балансировка в одном блоке).

### Бонус-фикс
Найден и устранён унаследованный баг в `CLASS-WAR-CHECK`: `peasants_pct -= 5` без передачи кому-либо → сумма классов проседала. Теперь репрессия убивает массу (`pop×0.95`), пропорции сохраняются. После фикса все 10 регионов держат сумму = 100 в течение 300 ходов.

### Stress test (300 ходов)
- Время: 1 секунда
- Целостность классов: 10/10 регионов = 100%
- Население: от 10K до 70M
- События: 205 wars / 105 revolutions / 33 mode-shifts / 24 collapse / 21 rebirth / 77 famines / ~123 climate hazards / 492 crisis
- Embervast: PROTO-INDUSTRL → MERCANTILE → FEUDAL — деградация мира тоже происходит, не только прогресс

### UI
Хроника получила цвета новых событий: EPIDEMIC (LightMagenta), DROUGHT (LightYellow), CAVE-IN (DarkGray), BUMPER-CROP (LightGreen), BAD-HARVEST (LightRed), STORM (Blue), BLIGHT (LightGreen), CLASS-WAR (Red), COLLAPSE (DarkGray), REBIRTH (Green).

### Файлы затронуты
- `cobol/simulate.cob` — большой блок констант, ROLL-EVENT, переписаны DYNASTIC-WAR-CHECK / CLASS-WAR-CHECK / CRISIS-WAR-CHECK / SOCIAL-ALL / ACCUMULATE-ALL / CHECK-CRISIS / RESOLVE-WAR / DISTRIBUTE-ALL / DEMOGRAPHY-ALL, новые EVT-* параграфы и CLIMATE-EVENTS-ALL
- `src/ui.rs` — расширенная палитра событий хроники

### Что НЕ сделано (на будущее)
- Cap для SOCIAL-ALL random: tension может пойти выше 100 из-за noise+famine — clamping есть, но cap chain местами хрупкий
- Probability events не записаны в DEBUG-лог — нельзя посмотреть «какая была вероятность» при дебаге балансировки
- INIT-MARKET всё ещё сбрасывает цены каждый ход — дельта от прошлого хода не накапливается

## [Phase 8.1 — Долги Phase 8] 2026-04-26

Закрытие трёх пунктов из «не сделано» в Phase 8 DEVLOG.

### 1. Персистентные цены
**Было:** `INIT-MARKET` сбрасывал цены к дефолтам каждый ход. Эволюция цены жила одну итерацию.

**Стало:**
- `INIT-MARKET` сначала ставит дефолты, затем вызывает `LOAD-PERSISTED-PRICES` — читает `market.dat` от прошлого хода и переписывает только `price` (имена и demand остаются дефолтными — это структурные константы).
- Добавлена параллельная таблица `WS-MKT-DEFAULTS` с эталонными ценами.
- Новый параграф `CLAMP-PRICE` зажимает цену в `[50%, 300%]` от default — чтобы перепроиз не загнал цену в 0.05, а дефицит не надул её до 50.00.
- `engine.rs::run_simulate` создаёт пустой `cobol/market.dat` если его нет (как с chronicle.dat) — чтобы `OPEN INPUT` не падал на первом ходу.
- `SELECT MARKET-FILE` получил `FILE STATUS IS WS-MKT-FILE-STATUS` для безопасной проверки существования.

**Результат на 100 ходов:**
```
Good       Y1    Y10    Y20    Y30    Y50   Y100
GRAIN    1.00   0.72   0.50   0.50   0.50   0.50    (perpetual overproduction → floor)
TIMBER   1.32   3.06   3.60   3.60   3.60   3.60    (chronic scarcity → ceiling)
ORE      2.20   5.14   6.00   6.00   1.00   1.00    (climbed to ceiling, crashed when MOUNTAINS upgraded)
PEAT     0.88   2.00   2.40   2.40   2.40   2.40    (single producer → ceiling)
FISH     1.10   2.56   3.00   3.00   0.50   0.50    (peaked, then crashed)
SPICES   4.40  10.32  12.00  12.00  12.00  12.00    (single producer → ceiling)
SALT     1.65   3.16   3.16   3.16   3.47   4.50    (oscillating)
COAL     2.75   6.44   7.50   7.50   7.50   7.50    (single producer)
```
Цены теперь читаются как структурный портрет экономики: что в избытке, что в дефиците, какие отрасли пережили технологический переход.

### 2. Debug probability log
**Было:** при балансировке вероятностей нельзя было посмотреть, какие шансы фактически сработали.

**Стало:**
- В COBOL: `ACCEPT WS-DEBUG-FLAG FROM ENVIRONMENT "ECOS_DEBUG"` в `MAIN-PARA`.
- Каждый PERFORM ROLL-EVENT теперь сначала ставит `WS-DEBUG-LABEL` (имя события). `ROLL-EVENT` при `ECOS_DEBUG=1` пишет строку в stderr через `DISPLAY ... UPON SYSERR`:
  ```
  [0001] DYNASTIC-WAR    idx=03 p=+0030 roll=0016 fired=1
  [0001] REVOLUTION      idx=05 p=+0000 roll=0000 fired=0
  ```
- В Rust: `engine.rs` при `ECOS_DEBUG=1` пробрасывает stderr COBOL прозрачно (`Stdio::inherit()`) — иначе захватывало бы и теряло.
- На 1 ход: ~45 entries (по числу probabilistic-проверок на 10 регионов).
- Помечены: DYNASTIC-WAR, CRISIS-WAR, CLASS-WAR, REVOLUTION, MODE-MERCANTILE, MODE-PROTO-IND, MARKET-CRISIS, CLIMATE-EPIDEM/DROUGH/CAVEIN/HARVES/STORM/BLIGHT.

**Использование:**
```bash
ECOS_DEBUG=1 ./cobol/simulate 2>/tmp/log.txt        # standalone
ECOS_DEBUG=1 cargo run                              # TUI с пробросом
```

### 3. Tension clamp helper
**Было:** блок `IF X > 100 MOVE 100 TO X` повторялся в WAR-VICTORY, EVT-EPIDEMIC, EVT-DROUGHT, EVT-HARVEST. При добавлении новых событий легко было забыть.

**Стало:**
- Параграф `CLAMP-TENSION`: caller ставит `WS-CLAMP-IDX`, вызов зажимает `WS-CLASS-TENSION(WS-CLAMP-IDX)` к `[0, 100]`.
- Параграф `CLAMP-ALL-TENSIONS`: бежит по всем регионам и зажимает каждый.
- Финальный вызов `PERFORM CLAMP-ALL-TENSIONS` в конце MAIN-PARA — защитная страховка перед WRITE-WORLD.
- Все ручные блоки заменены на `MOVE X TO WS-CLAMP-IDX  PERFORM CLAMP-TENSION` (5 мест).

### Тесты
- COBOL компиляция: ✓
- Cargo build / clippy: чисто (1 pre-existing dead_code warning)
- 300 ходов: 1.3 сек, без падений
- Integrity: классы 100/100, tension 0..100, длины записей 152 / 51 — все 10 регионов на 200 ходах
- Engine error path: ✓ (stderr COBOL пробрасывается через `Result<(), String>`)
- Debug log: 0 строк без ECOS_DEBUG, 45 строк с ECOS_DEBUG=1 на 1 ход

### Файлы
- `cobol/simulate.cob` — `LOAD-PERSISTED-PRICES`, `CLAMP-PRICE`, `CLAMP-TENSION`, `CLAMP-ALL-TENSIONS`, debug-инфраструктура, лейблы перед каждым ROLL-EVENT
- `src/engine.rs` — создание market.dat если нет, `Stdio::inherit()` под `ECOS_DEBUG`

## [Phase 9 — Лица, память, сознание] 2026-04-26

Превращение симуляции из таблицы в нарратив. Три новых слоя поверх вероятностной механики Phase 8.

### Слой 1 — Правители (named rulers)

Каждый регион имеет правителя:
- **Имя** из пула 20 (Aegon, Bjorn, Cassio, ..., Ulf)
- **Возраст** 25-80 (стартовый разброс 25-55)
- **Трейт** один из 5: AMBITIOUS / CAUTIOUS / CRUEL / PIOUS / MERCANT
- **Reign** — годы правления

Хроника теперь читается как история:
```
0006 RULER-DEATH    Stonehold     Cassio of Stonehold dies. Reign of 021 years ends.
0006 RULER-RISE     Stonehold     Maric ascends in Stonehold. Trait: CRUEL.
0020 REVOLUTION     Ashvale       Artisans seize means of production.
0020 RULER-RISE     Ashvale       Kael ascends in Ashvale. Trait: PIOUS.
```

WAR-START / WAR-END теперь персонифицированы: «Aegon of Ironmarch attacks Ashvale».

**Старение и смерть** (новый параграф `AGE-RULERS`):
- Каждый ход age++ и reign++
- При age >= 50: смерть с вероятностью `(age−50) × 30‰`
- При age >= 70: вероятность `(age−50) × 50‰` (резкий рост)

**Преемство** (`SUCCESSION`):
- Новое имя из пула (random)
- Возраст 25-35
- Трейт: 60% наследуется от предшественника, 40% случайный
- Reign сбрасывается в 0
- Триггерится при: 1) смерти от старости, 2) революции, 3) возрождении после коллапса

**Trait биасы** (новый параграф `APPLY-TRAIT-BIAS`, вызывается после расчёта prob и до cap):

| Трейт      | Эффекты на ‰ вероятностей |
|------------|---------------------------|
| AMBITIOUS  | +30 DYNASTIC, +20 CRISIS-WAR |
| CAUTIOUS   | −40 ко всем войнам |
| CRUEL      | +60 CLASS-WAR, +10 DYNASTIC |
| PIOUS      | −30 всем войнам, −10 REVOLUTION |
| MERCANT    | +30 MODE-MERCANTILE/PROTO-IND, −30 всем войнам |

### Слой 2 — Матрица отношений

Новый файл `cobol/relations.dat`: 10 строк × 40 байт. Хранение со смещением +500 (значение 0 = "0500", +50 = "0550", −100 = "0400") — unsigned 9(4) формат, чтобы избежать проблем со знаком в LINE SEQUENTIAL.

**Динамика:**
- WAR-START: relation -= 30 (симметрично)
- WAR-VICTORY: relation -= 20 (победа закрепляет вражду)
- TRADE: +1/ход для активной торговли соседей не в войне
- DECAY: каждое отношение приближается к 0 на 1/ход (память сглаживается)
- Зажим: `[-100, +100]`

**Биас на dynastic war:**
- relation > +60 → alliance, война = 0% (полностью блокирует)
- relation < 0 → вендетта, prob × (100 − relation)/100, до 2× при -100
- relation > 0 (но <60) → дружба, prob × (100 − relation)/100, до 0.4× при +60

Пример матрицы из 300-ходового прогона:
```
        1   2   3   4   5   6   7   8   9  10
  1:    0 -98   0   0   0   0  +5   0   0   0
  2:  -98   0 +32   0 +99   0   0   0   0   0    ← Ashvale в альянсе с Goldgate
  3:    0 +32   0   0   0 -81   0   0   0 -93    ← Stonehold ненавидит Duskveil и Cinderkeep
  ...
```

В Rust: новый модуль `src/relations.rs`, функции `parse_relations` и `top_relations` (для UI).

### Слой 3 — Классовое сознание

Новое поле `WS-CONSCIOUSNESS` 0-100. Стартует с 10 (глухая феодальная масса).

**Динамика** (новый параграф `CONSCIOUSNESS-ALL`, между CLIMATE и SOCIAL):
- +1/ход при MERCANTILE
- +2/ход при PROTO-INDUSTRL
- +1/ход при artisans_pct ≥ 30 (urban density)
- +3 за каждого соседа с tension ≥ 90 (proxy для революционного заражения)
- −5 после собственной революции (цикл сбрасывается)
- −2 после class-war репрессии
- При REBIRTH: сброс к 10
- Зажим `[0, 100]`

**Эффект:** в SOCIAL-ALL после расчёта revolution probability:
```
WS-PROB-PERMIL = WS-PROB-PERMIL × WS-CONSCIOUSNESS / 100
```

Tension=85, consciousness=20 → шанс уменьшается в 5 раз. Tension=85, consciousness=80 → почти полная вероятность. Это объясняет, почему крестьянские империи терпят, а промышленные взрываются.

### UI обновления

**Detail panel** теперь содержит:
```
Ironmarch
PLAINS      TEMPERATE
Pop:    1080000

👑 Aegon (age 35)
   AMBITIOUS — 10 yr reign

Tension:  20  Stable
Awareness:  10/100

Peasants   65%  Artisans  18%
...

⚔ Ashvale (-98)
🤝 Goldgate (+78)

Neighbors: 02  04  07
```

**Цвета хроники:** `RULER-DEATH` Gray, `RULER-RISE` White. Цвет трейта правителя в Detail: AMBITIOUS LightRed, CAUTIOUS LightBlue, CRUEL Red, PIOUS LightYellow, MERCANT LightCyan.

### Файлы

- `cobol/world.cob` — пул имён, трейтов; инициализация ruler/consciousness
- `cobol/simulate.cob` — `AGE-RULERS`, `SUCCESSION`, `APPLY-TRAIT-BIAS`, `LOAD-RELATIONS`, `WRITE-RELATIONS`, `RELATIONS-DECAY`, `REL-DELTA-PAIR`, `CONSCIOUSNESS-ALL`, `CONSCIOUSNESS-CONTAGION`. Биас в DYNASTIC/CRISIS/CLASS-WAR-CHECK, REVOLUTION (в SOCIAL-ALL), MODE-SHIFT в ACCUMULATE-ALL. Force-succession в REVOLUTION и REBIRTH. world.dat 152→190 байт.
- `cobol/relations.dat` — новый файл, 10×10 матрица unsigned 9(4) со смещением +500
- `src/world.rs` — Region расширен 5 полями (ruler_name, ruler_age, ruler_trait, ruler_reign, consciousness)
- `src/relations.rs` — новый модуль с `parse_relations` и `top_relations`
- `src/main.rs` — `mod relations`
- `src/engine.rs` — создаёт пустой relations.dat если нет (как chronicle/market)
- `src/ui.rs` — Ruler block, Awareness, Politics block с топ-2 союзников/врагов, цвета RULER-*, цвет трейта

### Тесты

- COBOL компиляция: ✓
- cargo build / clippy: 1 pre-existing warning (labour_hours never read), остальное чисто
- 300 ходов: 1.4 сек, без падений
- Integrity 10/10: world.dat=190 байт, relations.dat=40 байт, классы 100, tension≤100, cons≤100, имена правителей не пустые, трейты валидны
- Replay-safe: тот же seed → те же события (FUNCTION RANDOM сидится от WS-YEAR)

**События за 300 ходов:**
```
WAR-START: 170    WAR-END: 168     REVOLUTION: 86
MODE-SHIFT: 34    CLASS-WAR: 34
COLLAPSE: 15      REBIRTH: 14
RULER-DEATH: 60   RULER-RISE: 160  (выше потому что revolution/rebirth тоже триггерят)
EPIDEMIC: 13      DROUGHT: 16      BUMPER: 14   BAD-HARVEST: 28
STORM: 22         BLIGHT: 17
FAMINE: 268       CRISIS: 237
```

**Ключевое доказательство работы:** сознание блокирует ранние революции (молодой мир терпит), а зрелые PROTO-INDUSTRL регионы взрываются. Альянсы появляются естественно (двухсторонняя торговля). Война между традиционными врагами имеет вдвое больший шанс.

### Что осталось как известное

- **Goldgate-style death spiral**: регион при pop=10K (POP-FLOOR) и mass-revolutions может застрять в severe famine cycle. В 300-ходовом прогоне 204/268 famine принадлежат одному региону. Pop floor + low surplus + extreme tension → labour и output не растут. Нужно специальное условие восстановления для регионов на полу. Phase 10 кандидат.
- **Заражение сознания через neighbor.tension≥90** — это proxy для революции, не флаг самой революции. Работает похоже, но заражение нарастает по мере пика tension, а не в момент взрыва. Можно улучшить через персистентный `last_revolution_year` flag.
- **WS-NAME-IDX вначале (генерация)** не использует RANDOM — все стартовые имена детерминированы (Aegon в Ironmarch всегда). Это сделано намеренно для воспроизводимости стартового мира; разнообразие приходит через succession.

### Что специально не сделано

- Imperial wars (4-й тип войны для PROTO-INDUSTRL)
- Миграция населения между регионами
- Инновации/изобретения с долгосрочными эффектами
- Династии с порядковыми номерами (Aegon I/II/III)
- Брачные альянсы между правителями

Эти кандидаты в Phase 10+.

## [Phase 10 — Демография в движении + auto-step] 2026-04-26

Малая, но видимая фаза. Между большими событиями теперь всегда что-то движется, и за этим легко наблюдать.

### Что сделано

**1. Auto-step в TUI**
- Клавиша `[A]` переключает автошаг (500мс интервал, повторное `[A]` стоп)
- Футер показывает текущий статус: `[A] Auto: ON` зелёным или `Auto: OFF` тёмно-серым
- Любая клавиша (N, ↑/↓) сбрасывает таймер
- Игрок может «сесть и наблюдать» как мир разворачивается

**2. Class drift — 5 микро-переходов между классами каждый ход**

| Переход | Условия | Шанс/ход | Логика |
|---|---|---|---|
| **Урбанизация** P→A | MERCANTILE+ ∧ P>35 ∧ A<50 | 80‰ | Городская революция — рабочие тянутся в мануфактурные центры |
| **Коммерциализация** A→M | A>25 ∧ M<50 | 30‰ + 30‰ COAST + 30‰ MERCANT | Успешные ремесленники → мелкие торговцы |
| **Аристократический упадок** N→P | MERCANTILE+ ∧ N>4 | 40‰ | Буржуазия теснит знать, младшие сыновья в массу |
| **Религиозный подъём** P→C | C<20 ∧ P>35 | 15‰ + 50‰ PIOUS | Особенно при PIOUS правителе |
| **Рурализация** A→P | severe famine ∧ A>15 | 200‰ | Голод гонит горожан обратно к земле |

Эффект на 300 ходов: PROTO-INDUSTRL регионы переходят с базовых 65/18/10/7/3 → P30-37/A40-49/M9-27. FEUDAL регионы остаются с дефолтным составом (как и должно). Видна **естественная классовая дифференциация** между развитыми и архаичными.

**3. Миграция беженцев при коллапсе**
- При срабатывании COLLAPSE-ONE: 30% оставшегося населения распределяется поровну по живым соседям
- Принимающие регионы получают `+5 tension` (новые рты, ксенофобия)
- В хронике появляется новый тип события `REFUGEES`: «Refugees from Frostfen arrive. Pop +6604»
- Беженцы помогают соседям и убивают «Goldgate-style death spiral» (см. ниже)

**4. Бонус-фикс: REVOLUTION class invariant**
Найден старый баг: при `peasant_calc < floor` REVOLUTION ставил peasants=floor, но не уменьшал другие классы. Сумма уезжала выше 100 (Ironmarch=104, Goldgate=110 в первом тесте Phase 10). Исправлено: при недоборе крестьян излишек последовательно вычитается из artisans → merchants → clergy.

**5. Случайные стартовые имена правителей**
В `world.cob` `WS-NAME-IDX = WS-IDX` → `WS-NAME-IDX = FUNCTION INTEGER(FUNCTION RANDOM * 20) + 1`. Aegon больше не всегда в Ironmarch.

### Goldgate-style death spiral — РЕШЕНО

В Phase 9 один регион (Goldgate) держал 204 famine из 268 общих, застряв на pop=10000 с consciousness=100, постоянными революциями и голодом.

В Phase 10:
- Phase 9: 204 Goldgate / 21 Ashvale / 16 Duskveil / 15 Ironmarch → **гипер-концентрация**
- Phase 10: 28 Saltmere / 28 Frostfen / 21 Thornwall / 16 Stonehold / 13 Cinderkeep → **равномерное распределение**

Goldgate в финале на pop=858K — полностью восстановился. Механизм: `DRIFT-RURAL` во время severe famine переводит artisans→peasants, разгружая `WORKERS` и `SUBSIST-NEED`. Параллельно `MIGRATION` приносит население от коллапсирующих соседей, не давая популяции упасть в пол.

### Тесты

- COBOL: ✓ компиляция чистая
- Cargo: ✓ build / clippy чисто (1 pre-existing dead_code)
- 300 ходов: 1.5 сек, без падений
- Integrity 10/10: world.dat=190, классы=100, tension≤100, cons≤100
- Replay-safe сохранён

### События за 300 ходов

```
WAR-START: 190    WAR-END: 188      REVOLUTION: 82
MODE-SHIFT: 35    CLASS-WAR: 30     COLLAPSE: 22    REBIRTH: 20
FAMINE: 141       EPIDEMIC: 9
RULER-DEATH: 60   RULER-RISE: 162
REFUGEES: 62      CRISIS: 456
```

vs Phase 9: `WAR: 170, REV: 86, COLLAPSE: 15, FAMINE: 268`. В Phase 10 коллапсов больше (22 vs 15) — вероятно потому, что миграция делает соседей принимающих беженцев нестабильнее. Famine рассыпан по всему миру, а не концентрирован у одного.

### Файлы

- `cobol/world.cob` — random стартовое имя
- `cobol/simulate.cob` — Phase 10 константы, `CLASS-DRIFT-ALL` + 5 параграфов, `DISTRIBUTE-REFUGEES`+`REFUGEE-COUNT-NB`+`REFUGEE-ABSORB-NB`, REVOLUTION class-invariant fix
- `src/ui.rs` — auto-step state, 500мс trigger, `[A]` toggle, footer indicator

### Что осталось известным (не в скоупе Phase 10)

- Conscious contagion всё ещё через `tension≥90` proxy, не через persistent revolution flag — мелочь, не влияет на gameplay
- В Phase 11+ начинается тяжёлая часть (эпохи, древо технологий)

## [Phase 11 — Эпохи и империалистическая война] 2026-04-26

Расширение модусной лестницы с 3 до 7 ступеней. Мир «начинается с малого» (PRIMITIVE/SLAVE) и может дойти до позднего капитализма (INDUSTRIAL/IMPERIAL).

### Что сделано

**1. Расширенная лестница эпох** — 7 продуктивных модусов + COLLAPSED:

| Модус | EFF×1000 | Маркс |
|---|---|---|
| PRIMITIVE | 400 | первобытнообщинная |
| SLAVE | 750 | рабовладельческая |
| FEUDAL | 1000 | манориальная |
| MERCANTILE | 1100 | торговый капитал |
| PROTO-INDUSTRL | 1375 | мануфактурная |
| INDUSTRIAL | 1700 | фабричный капитал |
| IMPERIAL | 2200 | финансовый капитал, монополии |

**2. Четыре новых mode-shift transitions:**
- **PRIMITIVE → SLAVE**: pop > 200K ∧ capital > 5K, 30‰ base, AMBITIOUS/CRUEL +30‰
- **SLAVE → FEUDAL**: capital > 50K ∧ nobility ≥ 5, 50‰ base, PIOUS +30‰
- **PROTO-IND → INDUSTRIAL**: capital > 20M ∧ artisans > 30, 250‰ base
- **INDUSTRIAL → IMPERIAL**: capital > 100M ∧ **merchants ≥ 15**, 200‰ base, AMBITIOUS/CRUEL +30‰

`merchants` вместо `nobility` для IMPERIAL — потому что после революций аристократия уничтожена. Ленинская стадия требует финансовой буржуазии, не феодальной знати. Это и марксистски правильнее.

**3. Имперская война (4-й тип, давно обещанный)**
- `IMPERIAL-WAR-CHECK`: триггер `(mode=INDUSTRIAL ∨ IMPERIAL) ∧ trade_balance < -500`
- `IMPERIAL-WAR-TARGET`: вероятность `350‰ × |deficit|/1000`, cap 600‰
- Альянс блокирует. Trait биас (AMBITIOUS/CRUEL +, CAUTIOUS/PIOUS −, MERCANT слегка −)
- Хроника: «Sigurd of Ironmarch declares imperial war on Ashvale»
- War-resolve и victory не меняются — те же механики

**4. world.cob стартовые условия**
- DESERT, SWAMP → PRIMITIVE
- Все остальные → SLAVE
- Начальный капитал 500 (был 1000) — чтобы не проскакивать ранние эпохи

**5. UI**
- Цвета модуса в таблице регионов и detail panel:
  - PRIMITIVE: DarkGray, SLAVE: Yellow, FEUDAL: White
  - MERCANTILE: LightGreen, PROTO-INDUSTRL: LightCyan
  - INDUSTRIAL: LightBlue, IMPERIAL: LightMagenta
  - COLLAPSED: Red
- В detail panel `Mode:` строка теперь жирная и цветная

**6. APPLY-TRAIT-BIAS расширен**
Добавлены биасы для новых событий: MODE-SLAVE, MODE-FEUDAL, MODE-INDUSTRIAL, MODE-IMPERIAL, IMPERIAL-WAR.

### Тесты (500 ходов)

- COBOL: ✓ компиляция чистая
- cargo build: ✓ (1 pre-existing warning)
- 500 ходов: 2.2 сек
- Integrity 10/10: world.dat=190, классы=100, tension/cons ≤ 100
- Replay-safe сохранён

### Результаты эволюции (один прогон, 500 ходов)

```
=== Финальное распределение модусов ===
PROTO-INDUSTRL  4
INDUSTRIAL      2
IMPERIAL        1   ← Ironmarch достиг (Sigurd, PIOUS)
FEUDAL          2
COLLAPSED       1

=== История переходов ===
Total MODE-SHIFT: ~70
Slave→Feudal: ~10 (быстрая стадия)
Feudal→Mercantile: ~30
Mercantile→Proto-Ind: ~25
Proto-Ind→Industrial: ~5
Industrial→Imperial: 1

=== Войны ===
WAR-START: 305    Imperial wars: 44 (~14%)
```

Видно структурное чередование: империи (INDUSTRIAL/IMPERIAL) воюют чаще из-за дефицита торгового баланса. Frostfen (стартовал PRIMITIVE!) к ходу 500 имеет 875M капитала, но снова FEUDAL после нескольких циклов collapse-rebirth.

### События — пример хронологии

```
0001 MODE-SHIFT  Ironmarch  Slave -> Feudal. Manorial order replaces antiquity.
0007 MODE-SHIFT  Ironmarch  Feudal -> Mercantile. Trade capital accumulated.
0028 MODE-SHIFT  Ironmarch  Mercantile -> Proto-Industrial. Manufactures rise.
0125 MODE-SHIFT  Frostfen   Feudal -> Mercantile. Trade capital accumulated.
0142 MODE-SHIFT  Frostfen   Proto-Ind -> Industrial. Factory wage labour wins.
0143 WAR-START   Thornwall  Erik of Thornwall declares imperial war on Frostfen.
0168 MODE-SHIFT  Ironmarch  Industrial -> Imperial. Finance capital and monopoly.
```

Это уже похоже на реальную хронологию: античность → средневековье → индустриализация → империализм → войны за рынки.

### Файлы

- `cobol/world.cob` — стартовый модус по terrain, низкий начальный капитал
- `cobol/simulate.cob` — Phase 11 константы, 4 новых ветки в ACCUMULATE-ALL, IMPERIAL-WAR-CHECK + IMPERIAL-WAR-TARGET, расширенный APPLY-TRAIT-BIAS, PRODUCE-ALL для 7 эпох
- `src/ui.rs` — `mode_color` helper, цвета в таблице и detail

### Известное / на будущее

- **Класс composition не консистентна для PRIMITIVE/SLAVE**: стартовые классы — те же, что были для FEUDAL (peasants ~65, nobility ~7). Drift и переходы выровняют, но идейно правильно — настроить отдельно. Phase 12+.
- **SOCIALIST как 8-я эпоха**: пока не введён. Был задуман как post-revolution в IMPERIAL. Кандидат на следующую фазу.
- **PRIMITIVE→SLAVE редкий переход**: с pop > 200K порогом многие регионы стартуют выше (Ironmarch 1.2M) и проскакивают сразу к SLAVE→FEUDAL. По хронологии — реалистично (письменная история начинается с государства).

## [Phase 12 — Наблюдаемость] 2026-04-26

UI-only фаза. Никаких изменений в COBOL — добавлено три инструмента наблюдения за уже-работающей симуляцией.

### Что добавлено

**1. Sparklines в detail panel — 3 мини-графика (50 ходов)**

Внизу detail-секции для выбранного региона теперь показывается история:
```
─ Trends 50yr ─
tens  ▁▂▄▆█▇▅▃▂▁▁▂▄▆▇█
pop   ▁▁▂▃▅▆▇█▇▆▅▄▃▂▁▁
cap   ▁▁▂▄▆▇▇████▇▆▆▅▄
```

— класс. напряжение жёлтым, население голубым, капитал светло-зелёным. Сразу видно: «регион в спирали последние 30 лет», «капитал взорвался после mode-shift», «население сжимается из-за войн».

**Реализация:** новый модуль `src/history.rs` с `WorldHistory` и `RegionHistory<VecDeque>`. Хранит последние 50 ходов на регион. Per-session — не персистится в файл; начало новой сессии = пустая история, заполняется по мере наблюдения.

`record_if_new_year(year, regions, |r| (tension, pop, capital))` вызывается каждую итерацию main loop, но фактически пишет только если год сменился (защита от шума).

**2. Chronicle filter — клавиша [F]**

Циклически переключается между:
- `all` — все события (default)
- `wars` — WAR-START / WAR-END
- `politics` — REVOLUTION / COLLAPSE / REBIRTH / CLASS-WAR / RULER-DEATH / RULER-RISE
- `climate` — EPIDEMIC / DROUGHT / CAVE-IN / BUMPER-CROP / BAD-HARVEST / STORM / BLIGHT / FAMINE
- `region` — только события текущего выбранного региона

Заголовок секции хроники меняется: ` Chronicle [filter: wars] `. Полезно когда мир насыщен и хочется отследить что-то конкретное.

**3. Dashboard / World view — клавиша [W]**

Toggle между detail panel выбранного региона и панелью мирового состояния:

```
┌ World ──────────────────┐
│  Year 0245              │
│                         │
│ Total pop:    24.5M     │
│ Total cap:    1.2B      │
│ Active wars:    3       │
│                         │
│ Era distribution:       │
│   PRIMITIVE     ░  1   │
│   SLAVE         ░░ 2   │
│   FEUDAL        ░░░ 3  │
│   MERCANTILE    ░░ 2   │
│   PROTO-INDUSTRL ░ 1   │
│   IMPERIAL      ░ 1    │
│                         │
│ Most warlike:  Ironmarch (war yr 3)
│ Most rebellious: Goldgate (87)
│ Oldest ruler: Sigurd (age 67, Ashvale)
└─────────────────────────┘
```

Цвета баров эпох совпадают с цветами в таблице — узнаваемо с первого взгляда.

**4. Footer обновлён** — отражает все новые keybinds:
```
[N] Next  [A] Auto: ON  [W] Detail  [F] Filter (wars)  [↑/↓] Region  [Q] Quit
```

Зелёный `Auto: ON`, светло-голубой `[W] World`/`[W] Detail` (показывает активный режим).

### Файлы

- `src/history.rs` — новый модуль (~70 строк)
- `src/main.rs` — `mod history`
- `src/ui.rs`:
  - import `WorldHistory`, `Sparkline`, `Frame`, `Rect`
  - `ChronicleFilter` enum + `next()`, `label()`, `matches()`
  - вынесены `render_detail_with_trends` и `render_dashboard` как функции
  - `render_named_sparkline` helper
  - state: `history`, `chronicle_filter`, `show_dashboard`
  - `[F]` и `[W]` обработчики
  - footer перерисован

### Тесты

- COBOL: ✓ untouched, 100 ходов = 389мс, integrity OK
- cargo build: ✓ (1 pre-existing warning о labour_hours)
- cargo clippy: чисто
- Headless smoke: clean exit с «Device not configured» (нет TTY) — без паник Rust

### Что осталось на следующие фазы

- **Region history page** ([H] на регионе → отдельный экран с полной хроникой региона). Предлагалось в плане Phase 12 — отложено, чтобы не раздуть фазу. Phase 14+.
- **Phase 13 — древо технологий**: уже больший проект. Sparklines будут особенно ценны там — можно следить как «уровень науки» или «уровень индустрии» растёт.

### Маленькая радость

Sparklines + auto-step + dashboard вместе — игрок может включить `[A]`, сесть и за 30 секунд (60 ходов в авторежиме) увидеть как мир развивается. Наблюдаемая комплексность обрела форму.

## [Phase 13 — Древо технологий] 2026-04-26

Большая фаза: 4 ветви технологий по 3 уровня = 12 техов с условиями исследования и эффектами на симуляцию.

### Архитектура

**4 ветви технологий, организованных по марксистским осям:**

| Ветвь | L1 | L2 | L3 |
|-------|-----|-----|-----|
| **Production** (PROD) | Bronze | Iron | Steam |
| **Organization** (ORG) | Coinage | Banking | Joint-Stock |
| **Knowledge** (KNOW) | Writing | Printing | Empiricism |
| **Power** (POW) | Standing-Army | Bureaucracy | Mass-Conscription |

PROD — производительные силы (что и чем делать).
ORG — производственные отношения (как организован труд).
KNOW — надстройка (как объясняется и легитимируется).
POW — государство (как удерживается порядок).

**Хранилище:** новый файл `cobol/tech.dat`, 10 строк × 16 байт. Layout:
```
LLLL PPP PPP PPP PPP
1234 567 890 ABC DEF
```
- 4 цифры levels (0-3) для каждой ветви
- 4 группы по 3 цифры — progress (0-100) к следующему уровню

### Механика исследования

Каждый ход для каждого региона по каждой ветви, если уровень < 3:

```
прогресс +=
  base 2
  + 1 (если MERCANTILE+)
  + 2 (если профильный класс ≥ 20%)
  × 1.5 (если terrain match)
  × 1.5 (если KNOW L3 = Empiricism)
```

Профильные классы:
- PROD ↔ artisans
- ORG ↔ merchants
- KNOW ↔ clergy
- POW ↔ nobility

Terrain match (естественная специализация):
- MOUNTAINS → PROD (рудники, металлургия)
- COAST → ORG (торговые пути, банки)
- PLAINS → KNOW (университеты, аграрная цивилизация)
- FOREST → POW (лучники, гражданская армия)

При progress ≥ 100: уровень++, progress=0, в хронике запись `TECH-LEARNED` с уникальным описанием каждого тех'а.

### Эффекты на симуляцию

| Тех | Где применяется | Эффект |
|-----|-----------------|--------|
| Bronze (PROD L1) | PRODUCE-ALL | output × 1.05 |
| Iron (PROD L2) | CALC-MILITARY | military × 1.3 |
| Steam (PROD L3) | PRODUCE-ALL | output × 1.20 (поверх Bronze) |
| Coinage (ORG L1) | — | базовый множитель торгового баланса (через рост capital) |
| Banking (ORG L2) | PRODUCE-ALL | capital_acc × 1.3 |
| Joint-Stock (ORG L3) | PRODUCE-ALL | capital_acc × 1.5 (поверх Banking) |
| Writing (KNOW L1) | CONSCIOUSNESS-ALL | +1/ход |
| Printing (KNOW L2) | CONSCIOUSNESS-ALL | +2/ход (заменяет Writing) |
| Empiricism (KNOW L3) | TECH-RESEARCH-ALL | global research speed × 1.5 |
| Standing-Army (POW L1) | CALC-MILITARY | + 1000 базы |
| Bureaucracy (POW L2) | SOCIAL-ALL | tension delta × 2/3 (стабилизация) |
| Mass-Conscription (POW L3) | CALC-MILITARY | × 2 |

Эффекты накапливаются естественно: Ironmarch с Bronze + Iron + Steam + Banking + Joint-Stock получает производственный buff и быстрое накопление капитала, что ускоряет переход к IMPERIAL.

### Файлы

- `cobol/simulate.cob` — Phase 13 константы, новые поля `WS-TECH-LEVEL/PROGRESS`, параграфы `LOAD-TECH`, `WRITE-TECH`, `TECH-RESEARCH-ALL`, `TECH-COMPUTE-INC`, `CHRON-TECH-LEARNED`. Эффекты вшиты в PRODUCE-ALL, CONSCIOUSNESS-ALL, CALC-MILITARY, SOCIAL-ALL.
- `cobol/tech.dat` — новый файл состояния (10 × 16 байт)
- `src/tech.rs` — новый модуль, парсер `parse_tech` + `RegionTech` + имена техов
- `src/main.rs` — `mod tech`
- `src/engine.rs` — создание пустого tech.dat если нет
- `src/ui.rs` — Tech блок в detail panel (4 строки, статус каждой ветви), цвет TECH-LEARNED в хронике (LightCyan), цвет REFUGEES (LightYellow) добавлен заодно

### Прогресс наблюдения (одна сессия)

```
Year 50: разнообразие — кто-то DONE в одной ветке (Stonehold MOUNTAINS → PROD),
         кто-то на L1 везде. Frostfen ещё на L0 (стартовая PRIMITIVE).

Year 100: большинство на L2-3, лидеры (Ironmarch INDUSTRIAL) уже DONE везде.

Year 150-200: все 10 регионов maxed.
```

Это даёт ~150 ходов осмысленной тех-истории. После этого технологический ландшафт стабилизируется, но политика и войны продолжают меняться.

### Тесты

- COBOL: ✓ компиляция чистая
- cargo build / clippy: ✓ (1 pre-existing warning)
- 500 ходов: 2.3 сек
- Integrity 10/10: world.dat=190, tech.dat=16, классы=100
- TECH-LEARNED: 120 событий за 500 ходов (12 техов × 10 регионов = 120 максимум)

### UI

В detail panel добавлен компактный блок:
```
─ Tech ─
  prod Bronze     L1+▓▓▓░░░░░░░ 32%
  org  Coinage    L1+▓▓▓▓▓▓▓░░░ 67%
  know Writing    L1+▓░░░░░░░░░ 13%
  pow  StandArm   DONE
```

Когда уровень `< 3`, показывается прогресс-бар. На L3 (max) — `DONE` зелёным.

В хронике события TECH-LEARNED светятся цианом:
```
0027 TECH-LEARNED  Ironmarch  Writing spreads. Knowledge persists across generations.
```

### Что НЕ сделано (Phase 14+)

- **Конфликты ветвей** (Religion ↔ Empiricism penalty) — обсуждалось как Phase 14
- **Синергии** (Banking + Joint-Stock + Manufacturing = capitalist core bonus)
- **Диффузия** (если у соседа изучен Iron, у нас +50% к скорости PROD L2)
- **Военный грабёж** (победитель войны получает 1 случайный тех проигравшего)
- **Параллельные треки** ограничены capital — пока все 4 ветви всегда исследуются параллельно

Это естественно ложится на следующую фазу. Текущая база достаточна для наблюдения интересной тех-истории.

## [Phase 14 — Полная тех-механика] 2026-04-26

Расширение базового древа технологий тремя механиками: диффузией, синергиями/конфликтами между ветвями, военным грабежом.

### Что добавлено

**1. Диффузия технологий**

Если у любого соседа уровень в этой ветви выше нашего, мы получаем **+50%** к скорости исследования этой ветви. Имитирует историческое заимствование («комбинированное и неравномерное развитие» по Троцкому): отстающие догоняют быстрее, копируя готовое.

Реализация:
```cobol
PERFORM TECH-DIFFUSION-NB VARYING WS-NIDX FROM 1 BY 1
    UNTIL WS-NIDX > 3 OR WS-DIFFUSION-FOUND = 1
IF WS-DIFFUSION-FOUND = 1
    COMPUTE WS-TECH-INC = WS-TECH-INC * 3 / 2
END-IF
```

Эффект: естественный «выравнивающий» механизм. Пионер в ветви опережает на ~30-50 ходов, потом соседи догоняют.

**2. Синергии и конфликты между ветвями**

Каждая ветвь биасится наличием других:

| Ветвь | Синергии (+%) | Конфликты (−%) |
|-------|---------------|-----------------|
| **PROD** | KNOW≥1: +10%, ORG≥1: +15% | POW≥2: −10% (бюрократия отвлекает) |
| **ORG** | KNOW≥2: +15% (Printing) | POW≥1: −20% (постоянная армия душит торговлю) |
| **KNOW** | ORG≥1: +15% (Coinage финансирует университеты) | POW≥1: −15% (государство контролирует мысль) |
| **POW** | PROD≥1: +20% (Bronze→оружие) | ORG≥2: −15% (Banking сопротивляется милитаризму) |

Это создаёт **тактические дилеммы**: милитаристский регион плохо развивает торговлю и знание; коммерческий — плохо военку. Регионам надо балансировать.

**Минимум 1 прогресс/ход** даже после всех штрафов — иначе ветвь могла бы стагнировать.

**3. Военный грабёж технологий**

После каждого `WAR-VICTORY` победитель получает +1 к первой ветви, в которой проигравший опережал. Имитирует захват архивов, найм пленных инженеров, контрибуции технологиями.

Хроника пишет конкретное событие:
```
0030 TECH-LOOT  Frostfen    Frostfen seizes Ironmarch's Writing.
0035 TECH-LOOT  Embervast   Embervast seizes Cinderkeep's Iron.
0042 TECH-LOOT  Saltmere    Saltmere seizes Cinderkeep's Iron.
```

Это исторически правдоподобно: римляне копировали греческую инженерию, монголы перенимали огнестрел, СССР захватывал немецкие ракеты.

### Файлы

- `cobol/simulate.cob`:
  - `TECH-COMPUTE-INC` расширен: диффузия + синергии/конфликты между ветвями + минимум 1
  - Новый параграф `TECH-DIFFUSION-NB` (проверка соседей)
  - Новый параграф `WAR-TECH-LOOT`, вызывается в конце `WAR-VICTORY`
  - Новые поля: `WS-DIFFUSION-FOUND`, `WS-LOOT-BRANCH`, `WS-LOOT-LEVEL`, `WS-LOOT-NAME`
- `src/ui.rs`:
  - `TECH-LOOT` цвет в хронике (Magenta)
  - `Politics` фильтр включает `TECH-LOOT`

### Тесты

- COBOL: ✓ компиляция чистая
- cargo build / clippy: ✓ (1 pre-existing warning)
- 300 ходов: 1.5 сек
- Integrity 10/10

### События за 300 ходов

```
TECH-LEARNED: 91     (естественные открытия)
TECH-LOOT:    29     (захваты с войн)
```

29 grab'ов за 300 турниров — это ~10% войн дают тех-grab. Реалистично: не каждая война приводит к технологическому переносу, но достаточно часто чтобы держать техно-ландшафт текучим.

### Эффекты диффузии и конфликтов

Сравнить с Phase 13:
- Phase 13: 120 TECH-LEARNED за 500 ходов = 24/100 ходов
- Phase 14: 91 TECH-LEARNED + 29 TECH-LOOT за 300 ходов = 40/100 ходов

Сильно ускорилось — диффузия делает мировую тех-историю **общим достоянием**, как и должно быть. Регионы достигают maxed-out быстрее (год ~150-200 вместо 250-300), но между ними меньше диспропорций.

Конфликты замедляют POW-heavy регионы в KNOW/ORG. Это видно если запустить с ECOS_DEBUG=1: вычислить корреляцию между POW level и средним приростом ORG/KNOW.

### Что осталось на следующее (Phase 15+)

- **Параллельные треки** ограничены capital (сейчас все 4 ветви всегда развиваются параллельно)
- **Cultural drift** — militaristic/mercantile/religious score региона
- **Innovations** как rare events (Iron Plow, Printing Press с уникальными мировыми эффектами)
- **SOCIALIST mode** как post-revolution в IMPERIAL

Phase 14 закрывает основную тех-функциональность из roadmap. Дальше — расширения и углубление.

## [Phase 15 — Идентичность, инновации, социализм] 2026-04-26

Завершающая фаза основной дорожной карты. Три фичи: культурный дрейф, инновации, социалистический режим.

### 1. Cultural drift

Каждый регион имеет 3 культурных вектора (0..100):
- **militaristic** — растёт от военных побед (+5/победа), объявления войн (+1)
- **mercantile** — растёт +1/ход при MERCANT-правителе
- **religious** — растёт +1/ход при PIOUS, +3 после катастроф (эпидемия)

Распад: каждые 5 ходов −1 на каждый ненулевой вектор (без подкрепления культура медленно стирается).

**Влияние:** при сильной культуре (≥50) при наследовании трейта правителя 70% шанс взять профильный:
- mil ≥ 50 → AMBITIOUS или CRUEL (50/50)
- merc ≥ 50 → MERCANT
- rel ≥ 50 → PIOUS

Это создаёт **региональную идентичность через поколения**: торговая Ashvale всегда находит купеческих правителей, религиозная Duskveil — благочестивых, военная Thornwall — амбициозных или жестоких.

**Хранение:** добавлено 9 байт в world.dat (190 → **199** байт): culture_mil, culture_merc, culture_rel.

### 2. Innovations

Раз в 50-200 ходов на регион выпадает уникальное «изобретение» с одноразовым эффектом. Условия:
- Capital > 100K (нужна научная база)
- Конкретные tech-prerequisites

| Innovation | Условия | Эффект |
|------------|---------|--------|
| **Iron Plow** | PROD ≥ 1, GRAIN/TIMBER | labour × 1.20 |
| **Printing Press** | KNOW ≥ 2 | +20 self consciousness, +5 каждому соседу |
| **Double-Entry** | ORG ≥ 1, merchants ≥ 15 | capital +200K |
| **Compass** | COAST + ORG ≥ 1 | trade_balance +500 |
| **Gunpowder** | PROD ≥ 1 + POW ≥ 1 | military +5000, mil culture +5 |

Хроника:
```
0128 INNOVATION Goldgate    Printing press! Ideas multiply.
0146 INNOVATION Saltmere    Double-entry bookkeeping! Capital books accelerate.
0180 INNOVATION Thornwall   Gunpowder! Battlefields transformed.
```

5 типов × разные условия = реалистичный исторический рандом. Saltmere (COAST + commerce) получает Compass и Double-Entry; Thornwall (PLAINS + военная культура) — Gunpowder.

### 3. SOCIALIST mode

8-й (и последний) модус в марксистской лестнице. Триггер: **REVOLUTION в IMPERIAL → SOCIALIST**.

Свойства:
- **eff = 1.9** (между PROTO-IND и IMPERIAL — плановая экономика менее свободна, но без расточительности конкуренции)
- **surplus_rate = 5%** (низкая эксплуатация — рабочие контролируют средства производства)
- Хроника: «Imperial -> Socialist. Workers control means of production.»
- Цвет в TUI: красный (`Color::Red`)

Логика: империалистическая революция в позднюю стадию капитализма ведёт не к коллапсу, а к качественному скачку формации. После 500 ходов в моих тестах: 4 региона достигли SOCIALIST (Ironmarch на ходу 144, Goldgate 383, Ashvale 421, Stonehold 426).

### Файлы

- `cobol/world.cob` — 3 culture поля, инициализация 0
- `cobol/simulate.cob`:
  - Phase 15 константы (CULTURE-*, INNOVATION-*)
  - WS-MODE-SOCIALIST + EFF-SOCIALIST-X1000
  - PARSE-RECORD/WRITE-WORLD расширены на culture
  - PRODUCE-ALL обработка SOCIALIST в EVALUATE
  - REVOLUTION → переход IMPERIAL в SOCIALIST
  - Новые параграфы: `CULTURE-DRIFT-ALL`, `INNOVATION-CHECK-ALL`, `PICK-INNOVATION`, `PRINTING-NB-SPREAD`
  - SUCCESSION расширен culture-биасом трейта
  - WAR-VICTORY: +5 mil culture победителю
  - EVT-EPIDEMIC: +3 rel culture (страх → молитва)
- `src/world.rs` — Region расширен 3 culture полями, новая раскладка 199 байт
- `src/ui.rs` — culture блок в detail panel (символы ⚔ 💰 ☩), SOCIALIST в mode_color (красный), INNOVATION цвет в хронике (LightYellow)

### Тесты пройдены

- ✓ COBOL компиляция чистая
- ✓ cargo build, 1 pre-existing warning
- ✓ 500 ходов = 2.3 сек
- ✓ Integrity 10/10: world.dat=199, classes=100, tension/cons/culture все ≤100
- ✓ 17 INNOVATIONs, 4 SOCIALIST переходов, ~280+ TECH событий — мир насыщен

### Финальные культурные идентичности (одна сессия, год 500)

```
Region       Mode             Mil Merc  Rel  Trait
Ironmarch    SOCIALIST         99    0    0  AMBITIOUS
Ashvale      PROTO-INDUSTRL    40   99   16  MERCANT     ← мерч культура
Duskveil     PROTO-INDUSTRL    10   11   99  PIOUS       ← рел культура
Thornwall    FEUDAL            95    0   38  CRUEL       ← военная
Embervast    PROTO-INDUSTRL     1    0   96  CRUEL       ← рел+воен микс
Saltmere     SLAVE             17   99   46  MERCANT     ← торговая
```

Видна корреляция трейтов с культурой: MERCANT регионы накапливают merc, PIOUS — rel, AMBITIOUS/CRUEL — mil. Это **emergent**: ни одно правило явно не связывает их, но через succession bias культура сама себя воспроизводит. История становится «характерной».

### Phase 15 — что закрывает roadmap

| Идея | Статус |
|------|--------|
| Class drift | ✅ Phase 10 |
| Migration | ✅ Phase 10 |
| Auto-step | ✅ Phase 10 |
| Эпохи (PRIMITIVE..IMPERIAL) | ✅ Phase 11 |
| Imperial wars | ✅ Phase 11 |
| Sparklines + dashboard + filter | ✅ Phase 12 |
| Базовое древо (4×3 техов) | ✅ Phase 13 |
| Диффузия + грабёж + конфликты | ✅ Phase 14 |
| Cultural drift | ✅ Phase 15 |
| Innovations | ✅ Phase 15 |
| SOCIALIST mode | ✅ Phase 15 |

Дорожная карта проекта **закрыта**.

### Что осталось как «дальше»
- Save/load слоты мира
- Региональная история ([H] клавиша → полная страница)
- ASCII-карта вместо таблицы
- Player agency (если когда-нибудь)

## [Phase 16 — Визуализация древа технологий] 2026-04-26

Первая из трёх фаз большого структурированного плана по расширению tech tree (Phase 16-17-18). Эта — UI-only, никаких COBOL изменений. Цель: сделать видимым то, какой путь регион прошёл по дереву.

### Что добавлено

**1. DetailView enum** заменил `show_dashboard: bool`:
- `DetailView::Region` (default) — региональные детали
- `DetailView::Dashboard` — мировая сводка ([W] toggle)
- `DetailView::TechTree` — древо технологий ([T] toggle, новое)

Toggling: `[W]` циклирует Region ↔ Dashboard, `[T]` циклирует Region ↔ TechTree. Mutually exclusive.

**2. Tech Tree view**

Layout 4×3:
```
┌ Tech ─────────────────────────────────────────┐
│  Tech Tree — Ironmarch                         │
│                                                │
│            L1            L2            L3      │
│  PROD     ✓Bronze        ✓Iron        ⏳Steam 67%
│  ORG      ✓Coinage       ⏳Banking 34% ░Joint-Stk
│  KNOW     ✓Writing       ⏳Printing 78%░Empiric
│  POW      ⏳StandArm 89%  ░Bureaucracy ░MassCnsr
│                                                │
│  Legend: ✓ done   ⏳ researching   ░ locked   │
│  Total tech levels: 7/12                       │
└────────────────────────────────────────────────┘
```

**Цветовая схема:**
- ✓ done — Green (изучено)
- ⏳ researching N% — Yellow (текущий уровень в работе)
- ░ locked — DarkGray (требует предыдущего уровня)

Названия ветвей цветные: PROD/ORG/KNOW/POW в LightYellow/LightCyan/LightMagenta/LightRed (визуально отличает оси).

**Total tech levels** внизу — суммарный счётчик 0..12, с зелёным выделением при maxed (12/12).

**3. Footer обновлён** — два отдельных переключателя:
```
 [N] Next [A] Auto: ON  [W]orld [T]ech View: Tech    [F] all  [↑↓] [Q]
```

Цвет `View: ...` отражает текущий режим: серый для Region, голубой для Dashboard, светло-зелёный для TechTree.

### Файлы

- `src/ui.rs`:
  - Новый `DetailView` enum
  - Заменён `show_dashboard: bool` на `view: DetailView`
  - Новые функции: `render_tech_tree`, `tech_cell`
  - Обновлён dispatch в main render block (`match view`)
  - `[T]` handler добавлен
  - Footer переписан с двумя индикаторами

### Тесты

- ✓ cargo build, cargo clippy чисто
- ✓ COBOL не тронут (50 ходов прогон OK, integrity OK)
- ✓ Headless TUI: clean exit без паник

### Что дальше — Phase 17 (расширение)

В Phase 16 показали то, что есть. Phase 17 расширит дерево:

- Каждая L3 разветвится на 2-3 альтернативы
- Условия выбора при разветвлении (terrain/класс/трейт)
- tech.dat формат изменится (нужно знать какой L3 выбран)
- Визуализация в Phase 16 расширится для показа выбранной ветви

После Phase 17 будет ~20 техов вместо 12, с реальными «или/или» развилками.

Phase 18 добавит L4 sub-sub-branches (моторы → бензин/спирт/паровая турбина и т.п.), доводя до ~30+.

## [Phase 17 — Развилки L3] 2026-04-26

Вторая из трёх фаз большого плана расширения tech tree. Каждая ветвь на L3 теперь разветвляется на 3 альтернативы. Регион выбирает путь по условиям — терен, класс, режим, трейт правителя, культура.

### Что добавлено

**1. Развилки L3 — 12 новых техов (4 ветви × 3 альтернативы):**

| Ветвь | L3 alt 1 | L3 alt 2 | L3 alt 3 |
|-------|----------|----------|----------|
| **PROD** | Steam (industrial coal) | Forging (military quality) | Hydraulics (water/wind) |
| **ORG** | Joint-Stock (capital core) | Cooperatives (mutual aid) | Cartels (monopoly) |
| **KNOW** | Empiricism (science) | Scholasticism (religious/legal) | Folk Wisdom (practical crafts) |
| **POW** | Mass Conscription (total mob) | Professional Army (officer corps) | Militia (citizen defense) |

**2. PICK-L3-ALTERNATIVE — взвешенный выбор**

Каждая альтернатива имеет базовый вес (50/30/20) + бонусы от условий региона:

```
PROD L3:
  Steam      +30 если capital > 5M, +20 если INDUSTRIAL/IMPERIAL
  Forging    +30 если MOUNTAINS, +20 если nobility ≥ 5
  Hydraulics +30 если PLAINS/COAST, +20 если MERCANTILE

ORG L3:
  Joint-Stock  +30 если merchants ≥ 15, +20 если MERCANTILE+
  Cooperatives +50 если SOCIALIST, +30 если consciousness ≥ 70
  Cartels      +30 если capital > 5M, +20 если MERCANT-trait

KNOW L3:
  Empiricism    +30 если PROD/ORG ≥ 2, +20 если cons ≥ 50
  Scholasticism +30 если PIOUS-trait, +30 если rel-culture ≥ 50
  Folk Wisdom   +30 если artisans ≥ 30, +20 если PRIMITIVE/SLAVE/FEUDAL

POW L3:
  Mass-Conscr  +30 если pop > 1M, +20 если INDUSTRIAL+, +20 если AMBITIOUS/CRUEL
  Professional +30 если nobility ≥ 5, +20 если capital > 5M
  Militia      +30 если SOCIALIST, +20 если mil-culture ≥ 50
```

После расчёта весов — взвешенный random roll → choice 1/2/3.

**3. tech.dat 16 → 20 байт**

Layout:
```
LLLLPPP PPP PPP PPP CCCC
1234567890123456789012345
```
- 1-4: levels (4 цифры)
- 5-16: progresses по 3 цифры × 4
- 17-20: L3 choices (4 цифры; 0 = ещё не выбрано)

Backwards compat: если строка 16 байт (старый формат), choices = 0. Безопасный апгрейд старых сейвов.

**4. Эффекты L3 alternatives**

Каждая альтернатива модифицирует разные параметры. Вкратце:

| Tech | Эффект |
|------|--------|
| Steam | output × 1.20 |
| Forging | military × 1.30 (на каждом ходу через CALC-MILITARY) |
| Hydraulics | output × 1.15 (немного меньше Steam, но без капитальных требований) |
| Joint-Stock | capital_acc × 1.20 (поверх Banking) |
| Cooperatives | tension_delta / 2 (рабочие довольнее) |
| Cartels | capital_acc × 1.10 |
| Empiricism | research × 1.5 (раньше всегда был — теперь только этот alt) |
| Scholasticism | cons +3/ход, tension_delta × 0.7 (легитимация) |
| Folk Wisdom | cons +1/ход (но создаёт основу для чего-то ещё) |
| Mass-Conscr | military × 2 |
| Professional | military + 8000 fix |
| Militia | military + 3000, tension_delta − 2 (граждане защищают сами) |

Например Cooperatives + Scholasticism + Militia = социалистический регион с религиозной легитимностью и народной обороной — стабильный пацифист. Steam + Joint-Stock + Empiricism + MassConscr = классический индустриальный империалист.

**5. PICK fires в двух местах:**
- TECH-RESEARCH-ALL когда level прокачивается с 2 до 3 естественно
- WAR-TECH-LOOT при грабеже до L3 — копирует L3-CHOICE проигравшего (если есть) или вызывает PICK для победителя

**6. Хроника** для L3 показывает конкретную альтернативу:
```
0046 TECH-LEARNED Stonehold  Hydraulics built. Water and wind drive mills.
0144 TECH-LEARNED Ashvale    Joint-stock companies form. Investment flows.
0182 TECH-LEARNED Duskveil   Scholasticism — sacred texts and law dominate.
```

**7. UI визуализация развилок**

Tech tree view расширен: для каждой ветви показывается L1 → L2 → потом 3 альтернативы L3 на отдельных строках.

```
  PROD ✓Bronze    → ✓Iron       →
              ▶ Steam (chosen)
              · Forging
              · Hydraulics

  ORG  ✓Coinage   → ✓Banking    →
              · JointStk
              ▶ Coopers (chosen)
              · Cartels
```

Выбранный путь — `▶` светло-зелёный, отвергнутые — `·` тёмно-серый.

### Файлы

- `cobol/simulate.cob`:
  - tech.dat 16 → 20 байт
  - WS-TECH-L3-CHOICE OCCURS 4
  - LOAD-TECH/WRITE-TECH с поддержкой нового формата (backwards compat)
  - PICK-L3-ALTERNATIVE + 4 paragraph для каждой ветви (PICK-PROD-L3 etc.)
  - WAR-TECH-LOOT обновлён — копирует L3 choice проигравшего
  - PRODUCE-ALL: эффекты Steam vs Forging vs Hydraulics
  - CONSCIOUSNESS-ALL: эффекты Empiricism vs Scholasticism vs Folk Wisdom
  - CALC-MILITARY: эффекты Forging + POW L3 alternatives
  - SOCIAL-ALL: tension эффекты Cooperatives, Scholasticism, Militia
  - TECH-COMPUTE-INC: Empiricism research bonus только для alt 1
  - CHRON-TECH-LEARNED: специфичные тексты для каждой L3 alt
- `src/tech.rs`:
  - Расширен `RegionTech` с `l3_choice: [u8; 4]`
  - Новая константа `L3_ALTERNATIVES`
  - `current_tech_name` использует choice для L3
  - Парсер знает 20-байт формат
- `src/ui.rs`:
  - Импорт `L3_ALTERNATIVES`
  - Расширенный `render_tech_tree` с развилкой на отдельных строках
  - Новая функция `tech_l3_alt` (▶ chosen / · alternative)

### Тесты

- COBOL: ✓ компиляция чистая
- cargo build / clippy: ✓ (1 pre-existing warning)
- 500 ходов: 1.9 сек
- Integrity 10/10: world.dat=199, tech.dat=20, классы=100
- Все 12 L3 альтернатив получают reasonable shares (см. ниже)

### Распределение L3 picks (одна сессия, 500 ходов)

```
PROD L3:  Forging 2,  Hydraulics 5,  Steam 3        (Hydraulics популярна — много coast/plains)
ORG L3:   JointSt 5,  Coopers 4,    Cartels 1       (Cartels редкие — нужен MERCANT-правитель)
KNOW L3:  Scholas 2,  Empiric 6,    FolkWis 2       (Empiric доминирует — наука выгодна)
POW L3:   MassCon 7,  ProfArm 2,    Militia 1       (массовый призыв общий)
```

Распределение реалистичное: некоторые альтернативы редкие (Cartels, Militia) — они требуют специальных условий (MERCANT-правитель / SOCIALIST режим), поэтому появляются только когда история сложилась правильно.

### Финальные тех-траектории (примеры из сессии)

```
Ironmarch    Forging    JointStk   Scholas    MassCon  ← индустр.воин со схоластикой
Stonehold    Hydraulics Coopers    FolkWis    MassCon  ← горный кооператив
Goldgate     Steam      JointStk   Empiric    ProfArm  ← классическая капиталистическая
Duskveil     Steam      JointStk   Empiric    Militia  ← капитализм с civic-defense
Saltmere     Steam      Coopers    Empiric    MassCon  ← рабочее научное государство
Frostfen     Hydraulics Coopers    Scholas    MassCon  ← сельская коммуна с религией
```

Каждый регион теперь имеет **уникальную идеологию**, выраженную через комбинацию 4 L3 альтернатив. 3⁴ = 81 возможная комбинация — у 10 регионов вероятность всем выбрать разное велика.

### Что дальше — Phase 18

L4 sub-sub-branches. Каждый L3 alt может развиться в 2-3 sub-tech'а:
- Steam → Gasoline / Alcohol / Steam Turbine
- Empiricism → Scientific Method / Specialization
- Mass-Conscription → Total War / Reserves
- ...

Это добавит ещё 30+ техов и сделает 4-уровневую глубину. Tech tree view нужно будет ещё расширить.

## [Phase 18 — L4 Sub-Sub-Branches] 2026-04-26

Финальная фаза tech tree расширения. Каждая L3 альтернатива получает 2 L4 sub-tech'а — добавляется четвёртый уровень глубины. Tech tree теперь полноценный DAG с 44 техами (4×L1 + 4×L2 + 12×L3 + 24×L4).

### Что добавлено

**1. Новые 24 L4 sub-techs (по 2 на каждую L3 alt):**

| L3 alt | L4 sub 1 | L4 sub 2 |
|--------|----------|----------|
| **Steam** (PROD) | Gasoline | Turbine |
| **Forging** (PROD) | Damascus | Crossbow |
| **Hydraulics** (PROD) | WindTurb | TidalMl |
| **Joint-Stock** (ORG) | StockMkt | LimLiab |
| **Cooperatives** (ORG) | MutAid | WorkOwn |
| **Cartels** (ORG) | Trusts | VertInt |
| **Empiricism** (KNOW) | SciMeth | Special |
| **Scholasticism** (KNOW) | Theology | ComLaw |
| **Folk Wisdom** (KNOW) | OralTrad | PracCrft |
| **MassConscr** (POW) | TotalWar | Reserves |
| **ProfArmy** (POW) | OffCorps | SpecOps |
| **Militia** (POW) | CitArmy | Guerrilla |

Условия выбора L4 — взвешенный random, зависящий от L3 choice + текущего состояния региона. Например:
- Steam → Gasoline (mass market) если merchants ≥ 15, → Turbine (heavy industry) если INDUSTRIAL+
- Cooperatives → WorkOwn если SOCIALIST режим, → MutAid если высокая rel-culture
- MassConscr → TotalWar если mil-culture ≥ 70, → Reserves если ниже

**2. tech.dat 20 → 24 байт** (+ 4 чара для L4 choice)

Layout:
```
LLLL PPP PPP PPP PPP CCCC DDDD
1234 567 890 ABC DEF 17-20 21-24
```
- L: levels (теперь 0..4)
- P: progresses
- C: L3 choices
- D: L4 choices  ← новое

Backwards compat: старые сейвы 16/20 байт читаются с zeros для отсутствующих choices.

**3. PICK-L4-SUBTECH** диспатчит на 4 параграфа (PICK-PROD-L4, PICK-ORG-L4, etc.). Каждый разветвляется по WS-TECH-L3-CHOICE и устанавливает веса для 2 sub-tech'ов.

**4. Эффекты L4 sub-techs** — небольшие добавки поверх L3:

| Sub-tech | Эффект |
|----------|--------|
| Gasoline | output × 1.10 (поверх Steam) |
| Turbine | (military в CALC-MILITARY через Forging path не относится; Turbine: косвенный) |
| Damascus | military × 1.15 (поверх Forging) |
| Crossbow | output × 1.05 + military × 1.10 |
| WindTurb/TidalMl | output × 1.05 |
| StockMkt/LimLiab | capital_acc × 1.10 |
| WorkOwn | tension_delta / 2 (рабочие хозяева) |
| Trusts/VertInt | capital_acc × 1.10 |
| SciMeth/Theology/OralTrad | consciousness +1 |
| ComLaw | tension_delta × 0.8 (правовая стабильность) |
| TotalWar | military × 1.20 (поверх Mass Conscription) |
| Reserves | military + 3000 |
| OffCorps | military + 5000 |
| SpecOps | military + 3000 |
| Guerrilla | military + 2000 |

**5. CHRON-TECH-LEARNED** теперь имеет 4 sub-параграфа (CHRON-PROD-L4 и т.д.) для специфичных текстов на L4:

```
0059 TECH-LEARNED Stonehold  Tidal mills harness the coastal sea.
0074 TECH-LEARNED Saltmere   Mutual aid societies organize the workers.
0081 TECH-LEARNED Goldgate   Stock markets open. Speculation as institution.
0117 TECH-LEARNED Embervast  Total war doctrine. Society fully militarized.
0126 TECH-LEARNED Ironmarch  Common law. Precedent over decree.
0126 TECH-LEARNED Thornwall  Scientific method codified. Hypothesis and proof.
```

**6. UI tech tree** расширен — под выбранной L3 alt показываются обе L4 sub-techs:

```
  PROD ✓Bronze → ✓Iron →
              ▶ Steam (chosen)
                  ↳ ✓ Gasoline (chosen)
                  ↳ · Turbine
              · Forging
              · Hydraulics
```

Total tech levels счётчик теперь /16 (4 ветви × 4 уровня).

### Файлы

- `cobol/simulate.cob`:
  - `TECH-MAX-LEVEL` 3 → 4
  - `TECH-REC-LEN` 20 → 24
  - `WS-TECH-L4-CHOICE` OCCURS 4
  - LOAD-TECH/WRITE-TECH с поддержкой 24-байт + backwards compat
  - PICK-L4-SUBTECH + 4 paragraph-диспетчера (PICK-PROD-L4, etc.)
  - TECH-RESEARCH-ALL: при level → 4 вызывает PICK-L4-SUBTECH
  - PRODUCE-ALL: эффекты Gasoline/Turbine/Damascus/Crossbow/WindTurb/TidalMl
  - CALC-MILITARY: эффекты POW L4 (TotalWar/Reserves/OffCorps/SpecOps/Guerrilla)
  - CONSCIOUSNESS-ALL: KNOW L4 sub-effects
  - SOCIAL-ALL: tension эффекты WorkOwn и ComLaw
  - CHRON-TECH-LEARNED: новая ветка для L4 + CHRON-PROD/ORG/KNOW/POW-L4
- `src/tech.rs`:
  - `RegionTech` расширен `l4_choice: [u8; 4]`
  - Новая константа `L4_SUBTECHS[branch][l3_choice][l4_choice]`
  - `current_tech_name` для L4
  - Парсер 24-байт формата
- `src/ui.rs`:
  - Импорт `L4_SUBTECHS`
  - `render_tech_tree` показывает L4 sub-techs под выбранной L3 alt с `↳`
  - Новая функция `tech_l4_alt`
  - Total tech levels /16

### Тесты (500 ходов)

- ✓ COBOL компиляция
- ✓ cargo build / clippy чисто
- ✓ 500 ходов: 1.9 сек
- ✓ Integrity 10/10: world.dat=199, tech.dat=24, классы=100

### Финальные тех-траектории (одна сессия)

```
Region       PROD-L4    ORG-L4   KNOW-L4   POW-L4
Saltmere     Gasoline   MutAid   ComLaw    TotalWar
Embervast    WindTurb   MutAid   Theology  TotalWar
Stonehold    TidalMl    —        Special   Reserves
Duskveil     Turbine    WorkOwn  Special   SpecOps
Goldgate     Turbine    StockMkt —         —
Saltmere     Gasoline   MutAid   ComLaw    TotalWar
```

**44 уникальных техов всего.** На каждое государство — 4 L1 + 4 L2 + 4 L3 (по одному alt) + 4 L4 (по одному sub) = 16 техов в пути. Это даёт **3⁴ × 2⁴ = 1296 возможных «идентичностей»** (комбинаций L3 + L4 выбора). На 10 регионов почти всегда уникальная.

### Завершение тех-расширения

Phase 16-17-18 — большой структурированный план — закончен:
- **Phase 16** дала визуализацию существующего древа
- **Phase 17** добавила 12 L3 альтернатив
- **Phase 18** добавила 24 L4 sub-tech'а

Цивилизации теперь имеют не просто «уровень развития», а **конкретную идеологическую и материальную траекторию**. Saltmere — кооперативно-научно-милитаризованная, Stonehold — горный пацифистский технополис, Goldgate — индустриально-капиталистический. Каждая хроника становится историей выбора.

### Что осталось

Дорожная карта закрыта на 100%. Возможные расширения «дальше»:
- Save/load слоты для интересных миров
- Региональная история ([H] полная страница)
- ASCII-карта мира
- Player agency (если когда-нибудь)
