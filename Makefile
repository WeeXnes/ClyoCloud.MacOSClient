.PHONY: all app run clean install

all: app

app:
	@./scripts/build_app.sh

run: app
	@echo "==> Launching ClyoCloud.app..."
	@open build/ClyoCloud.app

install: app
	@echo "==> Installing to /Applications/ClyoCloud.app..."
	@rm -rf /Applications/ClyoCloud.app
	@cp -R build/ClyoCloud.app /Applications/
	@echo "Installed successfully to /Applications/ClyoCloud.app"

clean:
	@rm -rf build .build
