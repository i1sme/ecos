// Парсинг cobol/market.dat. Запись фиксированной длины 51 байт:
//
// | Поле   | Смещение (0-idx) | Длина | COBOL          |
// |--------|------------------|-------|----------------|
// | name   |   0              |  15   | X(15)          |
// | supply |  15              |  14   | 9(12)V99 / 100 |
// | demand |  29              |  14   | 9(12)V99 / 100 |
// | price  |  43              |   7   | 9(5)V99  / 100 |
// | crisis |  50              |   1   | 9              |

#[derive(Debug, Clone)]
pub struct Commodity {
    pub name: String,
    pub supply: f64,
    pub demand: f64,
    pub price: f64,
    pub crisis: bool,
}

pub fn parse_market(path: &str) -> Vec<Commodity> {
    let content = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return vec![],
    };

    content
        .lines()
        .filter(|l| l.len() >= 51)
        .map(|line| {
            let dec = |s: usize, len: usize| -> f64 {
                line[s..s + len].trim().parse::<u64>().unwrap_or(0) as f64 / 100.0
            };
            Commodity {
                name: line[0..15].trim().to_string(),
                supply: dec(15, 14),
                demand: dec(29, 14),
                price: dec(43, 7),
                crisis: &line[50..51] == "1",
            }
        })
        .collect()
}
