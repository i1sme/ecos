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
/// Phase 24 — Этап 1: world.dat расщеплён на regions.dat + polities.dat.
/// Старые слоты (с одним world.dat) автоматически мигрируются при load
/// функцией `migrate_legacy_slot()`.
const SAVE_FILES: [&str; 7] = [
    "regions.dat",
    "polities.dat",
    "year.dat",
    "chronicle.dat",
    "market.dat",
    "relations.dat",
    "tech.dat",
];

/// Legacy world.dat для миграции — оставлен в SAVE_FILES для записи в case
/// если кто-то положил world.dat вручную, но при первой load он расщепляется
/// на regions.dat + polities.dat и переименовывается в world.dat.legacy.
const LEGACY_WORLD: &str = "world.dat";

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
/// Phase 24 — Этап 1: «существующим» считается слот, у которого есть либо
/// regions.dat (новый формат), либо world.dat (legacy, мигрируется при load).
pub fn list_slots() -> Vec<SlotInfo> {
    (1..=SLOT_COUNT)
        .map(|i| {
            let dir = slot_dir(i);
            let regions = dir.join("regions.dat");
            let legacy_world = dir.join(LEGACY_WORLD);
            let has_regions = regions.exists()
                && regions.metadata().map(|m| m.len() > 0).unwrap_or(false);
            let has_legacy = legacy_world.exists()
                && legacy_world.metadata().map(|m| m.len() > 0).unwrap_or(false);
            if has_regions || has_legacy {
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

/// Phase 24 — Этап 1: разбивает legacy `world.dat` на `regions.dat` +
/// `polities.dat` по offset'ам Phase 21 (203/204-байтные строки).
/// Идемпотентен: если regions.dat уже существует, вызов no-op.
/// Оригинал world.dat НЕ удаляется — переименовывается в world.dat.legacy
/// для возможности отката.
fn migrate_legacy_slot(slot_dir: &Path) -> io::Result<()> {
    let world = slot_dir.join(LEGACY_WORLD);
    let regions_path = slot_dir.join("regions.dat");
    let polities_path = slot_dir.join("polities.dat");
    if !world.exists() || regions_path.exists() {
        return Ok(());
    }
    let content = fs::read_to_string(&world)?;
    let mut regions_out = String::new();
    let mut polities_out = String::new();
    for line in content.lines() {
        if line.is_empty() {
            continue;
        }
        // legacy layout (Phase 21, 0-indexed Rust offsets):
        //   name 0..20 | terrain 20..30 | climate 30..40 | population 40..48
        //   classes 48..63 | prod_mode 63..78 | primary_good 78..93
        //   labour_hours 93..103 | surplus_rate 103..108 | capital_stock 108..120
        //   class_tension 120..123 | military 123..128 | at_war_with 128..130
        //   collapse_timer 130..133 | war_year 133..136 | war_type 136..146
        //   neighbors 146..152 | ruler_name 152..172 | ruler_age 172..174
        //   ruler_trait 174..184 | ruler_reign 184..187 | consciousness 187..190
        //   culture 190..199 | mode_years 199..203 (или отсутствует у самых старых)
        let take = |start: usize, len: usize| -> &str {
            if start >= line.len() {
                return "";
            }
            let end = (start + len).min(line.len());
            &line[start..end]
        };
        // regions.dat: name | terrain | climate | primary_good | neighbors
        regions_out.push_str(&format!(
            "{:20}{:10}{:10}{:15}{:6}\n",
            take(0, 20),
            take(20, 10),
            take(30, 10),
            take(78, 15),
            take(146, 6),
        ));
        // polities.dat: name | population | classes | prod_mode | labour_hours |
        //   surplus_rate | capital_stock | class_tension | military | at_war_with |
        //   collapse_timer | war_year | war_type | ruler_name | ruler_age |
        //   ruler_trait | ruler_reign | consciousness | culture | mode_years
        let mode_years_field = if line.len() >= 203 {
            take(199, 4).to_string()
        } else {
            "0000".to_string()
        };
        polities_out.push_str(&format!(
            "{:20}{:8}{:15}{:15}{:10}{:5}{:12}{:3}{:5}{:2}{:3}{:3}{:10}{:20}{:2}{:10}{:3}{:3}{:9}{:4}\n",
            take(0, 20),
            take(40, 8),
            take(48, 15), // 5×3 классов одной строкой
            take(63, 15),
            take(93, 10),
            take(103, 5),
            take(108, 12),
            take(120, 3),
            take(123, 5),
            take(128, 2),
            take(130, 3),
            take(133, 3),
            take(136, 10),
            take(152, 20),
            take(172, 2),
            take(174, 10),
            take(184, 3),
            take(187, 3),
            take(190, 9), // 3×3 культур
            mode_years_field,
        ));
    }
    fs::write(&regions_path, regions_out)?;
    fs::write(&polities_path, polities_out)?;
    // Переименовываем legacy в .legacy для возможности отката.
    let legacy_renamed = slot_dir.join("world.dat.legacy");
    let _ = fs::rename(&world, &legacy_renamed);
    Ok(())
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
/// Phase 24 — Этап 1: автоматически мигрирует legacy world.dat в slot
/// в regions.dat + polities.dat если миграция ещё не выполнялась.
pub fn load_from_slot(idx: usize) -> io::Result<()> {
    if !(1..=SLOT_COUNT).contains(&idx) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "bad slot index"));
    }
    let src_dir = slot_dir(idx);
    if !src_dir.exists() {
        return Err(io::Error::new(io::ErrorKind::NotFound, "slot empty"));
    }
    // Миграция legacy → split. Идемпотентно.
    migrate_legacy_slot(&src_dir)?;
    fs::create_dir_all(COBOL_DIR)?;
    // Дополнительно подчищаем устаревший world.dat в live-каталоге чтобы
    // simulate.cob не парсил его (он его уже не читает, но во избежание
    // путаницы при ручной отладке).
    let _ = fs::remove_file(Path::new(COBOL_DIR).join(LEGACY_WORLD));
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

#[cfg(test)]
mod tests {
    use super::*;

    /// Smoke-тест миграции legacy. Создаёт временный slot с world.dat
    /// (Phase 21 формат, 203 байта), вызывает migrate_legacy_slot,
    /// проверяет что появились regions.dat и polities.dat корректных размеров.
    #[test]
    fn legacy_migration_splits_world_dat() {
        let tmp = std::env::temp_dir().join("ecos_test_slot");
        let _ = fs::remove_dir_all(&tmp);
        fs::create_dir_all(&tmp).unwrap();

        // Сэмпл строки world.dat (Phase 21, 203 байт): минимально валидный
        // регион Ironmarch, SLAVE, Gareth/PIOUS.
        let mut sample = String::new();
        sample.push_str("Ironmarch           "); // name 0..20
        sample.push_str("PLAINS    ");           // terrain 20..30
        sample.push_str("TEMPERATE ");           // climate 30..40
        sample.push_str("01000000");             // population 40..48
        sample.push_str("066014012005003");      // classes 48..63
        sample.push_str("SLAVE          ");      // prod_mode 63..78
        sample.push_str("GRAIN          ");      // primary_good 78..93
        sample.push_str("0000050000");           // labour_hours 93..103
        sample.push_str("03000");                // surplus_rate 103..108
        sample.push_str("000000050000");         // capital_stock 108..120
        sample.push_str("020");                  // class_tension 120..123
        sample.push_str("00050");                // military 123..128
        sample.push_str("00");                   // at_war_with 128..130
        sample.push_str("000");                  // collapse_timer 130..133
        sample.push_str("000");                  // war_year 133..136
        sample.push_str("PEACE     ");           // war_type 136..146
        sample.push_str("020407");               // neighbors 146..152
        sample.push_str("Gareth              "); // ruler_name 152..172
        sample.push_str("25");                   // ruler_age 172..174
        sample.push_str("PIOUS     ");           // ruler_trait 174..184
        sample.push_str("004");                  // ruler_reign 184..187
        sample.push_str("010");                  // consciousness 187..190
        sample.push_str("002000008");            // culture 190..199
        sample.push_str("0000");                 // mode_years 199..203
        assert_eq!(sample.len(), 203);
        sample.push('\n');

        fs::write(tmp.join("world.dat"), &sample).unwrap();
        fs::write(tmp.join("year.dat"), "0500\n").unwrap();

        migrate_legacy_slot(&tmp).unwrap();

        let regions = fs::read_to_string(tmp.join("regions.dat")).unwrap();
        let polities = fs::read_to_string(tmp.join("polities.dat")).unwrap();
        assert!(regions.contains("Ironmarch"), "regions.dat must include geo name");
        assert!(regions.contains("PLAINS"),    "regions.dat must include terrain");
        assert!(regions.contains("GRAIN"),     "regions.dat must include primary_good");
        assert!(polities.contains("Ironmarch"),"polities.dat must include polity name");
        assert!(polities.contains("SLAVE"),    "polities.dat must include prod_mode");
        assert!(polities.contains("Gareth"),   "polities.dat must include ruler");
        assert!(polities.contains("PIOUS"),    "polities.dat must include trait");
        // legacy переименован
        assert!(!tmp.join("world.dat").exists(),
                "legacy world.dat should have been renamed");
        assert!(tmp.join("world.dat.legacy").exists(),
                "world.dat.legacy must remain for rollback");

        // Идемпотентность: повторный вызов — no-op.
        migrate_legacy_slot(&tmp).unwrap();

        let _ = fs::remove_dir_all(&tmp);
    }
}

/// Стирает все cobol/*.dat — следующий запуск world.cob создаст свежий мир.
/// Год в Rust сбрасывается отдельно (вызывающим кодом).
pub fn new_game() -> io::Result<()> {
    fs::create_dir_all(COBOL_DIR)?;
    for f in SAVE_FILES {
        let p = Path::new(COBOL_DIR).join(f);
        let _ = fs::remove_file(&p);
    }
    // Также стираем legacy world.dat если остался от старой версии.
    let _ = fs::remove_file(Path::new(COBOL_DIR).join(LEGACY_WORLD));
    Ok(())
}
