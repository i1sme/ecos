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
