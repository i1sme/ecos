mod engine;
mod history;
mod market;
mod relations;
mod saves;
mod tech;
mod ui;
mod world;

fn main() {
    if let Err(e) = ui::run() {
        eprintln!("Error: {e}");
        std::process::exit(1);
    }
}
