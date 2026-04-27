// Парсинг cobol/tech.dat. Phase 18: 24 байт/строка с L3 + L4 choice.
//
// | Поле          | Смещение (1-idx COBOL) | Длина |
// |---------------|------------------------|-------|
// | level B1..B4  | 1..4                   | 1 each |
// | progress B1   | 5                      | 3 |
// | progress B2   | 8                      | 3 |
// | progress B3   | 11                     | 3 |
// | progress B4   | 14                     | 3 |
// | L3 choice 1..4| 17..20                 | 1 each | ← Phase 17
// | L4 choice 1..4| 21..24                 | 1 each | ← Phase 18
//
// 4 ветви × (L1, L2, L3 с 3 alts, L4 с 2 sub-tech на alt) = до 4 уровней глубины.

pub const BRANCH_COUNT: usize = 4;
pub const BRANCH_SHORT: [&str; BRANCH_COUNT] = ["prod", "org ", "know", "pow "];

/// Имена техов: TECH_NAMES[branch][level], где level 0..3.
/// Для level == 3 — общий placeholder, конкретное имя через L3_ALTERNATIVES.
pub const TECH_NAMES: [[&str; 4]; BRANCH_COUNT] = [
    ["—", "Bronze", "Iron", "(L3 PROD)"],
    ["—", "Coinage", "Banking", "(L3 ORG)"],
    ["—", "Writing", "Printing", "(L3 KNOW)"],
    ["—", "StandArm", "Bureauc", "(L3 POW)"],
];

/// L3 альтернативы по ветвям. Index 0 = не выбрано; 1/2/3 — конкретный путь.
pub const L3_ALTERNATIVES: [[&str; 4]; BRANCH_COUNT] = [
    ["?", "Steam",      "Forging",   "Hydraulics"],
    ["?", "JointStk",   "Coopers",   "Cartels"],
    ["?", "Empiric",    "Scholast",  "FolkWisd"],
    ["?", "MassCons",   "ProfArmy",  "Militia"],
];

/// L4 sub-tech имена. Индексирование: [branch][l3_choice][l4_choice].
/// l3_choice 1..3, l4_choice 1..2; индекс 0 = placeholder.
pub const L4_SUBTECHS: [[[&str; 3]; 4]; BRANCH_COUNT] = [
    // PROD
    [
        ["?", "?", "?"],          // l3 = 0 (no choice)
        ["?", "Gasoline", "Turbine"],   // l3 = 1 Steam
        ["?", "Damascus", "Crossbow"],  // l3 = 2 Forging
        ["?", "WindTurb", "TidalMl"],   // l3 = 3 Hydraulics
    ],
    // ORG
    [
        ["?", "?", "?"],
        ["?", "StockMkt", "LimLiab"],   // JointStk
        ["?", "MutAid",   "WorkOwn"],   // Coopers
        ["?", "Trusts",   "VertInt"],   // Cartels
    ],
    // KNOW
    [
        ["?", "?", "?"],
        ["?", "SciMeth",  "Special"],   // Empiric
        ["?", "Theology", "ComLaw"],    // Scholast
        ["?", "OralTrad", "PracCrft"],  // FolkWisd
    ],
    // POW
    [
        ["?", "?", "?"],
        ["?", "TotalWar", "Reserves"],  // MassCons
        ["?", "OffCorps", "SpecOps"],   // ProfArmy
        ["?", "CitArmy",  "Guerrilla"], // Militia
    ],
];

#[derive(Default, Clone, Copy)]
pub struct RegionTech {
    pub levels: [u8; BRANCH_COUNT],
    pub progress: [u8; BRANCH_COUNT],
    pub l3_choice: [u8; BRANCH_COUNT],
    pub l4_choice: [u8; BRANCH_COUNT],
}

impl RegionTech {
    /// Имя текущего top-tech в ветви: для L<3 — обычное имя, L3 — alternative,
    /// L4 — sub-tech.
    pub fn current_tech_name(&self, branch: usize) -> &'static str {
        let lvl = self.levels[branch] as usize;
        match lvl {
            0..=2 => TECH_NAMES[branch][lvl],
            3 => L3_ALTERNATIVES[branch][self.l3_choice[branch] as usize],
            _ => {
                let l3 = self.l3_choice[branch] as usize;
                let l4 = self.l4_choice[branch] as usize;
                L4_SUBTECHS[branch][l3][l4]
            }
        }
    }
}

pub fn parse_tech(path: &str) -> Vec<RegionTech> {
    let content = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return vec![],
    };

    content
        .lines()
        .filter(|l| l.len() >= 16)
        .map(|line| {
            let mut t = RegionTech::default();
            for b in 0..BRANCH_COUNT {
                t.levels[b] = line[b..b + 1].parse().unwrap_or(0);
            }
            for b in 0..BRANCH_COUNT {
                let start = 4 + b * 3;
                t.progress[b] = line[start..start + 3].parse().unwrap_or(0);
            }
            if line.len() >= 20 {
                for b in 0..BRANCH_COUNT {
                    t.l3_choice[b] = line[16 + b..16 + b + 1].parse().unwrap_or(0);
                }
            }
            if line.len() >= 24 {
                for b in 0..BRANCH_COUNT {
                    t.l4_choice[b] = line[20 + b..20 + b + 1].parse().unwrap_or(0);
                }
            }
            t
        })
        .collect()
}
