.PHONY: all build install run clean

all: build

build:
	swift build -c release

install:
	./scripts/install.sh

run: install
	open /Applications/Specter.app

clean:
	swift package clean
	rm -rf Specter.app
