// Парсинг cobol/relations.dat. 10 строк × 10 значений × 4 байта unsigned.
// Хранение со смещением +500: значение 0 = "0500", +50 = "0550", -100 = "0400".
// Симметричная матрица в диапазоне [-100, +100].
//
// Если файла нет / он пустой / короткие строки — возвращаем матрицу нулей.

pub type Relations = [[i8; 10]; 10];

pub fn parse_relations(path: &str) -> Relations {
    let mut m: Relations = [[0; 10]; 10];
    let content = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return m,
    };
    for (i, line) in content.lines().take(10).enumerate() {
        if line.len() < 40 {
            continue;
        }
        for j in 0..10 {
            let chunk = &line[j * 4..j * 4 + 4];
            let raw: i32 = chunk.trim().parse().unwrap_or(500);
            m[i][j] = (raw - 500).clamp(-100, 100) as i8;
        }
    }
    m
}

/// Возвращает (имя соседа, значение отношений) для топ-N союзников/врагов региона.
/// `kind = 1` — союзники (по убыванию), `kind = -1` — враги (по возрастанию).
pub fn top_relations(
    relations: &Relations,
    idx: usize,
    region_names: &[String],
    kind: i32,
    limit: usize,
) -> Vec<(String, i8)> {
    let mut row: Vec<(usize, i8)> = (0..10).map(|j| (j, relations[idx][j])).collect();
    row.retain(|&(j, v)| j != idx && v != 0);
    if kind > 0 {
        row.sort_by_key(|&(_, v)| std::cmp::Reverse(v));
        row.retain(|&(_, v)| v > 0);
    } else {
        row.sort_by_key(|&(_, v)| v);
        row.retain(|&(_, v)| v < 0);
    }
    row.into_iter()
        .take(limit)
        .filter_map(|(j, v)| region_names.get(j).map(|n| (n.clone(), v)))
        .collect()
}
