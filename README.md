# ecos — A World Simulator in COBOL and Rust

**Languages:** **English** · [Русский](README.ru.md)

A historical sandbox where **COBOL (1959)** simulates the contradictions of
capitalism, and **Rust (2015)** renders them in a terminal UI. The model is
built on Marxist political economy: value is created by labour, classes
struggle, modes of production succeed each other through accumulation and
revolution, and empires rise and fall on their own internal contradictions.

The point of the project is **observation**, not control. There is no player
agency in the historical sense — you watch a world unfold, year by year, and
read the chronicle.

> **Meta-irony**: a language built in the late 1950s for capitalist
> bookkeeping (payroll, ledgers, batch accounting) computes the structural
> contradictions of the system that gave birth to it.

---

## Table of Contents

1. [What it does](#what-it-does)
2. [Architecture](#architecture)
3. [The simulation step](#the-simulation-step)
4. [Modes of production](#modes-of-production)
5. [Polity life cycle](#polity-life-cycle)
6. [Wars](#wars)
7. [Tech tree](#tech-tree)
8. [Culture and consciousness](#culture-and-consciousness)
9. [Installation](#installation)
10. [Controls](#controls)
11. [Save / load](#save--load)
12. [Determinism and regression](#determinism-and-regression)
13. [Theoretical foundations](#theoretical-foundations)
14. [Roadmap](#roadmap)
15. [License](#license)

---

## What it does

`ecos` simulates a small world of **10 geographic regions** (terrain, climate,
neighbours — the *base*, never changing) populated by up to **30 polities**
(states, communities, societies — the *political superstructure*, always
changing). Each turn, each polity produces value, trades with neighbours,
faces internal class tension, fights wars, accumulates capital, and possibly
shifts mode of production, collapses, or fragments into successors.

The chronicle records every event:

```
0083 WAR-START      Goldgate            Cassio of Goldgate strikes Saltmere.
0091 MODE-SHIFT     Frostfen            Slave -> Feudal. Manorial order replaces antiquity.
0127 INNOVATION     Embervast           Printing press! Ideas multiply.
0238 REVOLUTION     Stonehold           Artisans seize means of production. New order.
0312 FRAGMENT       Neo-Goldgate        Empire fragments. New polity rises in its lands.
0731 EXTINCT        Cinderkeep          Polity ceases to exist. Region falls silent.
```

You scroll the table, jump between regions, watch sparklines of tension /
population / capital, browse the tech tree, observe markets and crises.

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                       Rust (TUI / driver)                  │
│  • ratatui + crossterm  •  game loop                       │
│  • parses regions.dat / polities.dat / tech.dat / …        │
│  • renders table, detail panel, sparklines, tech tree      │
└──────────────────────────┬─────────────────────────────────┘
                           │  std::process::Command
                           ▼
┌────────────────────────────────────────────────────────────┐
│                     COBOL (engine)                         │
│  • cobol/world.cob     — world generator (one-shot)        │
│  • cobol/simulate.cob  — one turn                          │
│  • exact decimal arithmetic (PIC 9V99) for economy         │
│  • LINE SEQUENTIAL files = persistent state                │
└────────────────────────────────────────────────────────────┘
```

**Two-process architecture:** Rust never modifies world state directly. It
runs the COBOL `simulate` binary as a subprocess once per turn, then re-reads
the resulting `.dat` files. This keeps the simulation deterministic, testable
in isolation, and faithful to the spirit of how mainframe batch jobs ran.

**Data files (in `cobol/`):**

| File | Description |
|---|---|
| `regions.dat` | 10 lines × 61 bytes — geography (name, terrain, climate, primary good, neighbours). Static; written once by `world.cob`. |
| `polities.dat` | 30 lines × 164 bytes — politics (mode, classes, ruler, capital, culture, mode-age, region_id). Rewritten every turn. |
| `tech.dat` | 10 lines × 24 bytes — research progress per polity, 4 branches × 4 levels. |
| `relations.dat` | 10×10 matrix — diplomatic relations (−100..+100). |
| `market.dat` | 8 commodities — global supply, demand, price, crisis flag. |
| `chronicle.dat` | append-only event log. |
| `year.dat` | the current turn number. |

## The simulation step

Each call to `cobol/simulate` processes one in-game year:

```
1.  TICK-MODE-YEARS    — every living polity ages its current era counter
2.  PRODUCE            — labour × efficiency = output value (Marx: value = labour time)
3.  MARKET             — aggregate supply / demand / price across 8 goods
4.  CHECK-CRISIS       — overproduction => price collapse, crisis flag
5.  TRADE              — neighbours exchange, trade balance updates
6.  WAR-CHECK / RESOLVE — 4 trigger types (see below), 3-year resolution
7.  DISTRIBUTE         — wage fund ↔ subsistence; famines if short
8.  DEMOGRAPHY         — population grows/shrinks; collapse/rebirth/extinct branch
9.  CLIMATE-EVENTS     — terrain-specific hazards
10. CONSCIOUSNESS      — class awareness drifts (Marx, slowly)
11. CLASS-DRIFT        — peasants ↔ artisans ↔ merchants ↔ nobility flux
12. SOCIAL             — class tension recomputed from exploitation rate
13. REVOLUTION         — if tension × consciousness fires, ruling class falls
14. ACCUMULATE         — capital → mode-shift transitions (organic path)
15. TECH-RESEARCH      — 4 branches, branching alternatives at L3, sub-techs at L4
16. CULTURE-DRIFT      — military / mercantile / religious vectors
17. INNOVATION-CHECK   — rare one-shot inventions (printing press, gunpowder, ...)
18. CALC-MILITARY      — military strength updated
19. AGE-RULERS         — rulers age, may die, succession
20. RELATIONS-DECAY    — diplomatic memory fades toward zero
```

## Modes of production

The Marxist ladder, 8 stages:

| Mode | Efficiency × 1000 | Notes |
|---|---|---|
| `PRIMITIVE` | 400 | Kin-based, ritual culture (Engels) |
| `SLAVE` | 750 | Early city-states, slave labour |
| `FEUDAL` | 1000 | Manorial baseline |
| `MERCANTILE` | 1100 | Trade capital |
| `PROTO-INDUSTRL` | 1375 | Manufacture, early factories |
| `INDUSTRIAL` | 1700 | Wage labour as dominant form |
| `IMPERIAL` | 2200 | Finance capital, monopolies (Lenin) |
| `SOCIALIST` | 1900 | Workers control means of production |

Plus two "dormant" states: `COLLAPSED` (dark age, recovers in 8 turns) and
`EXTINCT` (gone forever).

**Two paths between modes:**

- **Organic / accumulative** (in `ACCUMULATE-ALL`): capital threshold +
  class composition + cultural multiplier triggers a probabilistic transition.
- **Revolutionary** (in `REVOLUTION`): when class tension × consciousness
  bursts, the ruling class falls and the mode advances by one level. Slave →
  Feudal (artisans + merchants ≥ 20%), Mercantile → Proto-Industrial
  (artisans ≥ 25%), Proto-Industrial → Industrial (artisans ≥ 30%), Imperial
  → Socialist. Industrial → Imperial is intentionally **not** a revolutionary
  path — imperialism is, per Lenin, the organic outcome of finance capital
  concentration.

## Polity life cycle

```
                    ┌───── REBIRTH (8 turns) ─────┐
                    ▼                             │
    ALIVE ─────► COLLAPSED ───► EXTINCT (slot keeps geographic name)
      │                          ▲
      ├──── pop < 20k on collapse ┘
      │
      ├──── pop 20–69k on collapse ──► COLLAPSED → REBIRTH
      │
      └──── pop ≥ 70k on collapse ──► FRAGMENT
                                       │
                                       └► parent → EXTINCT
                                          heir polity spawned in same region
                                          (Neo-<region name>, ⅓ pop, ¼ capital,
                                          new ruler, FEUDAL, fresh consciousness)
```

This means **states can really die.** Map can lose population. Empires can
break up into successor states with new names ("Neo-Ironmarch", "Neo-Goldgate")
the way the Roman Empire fragmented into post-Roman kingdoms.

## Wars

Four trigger types, each with its own structural cause:

| Type | Trigger | Marxist reading |
|---|---|---|
| `DYNASTIC` | capital > 8 000, internal calm, weakened neighbour | Aristocracy expands accumulation when internal possibilities are exhausted. |
| `CRISIS` | overproduction crisis + tension > 60 | War as escape from crisis: destroys "surplus" production, employs the unemployed, redirects domestic anger outward. |
| `IMPERIAL` | mode ≥ INDUSTRIAL + trade balance < −500 | Lenin's stage: capital must expand or stagnate. |
| `CLASS` | class tension ≥ 90 + nobility > 5 | Internal repression — the ruling class uses force against rising consciousness. |

Wars resolve in 3 years. Victors seize 30% of the loser's capital, take
labour (15% of loser's hours), gain a tech (military loot), and drive the
loser closer to collapse.

## Tech tree

**4 branches × 4 levels = 16 cells per polity, 44 distinct technologies, 1296
possible identities.**

| Branch | Theme | L1 / L2 / L3 alternatives / L4 sub-techs |
|---|---|---|
| `prod` | Production | Bronze / Iron / Steam, Forging, Hydraulics / 6 sub-techs |
| `org` | Organisation | Coinage / Banking / Joint-Stock, Cooperatives, Cartels / 6 sub |
| `know` | Knowledge | Writing / Printing / Empiricism, Scholasticism, Folk Wisdom / 6 sub |
| `pow` | Power | Standing Army / Bureaucracy / Mass Conscription, Prof. Army, Militia / 6 sub |

Research speed depends on mode of production, terrain match, dominant class
%, knowledge L3 alternative chosen, and **cultural multiplier** (range
~0.33×–2.33×). Tech can also spread through diffusion (neighbour ahead by
1 level) or be looted in war.

## Culture and consciousness

Two distinct concepts, often conflated in pop political theory:

- **Culture** is *worldview*. Three vectors per polity, 0..100: `mil`
  (militaristic), `merc` (mercantile), `rel` (religious). Drift up from
  ruler's traits, mode of production, neighbours' influence; decay back
  toward zero without reinforcement. Culture multiplies mode-shift probabil­
  ities (Marx: superstructure feeds back into base) — without commercial
  culture, FEUDAL → MERCANTILE is sluggish even with capital piled up.
- **Class consciousness** is *awareness of structural exploitation*. Grows
  only when there is an active worker class (artisans + merchants ≥ 30%) —
  in pure peasant societies it stays at zero. PROTO-INDUSTRIAL and onwards
  feed it slowly (~1/turn). It decays without active class struggle (−1
  every 5 turns). It's the **multiplier** in the revolution probability:
  high tension is necessary, conscious class is what turns tension into
  revolution.

## Installation

### Requirements

- **GnuCOBOL 3.x** (`cobc`). On macOS: `brew install gnu-cobol`. On Debian/
  Ubuntu: `apt install gnucobol`.
- **Rust 1.70+** with `cargo`.
- Terminal with truecolor and unicode (most modern terminals).

### Build

```bash
make           # builds COBOL binaries + Rust release in one go
# OR explicitly:
make cobol     # cobc -x -free cobol/{world,simulate}.cob
cargo build --release
```

### Run

```bash
cargo run --release
```

You'll see a start menu — pick **New game**, choose a save slot to load, or
quit. Then the main view: a table of 10 regions with their current occupants,
detail panel on the right, market block, chronicle scroll, footer with
keybinds.

## Controls

| Key | Action |
|---|---|
| `N` | Next turn |
| `A` | Toggle auto-step (one turn per 500 ms) |
| `↑` / `↓` | Select region |
| `W` | Toggle world dashboard |
| `T` | Toggle tech tree view |
| `F` | Cycle chronicle filter (all / wars / politics / climate / region) |
| `S` | Save to slot 1–5 |
| `L` | Load slot 1–5 |
| `Q` | Quit |

## Save / load

Five fixed slots in `saves/slot1..5/`. Each slot is a snapshot of all `.dat`
files. Saves are explicit: quitting without `S` loses progress. The start
menu shows the year of each non-empty slot. Legacy single-file `world.dat`
saves are auto-migrated to the split `regions.dat` + `polities.dat` format
on first load.

## Determinism and regression

`FUNCTION RANDOM(seed)` in GnuCOBOL is deterministic given a fixed sequence
of calls. The seed is set once per turn from the current year. This means
**identical world.cob output + identical turn count = identical
chronicle.dat byte-for-byte**.

`scripts/baseline.sh capture | check` exploits this for regression testing:
captures a 500-turn run as the baseline, then verifies any future run still
matches. Used continuously during refactoring to prove that structural
changes don't shift behaviour.

## Theoretical foundations

The simulation is grounded in classical and modern Marxist theory. None of
this is hard-coded as ideology — it's the *mechanism* by which numbers move:

- **Marx**, *Capital*: labour theory of value, surplus extraction, crisis
  of overproduction, primacy of base over superstructure.
- **Engels**, *Origin of Family*: ritual / kin-based primitive culture is
  the starting point, not "blank slate".
- **Lenin**, *Imperialism*: finance capital concentration produces the
  imperial stage; combined and uneven development across regions.
- **Trotsky**: cultural diffusion as a mechanism by which less-developed
  regions absorb elements from more-developed neighbours.
- **Deng Xiaoping**: productive forces are primary; culture modulates speed
  but does not gate transitions.
- **Xi Jinping** ("cultural confidence"): culture has reverse impact on
  the material base — a proud knowledge tradition multiplies research speed.
- **Wang Hui**: multiple modernities — each polity finds its own path
  through the ladder of modes, not a single linear march.

## Roadmap

The project is built in **phases**, each one a focused, regression-tested
extension. See [`DEVLOG.md`](DEVLOG.md) for the full history. Highlights:

- **Phases 1–6** — generator, basic economy, war mechanics, TUI.
- **Phase 9** — rulers as named individuals with traits.
- **Phase 10** — demographic motion, refugee migration on collapse.
- **Phase 11** — full 7-stage mode ladder + imperial war.
- **Phases 13–18** — tech tree (4 × 4, branching alternatives, sub-techs).
- **Phases 19, 22, 23** — natural pacing of eras through cultural confidence
  and labour-driven consciousness; revolution as a mode-shift path.
- **Phase 20** — save / load, start menu.
- **Phase 21** (partially rolled back) — explicit epoch durations.
- **Phase 24 / Stage 1** — split `Region` (geography) from `Polity` (politics).
- **Phase 24 / Stage 2A** — `EXTINCT` mode for small polities (states can die).
- **Phase 24 / Stage 2B** — 30 polity slots; `FRAGMENT` collapse spawns heirs
  in the same region, named "Neo-X".

**Planned next:**

- **Phase 24 / Stage 2C** — `STATELESS` mode for tribal communities; spawn
  in vacant neighbouring regions; refugee-seeded settlements.
- **Phase 24 / Stage 2D** — 3 cells per region (mosaic gameplay); territorial
  annexation in war.

## License

To be decided. The project is currently a personal exploration; if you want
to fork or use it, open an issue first.

## A note from the author

This is a slow-burn weekend project, built incrementally with care. Each
phase is documented in `DEVLOG.md` with motivation, design, file diff, and
regression results. Read it alongside the code if you're curious how a
weird two-language Marxist sim came to be.

The dialogue with the assistant during development is part of the project
— see `CLAUDE.md` for the working agreement.
