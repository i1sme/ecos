// Save/load механика. 5 фиксированных слотов в `saves/slotN/`.
// Каждый слот — копия всех cobol/*.dat файлов.
// Год хранится в year.dat (тот же что использует COBOL),
// при загрузке Rust перечитывает его и продолжает счёт с того места.

use std::fs;
use std::io;
use std::path::{Path, PathBuf};

const SAVE_DIR: &str = "saves";
const COBOL_DIR: &str = "cobol";
pub const SLOT_COUNT: usize = 5;

/// Файлы, входящие в полный snapshot мира.
/// Все опциональны на загрузке — если в save'е нет (например старого формата),
/// просто не копируется (live-файл остаётся пустым, simulate.cob отнесётся
/// к этому как к "новой игре" для соответствующей подсистемы).
const SAVE_FILES: [&str; 6] = [
    "world.dat",
    "year.dat",
    "chronicle.dat",
    "market.dat",
    "relations.dat",
    "tech.dat",
];

#[derive(Clone)]
pub struct SlotInfo {
    pub idx: usize,           // 1..=SLOT_COUNT
    pub year: Option<u32>,    // None если слот пуст
}

fn slot_dir(idx: usize) -> PathBuf {
    PathBuf::from(SAVE_DIR).join(format!("slot{idx}"))
}

/// Читает текущий year из cobol/year.dat (если есть).
pub fn current_year() -> u32 {
    fs::read_to_string(Path::new(COBOL_DIR).join("year.dat"))
        .ok()
        .and_then(|s| s.trim().parse::<u32>().ok())
        .unwrap_or(0)
}

/// Возвращает 5 слотов (включая пустые) — для отображения в меню.
pub fn list_slots() -> Vec<SlotInfo> {
    (1..=SLOT_COUNT)
        .map(|i| {
            let dir = slot_dir(i);
            let world = dir.join("world.dat");
            if world.exists() && world.metadata().map(|m| m.len() > 0).unwrap_or(false) {
                let year = fs::read_to_string(dir.join("year.dat"))
                    .ok()
                    .and_then(|s| s.trim().parse::<u32>().ok());
                SlotInfo { idx: i, year }
            } else {
                SlotInfo { idx: i, year: None }
            }
        })
        .collect()
}

/// Сохраняет текущий cobol/* в slot. Перезаписывает существующий.
pub fn save_to_slot(idx: usize) -> io::Result<()> {
    if !(1..=SLOT_COUNT).contains(&idx) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "bad slot index"));
    }
    let dst_dir = slot_dir(idx);
    fs::create_dir_all(&dst_dir)?;
    for f in SAVE_FILES {
        let src = Path::new(COBOL_DIR).join(f);
        let dst = dst_dir.join(f);
        if src.exists() {
            fs::copy(&src, &dst)?;
        } else {
            // Если живого файла нет (например, никогда не симулировали) —
            // удаляем устаревший в слоте, чтобы snapshot был согласованным.
            let _ = fs::remove_file(&dst);
        }
    }
    Ok(())
}

/// Загружает slot в cobol/. Удаляет live-файлы которых нет в слоте,
/// чтобы остатки прошлой игры не протекли в загруженный мир.
pub fn load_from_slot(idx: usize) -> io::Result<()> {
    if !(1..=SLOT_COUNT).contains(&idx) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "bad slot index"));
    }
    let src_dir = slot_dir(idx);
    if !src_dir.exists() {
        return Err(io::Error::new(io::ErrorKind::NotFound, "slot empty"));
    }
    fs::create_dir_all(COBOL_DIR)?;
    for f in SAVE_FILES {
        let src = src_dir.join(f);
        let dst = Path::new(COBOL_DIR).join(f);
        if src.exists() {
            fs::copy(&src, &dst)?;
        } else {
            // Slot не содержит этот файл — стираем live, чтобы не остался
            // "хвост" предыдущей игры (особенно опасно для tech.dat / chronicle.dat).
            let _ = fs::remove_file(&dst);
        }
    }
    Ok(())
}

/// Стирает все cobol/*.dat — следующий запуск world.cob создаст свежий мир.
/// Год в Rust сбрасывается отдельно (вызывающим кодом).
pub fn new_game() -> io::Result<()> {
    fs::create_dir_all(COBOL_DIR)?;
    for f in SAVE_FILES {
        let p = Path::new(COBOL_DIR).join(f);
        let _ = fs::remove_file(&p);
    }
    Ok(())
}
