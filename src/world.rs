// Phase 24 — Этап 1: разделение Region (геофон) и Polity (политический слой).
//
// Сейчас файлы:
//   regions.dat   — статика, 10 строк × ~62 байта (terrain, climate, neighbors)
//   polities.dat  — динамика, 10 строк × ~163 байта (mode, классы, правитель,
//                   культура, mode_years, etc). Переписывается каждый ход.
//
// На Этапе 1 polity[i] всегда живёт в region[i]; имена синхронизированы
// (Polity.name == Region.name). На Этапе 2+ полития сможет переезжать,
// исчезать и спавниться, имена разойдутся.
//
// Layout regions.dat (0-indexed Rust offsets):
// | Поле          | Старт | Длина |
// |---------------|-------|-------|
// | name          |   0   |  20   |
// | terrain       |  20   |  10   |
// | climate       |  30   |  10   |
// | primary_good  |  40   |  15   |
// | neighbor_1    |  55   |   2   |
// | neighbor_2    |  57   |   2   |
// | neighbor_3    |  59   |   2   |
//
// Layout polities.dat (0-indexed Rust offsets):
// | Поле           | Старт | Длина |
// |----------------|-------|-------|
// | name           |   0   |  20   |
// | population     |  20   |   8   |
// Phase 24 / Этап 2B: добавлен region_id (сместил все последующие поля на 2).
// | name           |   0   |  20   |
// | region_id      |  20   |   2   | ← Phase 24/2B (1..10 для живых, 0 для EXTINCT)
// | population     |  22   |   8   |
// | peasants_pct   |  30   |   3   |
// | artisans_pct   |  33   |   3   |
// | merchants_pct  |  36   |   3   |
// | nobility_pct   |  39   |   3   |
// | clergy_pct     |  42   |   3   |
// | prod_mode      |  45   |  15   |
// | labour_hours   |  60   |  10   |
// | surplus_rate   |  70   |   5   | (×100, делим)
// | capital_stock  |  75   |  12   | (×100, делим)
// | class_tension  |  87   |   3   |
// | military_strength | 90 |   5   |
// | at_war_with    |  95   |   2   |
// | collapse_timer |  97   |   3   |
// | war_year       | 100   |   3   |
// | war_type       | 103   |  10   |
// | ruler_name     | 113   |  20   |
// | ruler_age      | 133   |   2   |
// | ruler_trait    | 135   |  10   |
// | ruler_reign    | 145   |   3   |
// | consciousness  | 148   |   3   |
// | culture_mil    | 151   |   3   |
// | culture_merc   | 154   |   3   |
// | culture_rel    | 157   |   3   |
// | mode_years     | 160   |   4   |

#[derive(Debug, Clone)]
pub struct Region {
    pub name: String,
    pub terrain: String,
    pub climate: String,
    pub primary_good: String,
    pub neighbors: [u8; 3],
}

#[derive(Debug, Clone)]
pub struct Polity {
    pub name: String,
    /// Phase 24 / Этап 2B: на каком регионе живёт полития (1..10);
    /// 0 для EXTINCT-резервов в slots 11..30.
    pub region_id: u8,
    pub population: u32,
    pub peasants_pct: u8,
    pub artisans_pct: u8,
    pub merchants_pct: u8,
    pub nobility_pct: u8,
    pub clergy_pct: u8,
    pub prod_mode: String,
    /// Поле читается, но в UI пока не отображается.
    #[allow(dead_code)]
    pub labour_hours: u64,
    pub surplus_rate: f64,
    pub capital_stock: f64,
    pub class_tension: u8,
    pub military_strength: u32,
    pub at_war_with: u8,
    pub war_year: u16,
    pub war_type: String,
    pub ruler_name: String,
    pub ruler_age: u8,
    pub ruler_trait: String,
    pub ruler_reign: u16,
    pub consciousness: u8,
    pub culture_mil: u8,
    pub culture_merc: u8,
    pub culture_rel: u8,
    pub mode_years: u16,
}

/// Связка геофона и политического слоя.
/// Phase 24 / Этап 2B: regions всегда 10, polities — до 30 (часть из них
/// EXTINCT-резервы для будущего spawn'а наследников).
pub struct World {
    pub regions: Vec<Region>,
    pub polities: Vec<Polity>,
}

impl World {
    /// Phase 24 / Этап 2B: ищем активную политию которая занимает
    /// данный регион. Линейный поиск по polities — на 30 элементов
    /// быстрый, не нужен mapping.
    /// Возвращает (polity_index, &Polity) или None если регион пустой.
    /// Используется UI на B.2+ когда polity_index перестанет совпадать
    /// с region_index. На B.1 ещё не вызывается, но определён уже сейчас.
    #[allow(dead_code)]
    pub fn occupant_of(&self, region_idx: usize) -> Option<(usize, &Polity)> {
        let region_id = (region_idx + 1) as u8;  // 0-indexed → 1-indexed
        self.polities
            .iter()
            .enumerate()
            .find(|(_, p)| p.region_id == region_id && p.prod_mode.trim() != "EXTINCT")
    }
}

fn slice_or_blank(line: &str, start: usize, len: usize) -> &str {
    if start >= line.len() {
        return "";
    }
    let end = (start + len).min(line.len());
    line[start..end].trim()
}

fn parse_u64(s: &str) -> u64 {
    s.parse().unwrap_or(0)
}

fn parse_dec(s: &str) -> f64 {
    parse_u64(s) as f64 / 100.0
}

pub fn parse_regions(path: &str) -> Vec<Region> {
    let content = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return vec![],
    };
    content
        .lines()
        .filter(|l| !l.is_empty())
        .map(|line| Region {
            name:         slice_or_blank(line, 0,  20).to_string(),
            terrain:      slice_or_blank(line, 20, 10).to_string(),
            climate:      slice_or_blank(line, 30, 10).to_string(),
            primary_good: slice_or_blank(line, 40, 15).to_string(),
            neighbors: [
                parse_u64(slice_or_blank(line, 55, 2)) as u8,
                parse_u64(slice_or_blank(line, 57, 2)) as u8,
                parse_u64(slice_or_blank(line, 59, 2)) as u8,
            ],
        })
        .collect()
}

pub fn parse_polities(path: &str) -> Vec<Polity> {
    let content = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return vec![],
    };
    content
        .lines()
        .filter(|l| !l.is_empty())
        .map(|line| Polity {
            name:              slice_or_blank(line, 0,   20).to_string(),
            region_id:         parse_u64(slice_or_blank(line, 20, 2)) as u8,
            population:        parse_u64(slice_or_blank(line, 22, 8)) as u32,
            peasants_pct:      parse_u64(slice_or_blank(line, 30, 3)) as u8,
            artisans_pct:      parse_u64(slice_or_blank(line, 33, 3)) as u8,
            merchants_pct:     parse_u64(slice_or_blank(line, 36, 3)) as u8,
            nobility_pct:      parse_u64(slice_or_blank(line, 39, 3)) as u8,
            clergy_pct:        parse_u64(slice_or_blank(line, 42, 3)) as u8,
            prod_mode:         slice_or_blank(line, 45, 15).to_string(),
            labour_hours:      parse_u64(slice_or_blank(line, 60, 10)),
            surplus_rate:      parse_dec(slice_or_blank(line, 70, 5)),
            capital_stock:     parse_dec(slice_or_blank(line, 75, 12)),
            class_tension:     parse_u64(slice_or_blank(line, 87, 3)) as u8,
            military_strength: parse_u64(slice_or_blank(line, 90, 5)) as u32,
            at_war_with:       parse_u64(slice_or_blank(line, 95, 2)) as u8,
            // collapse_timer @ 97..100 в polities.dat — используется только
            // COBOL'ом для отсчёта REBIRTH-DURATION; UI не отображает.
            war_year:          parse_u64(slice_or_blank(line, 100, 3)) as u16,
            war_type:          slice_or_blank(line, 103, 10).to_string(),
            ruler_name:        slice_or_blank(line, 113, 20).to_string(),
            ruler_age:         parse_u64(slice_or_blank(line, 133, 2)) as u8,
            ruler_trait:       slice_or_blank(line, 135, 10).to_string(),
            ruler_reign:       parse_u64(slice_or_blank(line, 145, 3)) as u16,
            consciousness:     parse_u64(slice_or_blank(line, 148, 3)) as u8,
            culture_mil:       parse_u64(slice_or_blank(line, 151, 3)) as u8,
            culture_merc:      parse_u64(slice_or_blank(line, 154, 3)) as u8,
            culture_rel:       parse_u64(slice_or_blank(line, 157, 3)) as u8,
            mode_years:        parse_u64(slice_or_blank(line, 160, 4)) as u16,
        })
        .collect()
}

/// Удобная единая точка входа: читаем оба файла и собираем `World`.
pub fn parse_world() -> World {
    World {
        regions: parse_regions("cobol/regions.dat"),
        polities: parse_polities("cobol/polities.dat"),
    }
}
