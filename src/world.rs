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
// | peasants_pct   |  28   |   3   |
// | artisans_pct   |  31   |   3   |
// | merchants_pct  |  34   |   3   |
// | nobility_pct   |  37   |   3   |
// | clergy_pct     |  40   |   3   |
// | prod_mode      |  43   |  15   |
// | labour_hours   |  58   |  10   |
// | surplus_rate   |  68   |   5   | (×100, делим)
// | capital_stock  |  73   |  12   | (×100, делим)
// | class_tension  |  85   |   3   |
// | military_strength | 88 |   5   |
// | at_war_with    |  93   |   2   |
// | collapse_timer |  95   |   3   |
// | war_year       |  98   |   3   |
// | war_type       | 101   |  10   |
// | ruler_name     | 111   |  20   |
// | ruler_age      | 131   |   2   |
// | ruler_trait    | 133   |  10   |
// | ruler_reign    | 143   |   3   |
// | consciousness  | 146   |   3   |
// | culture_mil    | 149   |   3   |
// | culture_merc   | 152   |   3   |
// | culture_rel    | 155   |   3   |
// | mode_years     | 158   |   4   |

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

/// Связка геофона и политического слоя. На Этапе 1 длина обоих векторов
/// равна 10 и индекс совпадает: polity_of(i) живёт в regions[i].
pub struct World {
    pub regions: Vec<Region>,
    pub polities: Vec<Polity>,
}

impl World {
    /// Полития в указанном регионе. На Этапе 1 — простая 1:1 связь.
    /// На Этапе 2+ это уже будет lookup через `region_id` поле политии.
    /// Сейчас не используется — UI работает с двумя векторами параллельно;
    /// метод оставлен для будущей миграции на индексирование через polity_id.
    #[allow(dead_code)]
    pub fn polity_of(&self, region_idx: usize) -> Option<&Polity> {
        self.polities.get(region_idx)
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
            population:        parse_u64(slice_or_blank(line, 20, 8)) as u32,
            peasants_pct:      parse_u64(slice_or_blank(line, 28, 3)) as u8,
            artisans_pct:      parse_u64(slice_or_blank(line, 31, 3)) as u8,
            merchants_pct:     parse_u64(slice_or_blank(line, 34, 3)) as u8,
            nobility_pct:      parse_u64(slice_or_blank(line, 37, 3)) as u8,
            clergy_pct:        parse_u64(slice_or_blank(line, 40, 3)) as u8,
            prod_mode:         slice_or_blank(line, 43, 15).to_string(),
            labour_hours:      parse_u64(slice_or_blank(line, 58, 10)),
            surplus_rate:      parse_dec(slice_or_blank(line, 68, 5)),
            capital_stock:     parse_dec(slice_or_blank(line, 73, 12)),
            class_tension:     parse_u64(slice_or_blank(line, 85, 3)) as u8,
            military_strength: parse_u64(slice_or_blank(line, 88, 5)) as u32,
            at_war_with:       parse_u64(slice_or_blank(line, 93, 2)) as u8,
            // collapse_timer @ 95..98 в polities.dat — используется только
            // COBOL'ом для отсчёта REBIRTH-DURATION; UI не отображает.
            war_year:          parse_u64(slice_or_blank(line, 98, 3)) as u16,
            war_type:          slice_or_blank(line, 101, 10).to_string(),
            ruler_name:        slice_or_blank(line, 111, 20).to_string(),
            ruler_age:         parse_u64(slice_or_blank(line, 131, 2)) as u8,
            ruler_trait:       slice_or_blank(line, 133, 10).to_string(),
            ruler_reign:       parse_u64(slice_or_blank(line, 143, 3)) as u16,
            consciousness:     parse_u64(slice_or_blank(line, 146, 3)) as u8,
            culture_mil:       parse_u64(slice_or_blank(line, 149, 3)) as u8,
            culture_merc:      parse_u64(slice_or_blank(line, 152, 3)) as u8,
            culture_rel:       parse_u64(slice_or_blank(line, 155, 3)) as u8,
            mode_years:        parse_u64(slice_or_blank(line, 158, 4)) as u16,
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
