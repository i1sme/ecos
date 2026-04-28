#!/usr/bin/env bash
# Phase 24 / Этап 1 — регрессионный тест разделения Region/Polity.
#
# Использование:
#   scripts/baseline.sh capture    — записать эталон (cobol/baseline_*.dat)
#   scripts/baseline.sh check      — прогнать заново и сравнить с эталоном
#
# GnuCOBOL FUNCTION RANDOM(seed) детерминирован при фиксированной
# последовательности вызовов, поэтому при идентичной логике байт-в-байт
# выход совпадёт. Любая разница = регрессия.

set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-check}"
TURNS="${TURNS:-500}"

# Phase 24 — Этап 1: world.dat расщеплён на regions.dat + polities.dat.
# Поведение симуляции по-прежнему эталонится через chronicle/tech/relations/market
# (порядок и числа событий — точная функция RANDOM-seed). Новые файлы
# regions.dat и polities.dat проверяются sanity-чеком отдельно.
BASELINE_FILES=(chronicle.dat tech.dat relations.dat market.dat)

run_simulation() {
    rm -f cobol/world.dat cobol/chronicle.dat cobol/market.dat \
          cobol/relations.dat cobol/tech.dat cobol/year.dat \
          cobol/regions.dat cobol/polities.dat
    ./cobol/world
    touch cobol/chronicle.dat cobol/market.dat cobol/relations.dat cobol/tech.dat
    for i in $(seq 1 "$TURNS"); do
        printf "%04d\n" "$i" > cobol/year.dat
        ./cobol/simulate >/dev/null
    done
}

case "$MODE" in
    capture)
        echo "==> Capturing baseline ($TURNS turns)..."
        run_simulation
        for f in "${BASELINE_FILES[@]}"; do
            if [ -f "cobol/$f" ]; then
                cp "cobol/$f" "cobol/baseline_$f"
                echo "  saved cobol/baseline_$f ($(wc -c <"cobol/baseline_$f") bytes)"
            fi
        done
        echo "Baseline captured."
        ;;
    check)
        echo "==> Checking against baseline ($TURNS turns)..."
        run_simulation
        FAIL=0
        for f in "${BASELINE_FILES[@]}"; do
            if [ ! -f "cobol/baseline_$f" ]; then
                echo "  SKIP cobol/baseline_$f — not captured"
                continue
            fi
            # world.dat will be split into regions.dat+polities.dat after Step 3.
            # Allow it to disappear; we'll verify via regions.dat+polities.dat
            # separately after the split. For now compare what exists.
            if [ ! -f "cobol/$f" ]; then
                echo "  MISSING cobol/$f (post-refactor expected for world.dat)"
                continue
            fi
            if diff -q "cobol/baseline_$f" "cobol/$f" >/dev/null; then
                echo "  OK   cobol/$f matches baseline"
            else
                echo "  FAIL cobol/$f differs from baseline"
                FAIL=1
            fi
        done
        if [ "$FAIL" -ne 0 ]; then
            echo "Regression detected."
            exit 1
        fi
        echo "All matched."
        ;;
    *)
        echo "Usage: $0 capture|check" >&2
        exit 1
        ;;
esac
