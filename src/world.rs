// Смещения полей в world.dat (0-indexed, fixed-width, LINE SEQUENTIAL).
// Десятичные поля хранятся без точки: PIC 9(3)V99 → 5 цифр, делить на 100.0.
// Длина строки: 203 байт (Phase 21).
//
// Phase 9: ruler (имя/возраст/трейт/правление) и consciousness.
// Phase 15: 3 culture vectors (militaristic / mercantile / religious), 0..100.
// Phase 21: WS-MODE-YEARS — счётчик ходов в текущей эпохе (минимальная выдержка).
//
// | Поле           | Старт | Длина |
// |----------------|-------|-------|
// | NAME           |   0   |  20   |
// | TERRAIN        |  20   |  10   |
// | CLIMATE        |  30   |  10   |
// | POPULATION     |  40   |   8   |
// | PEASANTS_PCT   |  48   |   3   |
// | ARTISANS_PCT   |  51   |   3   |
// | MERCHANTS_PCT  |  54   |   3   |
// | NOBILITY_PCT   |  57   |   3   |
// | CLERGY_PCT     |  60   |   3   |
// | PROD_MODE      |  63   |  15   |
// | PRIMARY_GOOD   |  78   |  15   |
// | LABOUR_HOURS   |  93   |  10   |
// | SURPLUS_RATE   | 103   |   5   | (9(3)V99, делить на 100)
// | CAPITAL_STOCK  | 108   |  12   | (9(10)V99, делить на 100)
// | CLASS_TENSION  | 120   |   3   |
// | MILITARY_STR   | 123   |   5   |
// | AT_WAR_WITH    | 128   |   2   |
// | COLLAPSE_TIMER | 130   |   3   |
// | WAR_YEAR       | 133   |   3   |
// | WAR_TYPE       | 136   |  10   |
// | NEIGHBOR_1     | 146   |   2   |
// | NEIGHBOR_2     | 148   |   2   |
// | NEIGHBOR_3     | 150   |   2   |
// | RULER_NAME     | 152   |  20   | ← Phase 9
// | RULER_AGE      | 172   |   2   | ← Phase 9
// | RULER_TRAIT    | 174   |  10   | ← Phase 9
// | RULER_REIGN    | 184   |   3   | ← Phase 9
// | CONSCIOUSNESS  | 187   |   3   | ← Phase 9
// | CULTURE_MIL    | 190   |   3   | ← Phase 15
// | CULTURE_MERC   | 193   |   3   | ← Phase 15
// | CULTURE_REL    | 196   |   3   | ← Phase 15
// | MODE_YEARS     | 199   |   4   | ← Phase 21

#[derive(Debug, Clone)]
pub struct Region {
    pub name: String,
    pub terrain: String,
    pub climate: String,
    pub population: u32,
    pub peasants_pct: u8,
    pub artisans_pct: u8,
    pub merchants_pct: u8,
    pub nobility_pct: u8,
    pub clergy_pct: u8,
    pub prod_mode: String,
    pub primary_good: String,
    /// Поле читается из world.dat для полноты, но в UI не отображается.
    #[allow(dead_code)]
    pub labour_hours: u64,
    pub surplus_rate: f64,
    pub capital_stock: f64,
    pub class_tension: u8,
    pub military_strength: u32,
    pub at_war_with: u8,
    pub war_year: u16,
    pub war_type: String,
    pub neighbors: [u8; 3],
    // Phase 9
    pub ruler_name: String,
    pub ruler_age: u8,
    pub ruler_trait: String,
    pub ruler_reign: u16,
    pub consciousness: u8,
    // Phase 15
    pub culture_mil: u8,
    pub culture_merc: u8,
    pub culture_rel: u8,
    // Phase 21
    pub mode_years: u16,
}

pub fn parse_world(path: &str) -> Vec<Region> {
    let content = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return vec![],
    };

    content
        .lines()
        .filter(|l| !l.is_empty())
        .map(|line| {
            let f = |s: usize, len: usize| -> &str {
                if s >= line.len() {
                    return "";
                }
                line[s..(s + len).min(line.len())].trim()
            };

            let dec = |s: usize, len: usize| -> f64 {
                f(s, len).parse::<u64>().unwrap_or(0) as f64 / 100.0
            };

            let num = |s: usize, len: usize| -> u64 {
                f(s, len).parse().unwrap_or(0)
            };

            Region {
                name:              f(0,   20).to_string(),
                terrain:           f(20,  10).to_string(),
                climate:           f(30,  10).to_string(),
                population:        num(40, 8) as u32,
                peasants_pct:      num(48, 3) as u8,
                artisans_pct:      num(51, 3) as u8,
                merchants_pct:     num(54, 3) as u8,
                nobility_pct:      num(57, 3) as u8,
                clergy_pct:        num(60, 3) as u8,
                prod_mode:         f(63,  15).to_string(),
                primary_good:      f(78,  15).to_string(),
                labour_hours:      num(93, 10),
                surplus_rate:      dec(103, 5),
                capital_stock:     dec(108, 12),
                class_tension:     num(120, 3) as u8,
                military_strength: num(123, 5) as u32,
                at_war_with:       num(128, 2) as u8,
                war_year:          num(133, 3) as u16,
                war_type:          f(136, 10).to_string(),
                neighbors: [
                    num(146, 2) as u8,
                    num(148, 2) as u8,
                    num(150, 2) as u8,
                ],
                ruler_name:    f(152, 20).to_string(),
                ruler_age:     num(172, 2) as u8,
                ruler_trait:   f(174, 10).to_string(),
                ruler_reign:   num(184, 3) as u16,
                consciousness: num(187, 3) as u8,
                culture_mil:   num(190, 3) as u8,
                culture_merc:  num(193, 3) as u8,
                culture_rel:   num(196, 3) as u8,
                mode_years:    num(199, 4) as u16,
            }
        })
        .collect()
}
