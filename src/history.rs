// История региональных метрик за последние N ходов.
// Используется в TUI для отрисовки sparklines (тренды tension/pop/capital).
// Per-session: не персистится в файл — игрок видит то, что произошло
// за время его сессии. Перезапуск симулятора начинает историю заново.

use std::collections::VecDeque;

const HISTORY_LEN: usize = 50;

#[derive(Default)]
pub struct RegionHistory {
    pub tension: VecDeque<u64>,
    pub population: VecDeque<u64>,
    pub capital: VecDeque<u64>,
}

impl RegionHistory {
    pub fn push(&mut self, tension: u64, population: u64, capital: u64) {
        push_capped(&mut self.tension, tension);
        push_capped(&mut self.population, population);
        push_capped(&mut self.capital, capital);
    }
}

fn push_capped(q: &mut VecDeque<u64>, v: u64) {
    if q.len() >= HISTORY_LEN {
        q.pop_front();
    }
    q.push_back(v);
}

/// Хранилище истории на 10 регионов. Индекс совпадает с `regions[i]`.
pub struct WorldHistory {
    regions: Vec<RegionHistory>,
    last_year: u32,
}

impl WorldHistory {
    pub fn new(n: usize) -> Self {
        Self {
            regions: (0..n).map(|_| RegionHistory::default()).collect(),
            last_year: 0,
        }
    }

    /// Записывает снимок если год сменился.
    /// Phase 24 / Этап 2B: callback получает (idx, &R) — это позволяет
    /// caller'у искать occupant_of(idx) для региона.
    pub fn record_if_new_year<R, F>(&mut self, year: u32, items: &[R], f: F)
    where
        F: Fn(usize, &R) -> (u64, u64, u64),
    {
        if year == self.last_year {
            return;
        }
        for (i, r) in items.iter().enumerate() {
            if i >= self.regions.len() {
                break;
            }
            let (t, p, c) = f(i, r);
            self.regions[i].push(t, p, c);
        }
        self.last_year = year;
    }

    pub fn region(&self, idx: usize) -> Option<&RegionHistory> {
        self.regions.get(idx)
    }
}
