use std::io::{self, stdout};

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Cell, List, ListItem, Paragraph, Row, Sparkline, Table, TableState},
    Frame, Terminal,
};

use crate::engine::{run_simulate, run_world_gen};
use crate::history::WorldHistory;
use crate::market::parse_market;
use crate::relations::{parse_relations, top_relations};
use crate::saves;
use crate::tech::{parse_tech, BRANCH_COUNT, BRANCH_SHORT, L3_ALTERNATIVES, L4_SUBTECHS, RegionTech};
use crate::world::{parse_world, Polity, Region};

/// Что показываем в правой панели — детали региона, мировой дашборд, или древо.
#[derive(Clone, Copy, PartialEq)]
enum DetailView {
    Region,
    Dashboard,
    TechTree,
}

/// Категории фильтра хроники.
#[derive(Clone, Copy, PartialEq)]
enum ChronicleFilter {
    All,
    Wars,
    Politics,   // REVOLUTION / COLLAPSE / REBIRTH / CLASS-WAR
    Climate,    // EPIDEMIC / DROUGHT / STORM / etc.
    Region,     // только текущий выбранный регион
}

impl ChronicleFilter {
    fn next(self) -> Self {
        match self {
            ChronicleFilter::All => ChronicleFilter::Wars,
            ChronicleFilter::Wars => ChronicleFilter::Politics,
            ChronicleFilter::Politics => ChronicleFilter::Climate,
            ChronicleFilter::Climate => ChronicleFilter::Region,
            ChronicleFilter::Region => ChronicleFilter::All,
        }
    }

    fn label(self) -> &'static str {
        match self {
            ChronicleFilter::All => "all",
            ChronicleFilter::Wars => "wars",
            ChronicleFilter::Politics => "politics",
            ChronicleFilter::Climate => "climate",
            ChronicleFilter::Region => "region",
        }
    }

    fn matches(self, e: &ChronicleEntry, region_name: &str) -> bool {
        match self {
            ChronicleFilter::All => true,
            ChronicleFilter::Wars => matches!(
                e.event_type.as_str(),
                "WAR-START" | "WAR-END"
            ),
            ChronicleFilter::Politics => matches!(
                e.event_type.as_str(),
                "REVOLUTION" | "COLLAPSE" | "REBIRTH" | "CLASS-WAR"
                | "RULER-DEATH" | "RULER-RISE" | "TECH-LOOT"
            ),
            ChronicleFilter::Climate => matches!(
                e.event_type.as_str(),
                "EPIDEMIC" | "DROUGHT" | "CAVE-IN" | "BUMPER-CROP" | "BAD-HARVEST" | "STORM" | "BLIGHT" | "FAMINE"
            ),
            ChronicleFilter::Region => e.region.trim() == region_name.trim(),
        }
    }
}

struct ChronicleEntry {
    year: u32,
    event_type: String,
    region: String,
    description: String,
}

fn parse_chronicle(path: &str) -> Vec<ChronicleEntry> {
    let content = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return vec![],
    };
    content
        .lines()
        .filter(|l| l.len() >= 39)
        .map(|line| ChronicleEntry {
            year: line[0..4].trim().parse().unwrap_or(0),
            event_type: line[4..19].trim().to_string(),
            region: line[19..39].trim().to_string(),
            description: line[39..].trim().to_string(),
        })
        .collect()
}

fn tension_color(t: u8) -> Color {
    match t {
        0..=39  => Color::Green,
        40..=69 => Color::Yellow,
        70..=89 => Color::Red,
        _       => Color::Magenta,
    }
}

fn tension_label(t: u8) -> &'static str {
    match t {
        0..=39  => "Stable",
        40..=69 => "Unrest",
        70..=89 => "Strike",
        90..=99 => "Revolt",
        _       => "REVOLUTION",
    }
}

fn is_collapsed(mode: &str) -> bool {
    mode.trim() == "COLLAPSED"
}

/// Phase 24 / Этап 2A — окончательно вымершая полития.
fn is_extinct(mode: &str) -> bool {
    mode.trim() == "EXTINCT"
}

/// Полития исключена из активной симуляции (COLLAPSED — временно,
/// EXTINCT — навсегда). Соответствует COBOL-условию `POLITY-DORMANT`.
#[allow(dead_code)]
fn is_dormant(mode: &str) -> bool {
    is_collapsed(mode) || is_extinct(mode)
}

/// Цвет эпохи — визуально отличает 8 ступеней лестницы + два «бездействующих».
fn mode_color(mode: &str) -> Color {
    match mode.trim() {
        "PRIMITIVE"      => Color::DarkGray,
        "SLAVE"          => Color::Yellow,
        "FEUDAL"         => Color::White,
        "MERCANTILE"     => Color::LightGreen,
        "PROTO-INDUSTRL" => Color::LightCyan,
        "INDUSTRIAL"     => Color::LightBlue,
        "IMPERIAL"       => Color::LightMagenta,
        "SOCIALIST"      => Color::Red,        // Phase 15: yes, красный
        "COLLAPSED"      => Color::DarkGray,
        "EXTINCT"        => Color::DarkGray,   // Phase 24 / Этап 2A
        _                => Color::Gray,
    }
}

/// Форматирует крупное число в человекочитаемый вид: 12,600,000 → "12.6M".
fn humanize(v: f64) -> String {
    let abs = v.abs();
    if abs >= 1_000_000.0 {
        format!("{:.1}M", v / 1_000_000.0)
    } else if abs >= 1_000.0 {
        format!("{:.1}K", v / 1_000.0)
    } else {
        format!("{v:.0}")
    }
}

/// Цвет товара по соотношению supply / demand.
fn market_status_color(supply: f64, demand: f64) -> Color {
    if demand <= 0.0 {
        return Color::Gray;
    }
    let ratio = supply / demand;
    if ratio > 1.2 {
        Color::Red       // перепроизводство — кризис
    } else if ratio < 0.8 {
        Color::Yellow    // дефицит — цены растут
    } else {
        Color::Green     // равновесие
    }
}

/// Результат работы стартового меню — что делать дальше.
enum StartChoice {
    NewGame,
    Load(usize), // slot index 1..=5
    Quit,
}

/// Тип модального диалога слотов в основном цикле.
#[derive(Clone, Copy, PartialEq)]
enum SlotDialog {
    Save,
    Load,
}

impl SlotDialog {
    fn title(self) -> &'static str {
        match self {
            SlotDialog::Save => " Save to slot ",
            SlotDialog::Load => " Load slot ",
        }
    }
}

/// Стартовое меню: показывает 5 слотов + New/Quit. Блокирующий вход в run().
fn run_start_menu<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
) -> io::Result<StartChoice> {
    // 0 = New game, 1..=5 = соответствующий slot, 6 = Quit
    let mut cursor: usize = 0;
    loop {
        let slots = saves::list_slots();
        terminal.draw(|f| {
            let area = f.size();
            // Центрируем небольшое окно меню
            let menu_w: u16 = 50;
            let menu_h: u16 = (saves::SLOT_COUNT as u16) + 6; // header + N + Q + borders
            let x = area.x + area.width.saturating_sub(menu_w) / 2;
            let y = area.y + area.height.saturating_sub(menu_h) / 2;
            let rect = Rect::new(x, y, menu_w.min(area.width), menu_h.min(area.height));

            let mut lines: Vec<Line> = Vec::new();
            lines.push(Line::from(Span::styled(
                "  ECOS WORLD SIMULATOR",
                Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
            )));
            lines.push(Line::from(""));

            // Опции: New game / 5 slots / Quit
            let entries: Vec<(usize, String, Color)> = {
                let mut v = vec![(0, "  [N]  New game".to_string(), Color::LightGreen)];
                for s in &slots {
                    let label = match s.year {
                        Some(y) => format!("  [{}]  Load slot {} — Year {:04}", s.idx, s.idx, y),
                        None => format!("  [{}]  Slot {} — empty", s.idx, s.idx),
                    };
                    let color = if s.year.is_some() { Color::White } else { Color::DarkGray };
                    v.push((s.idx, label, color));
                }
                v.push((saves::SLOT_COUNT + 1, "  [Q]  Quit".to_string(), Color::Gray));
                v
            };

            for (i, (_, label, color)) in entries.iter().enumerate() {
                let style = if i == cursor {
                    Style::default().fg(*color).bg(Color::DarkGray).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(*color)
                };
                lines.push(Line::from(Span::styled(label.clone(), style)));
            }
            lines.push(Line::from(""));
            lines.push(Line::from(Span::styled(
                "  ↑↓ select   Enter confirm   N/L1-5/Q shortcut",
                Style::default().fg(Color::DarkGray),
            )));

            let block = Block::default()
                .borders(Borders::ALL)
                .title(" Start ")
                .style(Style::default().fg(Color::White));
            f.render_widget(Paragraph::new(lines).block(block), rect);
        })?;

        if event::poll(std::time::Duration::from_millis(200))? {
            if let Event::Key(key) = event::read()? {
                if key.kind != KeyEventKind::Press {
                    continue;
                }
                let total = saves::SLOT_COUNT + 2; // N + 5 + Q
                match key.code {
                    KeyCode::Char('q') | KeyCode::Char('Q') | KeyCode::Esc => {
                        return Ok(StartChoice::Quit);
                    }
                    KeyCode::Char('n') | KeyCode::Char('N') => {
                        return Ok(StartChoice::NewGame);
                    }
                    KeyCode::Char(c @ '1'..='5') => {
                        let idx = c.to_digit(10).unwrap() as usize;
                        let slots = saves::list_slots();
                        if slots.iter().any(|s| s.idx == idx && s.year.is_some()) {
                            return Ok(StartChoice::Load(idx));
                        }
                        // Иначе — клавиша игнорируется (слот пуст)
                    }
                    KeyCode::Up => {
                        if cursor > 0 {
                            cursor -= 1;
                        }
                    }
                    KeyCode::Down => {
                        if cursor + 1 < total {
                            cursor += 1;
                        }
                    }
                    KeyCode::Enter => {
                        // 0 = New, 1..=5 = slot, 6 = Quit
                        if cursor == 0 {
                            return Ok(StartChoice::NewGame);
                        } else if cursor == total - 1 {
                            return Ok(StartChoice::Quit);
                        } else {
                            let idx = cursor; // 1..=5
                            let slots = saves::list_slots();
                            if slots.iter().any(|s| s.idx == idx && s.year.is_some()) {
                                return Ok(StartChoice::Load(idx));
                            }
                            // Слот пуст — игнор
                        }
                    }
                    _ => {}
                }
            }
        }
    }
}

/// Рисует overlay-диалог выбора слота (Save или Load) поверх игры.
fn render_slot_dialog(f: &mut Frame, area: Rect, dialog: SlotDialog) {
    let slots = saves::list_slots();
    let menu_w: u16 = 50;
    let menu_h: u16 = (saves::SLOT_COUNT as u16) + 5;
    let x = area.x + area.width.saturating_sub(menu_w) / 2;
    let y = area.y + area.height.saturating_sub(menu_h) / 2;
    let rect = Rect::new(x, y, menu_w.min(area.width), menu_h.min(area.height));

    let mut lines: Vec<Line> = Vec::new();
    lines.push(Line::from(""));
    for s in &slots {
        let label = match s.year {
            Some(y) => format!("  [{}]  Slot {} — Year {:04}", s.idx, s.idx, y),
            None => format!("  [{}]  Slot {} — empty", s.idx, s.idx),
        };
        let color = if s.year.is_some() { Color::White } else { Color::DarkGray };
        lines.push(Line::from(Span::styled(label, Style::default().fg(color))));
    }
    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled(
        "  1-5 select slot   Esc cancel",
        Style::default().fg(Color::DarkGray),
    )));

    let block = Block::default()
        .borders(Borders::ALL)
        .title(dialog.title())
        .style(Style::default().fg(Color::White).bg(Color::Black));
    f.render_widget(ratatui::widgets::Clear, rect); // прозрачный фон
    f.render_widget(Paragraph::new(lines).block(block), rect);
}

pub fn run() -> io::Result<()> {
    // Phase 24 — Этап 1: world.dat расщеплён. Существование regions.dat —
    // признак сгенерированного мира.
    let regions_path = "cobol/regions.dat";
    let chronicle_path = "cobol/chronicle.dat";

    enable_raw_mode()?;
    let mut out = stdout();
    execute!(out, EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(out))?;

    // Стартовое меню: New / Load slot N / Quit. Возвращает выбор пользователя.
    let start = run_start_menu(&mut terminal)?;

    let mut year: u32 = match start {
        StartChoice::NewGame => {
            // Стираем старые данные, генерируем свежий мир.
            let _ = saves::new_game();
            let _ = run_world_gen();
            0
        }
        StartChoice::Load(idx) => match saves::load_from_slot(idx) {
            Ok(()) => saves::current_year(),
            Err(_) => {
                // Слот пуст / ошибка — fallback на свежий мир.
                let _ = saves::new_game();
                let _ = run_world_gen();
                0
            }
        },
        StartChoice::Quit => {
            disable_raw_mode()?;
            execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
            terminal.show_cursor()?;
            return Ok(());
        }
    };

    // Если по какой-то причине regions.dat не появился (новый запуск,
    // или старый сейв в legacy формате не мигрировал) — сгенерируем мир
    // заново, чтобы UI не падал на парсинге пустого файла.
    if !std::path::Path::new(regions_path).exists() {
        let _ = run_world_gen();
        year = 0;
    }

    // None = ещё не запускали; Ok = успех; Err(msg) = stderr COBOL.
    let mut last_sim: Option<Result<(), String>> = None;
    let mut selected: usize = 0;
    let mut table_state = TableState::default();
    table_state.select(Some(0));

    // Phase 10 — auto-step: [A] переключает режим, шаг каждые 500мс.
    let mut auto_step = false;
    let mut last_step = std::time::Instant::now();
    let auto_step_interval = std::time::Duration::from_millis(500);

    // Phase 12 — наблюдаемость; Phase 16 — расширено tech tree view
    let mut history = WorldHistory::new(10);
    let mut chronicle_filter = ChronicleFilter::All;
    let mut view = DetailView::Region;

    // Phase 20 — save/load. None = нет диалога; Some(SaveOrLoad) = модальный overlay.
    let mut slot_dialog: Option<SlotDialog> = None;
    // Краткий статус операции save/load для строки заголовка (на 1 кадр).
    let mut transient_status: Option<String> = None;

    let market_path = "cobol/market.dat";
    let relations_path = "cobol/relations.dat";
    let tech_path = "cobol/tech.dat";

    'main: loop {
        // Phase 24 — Этап 1: parse_world() читает оба файла regions.dat
        // и polities.dat. На Этапе 1 polity[i] всегда живёт в region[i],
        // имена синхронизированы. UI работает с двумя векторами параллельно.
        let world = parse_world();
        let regions: &Vec<Region> = &world.regions;
        let polities: &Vec<Polity> = &world.polities;
        let chronicle = parse_chronicle(chronicle_path);
        let market = parse_market(market_path);
        let relations = parse_relations(relations_path);
        let tech = parse_tech(tech_path);
        let region_names: Vec<String> = regions.iter().map(|r| r.name.clone()).collect();
        let n = regions.len().min(polities.len());

        // Записываем снимок истории если год сменился (per-session, в памяти)
        history.record_if_new_year(year, polities, |p: &Polity| {
            (p.class_tension as u64, p.population as u64, p.capital_stock as u64)
        });

        terminal.draw(|f| {
            let area = f.size();

            // Vertical layout: header | body | market | chronicle | footer
            let vchunks = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(1),
                    Constraint::Min(10),
                    Constraint::Length(11),  // market: 8 commodities + header + 2 borders
                    Constraint::Length(7),
                    Constraint::Length(1),
                ])
                .split(area);

            // Header. Сначала transient (save/load) — он перекрывает обычный
            // simulate-статус ровно на один кадр. Иначе — обычный simulate-статус.
            let (status_text, header_style) = if let Some(s) = transient_status.as_ref() {
                (
                    format!("  {s}"),
                    Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD),
                )
            } else {
                match &last_sim {
                    None => (
                        String::new(),
                        Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
                    ),
                    Some(Ok(())) => (
                        "  ✓ simulated".to_string(),
                        Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
                    ),
                    Some(Err(msg)) => {
                        let trimmed: String = msg.chars().take(60).collect();
                        (
                            format!("  ✗ {trimmed}"),
                            Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
                        )
                    }
                }
            };
            f.render_widget(
                Paragraph::new(format!(" ECOS WORLD SIMULATOR  ─  Year {:04}{}", year, status_text))
                    .style(header_style),
                vchunks[0],
            );

            // Body: table (60%) | detail (40%)
            let hchunks = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([Constraint::Percentage(60), Constraint::Percentage(40)])
                .split(vchunks[1]);

            // --- Region table ---
            let hdr = Row::new(
                ["Region", "Terrain", "Pop", "Ten", "Status", "Mode"].map(|h| {
                    Cell::from(h).style(Style::default().add_modifier(Modifier::BOLD))
                }),
            )
            .height(1);

            let rows: Vec<Row> = regions
                .iter()
                .zip(polities.iter())
                .map(|(r, p)| {
                    if is_extinct(&p.prod_mode) {
                        // Phase 24 / Этап 2A: полития окончательно вымерла.
                        // Регион остаётся на карте (терраин/имя) — но без хозяина.
                        Row::new([
                            Cell::from(r.name.clone()),
                            Cell::from(r.terrain.clone()),
                            Cell::from("       —"),
                            Cell::from("  —"),
                            Cell::from("✗ EXTINCT"),
                            Cell::from("EXTINCT"),
                        ]).style(Style::default().fg(Color::DarkGray).add_modifier(Modifier::DIM))
                    } else if is_collapsed(&p.prod_mode) {
                        Row::new([
                            Cell::from(r.name.clone()),
                            Cell::from(r.terrain.clone()),
                            Cell::from(format!("{:>8}", p.population)),
                            Cell::from("  —").style(Style::default().fg(Color::DarkGray)),
                            Cell::from("☠ COLLAPSED").style(Style::default().fg(Color::DarkGray)),
                            Cell::from("COLLAPSED").style(Style::default().fg(Color::DarkGray)),
                        ]).style(Style::default().fg(Color::DarkGray))
                    } else {
                        let col = tension_color(p.class_tension);
                        let war = if p.at_war_with != 0 { "⚔ " } else { "  " };
                        let mcol = mode_color(&p.prod_mode);
                        Row::new([
                            Cell::from(r.name.clone()),
                            Cell::from(r.terrain.clone()),
                            Cell::from(format!("{:>8}", p.population)),
                            Cell::from(format!("{:>3}", p.class_tension))
                                .style(Style::default().fg(col)),
                            Cell::from(format!("{}{}", war, tension_label(p.class_tension)))
                                .style(Style::default().fg(col)),
                            Cell::from(p.prod_mode.clone())
                                .style(Style::default().fg(mcol)),
                        ])
                    }
                })
                .collect();

            let table = Table::new(
                rows,
                [
                    Constraint::Length(16),
                    Constraint::Length(9),
                    Constraint::Length(9),
                    Constraint::Length(4),
                    Constraint::Length(12),
                    Constraint::Length(13),
                ],
            )
            .header(hdr)
            .block(Block::default().borders(Borders::ALL).title(" Regions "))
            .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
            .highlight_symbol("▶ ");

            f.render_stateful_widget(table, hchunks[0], &mut table_state);

            // --- Detail panel ---
            // Phase 24 — Этап 1: иерархия Region (геофон) → Polity (политика).
            // На Этапе 1 имена синхронизированы; разделитель «Region: X / Polity: Y»
            // готов к будущему расхождению на Этапе 2+.
            // Phase 24 / Этап 2A: для EXTINCT региона показываем «без хозяина»
            // в укороченном виде — у него нет правителя, классов, культуры.
            let detail_lines = if let (Some(r), Some(p)) =
                (regions.get(selected), polities.get(selected))
            {
                if is_extinct(&p.prod_mode) {
                    vec![
                        Line::from(vec![
                            Span::styled("Region: ", Style::default().fg(Color::DarkGray)),
                            Span::styled(
                                r.name.clone(),
                                Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
                            ),
                            Span::styled(
                                format!("  {} {}", r.terrain.trim(), r.climate.trim()),
                                Style::default().fg(Color::DarkGray),
                            ),
                        ]),
                        Line::from(""),
                        Line::from(Span::styled(
                            "✗ EXTINCT",
                            Style::default().fg(Color::DarkGray).add_modifier(Modifier::BOLD),
                        )),
                        Line::from(Span::styled(
                            "Polity has ceased to exist.",
                            Style::default().fg(Color::DarkGray),
                        )),
                        Line::from(Span::styled(
                            "Population scattered.",
                            Style::default().fg(Color::DarkGray),
                        )),
                        Line::from(""),
                        Line::from(Span::styled(
                            format!("Good (untended): {}", r.primary_good.trim()),
                            Style::default().fg(Color::DarkGray),
                        )),
                    ]
                } else {
                let tcol = tension_color(p.class_tension);
                let war_line = if p.at_war_with == 0 {
                    Line::from(Span::styled("Peace", Style::default().fg(Color::Green)))
                } else {
                    Line::from(Span::styled(
                        format!(
                            "⚔ WAR vs {:02} — yr {:02} ({})",
                            p.at_war_with,
                            p.war_year,
                            p.war_type.trim()
                        ),
                        Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
                    ))
                };

                // Цвет трейта правителя — намёк на характер
                let trait_color = match p.ruler_trait.trim() {
                    "AMBITIOUS" => Color::LightRed,
                    "CAUTIOUS"  => Color::LightBlue,
                    "CRUEL"     => Color::Red,
                    "PIOUS"     => Color::LightYellow,
                    "MERCANT"   => Color::LightCyan,
                    _           => Color::Gray,
                };

                // Топ-2 союзника и врага
                let allies = top_relations(&relations, selected, &region_names, 1, 2);
                let enemies = top_relations(&relations, selected, &region_names, -1, 2);

                let mut lines = vec![
                    Line::from(vec![
                        Span::styled("Region: ", Style::default().fg(Color::DarkGray)),
                        Span::styled(
                            r.name.clone(),
                            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
                        ),
                        Span::styled(
                            format!("  {} {}", r.terrain.trim(), r.climate.trim()),
                            Style::default().fg(Color::DarkGray),
                        ),
                    ]),
                    Line::from(vec![
                        Span::styled("Polity: ", Style::default().fg(Color::DarkGray)),
                        Span::styled(
                            p.name.clone(),
                            Style::default().fg(Color::White).add_modifier(Modifier::BOLD),
                        ),
                    ]),
                    Line::from(format!("Pop: {:>9}", p.population)),
                    Line::from(""),
                    // Ruler block
                    Line::from(vec![
                        Span::styled("👑 ", Style::default().fg(Color::Yellow)),
                        Span::styled(
                            format!("{} (age {})", p.ruler_name.trim(), p.ruler_age),
                            Style::default().fg(Color::White).add_modifier(Modifier::BOLD),
                        ),
                    ]),
                    Line::from(vec![
                        Span::raw("   "),
                        Span::styled(
                            p.ruler_trait.trim().to_string(),
                            Style::default().fg(trait_color).add_modifier(Modifier::BOLD),
                        ),
                        Span::raw(format!(" — {} yr reign", p.ruler_reign)),
                    ]),
                    Line::from(""),
                    Line::from(Span::styled(
                        format!("Tension: {:>3}  {}", p.class_tension, tension_label(p.class_tension)),
                        Style::default().fg(tcol),
                    )),
                    Line::from(format!(
                        "Awareness: {:>3}/100",
                        p.consciousness
                    )),
                    Line::from(vec![
                        Span::raw("Culture:   "),
                        Span::styled(
                            format!("⚔{:>2}", p.culture_mil),
                            Style::default().fg(if p.culture_mil >= 50 { Color::Red } else { Color::DarkGray }),
                        ),
                        Span::raw(" "),
                        Span::styled(
                            format!("💰{:>2}", p.culture_merc),
                            Style::default().fg(if p.culture_merc >= 50 { Color::LightCyan } else { Color::DarkGray }),
                        ),
                        Span::raw(" "),
                        Span::styled(
                            format!("☩{:>2}", p.culture_rel),
                            Style::default().fg(if p.culture_rel >= 50 { Color::LightYellow } else { Color::DarkGray }),
                        ),
                    ]),
                    Line::from(""),
                    Line::from(format!(
                        "Peasants  {:>3}%  Artisans {:>3}%",
                        p.peasants_pct, p.artisans_pct
                    )),
                    Line::from(format!(
                        "Merchants {:>3}%  Nobility {:>3}%",
                        p.merchants_pct, p.nobility_pct
                    )),
                    Line::from(format!("Clergy    {:>3}%", p.clergy_pct)),
                    Line::from(""),
                    Line::from(vec![
                        Span::raw("Mode:    "),
                        Span::styled(
                            p.prod_mode.clone(),
                            Style::default().fg(mode_color(&p.prod_mode)).add_modifier(Modifier::BOLD),
                        ),
                        // Phase 21: возраст эпохи — сколько ходов регион уже в этом модусе.
                        Span::styled(
                            format!("  ({}y)", p.mode_years),
                            Style::default().fg(Color::DarkGray),
                        ),
                    ]),
                    Line::from(format!("Good:    {}", r.primary_good)),
                    Line::from(format!("Surplus: {:.2}%", p.surplus_rate)),
                    Line::from(format!("Capital: {:.0}", p.capital_stock)),
                    Line::from(format!("Military:{:>6}", p.military_strength)),
                    Line::from(""),
                    war_line,
                ];

                // Politics block
                if !allies.is_empty() || !enemies.is_empty() {
                    lines.push(Line::from(""));
                    for (n, v) in &enemies {
                        lines.push(Line::from(vec![
                            Span::styled("⚔ ", Style::default().fg(Color::Red)),
                            Span::raw(format!("{} ({:+})", n.trim(), v)),
                        ]));
                    }
                    for (n, v) in &allies {
                        lines.push(Line::from(vec![
                            Span::styled("🤝 ", Style::default().fg(Color::Green)),
                            Span::raw(format!("{} ({:+})", n.trim(), v)),
                        ]));
                    }
                }

                // Tech block (Phase 13) — текущий top-tech и progress по 4 ветвям
                if let Some(t) = tech.get(selected) {
                    lines.push(Line::from(""));
                    lines.push(Line::from(Span::styled(
                        "─ Tech ─",
                        Style::default().fg(Color::DarkGray),
                    )));
                    for b in 0..BRANCH_COUNT {
                        lines.push(tech_line(b, t));
                    }
                }

                lines.push(Line::from(""));
                lines.push(Line::from(vec![
                    Span::raw("Neighbors: "),
                    Span::styled(
                        format!("{:02}  {:02}  {:02}", r.neighbors[0], r.neighbors[1], r.neighbors[2]),
                        Style::default().fg(Color::Yellow),
                    ),
                ]));

                lines
                } // конец живой ветки (else после is_extinct)
            } else {
                vec![]
            };

            match view {
                DetailView::Dashboard => {
                    render_dashboard(f, hchunks[1], regions, polities, year);
                }
                DetailView::TechTree => {
                    let region_name = regions
                        .get(selected)
                        .map(|r| r.name.clone())
                        .unwrap_or_default();
                    render_tech_tree(
                        f,
                        hchunks[1],
                        &region_name,
                        tech.get(selected),
                    );
                }
                DetailView::Region => {
                    render_detail_with_trends(
                        f,
                        hchunks[1],
                        detail_lines,
                        history.region(selected),
                    );
                }
            }

            // --- Market panel ---
            let mkt_hdr = Row::new(
                ["Good", "Supply", "Demand", "Price", "Status"].map(|h| {
                    Cell::from(h).style(Style::default().add_modifier(Modifier::BOLD))
                }),
            )
            .height(1);

            let mkt_rows: Vec<Row> = market
                .iter()
                .map(|c| {
                    let col = market_status_color(c.supply, c.demand);
                    let status = if c.crisis {
                        Span::styled(
                            "⚠ CRISIS",
                            Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
                        )
                    } else if c.demand > 0.0 && c.supply / c.demand < 0.8 {
                        Span::styled("scarcity", Style::default().fg(Color::Yellow))
                    } else if c.demand > 0.0 && (c.supply / c.demand - 1.0).abs() < 0.2 {
                        Span::styled("balanced", Style::default().fg(Color::Green))
                    } else {
                        Span::styled("surplus ", Style::default().fg(Color::Cyan))
                    };
                    Row::new([
                        Cell::from(c.name.clone()),
                        Cell::from(humanize(c.supply)).style(Style::default().fg(col)),
                        Cell::from(humanize(c.demand)),
                        Cell::from(format!("{:>5.2}", c.price))
                            .style(Style::default().fg(Color::White)),
                        Cell::from(Line::from(status)),
                    ])
                })
                .collect();

            let mkt_table = Table::new(
                mkt_rows,
                [
                    Constraint::Length(10),
                    Constraint::Length(10),
                    Constraint::Length(10),
                    Constraint::Length(7),
                    Constraint::Length(10),
                ],
            )
            .header(mkt_hdr)
            .block(Block::default().borders(Borders::ALL).title(" Market "));

            f.render_widget(mkt_table, vchunks[2]);

            // --- Chronicle ---
            let current_region_name = regions
                .get(selected)
                .map(|r| r.name.clone())
                .unwrap_or_default();
            let items: Vec<ListItem> = chronicle
                .iter()
                .rev()
                .filter(|e| chronicle_filter.matches(e, &current_region_name))
                .take(5)
                .map(|e| {
                    let col = match e.event_type.as_str() {
                        "WAR-START"   => Color::Red,
                        "WAR-END"     => Color::Yellow,
                        "REVOLUTION"  => Color::Magenta,
                        "CLASS-WAR"   => Color::Red,
                        "COLLAPSE"    => Color::DarkGray,
                        "REBIRTH"     => Color::Green,
                        "FAMINE"      => Color::LightRed,
                        "MODE-SHIFT"  => Color::Cyan,
                        "CRISIS"      => Color::LightYellow,
                        // Phase 8 climate hazards
                        "EPIDEMIC"    => Color::LightMagenta,
                        "DROUGHT"     => Color::LightYellow,
                        "CAVE-IN"     => Color::DarkGray,
                        "BUMPER-CROP" => Color::LightGreen,
                        "BAD-HARVEST" => Color::LightRed,
                        "STORM"       => Color::Blue,
                        "BLIGHT"      => Color::LightGreen,
                        // Phase 9 — лица
                        "RULER-DEATH" => Color::Gray,
                        "RULER-RISE"  => Color::White,
                        // Phase 10 — миграция
                        "REFUGEES"    => Color::LightYellow,
                        // Phase 13 — техи
                        "TECH-LEARNED" => Color::LightCyan,
                        // Phase 14 — военный грабёж
                        "TECH-LOOT"    => Color::Magenta,
                        // Phase 15 — инновации
                        "INNOVATION"   => Color::LightYellow,
                        _             => Color::Gray,
                    };
                    ListItem::new(Line::from(vec![
                        Span::styled(
                            format!("{:04} ", e.year),
                            Style::default().fg(Color::DarkGray),
                        ),
                        Span::styled(
                            format!("{:<14}", e.event_type),
                            Style::default().fg(col).add_modifier(Modifier::BOLD),
                        ),
                        Span::styled(
                            format!(" {:18} ", e.region),
                            Style::default().fg(Color::White),
                        ),
                        Span::raw(e.description.clone()),
                    ]))
                })
                .collect();

            let chron_title = format!(" Chronicle [filter: {}] ", chronicle_filter.label());
            f.render_widget(
                List::new(items)
                    .block(Block::default().borders(Borders::ALL).title(chron_title)),
                vchunks[3],
            );

            // Footer
            let (auto_label, auto_color) = if auto_step {
                ("Auto: ON ", Color::Green)
            } else {
                ("Auto: OFF", Color::DarkGray)
            };
            let view_label = match view {
                DetailView::Region => " View: Region",
                DetailView::Dashboard => " View: World ",
                DetailView::TechTree => " View: Tech  ",
            };
            let view_color = match view {
                DetailView::Region => Color::DarkGray,
                DetailView::Dashboard => Color::Cyan,
                DetailView::TechTree => Color::LightGreen,
            };
            f.render_widget(
                Paragraph::new(Line::from(vec![
                    Span::raw(" [N] Next "),
                    Span::styled("[A] ", Style::default().fg(auto_color)),
                    Span::styled(auto_label, Style::default().fg(auto_color)),
                    Span::raw(" [W]orld [T]ech"),
                    Span::styled(view_label, Style::default().fg(view_color)),
                    Span::raw(format!(" [F] {}", chronicle_filter.label())),
                    Span::raw(" [S]ave [L]oad [↑↓] [Q]"),
                ]))
                .style(Style::default().fg(Color::DarkGray)),
                vchunks[4],
            );

            // Phase 20: модальные overlay'и save/load поверх UI.
            if let Some(d) = slot_dialog {
                render_slot_dialog(f, area, d);
            }
        })?;
        // Сбрасываем transient статус после рендера: показывается ровно 1 кадр.
        // (Поскольку каждый кадр рендерится после event/auto-step, юзер видит "✓ saved"
        // как минимум до следующего нажатия — чего достаточно.)
        let _ = transient_status.take();

        // Auto-step: триггер если режим включён и прошло 500мс с прошлого шага.
        if auto_step && last_step.elapsed() >= auto_step_interval {
            year += 1;
            last_sim = Some(run_simulate(year));
            last_step = std::time::Instant::now();
        }

        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind != KeyEventKind::Press {
                    continue 'main;
                }
                // Если открыт модальный диалог save/load — он ловит весь ввод.
                if let Some(dialog) = slot_dialog {
                    match key.code {
                        KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                            slot_dialog = None;
                        }
                        KeyCode::Char(c @ '1'..='5') => {
                            let idx = c.to_digit(10).unwrap() as usize;
                            match dialog {
                                SlotDialog::Save => {
                                    transient_status = Some(match saves::save_to_slot(idx) {
                                        Ok(()) => format!("✓ saved to slot {idx}"),
                                        Err(e) => format!("✗ save failed: {e}"),
                                    });
                                }
                                SlotDialog::Load => {
                                    let slots = saves::list_slots();
                                    let occupied = slots.iter().any(|s| s.idx == idx && s.year.is_some());
                                    if occupied {
                                        match saves::load_from_slot(idx) {
                                            Ok(()) => {
                                                year = saves::current_year();
                                                last_sim = None;
                                                history = WorldHistory::new(10);
                                                transient_status = Some(format!(
                                                    "✓ loaded slot {idx} (year {year:04})"
                                                ));
                                            }
                                            Err(e) => {
                                                transient_status = Some(format!("✗ load failed: {e}"));
                                            }
                                        }
                                    } else {
                                        // Молчаливо игнорируем — пустой slot.
                                        continue 'main;
                                    }
                                }
                            }
                            slot_dialog = None;
                        }
                        _ => {}
                    }
                    continue 'main;
                }
                match key.code {
                    KeyCode::Char('q') | KeyCode::Char('Q') => break,
                    KeyCode::Char('n') | KeyCode::Char('N') => {
                        year += 1;
                        last_sim = Some(run_simulate(year));
                        last_step = std::time::Instant::now();
                    }
                    KeyCode::Char('a') | KeyCode::Char('A') => {
                        auto_step = !auto_step;
                        last_step = std::time::Instant::now();
                    }
                    KeyCode::Char('w') | KeyCode::Char('W') => {
                        view = if matches!(view, DetailView::Dashboard) {
                            DetailView::Region
                        } else {
                            DetailView::Dashboard
                        };
                    }
                    KeyCode::Char('t') | KeyCode::Char('T') => {
                        view = if matches!(view, DetailView::TechTree) {
                            DetailView::Region
                        } else {
                            DetailView::TechTree
                        };
                    }
                    KeyCode::Char('f') | KeyCode::Char('F') => {
                        chronicle_filter = chronicle_filter.next();
                    }
                    KeyCode::Char('s') | KeyCode::Char('S') => {
                        slot_dialog = Some(SlotDialog::Save);
                    }
                    KeyCode::Char('l') | KeyCode::Char('L') => {
                        slot_dialog = Some(SlotDialog::Load);
                    }
                    KeyCode::Down if selected + 1 < n => {
                        selected += 1;
                        table_state.select(Some(selected));
                    }
                    KeyCode::Up if selected > 0 => {
                        selected -= 1;
                        table_state.select(Some(selected));
                    }
                    _ => {}
                }
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    Ok(())
}

/// Одна строка tech блока: ветвь, название текущего top-тех, progress.
/// Phase 18: max level = 4. DONE только при достижении L4 (полное древо).
fn tech_line(branch: usize, t: &RegionTech) -> Line<'static> {
    let lvl = t.levels[branch];
    let name = t.current_tech_name(branch);
    let progress = t.progress[branch];
    let (color, status) = if lvl >= 4 {
        (Color::LightGreen, "DONE".to_string())
    } else {
        let bar_len = (progress / 10) as usize; // 0..10
        let bar: String = "▓".repeat(bar_len) + &"░".repeat(10 - bar_len);
        (Color::DarkGray, format!("L{}+{} {}%", lvl, bar, progress))
    };
    Line::from(vec![
        Span::styled(
            format!("  {} ", BRANCH_SHORT[branch]),
            Style::default().fg(Color::DarkGray),
        ),
        Span::styled(
            format!("{:<9}", name),
            Style::default().fg(Color::White),
        ),
        Span::styled(format!(" {}", status), Style::default().fg(color)),
    ])
}

/// Detail panel + sparklines на 3 трендах (tension / pop / capital).
fn render_detail_with_trends(
    f: &mut Frame,
    area: Rect,
    detail_lines: Vec<Line>,
    history: Option<&crate::history::RegionHistory>,
) {
    // Внешний бордюр
    let outer = Block::default().borders(Borders::ALL).title(" Detail ");
    let inner_area = outer.inner(area);
    f.render_widget(outer, area);

    // Делим внутреннюю область: текст наверху, 3 sparkline внизу (по 2 строки каждый)
    // Минимум 6 строк нужно на 3 sparkline + заголовок. Если совсем тесно, упадём в graceful.
    let trends_height: u16 = 7;
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(5), Constraint::Length(trends_height)])
        .split(inner_area);

    f.render_widget(Paragraph::new(detail_lines), chunks[0]);

    // Заголовок и три sparkline
    let trend_block = Block::default().borders(Borders::TOP).title(" Trends 50yr ");
    let trends_inner = trend_block.inner(chunks[1]);
    f.render_widget(trend_block, chunks[1]);

    let trend_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(2),
            Constraint::Length(2),
            Constraint::Length(2),
        ])
        .split(trends_inner);

    let (tension_data, pop_data, capital_data): (Vec<u64>, Vec<u64>, Vec<u64>) =
        match history {
            Some(h) => (
                h.tension.iter().copied().collect(),
                h.population.iter().copied().collect(),
                h.capital.iter().copied().collect(),
            ),
            None => (vec![], vec![], vec![]),
        };

    render_named_sparkline(f, trend_chunks[0], "tens ", &tension_data, Color::Yellow);
    render_named_sparkline(f, trend_chunks[1], "pop  ", &pop_data, Color::Cyan);
    render_named_sparkline(f, trend_chunks[2], "cap  ", &capital_data, Color::LightGreen);
}

fn render_named_sparkline(f: &mut Frame, area: Rect, label: &str, data: &[u64], color: Color) {
    if area.height == 0 {
        return;
    }
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Length(5), Constraint::Min(0)])
        .split(area);
    f.render_widget(
        Paragraph::new(label).style(Style::default().fg(Color::DarkGray)),
        chunks[0],
    );
    let sparkline = Sparkline::default()
        .data(data)
        .style(Style::default().fg(color));
    f.render_widget(sparkline, chunks[1]);
}

/// Tech tree view с L3 развилками. Для каждой ветви показывает L1, L2 и
/// L3 как 3 альтернативы. Если L3 достигнут — выбранная зелёным, остальные
/// тёмно-серые (исторически закрыты). Если ещё не L3 — все 3 показаны как
/// возможные (светло-серым).
fn render_tech_tree(
    f: &mut Frame,
    area: Rect,
    region_name: &str,
    tech: Option<&RegionTech>,
) {
    use crate::tech::TECH_NAMES;

    let mut lines: Vec<Line> = vec![];
    lines.push(Line::from(Span::styled(
        format!(" Tech Tree — {}", region_name.trim()),
        Style::default().fg(Color::LightGreen).add_modifier(Modifier::BOLD),
    )));
    lines.push(Line::from(""));

    let labels = ["PROD", "ORG ", "KNOW", "POW "];
    let branch_colors = [Color::LightYellow, Color::LightCyan, Color::LightMagenta, Color::LightRed];

    for b in 0..BRANCH_COUNT {
        let level = tech.map(|t| t.levels[b]).unwrap_or(0);
        let progress = tech.map(|t| t.progress[b]).unwrap_or(0);
        let l3_choice = tech.map(|t| t.l3_choice[b]).unwrap_or(0);
        let l4_choice = tech.map(|t| t.l4_choice[b]).unwrap_or(0);

        // Строка: ветвь | L1 → L2 →
        lines.push(Line::from(vec![
            Span::styled(
                format!("  {} ", labels[b]),
                Style::default().fg(branch_colors[b]).add_modifier(Modifier::BOLD),
            ),
            tech_cell(1, level, progress, TECH_NAMES[b][1]),
            Span::raw(" → "),
            tech_cell(2, level, progress, TECH_NAMES[b][2]),
            Span::raw(" →"),
        ]));
        // L3 развилка (3 варианта). Под выбранным — L4 sub-techs.
        for alt in 1..=3u8 {
            lines.push(Line::from(vec![
                Span::raw("              "),
                tech_l3_alt(level, l3_choice, alt, L3_ALTERNATIVES[b][alt as usize]),
            ]));
            // L4 показываем только под выбранной L3 alt
            if l3_choice == alt && level >= 3 {
                let l4_name_1 = L4_SUBTECHS[b][alt as usize][1];
                let l4_name_2 = L4_SUBTECHS[b][alt as usize][2];
                lines.push(Line::from(vec![
                    Span::raw("                  ↳ "),
                    tech_l4_alt(level, l4_choice, 1, l4_name_1, progress),
                ]));
                lines.push(Line::from(vec![
                    Span::raw("                  ↳ "),
                    tech_l4_alt(level, l4_choice, 2, l4_name_2, progress),
                ]));
            }
        }
        lines.push(Line::from(""));
    }

    lines.push(Line::from(Span::styled(
        " ✓ done  ⏳ %  ░ locked  ▶ chosen path  ↳ L4 sub-tech",
        Style::default().fg(Color::DarkGray),
    )));

    if let Some(t) = tech {
        let total: u32 = t.levels.iter().map(|&l| l as u32).sum();
        lines.push(Line::from(""));
        lines.push(Line::from(vec![
            Span::raw(" Total tech levels: "),
            Span::styled(
                format!("{}/16", total),
                Style::default().fg(if total >= 16 { Color::Green } else { Color::White })
                    .add_modifier(Modifier::BOLD),
            ),
        ]));
    }

    f.render_widget(
        Paragraph::new(lines)
            .block(Block::default().borders(Borders::ALL).title(" Tech ")),
        area,
    );
}

/// Ячейка для L1/L2: ✓ done, ⏳ N%, ░ locked.
fn tech_cell(lvl: u8, current_level: u8, progress: u8, name: &str) -> Span<'static> {
    if current_level >= lvl {
        Span::styled(
            format!("✓{:<11}", name),
            Style::default().fg(Color::Green).add_modifier(Modifier::BOLD),
        )
    } else if current_level + 1 == lvl {
        Span::styled(
            format!("⏳{}{:>3}%", &name[..name.len().min(7)], progress),
            Style::default().fg(Color::Yellow),
        )
    } else {
        Span::styled(
            format!("░{:<11}", name),
            Style::default().fg(Color::DarkGray),
        )
    }
}

/// L3 alternative: если выбрана — ▶ зелёным, иначе если L3 достигнут — серый ·,
/// если L3 не достигнут — серый · (всё ещё возможно, но в рассеянной потенции).
fn tech_l3_alt(current_level: u8, l3_choice: u8, alt: u8, name: &str) -> Span<'static> {
    if current_level >= 3 && l3_choice == alt {
        Span::styled(
            format!("▶ {} (chosen)", name),
            Style::default().fg(Color::LightGreen).add_modifier(Modifier::BOLD),
        )
    } else if current_level >= 3 {
        Span::styled(
            format!("· {}", name),
            Style::default().fg(Color::DarkGray),
        )
    } else {
        Span::styled(
            format!("· {}", name),
            Style::default().fg(Color::Gray),
        )
    }
}

/// L4 sub-tech: достижение четвёртого уровня глубины.
/// L4 показывается только под выбранной L3 alt.
fn tech_l4_alt(current_level: u8, l4_choice: u8, alt: u8, name: &str, progress: u8) -> Span<'static> {
    if current_level >= 4 && l4_choice == alt {
        Span::styled(
            format!("✓ {} (chosen)", name),
            Style::default().fg(Color::Green).add_modifier(Modifier::BOLD),
        )
    } else if current_level >= 4 {
        // L4 выбрано — другие отвергнуты
        Span::styled(
            format!("· {}", name),
            Style::default().fg(Color::DarkGray),
        )
    } else if current_level == 3 && alt == 1 {
        // Прогресс к L4 показываем только один раз (на первой alt) с %
        Span::styled(
            format!("⏳ researching... {}%", progress),
            Style::default().fg(Color::Yellow),
        )
    } else if current_level == 3 {
        // На L3 — обе alt видны как «возможные»
        Span::styled(
            format!("· {}", name),
            Style::default().fg(Color::Gray),
        )
    } else {
        // L3 не достигнут — L4 заперто
        Span::styled(String::new(), Style::default())
    }
}

/// Dashboard: суммарная картина мира — всего населения, капитала, активных войн,
/// распределение эпох. Toggled by [W].
/// Phase 24 — Этап 1: обращение к политическим полям через `polities[i]`,
/// геофон-имена через `regions[i]`.
fn render_dashboard(
    f: &mut Frame,
    area: Rect,
    regions: &[Region],
    polities: &[Polity],
    year: u32,
) {
    let total_pop: u64 = polities.iter().map(|p| p.population as u64).sum();
    let total_cap: u64 = polities.iter().map(|p| p.capital_stock as u64).sum();
    let active_wars: usize = polities.iter().filter(|p| p.at_war_with != 0).count() / 2;

    // Era distribution
    let mut counts = std::collections::BTreeMap::new();
    for p in polities {
        *counts.entry(p.prod_mode.trim().to_string()).or_insert(0u32) += 1;
    }
    // Order modes by ladder
    let order = [
        "PRIMITIVE",
        "SLAVE",
        "FEUDAL",
        "MERCANTILE",
        "PROTO-INDUSTRL",
        "INDUSTRIAL",
        "IMPERIAL",
        "SOCIALIST",
        "COLLAPSED",
        "EXTINCT", // Phase 24 / Этап 2A
    ];

    // Most warlike (highest war_year), most rebellious (highest tension), oldest ruler.
    // Возвращаем индекс — потом lookup на regions[i] для имени территории.
    let warlike: Option<(usize, &Polity)> = polities
        .iter()
        .enumerate()
        .filter(|(_, p)| !is_dormant(&p.prod_mode))
        .max_by_key(|(_, p)| p.war_year);
    let rebel: Option<(usize, &Polity)> = polities
        .iter()
        .enumerate()
        .filter(|(_, p)| !is_dormant(&p.prod_mode))
        .max_by_key(|(_, p)| p.class_tension);
    let oldest_ruler: Option<(usize, &Polity)> = polities
        .iter()
        .enumerate()
        .filter(|(_, p)| !is_dormant(&p.prod_mode))
        .max_by_key(|(_, p)| p.ruler_age);

    let mut lines: Vec<Line> = vec![
        Line::from(Span::styled(
            format!(" Year {:04}", year),
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(format!("Total pop:    {}", humanize(total_pop as f64))),
        Line::from(format!("Total cap:    {}", humanize(total_cap as f64))),
        Line::from(format!("Active wars:    {}", active_wars)),
        Line::from(""),
        Line::from(Span::styled(
            "Era distribution:",
            Style::default().add_modifier(Modifier::BOLD),
        )),
    ];
    for &mode in &order {
        let n = counts.get(mode).copied().unwrap_or(0);
        if n > 0 {
            let bar: String = "█".repeat(n as usize);
            lines.push(Line::from(vec![
                Span::raw(format!("  {:14}", mode)),
                Span::styled(bar, Style::default().fg(mode_color(mode))),
                Span::raw(format!(" {}", n)),
            ]));
        }
    }
    lines.push(Line::from(""));
    if let Some((i, p)) = warlike {
        if p.at_war_with != 0 || p.war_year > 0 {
            lines.push(Line::from(format!(
                "Most warlike:  {} (war yr {})",
                regions.get(i).map(|r| r.name.trim()).unwrap_or(""),
                p.war_year
            )));
        }
    }
    if let Some((i, p)) = rebel {
        if p.class_tension > 50 {
            lines.push(Line::from(vec![
                Span::raw("Most rebellious: "),
                Span::styled(
                    format!(
                        "{} ({})",
                        regions.get(i).map(|r| r.name.trim()).unwrap_or(""),
                        p.class_tension
                    ),
                    Style::default().fg(tension_color(p.class_tension)),
                ),
            ]));
        }
    }
    if let Some((i, p)) = oldest_ruler {
        lines.push(Line::from(format!(
            "Oldest ruler:  {} (age {}, {})",
            p.ruler_name.trim(),
            p.ruler_age,
            regions.get(i).map(|r| r.name.trim()).unwrap_or("")
        )));
    }

    f.render_widget(
        Paragraph::new(lines).block(Block::default().borders(Borders::ALL).title(" World ")),
        area,
    );
}
