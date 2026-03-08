# Desktop Sorter (Flutter + Dart)

This folder contains a Flutter desktop rewrite of Desktop Sorter with feature parity goals:

- tray icon + tray menu (`Open settings`, `Sort now`, monitoring toggle, `Exit`)
- hide to tray when closing
- restore from tray click
- desktop watcher with debounce and minimum file age handling
- optional pause while fullscreen app is active (Windows)
- sort rules (`Move`, `Pattern`, `Trash`, `Keep`)
- wildcard include/exclude matching (`*`, `?`)
- ordered rules with up/down controls
- autostart toggle
- persistent TOML config at the same default location

## Quick start (Windows)

1. Install Flutter SDK and enable Windows desktop:
   - `flutter config --enable-windows-desktop`
2. In this folder, generate host files (if missing):
   - `flutter create --platforms=windows .`
3. Fetch dependencies:
   - `flutter pub get`
4. Run:
   - `flutter run -d windows`

## Build

- `flutter build windows --release`

## CLI options

- `--config <path>`
- `--hidden`
- `--help`

Environment override:

- `DESKTOP_SORTER_CONFIG`

## Notes

- Config format is TOML and matches the Rust app schema (`desktop_path`, `rules`, etc.).
- The Windows tray icon is loaded from `assets/app_icon.png`.
- The `Trash` action uses Windows shell APIs to move files to Recycle Bin.