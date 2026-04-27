use std::fs;
use std::process::Command;

/// Запускает COBOL-процесс и возвращает короткое сообщение об ошибке если что.
/// Если выставлен ECOS_DEBUG=1 — stderr идёт сквозь (для probability log).
/// На chyba (не-нулевой код) stderr захватывается и первая строка возвращается как Err.
fn run_cobol(bin: &str) -> Result<(), String> {
    let debug = std::env::var("ECOS_DEBUG").as_deref() == Ok("1");
    let mut cmd = Command::new(bin);
    if debug {
        // Прозрачно пробрасываем stderr — пользователь видит log в терминале.
        cmd.stderr(std::process::Stdio::inherit());
    }
    let out = cmd
        .output()
        .map_err(|e| format!("spawn {bin}: {e}"))?;
    if out.status.success() {
        return Ok(());
    }
    let stderr = String::from_utf8_lossy(&out.stderr);
    let stdout = String::from_utf8_lossy(&out.stdout);
    let msg = stderr
        .lines()
        .chain(stdout.lines())
        .find(|l| !l.trim().is_empty())
        .unwrap_or("non-zero exit, no message")
        .trim()
        .to_string();
    Err(msg)
}

pub fn run_world_gen() -> Result<(), String> {
    run_cobol("cobol/world")
}

pub fn run_simulate(year: u32) -> Result<(), String> {
    fs::write("cobol/year.dat", format!("{:04}\n", year))
        .map_err(|e| format!("year.dat: {e}"))?;
    // OPEN EXTEND/INPUT в GnuCOBOL падают если файл не существует.
    // chronicle.dat — для extend; market.dat — для read prices от прошлого хода.
    for f in [
        "cobol/chronicle.dat",
        "cobol/market.dat",
        "cobol/relations.dat",
        "cobol/tech.dat",
    ] {
        if !std::path::Path::new(f).exists() {
            let _ = fs::write(f, "");
        }
    }
    run_cobol("cobol/simulate")
}
