all: cobol rust

cobol:
	/opt/homebrew/bin/cobc -x -free cobol/world.cob    -o cobol/world
	/opt/homebrew/bin/cobc -x -free cobol/simulate.cob -o cobol/simulate

rust:
	cargo build --release

run:
	cargo run --release

clean:
	rm -f cobol/world cobol/simulate cobol/world.dat cobol/chronicle.dat
	cargo clean
