# Dispel

Menubar app for macOS that suppresses accidental tap‑to‑clicks while typing. It helps prevent the “cursor jumps while typing” problem caused by stray trackpad taps.

- macOS 15+ (Sequoia), Apple Silicon (arm64) only
- Accessibility permission required (no root, no daemons)
- Built with AppKit; lives in the menu bar (no Dock icon)

## Features
- Suppression delay slider: 0–1000 ms in 100 ms steps (0 = off)
- Advanced controls:
  - Activation delay (default 20 ms, range 0–100 ms in 10 ms steps)
  - Trigger on Key Down or Key Up (default Key Up)
  - Select which mouse phases to block: Mouse Down (default on), Mouse Up (default off)
- Recovers automatically if the system disables the event tap by timeout
- Low CPU overhead; immediate live changes

## Why this exists
Some users observe “ghost taps” while typing (often a palm grazing the trackpad), which can move the insertion point and cause text to jump. Dispel blocks clicks for a short window after keys are pressed to avoid those stray taps.

## Build

Prerequisites
- Xcode 16+
- macOS 15+ on Apple Silicon

Options
- Xcode: open `Dispel/Dispel.xcodeproj` and run the `Dispel` scheme.
- Makefile: run `make build` to archive and export the app into `./build`.

Make targets
- `make build` → `build/Dispel.xcarchive` and `build/Dispel.app`
- `make archive` → `build/Dispel.xcarchive`
- `make export` → export `.app` using `ExportOptions.plist` into `./build`
- `make open` → open the exported app
- `make clean` → remove `./build`

Export options
- The Makefile uses `./ExportOptions.plist`. Adjust its contents if you need specific signing/export behaviors.

## Run and grant permission
1) Launch Dispel; an icon appears in the menu bar.
2) Open the menu and click “Grant Accessibility Permission…”.
3) In System Settings → Privacy & Security → Accessibility, enable Dispel. The status in the menu should show “Active” once permission is granted and suppression is on.

## Usage
- Set the suppression delay with the main slider. 200–300 ms is a good starting point; 0 ms disables suppression entirely.
- If Finder rename or other click‑to‑focus flows feel blocked, increase the Activation delay to 20–40 ms (Advanced).
- For maximum protection, set Trigger = Key Down and optionally block Mouse Up (Advanced), noting this can interfere a bit more with click‑to‑focus.

## Defaults
- Trigger: Key Up
- Block phases: Mouse Down (on), Mouse Up (off)
- Activation delay: 20 ms
- Suppression delay: set by your slider (default 200 ms on first run)

## Settings storage
- Uses UserDefaults (per-user). Keys:
  - `delayMs`, `activationDelayMs`, `trigger` ("keyDown"/"keyUp"), `blockMouseDown` (Bool), `blockMouseUp` (Bool)
- On a sandboxed build, values are stored under the app’s container preferences plist.

## Troubleshooting
- No effect on clicks: ensure Accessibility permission is ON; relaunch the app after enabling.
- Finder rename glitches: keep Trigger = Key Up and use Activation delay ~20–40 ms.
- Over‑blocking: reduce suppression delay, uncheck “Mouse Up”, or set Trigger = Key Up.
- Under‑blocking: increase suppression delay; reduce or zero Activation delay; consider Trigger = Key Down and block both phases.
- After sleep the app stops blocking: it should auto‑recover; if not, toggle suppression or relaunch the app.

## Security & Privacy
- Dispel requests Accessibility permission to observe/modify input events locally. It does not log keystrokes or send data anywhere.
- No network access required; no background daemons installed.

## Roadmap
- Start at login (via SMAppService) — optional
- One‑click presets (e.g., “Aggressive mode”)
- Experimental “trackpad‑only” filtering (best effort via IOKit)

## Acknowledgements
- Inspired by [TouchGuard](https://github.com/thesyntaxinator/TouchGuard).
- Google Gemini and OpenAI GPT families of models and all the labs involved making these possible 🙏