# Кризис → разорение (реализация стоимости) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Замкнуть контур «кризис → разорение»: рыночная цена начинает влиять на экономику политии — недореализация стоимости обесценивает капитал, рушит зарплаты, плодит безработицу, а обнищание поднимает напряжение и классовое сознание.

**Architecture:** Накопление капитала и расчёт зарплатного фонда выносятся из `PRODUCE-ALL` в новый параграф `REALIZE-ALL` (выполняется после того, как рынок выставил цены). Реализованная стоимость = `output × (цена / базовая цена)`. При обвале цены ниже издержек рабочей силы капитал списывается. Новое персистентное поле `WS-UNEMPLOYMENT-PCT` моделирует резервную армию труда с обратной связью на производство. Все числовые параметры — 78-level константы.

**Tech Stack:** GnuCOBOL 3.2 (`/opt/homebrew/bin/cobc -x -free`), Rust (ratatui TUI), bash-харнесс регрессии `scripts/baseline.sh`.

**Спецификация:** [docs/superpowers/specs/2026-06-01-crisis-immiseration-design.md](../specs/2026-06-01-crisis-immiseration-design.md)

**Тестовая стратегия (адаптация TDD под COBOL-симуляцию):**
- COBOL не имеет unit-фреймворка. «Тест» бывает двух видов:
  - **Регрессия byte-identical** (`scripts/baseline.sh check`) — для шагов, которые НЕ должны менять поведение (добавление неиспользуемого поля, чистый рефакторинг). Эталон снимается в Task 1 от текущего HEAD.
  - **Стресс-тест инвариантов** (`scripts/stress.sh`, создаётся в Task 1) — для шагов, которые МЕНЯЮТ поведение: прогон 1000 ходов + сводка событий и end-state, проверка что мир не вырождается.
- Rust-изменения парсинга/миграции покрываются `cargo test`.

---

## Карта файлов

| Файл | Ответственность | Задачи |
|---|---|---|
| `scripts/stress.sh` | **создать** — прогон N ходов + сводка инвариантов | T1 |
| `cobol/world.cob` | генерация: структура политии, init поля, запись строки | T2 |
| `cobol/simulate.cob` | структура, parse/write, `REALIZE-ALL`, безработица, социология, формат-guard | T2,T3,T4,T5,T6,T7 |
| `src/world.rs` | `Polity` struct + `parse_polities` + layout-комментарий + length-warning | T2,T7 |
| `src/saves.rs` | миграция legacy (формат строки + тест) | T2 |
| `src/ui.rs` | detail-панель: profit rate, unemployment; цвет BANKRUPTCY | T8 |
| `DEVLOG.md` | запись фазы | T9 |

Поле `WS-UNEMPLOYMENT-PCT` добавляется **в конец** записи `polities.dat` (после `MODE-YEARS`) → существующие offset'ы не сдвигаются. Запись: 164 → 167 байт.

---

## Task 1: Инструмент стресс-теста + захват эталона

**Files:**
- Create: `scripts/stress.sh`
- Baseline: `cobol/baseline_*.dat` (генерируются)

- [ ] **Step 1: Создать `scripts/stress.sh`**

```bash
#!/usr/bin/env bash
# Phase 25 — стресс-тест инвариантов экономики (НЕ регрессия byte-identical).
# Прогоняет свежий мир на N ходов и печатает сводку: счётчики событий,
# число живых политий, распределение эпох, диапазон капитала.
# Использование:  TURNS=1000 scripts/stress.sh
set -euo pipefail
cd "$(dirname "$0")/.."
TURNS="${TURNS:-1000}"

rm -f cobol/world.dat cobol/chronicle.dat cobol/market.dat \
      cobol/relations.dat cobol/tech.dat cobol/year.dat \
      cobol/regions.dat cobol/polities.dat
./cobol/world
touch cobol/chronicle.dat cobol/market.dat cobol/relations.dat cobol/tech.dat
for i in $(seq 1 "$TURNS"); do
    printf "%04d\n" "$i" > cobol/year.dat
    ./cobol/simulate >/dev/null
done

echo "=== stress: $TURNS turns ==="
echo "-- event counts (chronicle) --"
cut -c5-19 cobol/chronicle.dat | sort | uniq -c | sort -rn
echo "-- living polities (non-EXTINCT, non-blank) --"
awk 'NF && $0 !~ /EXTINCT/' cobol/polities.dat | wc -l
echo "-- end-state modes --"
cut -c46-60 cobol/polities.dat | sort | uniq -c | sort -rn
```

- [ ] **Step 2: Сделать исполняемым**

Run: `chmod +x scripts/stress.sh`
Expected: без вывода, код 0.

- [ ] **Step 3: Убедиться, что бинарники собраны**

Run: `/opt/homebrew/bin/cobc -x -free cobol/world.cob -o cobol/world && /opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate && echo BUILD-OK`
Expected: `BUILD-OK`

- [ ] **Step 4: Захватить эталон регрессии от текущего HEAD (до любых правок)**

Run: `TURNS=500 scripts/baseline.sh capture`
Expected: `Baseline captured.` и строки `saved cobol/baseline_chronicle.dat ...` для 4 файлов.

- [ ] **Step 5: Прогнать стресс-тест как «снимок до» (для сравнения баланса позже)**

Run: `TURNS=1000 scripts/stress.sh`
Expected: таблица событий (WAR-END, REVOLUTION, MODE-SHIFT, COLLAPSE и т.п.), число живых политий > 0. Сохрани вывод в описание коммита/заметку — это «экономика до фазы».

- [ ] **Step 6: Commit**

```bash
git add scripts/stress.sh
git commit -m "test: стресс-тест инвариантов экономики (scripts/stress.sh)"
```

---

## Task 2: Добавить поле `WS-UNEMPLOYMENT-PCT` (формат, =0, ещё не используется)

Цель: провести новое поле через весь контур COBOL↔Rust **без изменения поведения**. Поле инициализируется нулём и нигде не читается логикой.

**Files:**
- Modify: `cobol/world.cob` (структура, INIT-REGION, INIT-EXTINCT-SLOT, WRITE-POLITY-ROW)
- Modify: `cobol/simulate.cob` (структура, PARSE-POLITY-RECORD, WRITE-WORLD)
- Modify: `src/world.rs` (struct, parse_polities, layout-комментарий)
- Modify: `src/saves.rs` (две format!-строки миграции + ассерт в тесте)

- [ ] **Step 1: `world.cob` — добавить поле в структуру**

В `01 WS-POLITIES OCCURS 30 TIMES`, сразу после `05 WS-MODE-YEARS PIC 9(4).` (строка ~72) добавить:

```cobol
*> Phase 25 — резервная армия труда (доля безработных, 0..100).
   05 WS-UNEMPLOYMENT-PCT  PIC 9(3).
```

- [ ] **Step 2: `world.cob` — инициализация в INIT-REGION**

В конце `INIT-REGION`, после `MOVE WS-IDX TO WS-REGION-ID(WS-IDX).` (строка ~361) — заменить точку на пробел и добавить строку (или добавить отдельным MOVE):

```cobol
    MOVE WS-IDX              TO WS-REGION-ID(WS-IDX)
*>  Phase 25 — стартовая безработица отсутствует.
    MOVE 0                  TO WS-UNEMPLOYMENT-PCT(WS-IDX).
```

- [ ] **Step 3: `world.cob` — инициализация в INIT-EXTINCT-SLOT**

В конце `INIT-EXTINCT-SLOT`, после `MOVE 0 TO WS-MODE-YEARS(WS-IDX).` (строка ~393) — аналогично:

```cobol
    MOVE 0                   TO WS-MODE-YEARS(WS-IDX)
    MOVE 0                   TO WS-UNEMPLOYMENT-PCT(WS-IDX).
```

- [ ] **Step 4: `world.cob` — запись в WRITE-POLITY-ROW**

В `STRING` внутри `WRITE-POLITY-ROW`, после строки `WS-MODE-YEARS(WS-IDX) DELIMITED SIZE` (строка ~505) добавить:

```cobol
        WS-MODE-YEARS(WS-IDX)       DELIMITED SIZE
        WS-UNEMPLOYMENT-PCT(WS-IDX) DELIMITED SIZE
```

- [ ] **Step 5: `simulate.cob` — добавить поле в структуру**

В `01 WS-POLITIES OCCURS 30 TIMES`, после `05 WS-MODE-YEARS PIC 9(4).` (строка ~523):

```cobol
*> Phase 25 — резервная армия труда (доля безработных, 0..100).
   05 WS-UNEMPLOYMENT-PCT  PIC 9(3).
```

- [ ] **Step 6: `simulate.cob` — парсинг в PARSE-POLITY-RECORD**

В конце `PARSE-POLITY-RECORD`, после `MOVE FUNCTION NUMVAL(WS-POLITY-REC(161:4)) TO WS-MODE-YEARS(WS-IDX).` (строка ~887) — заменить завершающую точку и добавить (offset @165, т.к. MODE-YEARS @161 len 4 заканчивается на 164):

```cobol
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(161:4)) TO WS-MODE-YEARS(WS-IDX)
    MOVE FUNCTION NUMVAL(WS-POLITY-REC(165:3)) TO WS-UNEMPLOYMENT-PCT(WS-IDX).
```

Также обновить комментарий-layout над параграфом: добавить строку
`*>    UNEMPLOYMENT    @ 165 len 3   = 167 байт (запись)` и заменить старую пометку «= 164 байт».

- [ ] **Step 7: `simulate.cob` — запись в WRITE-WORLD**

В `STRING` внутри `WRITE-WORLD`, после `WS-MODE-YEARS(WS-IDX) DELIMITED SIZE` (строка ~2651):

```cobol
            WS-MODE-YEARS(WS-IDX)        DELIMITED SIZE
            WS-UNEMPLOYMENT-PCT(WS-IDX)  DELIMITED SIZE
```

- [ ] **Step 8: `src/world.rs` — поле структуры**

В `pub struct Polity`, после `pub mode_years: u16,` (строка ~97) добавить:

```rust
    /// Phase 25 — доля безработных (резервная армия труда), 0..100.
    pub unemployment_pct: u8,
```

- [ ] **Step 9: `src/world.rs` — парсинг**

В `parse_polities`, после `mode_years: parse_u64(slice_or_blank(line, 160, 4)) as u16,` (строка ~199):

```rust
            mode_years:        parse_u64(slice_or_blank(line, 160, 4)) as u16,
            unemployment_pct:  parse_u64(slice_or_blank(line, 164, 3)) as u8,
```

Также в layout-комментарии (строки 23–55) добавить строку `// | unemployment_pct | 164 | 3 |` после `mode_years`.

- [ ] **Step 10: `src/saves.rs` — обе format!-строки миграции**

В `migrate_legacy_slot`, в обоих `format!` (active-полития ~138 и EXTINCT-резерв ~167) добавить ещё одно поле в конец. Для active добавить `"000"` (legacy не имел безработицы):

active (после `mode_years_field,`):
```rust
            "{:20}{}{:8}{:15}{:15}{:10}{:5}{:12}{:3}{:5}{:2}{:3}{:3}{:10}{:20}{:2}{:10}{:3}{:3}{:9}{:4}{:3}\n",
            ...
            mode_years_field,
            "000",
```

EXTINCT (после `"0000", // mode_years`):
```rust
            "{:20}{:2}{:8}{:15}{:15}{:10}{:5}{:12}{:3}{:5}{:2}{:3}{:3}{:10}{:20}{:2}{:10}{:3}{:3}{:9}{:4}{:3}\n",
            ...
            "0000",              // mode_years
            "000",               // unemployment_pct
```

- [ ] **Step 11: `src/saves.rs` — ассерт длины в тесте**

В `legacy_migration_splits_world_dat`, после получения `polities` добавить проверку, что каждая строка теперь 167 символов:

```rust
        for l in polities.lines().filter(|l| !l.is_empty()) {
            assert_eq!(l.len(), 167, "polities.dat line must be 167 bytes after Phase 25");
        }
```

- [ ] **Step 12: Компиляция COBOL**

Run: `/opt/homebrew/bin/cobc -x -free cobol/world.cob -o cobol/world && /opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate && echo OK`
Expected: `OK` (без ошибок/предупреждений компилятора).

- [ ] **Step 13: Проверка длины записи polities.dat = 167**

Run: `./cobol/world && awk '{print length}' cobol/polities.dat | sort -u`
Expected: единственное значение `167`.

- [ ] **Step 14: Регрессия byte-identical (поле не влияет на эталонные файлы)**

Run: `TURNS=500 scripts/baseline.sh check`
Expected: `All matched.` — chronicle/tech/relations/market не изменились (поле =0, не используется).

- [ ] **Step 15: Rust сборка + тест миграции**

Run: `cargo build 2>&1 | tail -3 && cargo test legacy_migration 2>&1 | tail -5`
Expected: сборка без ошибок; тест `legacy_migration_splits_world_dat` — `ok`.

- [ ] **Step 16: Commit**

```bash
git add cobol/world.cob cobol/simulate.cob src/world.rs src/saves.rs
git commit -m "feat(econ): поле WS-UNEMPLOYMENT-PCT в polities.dat (164→167 байт, =0)"
```

---

## Task 3: Рефакторинг — вынести накопление и wage в `REALIZE-ALL` (byte-identical)

Цель: переместить расчёт прибавочной стоимости, накопления капитала и зарплатного фонда из `PRODUCE-ALL` в новый параграф `REALIZE-ALL`, зафиксировав `realize = 1000` (полная реализация). Поведение **не меняется** — контрольная точка корректности.

**Files:**
- Modify: `cobol/simulate.cob` (WORKING-STORAGE, MAIN-PARA, PRODUCE-ALL, +REALIZE-ALL, +ACCUMULATE-TECH-BONUS)

- [ ] **Step 1: WORKING-STORAGE — рабочие переменные реализации**

После `01 WS-SURPLUS-VAL PIC S9(12)V99.` (строка ~428) добавить:

```cobol
*> Phase 25 — реализация стоимости
01 WS-REALIZE-PERMIL    PIC S9(5).
01 WS-REALIZED-OUTPUT   PIC S9(12)V99.
01 WS-REALIZED-PROFIT   PIC S9(12)V99.
01 WS-WAGE-COST         PIC S9(12)V99.
01 WS-LOSS              PIC S9(12)V99.
```

- [ ] **Step 2: PRODUCE-ALL — убрать накопление и wage**

В `PRODUCE-ALL` удалить блок накопления капитала и зарплаты — строки от `*> Прибавочная стоимость: изъятие правящим классом` (после `MOVE WS-OUTPUT-VAL TO WS-OUTPUT-VALUE(WS-IDX)`, ~958) до `COMPUTE WS-WAGE-FUND(WS-IDX) = WS-OUTPUT-VAL - WS-SURPLUS-VAL` включительно (~1000). То есть удаляются строки 958–1000.

После удаления хвост ветки `IF NOT POLITY-DORMANT` в PRODUCE-ALL заканчивается на `MOVE WS-OUTPUT-VAL TO WS-OUTPUT-VALUE(WS-IDX)`. Блок `ELSE / MOVE 0 ... / END-IF` (dormant: output=0, wage=0) **остаётся**.

- [ ] **Step 3: MAIN-PARA — вызвать REALIZE-ALL после WRITE-MARKET**

Между `PERFORM WRITE-MARKET` (строка 652) и `PERFORM TRADE-ALL` (строка 653) вставить:

```cobol
    PERFORM WRITE-MARKET
    PERFORM REALIZE-ALL
    PERFORM TRADE-ALL
```

- [ ] **Step 4: Добавить параграф REALIZE-ALL**

Добавить новый параграф (например, сразу после `CLAMP-PRICE`, ~строка 1075). На этом шаге `realize` фиксировано = 1000:

```cobol
REALIZE-ALL.
*> Phase 25 — реализация стоимости. На под-шаге рефакторинга realize=1000
*> (полная реализация) → поведение идентично прежнему PRODUCE-ALL.
*> Реальная цена подключается в следующей задаче.
    PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > REGION-COUNT
        IF NOT POLITY-DORMANT(WS-IDX)
            MOVE 1000 TO WS-REALIZE-PERMIL
            COMPUTE WS-REALIZED-OUTPUT =
                WS-OUTPUT-VALUE(WS-IDX) * WS-REALIZE-PERMIL / 1000
            COMPUTE WS-SURPLUS-VAL =
                WS-OUTPUT-VALUE(WS-IDX) * WS-SURPLUS-RATE(WS-IDX) / 100
            COMPUTE WS-WAGE-COST =
                WS-OUTPUT-VALUE(WS-IDX) - WS-SURPLUS-VAL
            COMPUTE WS-REALIZED-PROFIT =
                WS-REALIZED-OUTPUT - WS-WAGE-COST
            IF WS-REALIZED-PROFIT >= 0
                COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
                    + WS-REALIZED-PROFIT / CAPITAL-ACC-DIVISOR
                PERFORM ACCUMULATE-TECH-BONUS
                MOVE WS-WAGE-COST TO WS-WAGE-FUND(WS-IDX)
            ELSE
                COMPUTE WS-LOSS = WS-WAGE-COST - WS-REALIZED-OUTPUT
                COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
                    - WS-LOSS / CRISIS-WRITEDOWN-DIVISOR
                IF WS-CAPITAL-STOCK(WS-IDX) < 0
                    MOVE 0 TO WS-CAPITAL-STOCK(WS-IDX)
                END-IF
                MOVE WS-REALIZED-OUTPUT TO WS-WAGE-FUND(WS-IDX)
            END-IF
        END-IF
    END-PERFORM.

ACCUMULATE-TECH-BONUS.
*> Phase 25 — tech-бонусы накопления, перенесены из PRODUCE-ALL.
*> База — реализованная прибыль (при realize=1000 равна прибавочной стоимости,
*> поэтому рефакторинг byte-identical).
    IF WS-TECH-LEVEL(WS-IDX, 2) >= 2
        COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
            + WS-REALIZED-PROFIT / CAPITAL-ACC-DIVISOR * 30 / 100
    END-IF
    IF WS-TECH-LEVEL(WS-IDX, 2) >= 3
        EVALUATE WS-TECH-L3-CHOICE(WS-IDX, 2)
            WHEN 1
                COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
                    + WS-REALIZED-PROFIT / CAPITAL-ACC-DIVISOR * 20 / 100
            WHEN 2
                CONTINUE
            WHEN 3
                COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
                    + WS-REALIZED-PROFIT / CAPITAL-ACC-DIVISOR * 10 / 100
        END-EVALUATE
    END-IF
    IF WS-TECH-LEVEL(WS-IDX, 2) >= 4
        EVALUATE TRUE
            WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 1
                COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
                    + WS-REALIZED-PROFIT / CAPITAL-ACC-DIVISOR * 10 / 100
            WHEN WS-TECH-L3-CHOICE(WS-IDX, 2) = 3
                COMPUTE WS-CAPITAL-STOCK(WS-IDX) = WS-CAPITAL-STOCK(WS-IDX)
                    + WS-REALIZED-PROFIT / CAPITAL-ACC-DIVISOR * 10 / 100
        END-EVALUATE
    END-IF.
```

Примечание: значения констант `CRISIS-WRITEDOWN-DIVISOR` и др. ещё не объявлены — на этом шаге ветка `ELSE` недостижима (realize=1000 → profit≥0 всегда при surplus_rate≥0), но `CRISIS-WRITEDOWN-DIVISOR` используется в коде, поэтому объяви его заранее. Добавь в блок констант (после `78 CAPITAL-ACC-DIVISOR VALUE 10.`, ~строка 232):

```cobol
*> Phase 25 — обесценивание капитала при нереализации
78 CRISIS-WRITEDOWN-DIVISOR  VALUE 5.
```

- [ ] **Step 5: Компиляция**

Run: `/opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate && echo OK`
Expected: `OK`

- [ ] **Step 6: Регрессия byte-identical (рефакторинг не меняет поведение)**

Run: `TURNS=500 scripts/baseline.sh check`
Expected: `All matched.` — **критическая контрольная точка**. Если есть расхождение, рефакторинг внёс ошибку (проверь порядок/формулы; profit при realize=1000 = surplus).

- [ ] **Step 7: Commit**

```bash
git add cobol/simulate.cob
git commit -m "refactor(econ): вынести накопление и wage в REALIZE-ALL (byte-identical)"
```

---

## Task 4: Включить реальную реализацию из цены + обесценивание капитала

Цель: заменить фиксированное `realize=1000` на расчёт из рыночной цены товара. Теперь поведение **меняется намеренно** — переходим на стресс-тест.

**Files:**
- Modify: `cobol/simulate.cob` (константы, REALIZE-ALL)

- [ ] **Step 1: Константы реализации**

После `78 CRISIS-WRITEDOWN-DIVISOR VALUE 5.` добавить:

```cobol
78 REALIZE-MAX-PERMIL        VALUE 3000.  *> кэп реализации (страховка)
78 BANKRUPTCY-CHRON-MIN      VALUE 1000.  *> мин. убыток для записи BANKRUPTCY
```

- [ ] **Step 2: REALIZE-ALL — расчёт цены товара вместо realize=1000**

Заменить строку `MOVE 1000 TO WS-REALIZE-PERMIL` в начале цикла REALIZE-ALL на блок поиска цены товара политии (lookup как в `MARKET-AGGREGATE`):

```cobol
            MOVE 1000 TO WS-REALIZE-PERMIL
            MOVE 0 TO WS-FOUND
            PERFORM VARYING WS-MIDX FROM 1 BY 1
                    UNTIL WS-MIDX > MARKET-COUNT OR WS-FOUND = 1
                IF FUNCTION TRIM(WS-MKT-NAME(WS-MIDX)) =
                   FUNCTION TRIM(WS-PRIMARY-GOOD(WS-REGION-ID(WS-IDX)))
                    IF WS-MKT-DFLT(WS-MIDX) > 0
                        COMPUTE WS-REALIZE-PERMIL =
                            WS-MKT-PRICE(WS-MIDX) * 1000
                            / WS-MKT-DFLT(WS-MIDX)
                    END-IF
                    MOVE 1 TO WS-FOUND
                END-IF
            END-PERFORM
            IF WS-REALIZE-PERMIL > REALIZE-MAX-PERMIL
                MOVE REALIZE-MAX-PERMIL TO WS-REALIZE-PERMIL
            END-IF
```

- [ ] **Step 3: REALIZE-ALL — событие BANKRUPTCY в ветке убытка**

В ветке `ELSE` (убыток), после `MOVE WS-REALIZED-OUTPUT TO WS-WAGE-FUND(WS-IDX)` добавить запись в хронику:

```cobol
                MOVE WS-REALIZED-OUTPUT TO WS-WAGE-FUND(WS-IDX)
                IF WS-LOSS >= BANKRUPTCY-CHRON-MIN
                    MOVE WS-YEAR TO WS-CHRON-YEAR
                    MOVE "BANKRUPTCY     " TO WS-CHRON-TYPE
                    MOVE WS-POLITY-NAME(WS-IDX) TO WS-CHRON-RGON
                    MOVE "Capital destroyed as prices fall below cost."
                        TO WS-CHRON-DESC
                    PERFORM WRITE-CHRONICLE
                END-IF
```

- [ ] **Step 4: Компиляция**

Run: `/opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate && echo OK`
Expected: `OK`

- [ ] **Step 5: Стресс-тест — проверка инвариантов (поведение изменилось)**

Run: `TURNS=1000 scripts/stress.sh`
Expected, проверить глазами:
- В сводке событий появилась строка `BANKRUPTCY` (кризисы теперь разоряют).
- Число живых политий **> 0** (мир не вымер поголовно — death spiral нет).
- Распределение эпох не схлопнулось целиком в `COLLAPSED`/`EXTINCT`.

Если все политии вымерли или капитал у всех 0 → списание слишком агрессивно: увеличь `CRISIS-WRITEDOWN-DIVISOR` (например 5→10) и повтори. Если BANKRUPTCY не появляется вовсе → уменьши `BANKRUPTCY-CHRON-MIN` или проверь, что цены реально падают (кризисы есть в сводке).

- [ ] **Step 6: Commit**

```bash
git add cobol/simulate.cob
git commit -m "feat(econ): реализация стоимости из рыночной цены + обесценивание капитала"
```

---

## Task 5: Безработица (резервная армия труда) + обратная связь на производство

Цель: поле `WS-UNEMPLOYMENT-PCT` (создано в T2) начинает жить — растёт при недореализации, рассасывается при подъёме, и снижает эффективный труд.

**Files:**
- Modify: `cobol/simulate.cob` (константы, WORKING-STORAGE, REALIZE-ALL, PRODUCE-ALL)

- [ ] **Step 1: Константы безработицы**

После `78 BANKRUPTCY-CHRON-MIN VALUE 1000.` добавить:

```cobol
78 UNEMPLOYMENT-SCALE        VALUE 20.   *> (1000−realize)/20 = target % безработицы
78 UNEMPLOYMENT-SMOOTHING    VALUE 3.    *> инерция резервной армии
```

- [ ] **Step 2: WORKING-STORAGE — временные переменные**

После `01 WS-LOSS PIC S9(12)V99.` добавить:

```cobol
01 WS-UNEMP-TARGET      PIC S9(4).
01 WS-EFFECTIVE-LABOUR  PIC 9(10).
```

- [ ] **Step 3: REALIZE-ALL — обновление безработицы**

В конце цикла REALIZE-ALL, внутри `IF NOT POLITY-DORMANT`, после блока IF/ELSE прибыли (перед `END-IF` цикла политии) добавить:

```cobol
*>          Phase 25 — резервная армия труда. Перепроизводство (realize<1000)
*>          толкает безработицу вверх; подъём (realize≥1000) рассасывает её.
*>          Движение с инерцией — резервная армия не появляется мгновенно.
            IF WS-REALIZE-PERMIL < 1000
                COMPUTE WS-UNEMP-TARGET =
                    (1000 - WS-REALIZE-PERMIL) / UNEMPLOYMENT-SCALE
            ELSE
                MOVE 0 TO WS-UNEMP-TARGET
            END-IF
            COMPUTE WS-UNEMPLOYMENT-PCT(WS-IDX) =
                WS-UNEMPLOYMENT-PCT(WS-IDX)
                + (WS-UNEMP-TARGET - WS-UNEMPLOYMENT-PCT(WS-IDX))
                  / UNEMPLOYMENT-SMOOTHING
            IF WS-UNEMPLOYMENT-PCT(WS-IDX) > 100
                MOVE 100 TO WS-UNEMPLOYMENT-PCT(WS-IDX)
            END-IF
```

(Нижняя граница 0 гарантирована типом `PIC 9(3)` без знака и тем, что target ≥ 0.)

- [ ] **Step 4: PRODUCE-ALL — эффективный труд с учётом безработицы**

В `PRODUCE-ALL`, перед `EVALUATE WS-PROD-MODE(WS-IDX)` (строка ~899), вычислить эффективный труд, и в каждой ветке EVALUATE заменить `WS-LABOUR-HOURS(WS-IDX)` на `WS-EFFECTIVE-LABOUR`.

Вставить перед EVALUATE:
```cobol
            COMPUTE WS-EFFECTIVE-LABOUR =
                WS-LABOUR-HOURS(WS-IDX)
                * (100 - WS-UNEMPLOYMENT-PCT(WS-IDX)) / 100
```

Затем в каждой из 8 веток `WHEN ... COMPUTE WS-OUTPUT-VAL = WS-LABOUR-HOURS(WS-IDX) * EFF-...-X1000 / 1000` и в `WHEN OTHER` заменить `WS-LABOUR-HOURS(WS-IDX)` → `WS-EFFECTIVE-LABOUR` (9 замен).

- [ ] **Step 5: Компиляция**

Run: `/opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate && echo OK`
Expected: `OK`

- [ ] **Step 6: Стресс-тест — безработица колеблется, не залипает**

Run: `TURNS=1000 scripts/stress.sh && echo "-- unemployment sample --" && cut -c165-167 cobol/polities.dat | sort | uniq -c`
Expected:
- Распределение значений безработицы разнообразное (не у всех `000` и не у всех `100`).
- Число живых политий > 0; мир по-прежнему проходит через эпохи (есть MODE-SHIFT/REVOLUTION).

Если безработица залипает на 100 у многих → ослабь связь: увеличь `UNEMPLOYMENT-SCALE` (медленнее растёт) или `UNEMPLOYMENT-SMOOTHING` (инертнее). Если всегда 0 → проверь, что кризисы роняют цену (realize<1000 случается).

- [ ] **Step 7: Commit**

```bash
git add cobol/simulate.cob
git commit -m "feat(econ): резервная армия труда — безработица от недореализации, обратная связь на output"
```

---

## Task 6: Обнищание → классовое напряжение и сознание

Цель: безработица напрямую поднимает напряжение и (при наличии рабочего класса) ускоряет рост классового сознания.

**Files:**
- Modify: `cobol/simulate.cob` (константы, SOCIAL-ALL, CONSCIOUSNESS-ALL)

- [ ] **Step 1: Константы**

После `78 UNEMPLOYMENT-SMOOTHING VALUE 3.` добавить:

```cobol
78 UNEMPLOYMENT-TENSION-WT   VALUE 5.    *> делитель вклада безработицы в tension
78 UNEMPLOYMENT-CONSC-MIN    VALUE 15.   *> порог безработицы для +1 сознание
```

- [ ] **Step 2: SOCIAL-ALL — член безработицы в tension delta**

В `SOCIAL-ALL`, после блока голода (`EVALUATE WS-HUNGER-FLAGS ... END-EVALUATE`, ~строка 2094) и перед блоком шума (`MOVE FUNCTION RANDOM TO WS-RAND-VAL`, ~2098) добавить:

```cobol
*>          Phase 25 — безработица злит: резервная армия давит на настроения.
            COMPUTE WS-TENSION-DELTA = WS-TENSION-DELTA
                + WS-UNEMPLOYMENT-PCT(WS-IDX) / UNEMPLOYMENT-TENSION-WT
```

- [ ] **Step 3: CONSCIOUSNESS-ALL — кризис обнажает противоречия**

Открой `CONSCIOUSNESS-ALL` (параграф ~строка 1092). Найди блок, где сознание растёт при условии `WS-WORKER-PCT >= CONSCIOUSNESS-URBAN-MIN` (рабочий класс есть). Рядом с этим ростом, внутри той же ветки `IF NOT POLITY-DORMANT` и условия наличия рабочего класса, добавить:

```cobol
*>          Phase 25 — массовая безработица — школа классового сознания.
            IF WS-UNEMPLOYMENT-PCT(WS-IDX) > UNEMPLOYMENT-CONSC-MIN
               AND WS-WORKER-PCT >= CONSCIOUSNESS-URBAN-MIN
                ADD 1 TO WS-CONSCIOUSNESS(WS-IDX)
                IF WS-CONSCIOUSNESS(WS-IDX) > CONSCIOUSNESS-MAX
                    MOVE CONSCIOUSNESS-MAX TO WS-CONSCIOUSNESS(WS-IDX)
                END-IF
            END-IF
```

Примечание: `WS-WORKER-PCT` вычисляется внутри `CONSCIOUSNESS-ALL` (artisans+merchants). Если в точке вставки оно ещё не посчитано — вставить после строки, где оно присваивается. Прочитай параграф перед вставкой, чтобы попасть в правильное место.

- [ ] **Step 4: Компиляция**

Run: `/opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate && echo OK`
Expected: `OK`

- [ ] **Step 5: Стресс-тест — кризисы порождают политическую динамику**

Run: `TURNS=1000 scripts/stress.sh`
Expected:
- REVOLUTION по-прежнему происходят (а связь сознания с кризисом не должна их обнулить).
- Мир жив (> 0 политий), эпохи достигаются.
- Сравни с «снимком до» из Task 1: ожидаемо больше напряжённых событий в периоды кризисов.

Если революции зашкаливают (мир в перманентной смуте) → уменьши вклад: увеличь `UNEMPLOYMENT-TENSION-WT` (слабее эффект) и `UNEMPLOYMENT-CONSC-MIN` (реже растит сознание).

- [ ] **Step 6: Commit**

```bash
git add cobol/simulate.cob
git commit -m "feat(econ): обнищание поднимает напряжение и классовое сознание"
```

---

## Task 7: Защита формата COBOL↔Rust

Цель: точечный guard против молчаливого рассинхрона записи `polities.dat`.

**Files:**
- Modify: `cobol/simulate.cob` (WRITE-WORLD)
- Modify: `src/world.rs` (parse_polities)

- [ ] **Step 1: COBOL — предупреждение о дрейфе длины записи**

В `WRITE-WORLD`, внутри `PERFORM VARYING`, после `END-STRING` и перед `WRITE WS-POLITY-REC FROM WS-OUT-LINE` добавить guard (ожидаемая длина 167):

```cobol
        END-STRING
        IF FUNCTION LENGTH(FUNCTION TRIM(WS-OUT-LINE TRAILING)) > 167
            DISPLAY "WARN: polities.dat record drift > 167" UPON SYSERR
        END-IF
        WRITE WS-POLITY-REC FROM WS-OUT-LINE
```

- [ ] **Step 2: Rust — предупреждение о коротких строках**

В `parse_polities`, заменить тело замыкания `.map(|line| ...)` так, чтобы коротким строкам выдавалось предупреждение. Добавить проверку в начало замыкания (после `.map(|line| {`):

```rust
        .map(|line| {
            if line.len() < 167 {
                eprintln!(
                    "WARN: polities.dat line {} bytes, expected 167 — формат рассинхронизирован?",
                    line.len()
                );
            }
            Polity {
                name: slice_or_blank(line, 0, 20).to_string(),
                // ... остальные поля без изменений ...
            }
        })
```

(Заметь: текущий код использует `.map(|line| Polity { ... })` без блока. Превратить в блок с `{ ... Polity { ... } }`.)

- [ ] **Step 3: Компиляция COBOL + Rust**

Run: `/opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate && cargo build 2>&1 | tail -3 && echo OK`
Expected: `OK`, сборка Rust без ошибок.

- [ ] **Step 4: Проверка отсутствия ложных предупреждений на корректных данных**

Run: `./cobol/world && printf "0001\n" > cobol/year.dat && ./cobol/simulate 2>stderr.txt; cat stderr.txt; rm -f stderr.txt`
Expected: stderr пустой — корректная запись 167 байт не вызывает WARN.

- [ ] **Step 5: Регрессия не сломана**

Run: `TURNS=500 scripts/baseline.sh check`
Expected: поведение не изменилось относительно эталона **этой фазы** — но эталон ещё старый (от Task 1). Ожидается расхождение по chronicle (появились BANKRUPTCY) — это нормально, новый эталон снимем в Task 9. Здесь достаточно убедиться, что симуляция отрабатывает 500 ходов без падения (нет libcob-ошибок в выводе).

- [ ] **Step 6: Commit**

```bash
git add cobol/simulate.cob src/world.rs
git commit -m "feat(robustness): guard на дрейф формата polities.dat (COBOL + Rust)"
```

---

## Task 8: UI — норма прибыли, безработица, цвет BANKRUPTCY

Цель: показать новые экономические величины в detail-панели и подсветить событие банкротства.

**Files:**
- Modify: `src/ui.rs` (detail-панель, chronicle color mapping)
- Modify: `src/market.rs` (если нужен доступ к цене из detail — проверить, парсится ли market в ui)

- [ ] **Step 1: Прочитать контекст рендеринга detail-панели**

Открой `src/ui.rs`, найди функцию рендеринга detail-панели (содержит строки `Capital`, `Tension`, классы). Найди, как туда передаётся `&Polity` и доступен ли уже распарсенный market (`parse_market`). Это нужно, чтобы посчитать норму прибыли.

- [ ] **Step 2: Добавить строку «Unemployment»**

В detail-панели, рядом со строкой капитала/напряжения, добавить (значение уже есть в `polity.unemployment_pct`):

```rust
lines.push(Line::from(vec![
    Span::raw("Unemployment: "),
    Span::styled(
        format!("{}%", polity.unemployment_pct),
        Style::default().fg(if polity.unemployment_pct >= 25 {
            Color::Red
        } else if polity.unemployment_pct >= 10 {
            Color::Yellow
        } else {
            Color::Gray
        }),
    ),
]));
```

(Сопоставь стиль с существующими строками панели — используй тот же конструктор, что и соседние строки.)

- [ ] **Step 3: Добавить строку «Profit rate» (производная)**

Норма прибыли считается на лету. Если distinct-цена товара доступна в ui через `parse_market`, найди цену по `region.primary_good`, иначе аппроксимируй через surplus/capital. Минимальная версия без цены (приближение нормы прибыли через прибавочную стоимость к капиталу):

```rust
let profit_rate = if polity.capital_stock > 0.0 {
    // m / C: реализованную прибыль аппроксимируем surplus-долей output
    let surplus = polity.surplus_rate / 100.0; // доля
    let approx_profit = (polity.labour_hours as f64) * surplus; // грубая оценка масштаба
    (approx_profit / polity.capital_stock) * 100.0
} else {
    0.0
};
lines.push(Line::from(format!("Profit rate: ~{:.1}%", profit_rate)));
```

Примечание: если в ui уже парсится market и доступна реальная цена товара — предпочесть точную формулу `(output × price/dflt − wage_cost) / capital`. Реши при реализации по доступным данным; грубой оценки достаточно для индикатора.

- [ ] **Step 4: Цвет события BANKRUPTCY в хронике**

Найди в `src/ui.rs` сопоставление типов событий цветам (большой `match` по `event_type` с ветками `"WAR-START"`, `"REVOLUTION"` и т.п.). Добавить ветку:

```rust
"BANKRUPTCY" => Color::LightRed,
```

И если есть фильтр хроники по категориям (`ChronicleFilter`) — включить `BANKRUPTCY` в категорию политики/экономики там, где уже перечислены `REVOLUTION`/`MODE-SHIFT`.

- [ ] **Step 5: Сборка**

Run: `cargo build 2>&1 | tail -5 && echo OK`
Expected: `OK`, без ошибок и новых предупреждений о неиспользуемых полях (`unemployment_pct` теперь читается).

- [ ] **Step 6: Дымовой запуск (ручная проверка рендера)**

Run: `cargo build && echo "Запусти вручную: cargo run --release, выбери New game, проверь detail-панель (Unemployment, Profit rate) и цвет BANKRUPTCY в хронике после нескольких ходов [N]."`
Expected: команда печатает инструкцию; ручная проверка подтверждает, что строки отображаются и не ломают верстку.

- [ ] **Step 7: Commit**

```bash
git add src/ui.rs src/market.rs
git commit -m "feat(ui): норма прибыли, безработица в detail-панели, цвет BANKRUPTCY"
```

---

## Task 9: Новый baseline, DEVLOG, память

Цель: зафиксировать новый эталон регрессии (поведение изменилось по построению) и задокументировать фазу.

**Files:**
- Regenerate: `cobol/baseline_*.dat`
- Modify: `DEVLOG.md`
- (memory обновляется отдельно ассистентом, см. Step 4)

- [ ] **Step 1: Снять новый эталон регрессии**

Run: `/opt/homebrew/bin/cobc -x -free cobol/world.cob -o cobol/world && /opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate && TURNS=500 scripts/baseline.sh capture`
Expected: `Baseline captured.`

- [ ] **Step 2: Проверить детерминизм нового эталона (повторный check проходит)**

Run: `TURNS=500 scripts/baseline.sh check`
Expected: `All matched.` — новый эталон стабилен и воспроизводим.

- [ ] **Step 3: Запись в DEVLOG.md**

Дописать в конец `DEVLOG.md` запись по шаблону из CLAUDE.md:

```markdown
## [Phase 25 — Кризис → разорение (реализация стоимости)] 2026-06-01

### Что сделано
- Новый параграф REALIZE-ALL: реализованная стоимость = output × (цена/базовая).
  Накопление капитала и wage вынесены из PRODUCE-ALL (производство и реализация
  разделены, как у Маркса).
- Обвал цены ниже издержек рабочей силы списывает капитал (банкротство, событие
  BANKRUPTCY).
- Новое поле WS-UNEMPLOYMENT-PCT (резервная армия труда): растёт при
  недореализации, рассасывается при подъёме, снижает эффективный труд → output.
- Обнищание (безработица) поднимает напряжение (SOCIAL-ALL) и классовое сознание
  (CONSCIOUSNESS-ALL).
- Guard на дрейф формата polities.dat (COBOL WARN + Rust eprintln).
- UI: норма прибыли, безработица в detail-панели, цвет BANKRUPTCY.

### Какие файлы затронуты
- cobol/simulate.cob — REALIZE-ALL, ACCUMULATE-TECH-BONUS, безработица в PRODUCE/
  REALIZE, члены в SOCIAL/CONSCIOUSNESS, константы, формат-guard, parse/write поля
- cobol/world.cob — поле UNEMPLOYMENT, init, запись
- src/world.rs — Polity.unemployment_pct, parse, length-warning
- src/saves.rs — миграция legacy + ассерт 167 байт
- src/ui.rs — profit rate, unemployment, BANKRUPTCY color
- scripts/stress.sh — новый инструмент стресс-теста

### Результат компиляции
- COBOL: OK
- Rust: OK (cargo test legacy_migration — ok)

### Регрессия
- polities.dat: 164 → 167 байт (поле в конце, offset'ы стабильны)
- Новый baseline зафиксирован (старый устарел — поведение изменилось по построению)
- Стресс-тест 1000 ходов: <вставить итоговые счётчики событий и число живых политий>

### Что дальше
- Phase 26 (следующая): структурный c/v и тенденция нормы прибыли к понижению (TRPF)
```

(Замени `<вставить...>` фактическим выводом последнего `scripts/stress.sh`.)

- [ ] **Step 4: Обновить память проекта (ассистент, не субагент)**

Обновить `project_ecos.md`: добавить пункт Phase 25 (REALIZE-ALL, поле UNEMPLOYMENT @165/@164, байтовая карта 164→167, разделение производства/реализации, связь кризиса с сознанием, новый baseline). Это делает ассистент по завершении фазы.

- [ ] **Step 5: Commit**

```bash
git add DEVLOG.md cobol/baseline_chronicle.dat cobol/baseline_tech.dat cobol/baseline_relations.dat cobol/baseline_market.dat
git commit -m "docs: DEVLOG + новый baseline фазы 25 (кризис → разорение)"
```

Примечание: `.gitignore` исключает `*.dat`. Если эталоны не должны попадать в git — пропусти их в `git add` и закоммить только `DEVLOG.md`. Эталоны останутся локальными (как и раньше).

---

## Self-Review (выполнено при написании плана)

**Spec coverage:** все разделы спека покрыты — реализация стоимости (T3,T4), обесценивание капитала (T4), резервная армия (T5), обнищание→напряжение+сознание (T6), новое поле + защита формата (T2,T7), chronicle+UI (T4,T8), тестирование/baseline (T1,T9), YAGNI-границы соблюдены (TRPF вынесён в «что дальше»).

**Placeholder scan:** конкретный код во всех шагах правок; единственное намеренно-вариативное место — формула profit rate в UI (T8 Step 3), где приближение допускается по доступности market-данных и явно описано.

**Type/name consistency:** `WS-UNEMPLOYMENT-PCT` (COBOL) / `unemployment_pct` (Rust), `REALIZE-ALL`/`ACCUMULATE-TECH-BONUS`, `WS-REALIZE-PERMIL/REALIZED-OUTPUT/REALIZED-PROFIT/WAGE-COST/LOSS`, `WS-UNEMP-TARGET/EFFECTIVE-LABOUR`, константы `CRISIS-WRITEDOWN-DIVISOR/REALIZE-MAX-PERMIL/BANKRUPTCY-CHRON-MIN/UNEMPLOYMENT-SCALE/SMOOTHING/TENSION-WT/CONSC-MIN` — имена согласованы между задачами. Offset @165 (COBOL 1-indexed) = @164 (Rust 0-indexed) для записи длиной 167.
